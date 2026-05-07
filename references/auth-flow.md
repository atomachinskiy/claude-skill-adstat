# Auth flow

OAuth-style: пользователь вводит логин+пароль один раз, получает пару токенов:
- **access_token** — для всех API-запросов в `Authorization: Bearer <token>`. TTL **1 час**.
- **refresh_token** — для тихого обновления access без перевхода. TTL **30 дней**.

## Хранение

| Файл | Что внутри | Permissions |
|---|---|---|
| `~/.claude/skills/adstat/config/.env` | `ADSTAT_LOGIN`, `ADSTAT_PASSWORD` | chmod 600 |
| `~/.claude/secrets/adstat-tokens` | `ADSTAT_USER_ID`, `ADSTAT_ACCESS_TOKEN`, `ADSTAT_REFRESH_TOKEN` | chmod 600 |

`config/.env` под `.gitignore` — никогда не коммитится.

## Endpoints

```
POST /api/v2/login
  Content-Type: application/x-www-form-urlencoded
  body: username=<login>&password=<password>
  →  {user_id, access_token, refresh_token}

GET /api/v2/access-token
  header: refresh_token: <refresh_token>
  →  {access_token, token_type:"Bearer"}

POST /api/v2/logout
  header: Authorization: Bearer <access_token>
  →  ok
```

## Жизненный цикл (что делает _common.sh)

```
api_request <METHOD> <PATH>
  ↓
  load_tokens из ~/.claude/secrets/adstat-tokens
  ↓
  если нет токенов → do_login (читает .env, идёт в /login)
  ↓
  curl с Bearer access_token
  ↓
  если HTTP 401 → do_refresh (refresh → новый access)
       ↓
       если refresh устарел → попросить bash auth-relogin.sh
  ↓
  возвращает body
```

## Ошибки

| Код | Что значит | Действие |
|---|---|---|
| 401 (первый запрос) | Access истёк | `_common.sh` сам сделает refresh |
| 401 после refresh | Refresh устарел / отозван | Запусти `bash scripts/auth-relogin.sh` |
| 401 при логине | Неверный login/password | Проверь `.env` |
| 403 | Нет прав на endpoint | Не все endpoints доступны для role=client (например, partner-эндпоинты) |
| `{"detail":"Refresh Token Expired","status_code":401}` | Refresh истёк | Re-login |

## Безопасность

- Пароль НИКОГДА не передаётся через CLI-флаги (флаги попадают в shell history). Только через файл `.env`.
- Токены НИКОГДА не печатаются в stdout полностью (`_common.sh` показывает только префикс).
- AI ассистент не должен запрашивать пароль в чате — он сам читает `.env`.
- Если кому-то передаёшь скилл — делишься скриптами, НЕ файлом `.env` и НЕ файлом `adstat-tokens`.

## Multi-account (если у тебя несколько Adstat кабинетов)

Сейчас MVP поддерживает один аккаунт. Для нескольких — продублируй структуру:

```
~/.claude/skills/adstat/config/.env       # default
~/.claude/skills/adstat/config/.env.client2
```

И запускай с переменной:
```bash
ENV_FILE=~/.claude/skills/adstat/config/.env.client2 bash scripts/balance.sh
```

(в v0.2 будет полноценный `--client <slug>` флаг как в vk-ads)
