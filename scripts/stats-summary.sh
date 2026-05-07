#!/usr/bin/env bash
# Сводка stats за период.
# Usage:
#   stats-summary.sh              — за месяц по telegram (default)
#   stats-summary.sh week
#   stats-summary.sh today telegram
#
# Период: today | yesterday | week | month
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

PERIOD="${1:-month}"
PLATFORM="${2:-telegram}"

echo "=== Stats $PERIOD / $PLATFORM ==="
api_request GET "/api/dashboard/statistics/$PERIOD/$PLATFORM/" | jq .
echo
echo "=== Expenses (динамика по датам) ==="
api_request GET "/api/dashboard/statistics/expenses/$PERIOD/$PLATFORM/" | jq .
echo
echo "=== CPM (динамика по датам) ==="
api_request GET "/api/dashboard/statistics/cpm/$PERIOD/$PLATFORM/" | jq .
