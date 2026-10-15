#!/usr/bin/env bash
set -euo pipefail

url=$1
version=$2
duration=$3

new=0
old=0
end=$((SECONDS + duration))

while ((SECONDS < end)); do
  body=$(curl --silent --fail --max-time 5 "$url/") || { echo "Request failed"; exit 1; }
  echo "$body" | jq --exit-status '.message and .timestamp and .version' > /dev/null || { echo "Bad response: $body"; exit 1; }
  if [[ $(echo "$body" | jq --raw-output .version) == "$version" ]]; then
    new=$((new + 1))
  else
    old=$((old + 1))
  fi
done

echo "$((new + old)) requests: $new served by $version, $old served by the previous version"

if ((new == 0 || old == 0)); then
  echo "Expected traffic to be split between both versions"
  exit 1
fi
