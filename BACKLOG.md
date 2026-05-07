---
status: backlog
created: 2026-05-07
owner: Андрей
last_review: 2026-05-07 (Андрей: «нравятся идеи, завтра займёмся»)
---

# Backlog claude-skill-adstat

Расширения после MVP. Все идеи продуманы, по каждой есть план и эффорт. Утвердить порядок и взять в работу когда готовы.

⚠️ **Никаких CRUD-тестов на боевом кабинете** до согласования (Андрей 2026-05-07 18:05). Всё с dry-run по умолчанию + сначала спрашиваем у Adstat support про sandbox через их же `/api/v2/support/ticket/`.

---

## 1. CRUD scripts — full запись в кабинет

**Зачем:** сейчас MVP только читает. Чтобы AI мог не только показывать стату, но и реально управлять кампаниями ("останови все ads с CTR <0.3%", "подними CPM флагмана на 30%", "создай кампанию на канал X").

**Скрипты:**

- `create-campaign.sh --name "..." --account ACC... --daily-budget N` → POST /api/campaigns/ → возвращает campaign_id
- `create-ad.sh --campaign-id N --title "..." --text "..." --object t.me/X --cpm N --daily-budget N --kktu CODE --action join [--image path]` → POST /api/advertisement/telegram/ + опционально upload-picture
- `edit-status.sh --status active|stopped --ad ID[,ID,...]` или `--campaign ID` → POST /api/advertisement/telegram/status/ (массовое)
- `edit-cpm.sh --ad ID --cpm N` → POST /api/advertisement/telegram/cpm/
- `edit-budget.sh --ad ID --daily N` → POST /api/advertisement/telegram/budget/
- `delete.sh --campaign ID[,ID]` или `--ad ID[,ID]` → POST /api/campaigns/delete или /api/advertisement/telegram/delete/
- `xlsx-import.sh --campaign ID --file ads.xlsx` → POST /api/advertisement/telegram/xlsx_validation → /xlsx_creation

**Безопасность (обязательная):**
- Все скрипты ИМЕЮТ `--dry-run` по умолчанию (печатают body+URL, не шлют). Реальная отправка ТОЛЬКО при `--execute`.
- В хедере каждого скрипта: «ВНИМАНИЕ: --execute шлёт реальный запрос в боевой кабинет. Проверь --dry-run сначала.»
- AI должен показывать body пользователю до --execute.

**Эффорт:** 1.5–2 часа на 7 скриптов (после получения sandbox или согласия на тестовую кампанию).

---

## 2. scripts/report.py — генератор HTML-отчёта универсальный

**Зачем:** сейчас отчёт по кабинету — это разовый HTML который я собрал руками. Цифры захардкожены, никто другой не повторит, AI каждый раз пишет HTML с нуля.

**Что добавим:**
```bash
python3 scripts/report.py --period month --out ~/Desktop/report-2026-05.html
python3 scripts/report.py --period week --client X --out report-X-week.html
python3 scripts/report.py --period month --pdf      # дополнительно PDF через Playwright
```

**Внутри:**
- Использует тот же cli.py для запросов (auth flow переиспользует)
- Агрегирует: статус кампаний, топ ads, баланс по аккаунтам, CTR/CPM/CPS
- Рендерит из `templates/report.html.j2` (Jinja2) — со встроенным CSS в стиле AI Target Pro (тёплая бумага OKLCH, Bricolage Grotesque + Onest + JetBrains Mono)
- Опционально: вызывает Playwright и сохраняет PDF/PNG

**Шаблон один, цифры разные** — каждая участница каждый месяц получает свой отчёт. AI вместо генерации 700 строк HTML вызывает одну команду.

**Бонус-сценарий:** "Каждый понедельник присылай мне отчёт за прошлую неделю" → cron + report.py + telegram-bot hook.

**Эффорт:** 3–4 часа. Шаблон у нас уже есть (тот HTML что я делал по кабинету daha150393), нужно вынести в Jinja2 + написать aggregation на cli.py + опциональный Playwright export.

---

## 3. Strategies API — авто-управление кампаниями

**Зачем:** в Adstat есть встроенный движок «если X, то Y» — Adstat сам мониторит метрики и применяет действия БЕЗ участия таргетолога. Особенно ценно для агентства с несколькими кабинетами — physically невозможно мониторить каждое объявление каждый день.

