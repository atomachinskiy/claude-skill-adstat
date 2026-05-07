#!/usr/bin/env bash
# Все TG-аккаунты (юр.лица) с балансами и статусом.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

api_request GET /api/accounts/telegram/ | jq '.items[] | {
  account_id,
  account_name,
  status,
  legal_name,
  balance_active,
  balance_available,
  balance_total,
  balance_spent,
  objects,
  category_name
}'
