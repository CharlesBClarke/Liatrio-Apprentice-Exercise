#!/usr/bin/env bash
set -euo pipefail

url=$1
version=$2
duration=$3
max_failed_percent=2

new=0
old=0
failed=0
end=$((SECONDS + duration))

while ((SECONDS < end)); do
  if ! body=$(curl --silent --fail --max-time 5 "$url/"); then
    failed=$((failed + 1))
    continue
  fi
  echo "$body" | jq --exit-status '.message and .timestamp and .version' > /dev/null || { echo "Bad response: $body"; exit 1; }
  if [[ $(echo "$body" | jq --raw-output .version) == "$version" ]]; then
    new=$((new + 1))
  else
    old=$((old + 1))
  fi
done

total=$((new + old + failed))
echo "$total requests: $new served by $version, $old served by the previous version, $failed failed"

if ((failed * 100 > total * max_failed_percent)); then
  echo "More than $max_failed_percent% of requests failed"
  exit 1
fi

if ((new == 0 || old == 0)); then
  echo "Expected traffic to be split between both versions"
  exit 1
fi
