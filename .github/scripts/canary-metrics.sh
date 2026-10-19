#!/usr/bin/env bash
set -euo pipefail

project=$1
service=$2
stable=$3
candidate=$4
start=$5

min_requests=100
max_error_rate_increase=0.01
max_latency_ratio=2
min_latency_ms=100
timeout=360

query() {
  local metric=$1 reducer=$2
  shift 2
  local end period groups=()
  end=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  period=$(($(date -d "$end" +%s) - $(date -d "$start" +%s)))
  for field in "$@"; do
    groups+=(--data-urlencode "aggregation.groupByFields=$field")
  done
  curl --silent --fail-with-body --get "https://monitoring.googleapis.com/v3/projects/$project/timeSeries" \
    --header "Authorization: Bearer $(gcloud auth print-access-token)" \
    --data-urlencode "filter=metric.type=\"run.googleapis.com/$metric\" AND resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"$service\"" \
    --data-urlencode "interval.startTime=$start" \
    --data-urlencode "interval.endTime=$end" \
    --data-urlencode "aggregation.alignmentPeriod=${period}s" \
    --data-urlencode "aggregation.perSeriesAligner=ALIGN_DELTA" \
    --data-urlencode "aggregation.crossSeriesReducer=$reducer" \
    "${groups[@]}"
}

count() {
  echo "$counts" | jq --arg r "$1" --arg c "${2:-}" \
    '[.timeSeries[]? | select(.resource.labels.revision_name == $r and ($c == "" or .metric.labels.response_code_class == $c)) | .points[].value.int64Value | tonumber] | add // 0'
}

p95() {
  echo "$latencies" | jq --arg r "$1" \
    '[.timeSeries[]? | select(.resource.labels.revision_name == $r) | .points[].value.doubleValue] | max // 0'
}

check() {
  awk "BEGIN { exit !($1) }"
}

deadline=$((SECONDS + timeout))
while true; do
  counts=$(query request_count REDUCE_SUM resource.label.revision_name metric.label.response_code_class)
  stable_total=$(count "$stable")
  candidate_total=$(count "$candidate")
  if ((stable_total >= min_requests && candidate_total >= min_requests)); then
    break
  fi
  if ((SECONDS >= deadline)); then
    echo "Timed out waiting for metrics: stable has $stable_total requests, candidate has $candidate_total"
    exit 1
  fi
  echo "Waiting for metrics: stable has $stable_total requests, candidate has $candidate_total" >&2
  sleep 30
done

latencies=$(query request_latencies REDUCE_PERCENTILE_95 resource.label.revision_name)

stable_errors=$(count "$stable" 5xx)
candidate_errors=$(count "$candidate" 5xx)
stable_rate=$(awk "BEGIN { print $stable_errors / $stable_total }")
candidate_rate=$(awk "BEGIN { print $candidate_errors / $candidate_total }")
stable_p95=$(p95 "$stable")
candidate_p95=$(p95 "$candidate")

echo "Stable $stable: $stable_total requests, $stable_errors 5xx (rate $stable_rate), p95 ${stable_p95}ms"
echo "Candidate $candidate: $candidate_total requests, $candidate_errors 5xx (rate $candidate_rate), p95 ${candidate_p95}ms"

failed=0
if check "$candidate_rate > $stable_rate + $max_error_rate_increase"; then
  echo "Candidate 5xx rate is more than $max_error_rate_increase above stable"
  failed=1
fi
if check "$candidate_p95 > $min_latency_ms && $candidate_p95 > $stable_p95 * $max_latency_ratio"; then
  echo "Candidate p95 latency is more than ${max_latency_ratio}x stable"
  failed=1
fi
exit $failed
