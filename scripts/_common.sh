#!/usr/bin/env bash
# Adstat skill — общие хелперы.
#
# Файлы:
#   ~/.claude/skills/adstat/config/.env      — креды пользователя (login + password)
#   ~/.claude/secrets/adstat-tokens          — issued tokens (access 1h, refresh 30d)
#
# Принципы:
# - Секреты всегда chmod 600.
# - Auth flow: пытается access → если 401, refresh → если refresh устарел, попросит relogin.
# - НИКОГДА не печатает пароль или токены в stdout (только короткий префикс).

set -e

ADSTAT_BASE="${ADSTAT_BASE:-https://client.adstat.pro}"
SECRETS_DIR="$HOME/.claude/secrets"
TOKENS_FILE="$SECRETS_DIR/adstat-tokens"
SKILL_DIR="${ADSTAT_SKILL_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
ENV_FILE="$SKILL_DIR/config/.env"

mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR" 2>/dev/null || true

CYAN=$'\033[0;36m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; RST=$'\033[0m'
ok()    { echo "${GREEN}✓ $*${RST}"; }
warn()  { echo "${YELLOW}⚠ $*${RST}"; }
die()   { echo "${RED}✗ $*${RST}" >&2; exit 1; }

# load_env: читает .env пользователя (login + password) если есть
load_env() {
  [ -f "$ENV_FILE" ] || return 1
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
  return 0
}

# load_tokens: читает access + refresh из ~/.claude/secrets/adstat-tokens
load_tokens() {
  [ -f "$TOKENS_FILE" ] || return 1
  set -a
  # shellcheck disable=SC1090
  . "$TOKENS_FILE"
  set +a
  [ -n "${ADSTAT_ACCESS_TOKEN:-}" ] || return 1
  return 0
}

# save_tokens: записывает access (+ refresh если передан) в файл
# args: access_token [refresh_token] [user_id]
save_tokens() {
  local access="$1" refresh="${2:-${ADSTAT_REFRESH_TOKEN:-}}" uid="${3:-${ADSTAT_USER_ID:-}}"
  local now
  now="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  cat > "$TOKENS_FILE" <<EOF
# Adstat tokens (issued $now)
# access expires in 1h, refresh in 30d
ADSTAT_USER_ID=$uid
ADSTAT_ACCESS_TOKEN=$access
ADSTAT_REFRESH_TOKEN=$refresh
EOF
  chmod 600 "$TOKENS_FILE"
}

# do_login: первичный логин login+password → access+refresh
# requires .env to be loaded
do_login() {
  load_env || die "Не найден $ENV_FILE — скопируй из config/.env.example и заполни ADSTAT_LOGIN/ADSTAT_PASSWORD"
  [ -n "${ADSTAT_LOGIN:-}" ] || die "ADSTAT_LOGIN пустой в $ENV_FILE"
  [ -n "${ADSTAT_PASSWORD:-}" ] || die "ADSTAT_PASSWORD пустой в $ENV_FILE"

  local resp
  resp="$(curl -sS -X POST "$ADSTAT_BASE/api/v2/login" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "username=$ADSTAT_LOGIN" \
    --data-urlencode "password=$ADSTAT_PASSWORD")"
  local access refresh uid
  access="$(printf '%s' "$resp" | jq -r '.access_token // empty')"
  refresh="$(printf '%s' "$resp" | jq -r '.refresh_token // empty')"
  uid="$(printf '%s' "$resp" | jq -r '.user_id // empty')"
  [ -n "$access" ] || die "Login failed: $(printf '%s' "$resp" | head -c 200)"
  save_tokens "$access" "$refresh" "$uid"
  ok "Logged in as $ADSTAT_LOGIN (uid=${uid:0:8}…)"
}

# do_refresh: обновить access по refresh
do_refresh() {
  load_tokens || die "Нет tokens-файла, запусти auth-relogin.sh"
  [ -n "${ADSTAT_REFRESH_TOKEN:-}" ] || die "Нет refresh_token, запусти auth-relogin.sh"

  local resp access
  resp="$(curl -sS -H "refresh_token: $ADSTAT_REFRESH_TOKEN" "$ADSTAT_BASE/api/v2/access-token")"
  access="$(printf '%s' "$resp" | jq -r '.access_token // empty')"
  if [ -z "$access" ]; then
    warn "Refresh failed: $(printf '%s' "$resp" | head -c 200)"
    return 1
  fi
  # Сохраняем новый access, refresh оставляем (он живёт 30 дней)
  save_tokens "$access" "$ADSTAT_REFRESH_TOKEN" "$ADSTAT_USER_ID"
  ok "Refreshed access token"
  return 0
}

# api_request <METHOD> <PATH> [curl args ...]
# Делает запрос с авто-refresh при 401. Печатает body в stdout.
api_request() {
  local method="$1" path="$2"; shift 2
  load_tokens || { do_login; load_tokens || die "Не удалось логиниться"; }

  local url="$ADSTAT_BASE$path"
  local resp code body
  resp="$(curl -sS -w '\n__HTTP_CODE__%{http_code}' \
    -X "$method" \
    -H "Authorization: Bearer $ADSTAT_ACCESS_TOKEN" \
    -H "Accept: application/json" \
    "$@" \
    "$url")"
  code="$(printf '%s' "$resp" | tail -n1 | sed 's/^.*__HTTP_CODE__//')"
  body="$(printf '%s' "$resp" | sed '$d' | sed 's/__HTTP_CODE__[0-9]*$//')"

  if [ "$code" = "401" ]; then
    warn "Got 401 — пробую refresh"
    if do_refresh; then
      load_tokens
      resp="$(curl -sS -w '\n__HTTP_CODE__%{http_code}' \
        -X "$method" \
        -H "Authorization: Bearer $ADSTAT_ACCESS_TOKEN" \
        -H "Accept: application/json" \
        "$@" \
        "$url")"
      code="$(printf '%s' "$resp" | tail -n1 | sed 's/^.*__HTTP_CODE__//')"
      body="$(printf '%s' "$resp" | sed '$d' | sed 's/__HTTP_CODE__[0-9]*$//')"
    else
      warn "Refresh не получился — нужен полный re-login. Запусти: bash $SKILL_DIR/scripts/auth-relogin.sh"
      printf '%s' "$body"
      return 1
    fi
  fi

  if [ "$code" -ge 400 ]; then
    warn "HTTP $code: $url"
  fi
  printf '%s' "$body"
}
