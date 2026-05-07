#!/usr/bin/env bash
# Полный re-login: читает .env (login + password) → выпускает access + refresh → сохраняет.
# Запускай когда refresh устарел (>30 дней без активности) или впервые.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

do_login
ok "Готово. Токены в $TOKENS_FILE"
