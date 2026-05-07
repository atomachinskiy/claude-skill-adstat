#!/usr/bin/env bash
# Сколько кампаний в каждом статусе.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

for status in active stopped deleted on_hold declined in_review; do
  count=$(api_request GET "/api/dashboard/campaigns/$status/count/" | jq -r '.count // "?"')
  printf "%-12s %s\n" "$status" "$count"
done
