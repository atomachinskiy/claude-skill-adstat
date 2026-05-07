#!/usr/bin/env bash
# Текущий баланс рекламного кабинета.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

api_request GET /api/dashboard/balances | jq .