**Примеры стратегий:**
- «Если CTR объявления опускается ниже 0.3% за 24 часа → останови»
- «Если CPS превышает 10 € за 7 дней → понизь CPM на 20%»
- «Каждый понедельник в 9:00 → запусти все объявления кампании Z»
- «Если баланс аккаунта ниже 50 € → останови все кампании»

**API:** 12 эндпоинтов в `/api/strategies/`:
- GET `/api/strategies/strategies` — список
- POST `/api/strategies/strategies` — создать
- POST `/api/strategies/strategies/{id}/start` — применить к группе объявлений
- POST `/api/strategies/strategies/{id}/actions` — enable/disable
- GET `/api/strategies/action-logs/{log_id}` — что делала и когда
- GET `/api/strategies/openapi.json` — отдельная OpenAPI спека для условий/действий

**Скрипты:**
- `list-strategies.sh` — мои стратегии
- `create-strategy.sh` — создать с готовыми пресетами («auto-stop low-CTR», «auto-scale winners», «balance guardian»)
- `attach-strategy.sh` — привязать к кампании или объявлениям
- `strategy-logs.sh` — что стратегия делала за период
- `references/strategies.md` — описание условий и действий, типичные пресеты

**Сценарий:** «создай стратегию: останавливай ads с CTR <0.3% за 3 дня, при балансе <50€ ставь на паузу всю кампанию» → AI собирает body, вызывает create-strategy + attach-strategy. Дальше Adstat сам рулит.

**Эффорт:** 3–4 часа на скрипты + 1–2 часа на references/strategies.md с пресетами.

---

## 4. Multi-account через --client slug

**Зачем:** сейчас один скилл = один Adstat-логин. Если фрилансер ведёт 3 разных Adstat-кабинета (свой + клиентов под белыми ОРД-документами) — придётся каждый раз переписывать .env или дублировать скилл.

⚠️ **Это НЕ про partner_list внутри одного логина** (как у тебя 9 юр.лиц на daha150393). Это про разные логины Adstat. Внутри одного логина разделение через account_id и contract_id уже работает в API без доп.авторизации.

**Структура (по образцу vk-ads):**
```
~/.claude/skills/adstat/config/
├── .env                       — default
├── clients/
│   ├── alpha.env              — клиент Alpha (свой логин/пароль)
│   ├── beta.env               — клиент Beta

~/.claude/secrets/
├── adstat-tokens              — default
├── adstat-tokens.alpha
├── adstat-tokens.beta
```

**CLI:**
```bash
python3 scripts/cli.py GET /api/info/user                  # default
python3 scripts/cli.py GET /api/info/user --client alpha   # из clients/alpha.env
bash scripts/balance.sh --client beta
```

**Эффорт:** 2–3 часа. Нужно прокинуть `--client` параметр через _common.sh + cli.py + все обёртки.

**Когда делать:** только если конкретно у участницы появятся несколько Adstat-логинов. Сейчас у большинства один.

---

## 5. Тикет в Adstat support — про sandbox

**Когда:** перед началом CRUD (см. пункт 1).

**Что спросить:**
- Есть ли test API key / sandbox-окружение для разработчиков-партнёров
- Что именно даёт флаг `is_demo_cabinet: true` в /api/info/user
- Минимальный безопасный путь для тестирования POST/PUT-эндпоинтов

**Как сделать:**
```bash
python3 scripts/cli.py POST /api/v2/support/ticket/ --body-inline '{
  "theme": "developer-question",
  "message": "Здравствуйте! Разрабатываю интеграцию с вашим API через OpenAPI спецификацию client.adstat.pro/api/openapi.json. Подскажите: 1) Есть ли sandbox/test-окружение для разработчиков? 2) Что означает флаг is_demo_cabinet: true в ответе /api/info/user? 3) Какой безопасный способ тестировать POST/PUT-эндпоинты без риска для боевых кампаний? Спасибо!"
}'
```

После ответа саппорта решаем как тестировать CRUD.

---

## Приоритезация (Андрей завтра подтвердит)

| # | Расширение | Эффорт | Когда полезно |
|---|---|---|---|
| 0 | Тикет в Adstat support про sandbox | 5 мин (отправить) + день ждать | Перед CRUD |
| 1 | scripts/report.py (универсальный отчёт) | 3–4 ч | Сразу — самая видимая ценность для всех участниц |
| 2 | CRUD (create + edit-status + edit-cpm) | 1.5–2 ч | После sandbox-ответа |
| 3 | Strategies API | 4–6 ч | Когда у тебя реально много кампаний и хочется экономить время |
| 4 | Multi-account через --client | 2–3 ч | Когда конкретно понадобится |
