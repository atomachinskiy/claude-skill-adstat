#!/usr/bin/env bash
# Обновить access по refresh (без участия пользователя). Используется автоматически в _common.sh.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

do_refresh || die "Refresh не получился — нужен полный re-login через auth-relogin.sh"
