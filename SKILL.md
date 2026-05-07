---
name: adstat
description: Работа с рекламным кабинетом Telegram Ads через Adstat.pro (Magnetto Cabinet API) как сеньор-таргетолог. Закрывает чтение (статистика, балансы, кампании, объявления, аккаунты, контракты, OAuth-токены) и запись (создание/редактирование кампаний и объявлений, бюджеты, статусы, аудитории, KKTU-маркировка, ОРД-цикл). Используй когда клиент просит проанализировать TG-рекламу, построить отчёт по тратам, найти лучшие/худшие креативы, реанимировать архив, проверить статус кампаний или подключить новый рекламный аккаунт через Adstat.
allowed-tools: Bash, Read, Write, Edit
---

# Adstat (Magnetto) — TG Ads через Adstat.pro

Скилл для работы с Magnetto Cabinet API (`client.adstat.pro`) — это рекламный кабинет Telegram Ads с поддержкой ОРД РКН (контракты, KKTU-коды, инвойсы), 100+ эндпоинтов в OpenAPI спецификации `https://client.adstat.pro/api/openapi.json`.

> **Кому это:** таргетологам которые ведут TG Ads через Adstat/Magnetto (Россия) — единичные клиенты, агентства с 10+ юр.лиц, инхаус с одним каналом.

---

## КОГДА ТРИГГЕРИТЬСЯ

**Чтение / аналитика**
- «Покажи активные кампании в TG Ads»
- «Сколько потрачено за последний месяц по всем клиентам»
- «Какие у меня баланс / свободные средства в Adstat»
- «Сделай отчёт по моему TG-кабинету уровня топ-маркетолога»
- «Найди в архиве креативы с высоким CTR — какие можно вернуть»
- «Сравни CPM моих клиентов»
- «Покажи кампании на паузе с потраченным бюджетом >1000 €»

**Запуск / создание**
- «Запусти кампанию на канал t.me/X с бюджетом N»
- «Создай объявление с текстом X в кампании Y»
- «Загрузи XLSX с массовой выгрузкой объявлений»
- «Создай аудиторию по похожим каналам»

**Управление / оптимизация**
- «Останови все объявления с CTR ниже 0,3%»
- «Подними CPM флагмана с 1,4 до 2 €»
- «Удали кампании клиента X оптом»
- «Подключи стратегию авто-оптимизации»

**ОРД / Юридические**
- «Сделай отчёт по ОРД-маркировке за квартал»
- «Создай инвойс на N € для агентства»
- «Привяжи KKTU-код к аккаунту клиента»
- «Покажи мои контракты в Magnetto»

---

## АРХИТЕКТУРА API

### Base URL
`https://client.adstat.pro/api/`

### Auth flow (OAuth-style с access + refresh)

```
POST /api/v2/login        username + password (form data)  →  {user_id, access_token, refresh_token}
GET  /api/v2/access-token  header: refresh_token            →  {access_token, token_type:"Bearer"}
POST /api/v2/logout        Bearer access_token              →  ok
```

- **access_token** живёт **1 час**, передаётся в `Authorization: Bearer <token>`
- **refresh_token** живёт **30 дней**, обновляет access без перезахода

`scripts/_common.sh` делает auto-refresh: при 401 пытается обновить access через refresh, если refresh устарел — пользователь должен перелогиниться через `auth-relogin.sh`.

### Группы эндпоинтов (по тэгам OpenAPI)

