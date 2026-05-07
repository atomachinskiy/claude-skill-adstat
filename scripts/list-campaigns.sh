#!/usr/bin/env bash
# Кампании.
# Usage:
#   list-campaigns.sh                      — все кампании за всю историю
#   list-campaigns.sh --period=month       — за месяц
#   list-campaigns.sh --period=month --status=active
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

PARAMS="--param limit=200"
for arg in "$@"; do
  case "$arg" in
    --period=*) PARAMS="$PARAMS --param period=${arg#*=}" ;;
    --status=*) PARAMS="$PARAMS --param status=${arg#*=}" ;;
    *) PARAMS="$PARAMS --param ${arg}" ;;
  esac
done

# shellcheck disable=SC2086
python3 "$SCRIPT_DIR/cli.py" GET /api/v2/campaigns/ $PARAMS --pretty
