#!/usr/bin/env bash
# adstat-oauth-setup.sh — интерактивный мастер первичной настройки.
# Запускается в ОТДЕЛЬНОМ окне терминала через adstat-launch-wizard.sh,
# чтобы пароль не попал в transcript AI.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_DIR="$HOME/.claude/secrets"
ENV_FILE="$SKILL_DIR/config/.env"
TOKENS_FILE="$SECRETS_DIR/adstat-tokens"
ADSTAT_BASE="${ADSTAT_BASE:-https://client.adstat.pro}"

C_RESET="\033[0m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"

die() { echo -e "${C_RED}[!] $*${C_RESET}" >&2; exit 1; }

echo -e "${C_CYAN}═══════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_CYAN}  Adstat (Magnetto) — настройка${C_RESET}"
echo -e "${C_CYAN}═══════════════════════════════════════════════════════════════${C_RESET}"
echo ""

command -v jq   >/dev/null 2>&1 || die "Не найден jq.   macOS: brew install jq | Linux: sudo apt install jq"
command -v curl >/dev/null 2>&1 || die "Не найден curl"

mkdir -p "$SECRETS_DIR" "$SKILL_DIR/config"
chmod 700 "$SECRETS_DIR" 2>/dev/null || true

# Если .env существует — спросить переиспользовать или нет
USE_EXISTING_ENV=0
if [ -f "$ENV_FILE" ] && grep -q '^ADSTAT_LOGIN=' "$ENV_FILE" 2>/dev/null \
   && grep -q '^ADSTAT_PASSWORD=' "$ENV_FILE" 2>/dev/null \
   && ! grep -q 'твой@email.ru' "$ENV_FILE" 2>/dev/null; then
  echo -e "${C_GREEN}[✓]${C_RESET} Найден заполненный $ENV_FILE"
  read -r -p "Использовать существующий логин/пароль? [Y/n] " ans
  case "$ans" in
    n|N|no|No) USE_EXISTING_ENV=0 ;;
    *) USE_EXISTING_ENV=1 ;;
  esac
fi

if [ "$USE_EXISTING_ENV" = "0" ]; then
  echo ""
  echo -e "${C_YELLOW}Введи свои данные от https://client.adstat.pro${C_RESET}"
  echo "(пароль не отображается — это нормально)"
  echo ""

  read -r -p "Email-логин: " ADSTAT_LOGIN
  [ -n "$ADSTAT_LOGIN" ] || die "Логин пустой"

  read -r -s -p "Пароль: " ADSTAT_PASSWORD; echo
  [ -n "$ADSTAT_PASSWORD" ] || die "Пароль пустой"

  # Сохраняем в .env (chmod 600)
  cat > "$ENV_FILE" <<EOF
# Adstat (Magnetto Cabinet) credentials
# Сгенерировано $(date +'%Y-%m-%d %H:%M:%S')
ADSTAT_LOGIN=$ADSTAT_LOGIN
ADSTAT_PASSWORD=$ADSTAT_PASSWORD
EOF
  chmod 600 "$ENV_FILE"
  echo -e "${C_GREEN}[✓]${C_RESET} Сохранил в $ENV_FILE (chmod 600)"
else
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

echo ""
echo -e "${C_YELLOW}Логинюсь в Adstat…${C_RESET}"
RESP="$(curl -sS -w '\n__HTTP_CODE__%{http_code}' -X POST "$ADSTAT_BASE/api/v2/login" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "username=$ADSTAT_LOGIN" \
  --data-urlencode "password=$ADSTAT_PASSWORD")"
HTTP_CODE="$(printf '%s' "$RESP" | tail -n1 | sed 's/^.*__HTTP_CODE__//')"
BODY="$(printf '%s' "$RESP" | sed '$d')"

if [ "$HTTP_CODE" != "200" ]; then
  echo -e "${C_RED}[!] HTTP $HTTP_CODE${C_RESET}"
  echo "$BODY" | head -c 300
  echo ""
  die "Не удалось залогиниться. Проверь логин/пароль в $ENV_FILE и перезапусти мастер."
fi

ACCESS="$(printf '%s' "$BODY" | jq -r '.access_token // empty')"
REFRESH="$(printf '%s' "$BODY" | jq -r '.refresh_token // empty')"
UID_VAL="$(printf '%s' "$BODY" | jq -r '.user_id // empty')"
[ -n "$ACCESS" ] || die "Не получили access_token: $BODY"

NOW="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
cat > "$TOKENS_FILE" <<EOF
# Adstat tokens (issued $NOW)
# access expires in 1h, refresh in 30d
ADSTAT_USER_ID=$UID_VAL
ADSTAT_ACCESS_TOKEN=$ACCESS
ADSTAT_REFRESH_TOKEN=$REFRESH
EOF
chmod 600 "$TOKENS_FILE"
echo -e "${C_GREEN}[✓]${C_RESET} Логин успешный (uid=${UID_VAL:0:8}…)"
echo -e "${C_GREEN}[✓]${C_RESET} Токены сохранены: $TOKENS_FILE"

echo ""
echo -e "${C_YELLOW}Проверяю кабинет…${C_RESET}"
INFO="$(curl -sS -H "Authorization: Bearer $ACCESS" -H 'Accept: application/json' \
  "$ADSTAT_BASE/api/info/user")"
EMAIL="$(printf '%s' "$INFO" | jq -r '.email // empty')"
ROLE="$(printf '%s' "$INFO" | jq -r '.role // empty')"
PARTNERS="$(printf '%s' "$INFO" | jq -r '.partner_list | length // 0')"

BAL="$(curl -sS -H "Authorization: Bearer $ACCESS" -H 'Accept: application/json' \
  "$ADSTAT_BASE/api/dashboard/balances")"
BAL_TOTAL="$(printf '%s' "$BAL" | jq -r '.total.amount // 0')"
BAL_AVAIL="$(printf '%s' "$BAL" | jq -r '.available.amount // 0')"
CUR="$(printf '%s' "$BAL" | jq -r '.total.currency // "EUR"')"

echo ""
echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_GREEN}  ✅ Adstat настроен и работает${C_RESET}"
echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════${C_RESET}"
echo ""
echo "  Кабинет:        $EMAIL  ($ROLE)"
echo "  Партнёров:      $PARTNERS"
echo "  Баланс всего:   $BAL_TOTAL $CUR"
echo "  Свободно:       $BAL_AVAIL $CUR"
echo ""
echo "  Конфиг:    $ENV_FILE"
echo "  Токены:    $TOKENS_FILE"
echo ""
echo "Дальше в чате с Клодом можно спрашивать:"
echo "  • «Сделай отчёт по моему TG-кабинету за месяц»"
echo "  • «Покажи свободные балансы по аккаунтам»"
echo "  • «Найди в архиве креативы с высоким CTR»"
echo ""
read -r -p "Готово. Нажми Enter чтобы закрыть это окно… "