| Тэг | Endpoints | О чём |
|---|---|---|
| Auth | 8 | login, logout, register, refresh, password reset, email confirm |
| Accounts | 5 | TG-аккаунты (юр.лица), их балансы, kktu-default, объекты-каналы |
| Campaigns | 6 | CRUD кампаний, fast/short list |
| Advertisement | 30+ | CRUD объявлений, bulk операции, audiences, similar bots/channels, XLSX import/export, validate |
| Advertising | 4 | Справочники: countries, langs, locations, topics |
| Cabinet | 1 | Кабинеты по contract_id |
| Contract | 1 | Список контрактов (для ОРД) |
| Dashboard | 6 | Баланс, статистика expenses/CPM, счётчики кампаний по статусу |
| Statistics V1 | 3 | File reports, stats page |
| KKTU | 1 | Коды для ОРД-маркировки РКН |
| pixel_events | 6 | Пиксель + события post-click |
| strategies | 12 | Авто-стратегии управления кампаниями |
| InvoiceRequested | 6 | Инвойсы для агентств |
| Report | 5 | PDF-отчёты, send by email |
| Support | 7 | Тикеты в поддержку Adstat |
| Info / Cabinet / Promo / KKTU | разное | Справочники и метаданные |

Полный каталог в `references/endpoints.md`.

---

## УСТАНОВКА (универсальная, для любого пользователя)

### Шаг 1 — Клонирование
```bash
git clone https://github.com/atomachinskiy/claude-skill-adstat.git ~/.claude/skills/adstat
chmod +x ~/.claude/skills/adstat/scripts/*.sh
```

### Шаг 2 — Подготовка credentials
```bash
cp ~/.claude/skills/adstat/config/.env.example ~/.claude/skills/adstat/config/.env
chmod 600 ~/.claude/skills/adstat/config/.env
```

Открой `.env` в редакторе и заполни:
```
ADSTAT_LOGIN=твой@email.ru
ADSTAT_PASSWORD=твойпароль
```

⚠️ **Security:** пароль НЕ светить в чат с AI. AI читает только из файла, не запрашивает в диалоге.

### Шаг 3 — Первый логин
```bash
bash ~/.claude/skills/adstat/scripts/auth-relogin.sh
```

Скрипт прочитает `.env`, сходит за токенами, сохранит их в `~/.claude/secrets/adstat-tokens` (chmod 600). Дальше скилл читает только токены — пароль больше не нужен на каждый запрос.

### Шаг 4 — Sanity-check
```bash
bash ~/.claude/skills/adstat/scripts/balance.sh
bash ~/.claude/skills/adstat/scripts/list-tg-accounts.sh
```

Должны вернуться твой баланс и список TG-аккаунтов.

---

## КАТАЛОГ СКРИПТОВ

```
scripts/
├── _common.sh                  Auto-refresh access токена, request helper
├── auth-relogin.sh             Полный логин: .env → tokens (только если refresh устарел)
├── auth-refresh.sh             Обновление access по refresh
├── cli.py                      Универсальный API-клиент: GET/POST/PUT/DELETE любого эндпоинта
├── balance.sh                  Текущий баланс кабинета
├── list-tg-accounts.sh         Все TG-аккаунты (юр.лица) с балансами
├── list-contracts.sh           ОРД-контракты
├── list-campaigns.sh           Все кампании (с фильтром по статусу)
├── list-ads.sh                 Все объявления (с фильтром)
├── stats-summary.sh            Сводка по периоду (week/month/today/yesterday)
└── campaign-counts.sh          Сколько кампаний в каждом статусе
```

### Универсальный CLI

```bash
python3 scripts/cli.py GET /api/dashboard/balances
python3 scripts/cli.py GET /api/v2/campaigns/ --param period=month --param limit=50
python3 scripts/cli.py POST /api/campaigns/ --body campaign.json
python3 scripts/cli.py PUT /api/campaigns/123 --body-inline '{"name":"new"}'
```

Параметры:
- `--param k=v` — query параметры (повторяй для нескольких)
- `--body file.json` — body из файла (для POST/PUT)
- `--body-inline '{...}'` — body inline
- `--pretty` — pretty-print JSON
- `--raw` — без парсинга JSON

---

## КЛЮЧЕВЫЕ СЦЕНАРИИ

### Сценарий 1 — Отчёт за месяц по всему кабинету

