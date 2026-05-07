#!/usr/bin/env bash
# Объявления.
# Usage:
#   list-ads.sh                                — все объявления (limit 200)
#   list-ads.sh --status=active                — только активные
#   list-ads.sh --status=stopped --limit=50
#   list-ads.sh --campaign_id=22990
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

PARAMS="--param limit=200"
for arg in "$@"; do
  case "$arg" in
    --limit=*)       PARAMS=$(echo "$PARAMS" | sed 's/--param limit=200//'); PARAMS="$PARAMS --param limit=${arg#*=}" ;;
    --status=*)      PARAMS="$PARAMS --param status=${arg#*=}" ;;
    --campaign_id=*) PARAMS="$PARAMS --param campaign_id=${arg#*=}" ;;
    --account_id=*)  PARAMS="$PARAMS --param account_id=${arg#*=}" ;;
    *)               PARAMS="$PARAMS --param ${arg}" ;;
  esac
done

# shellcheck disable=SC2086
python3 "$SCRIPT_DIR/cli.py" GET /api/v2/advertisement/ $PARAMS --pretty
