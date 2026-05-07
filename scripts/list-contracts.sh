#!/usr/bin/env bash
# ОРД-контракты пользователя.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

api_request GET /api/contract/ | jq .