```bash
# 1. Stats за месяц
python3 scripts/cli.py GET /api/dashboard/statistics/month/telegram/

# 2. Все TG-аккаунты с балансами
python3 scripts/cli.py GET /api/accounts/telegram/

# 3. Активные кампании (счётчик)
python3 scripts/cli.py GET /api/dashboard/campaigns/active/count/

# 4. Объявления (для разбора креативов)
python3 scripts/cli.py GET /api/v2/advertisement/ --param limit=200
```

Дальше AI агрегирует по нишам, считает CPS/CPM, находит топ/флоп, формирует HTML-отчёт.

### Сценарий 2 — Реанимировать архив

```bash
# Все ads со статусом stopped/deleted, отсортированные по CTR desc
python3 scripts/cli.py GET /api/v2/advertisement/ --param status=stopped --param limit=200 \
  | jq '.data | sort_by(-.ctr) | .[0:10]'
```

AI смотрит топ-10 креативов с высоким CTR в архиве, предлагает 3-5 для повторного запуска.

### Сценарий 3 — Создать кампанию + объявление

```bash
# 1. Создать кампанию
python3 scripts/cli.py POST /api/campaigns/ --body-inline '{
  "name": "Тест канала X",
  "tg_account_id": "ACC132248",
  "daily_budget": 10
}'
# → получишь campaign_id

# 2. Создать объявление в ней
python3 scripts/cli.py POST /api/advertisement/telegram/ --body-inline '{
  "campaign_id": <id>,
  "advertisement_title": "тест 1",
  "ad_text": "Текст объявления",
  "object": "t.me/myChannel",
  "cpm": 2.5,
  "daily_budget": 10,
  "kktu_codes": ["29.2.9"],
  "action_type": "join"
}'
```

### Сценарий 4 — Sanity по балансам клиентов агентства

```bash
python3 scripts/cli.py GET /api/accounts/telegram/ \
  | jq '.items[] | {name: .account_name, status, balance_active, balance_available, balance_spent, legal: .legal_name}'
```

Покажет таблицу: какой клиент активен, сколько свободного бюджета, сколько уже потрачено.

---

## БЕЗОПАСНОСТЬ

- ❌ **Никогда не присылай пользователю запрос «дай пароль в чат»** — пользователь сам кладёт в `config/.env`.
- ❌ Не передавай токены через флаги CLI — они уходят в shell history. Только через `.env` или `secrets/`.
- ❌ Не предлагай «удобную автоматизацию» с раскрытием пароля.
- ❌ Не делай скрин с access_token и не копируй его в TG/чат.
- ✅ Все секреты — `chmod 600`, в `~/.claude/secrets/adstat-tokens` и `~/.claude/skills/adstat/config/.env`.
- ✅ Если access_token не обновляется (refresh устарел) — попроси пользователя перезапустить `auth-relogin.sh` (он сам прочитает пароль из .env).

---

## ИЗВЕСТНЫЕ ОГРАНИЧЕНИЯ ADSTAT API

- `period` enum для dashboard: только `today | yesterday | week | month` (НЕ `30d`, не custom dates)
- `/api/cabinet/` требует параметр `contract_id` (получи из `/api/contract/`)
- Некоторые v3-эндпоинты возвращают 500 без явных параметров — используй v2 fallback
- `/api/dashboard/campaigns/{status}/count/` принимает только: `active`, `stopped`, `deleted`, `on_hold`, `declined`, `in_review` (НЕ `paused`, не `pending`)
- Все денежные значения в EUR (даже для российских аккаунтов)
- `advertisement_title` — внутреннее имя для таргетолога, НЕ заголовок объявления
- `ad_text` — поддерживает Telegram emoji через `![X](tg://emoji?id=...)` синтаксис

---

## ССЫЛКИ

- API спецификация: https://client.adstat.pro/api/openapi.json
- Документация: https://developers.adstat.pro
- Кабинет: https://client.adstat.pro
- Этот скилл: https://github.com/atomachinskiy/claude-skill-adstat
