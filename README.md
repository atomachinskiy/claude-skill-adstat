# claude-skill-adstat

Claude Code skill для работы с **Adstat.pro / Magnetto Cabinet API** — рекламный кабинет Telegram Ads с поддержкой ОРД РКН (контракты, KKTU-коды, инвойсы).

100+ эндпоинтов из OpenAPI спецификации `https://client.adstat.pro/api/openapi.json`. Покрывает чтение (стата, балансы, кампании, объявления, аккаунты, контракты) и запись (CRUD кампаний/объявлений, бюджеты, статусы, аудитории, ОРД-цикл).

## Установка

```bash
git clone https://github.com/atomachinskiy/claude-skill-adstat.git ~/.claude/skills/adstat
chmod +x ~/.claude/skills/adstat/scripts/*.sh
cp ~/.claude/skills/adstat/config/.env.example ~/.claude/skills/adstat/config/.env
chmod 600 ~/.claude/skills/adstat/config/.env
# отредактируй .env: впиши свои ADSTAT_LOGIN и ADSTAT_PASSWORD от client.adstat.pro
bash ~/.claude/skills/adstat/scripts/auth-relogin.sh
```

После этого Claude может использовать любой эндпоинт через универсальный CLI:

```bash
python3 ~/.claude/skills/adstat/scripts/cli.py GET /api/dashboard/balances
python3 ~/.claude/skills/adstat/scripts/cli.py GET /api/v2/campaigns/ --param period=month --param limit=50
```

## Зависимости

- `bash`, `curl`, `jq`, `python3` (Python ≥ 3.8)

На macOS: `brew install jq`. На Linux: `apt install jq`. На Windows: используй Git Bash + Python с python.org.

## Архитектура

- **Auth flow:** OAuth-style. `login + password → access (1h) + refresh (30d)`. Токены лежат в `~/.claude/secrets/adstat-tokens` (chmod 600). `_common.sh` делает auto-refresh при 401.
- **Universal CLI:** `cli.py` принимает любой HTTP method + path + params + body → возвращает JSON. Обёртки `list-*.sh` для частых сценариев.
- **Безопасность:** пароль никогда не передаётся через CLI-флаги (только через `.env`). Токены не попадают в shell history.

Подробности — в `SKILL.md`.

## Готовые сценарии (типичные запросы)

- «Сделай отчёт за месяц по моему TG-кабинету уровня топ-маркетолога»
- «Покажи активные кампании / какие сейчас идут»
- «Найди в архиве креативы с CTR >1% — какие можно вернуть»
- «Сравни CPM моих клиентов»
- «Сколько свободного баланса у каждого аккаунта»
- «Создай кампанию на канал t.me/X с бюджетом N €»
- «Останови все объявления с CTR ниже 0,3%»

См. полный каталог в `SKILL.md`.

## Известные ограничения Adstat API

- `period` enum для dashboard endpoints: только `today | yesterday | week | month`
- Все денежные значения в EUR (даже для российских аккаунтов)
- `/api/cabinet/` требует параметр `contract_id` (получи из `/api/contract/`)
- `/api/dashboard/campaigns/{status}/count/` принимает только: `active`, `stopped`, `deleted`, `on_hold`, `declined`, `in_review`

## Ссылки

- **API спецификация:** https://client.adstat.pro/api/openapi.json
- **Документация:** https://developers.adstat.pro
- **Кабинет:** https://client.adstat.pro

MIT License.
