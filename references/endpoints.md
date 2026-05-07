# Adstat (Magnetto Cabinet API) — каталог эндпоинтов

OpenAPI: https://client.adstat.pro/api/openapi.json

Base: `https://client.adstat.pro`. Auth: `Authorization: Bearer <access_token>`.

---

## Auth

| Method | Path | Описание |
|---|---|---|
| POST | `/api/v2/login` | Login (form: `username`, `password`) → `{user_id, access_token, refresh_token}` |
| GET  | `/api/v2/access-token` | Refresh access (header: `refresh_token: <refresh>`) |
| POST | `/api/v2/logout` | Logout |
| POST | `/api/v2/register` | Register |
| POST | `/api/v2/forgot-password` | Forgot password |
| POST | `/api/v2/reset-password` | Reset password |
| GET  | `/api/v2/email-confirmation` | Email confirmation |
| GET  | `/api/v2/legal-documents` | Legal documents |

## Accounts (Telegram)

| Method | Path | Описание |
|---|---|---|
| GET | `/api/accounts/telegram/` | TG-аккаунты с balance_total |
| GET | `/api/v2/accounts/telegram/` | TG-аккаунты (краткие) |
| GET | `/api/v3/accounts/telegram/` | Без spent |
| GET | `/api/accounts/telegram/names` | Только имена |
| GET | `/api/accounts/telegram/{account_id}` | Инфо по аккаунту |
| PATCH | `/api/accounts/set-default-kktu` | Установить default KKTU для аккаунта |

## Cabinet

| Method | Path | Описание |
|---|---|---|
| GET | `/api/cabinet/` | Кабинеты (требует `contract_id` query param) |

## Contract

| Method | Path | Описание |
|---|---|---|
| GET | `/api/contract/` | Все контракты пользователя (для ОРД) |

## Campaigns

| Method | Path | Описание |
|---|---|---|
| GET  | `/api/campaigns/` | Кампании with total |
| POST | `/api/campaigns/` | Создать кампанию |
| GET  | `/api/campaigns/short` | Только id+name |
| GET  | `/api/campaigns/{id}` | Деталь |
| PUT  | `/api/campaigns/{id}` | Edit |
| POST | `/api/campaigns/delete` | Bulk delete |
| GET  | `/api/v2/campaigns/` | v2 list (требует `period` query) |
| GET  | `/api/v2/campaigns/fast` | Fast list |

## Advertisement

CRUD рекламных объявлений + bulk-операции + аудитории + XLSX import/export.

| Method | Path | Описание |
|---|---|---|
| GET  | `/api/v2/advertisement/` | Все объявления |
| GET  | `/api/v2/advertisement/fast` | Fast list (Boromir) |
| GET  | `/api/advertisement/short` | Краткий список |
| POST | `/api/advertisement/{platform}/` | Создать объявление (`platform=telegram`) |
| GET  | `/api/advertisement/{platform}/{ad_id}` | Деталь объявления |
| PUT  | `/api/advertisement/{platform}/{ad_id}/` | Edit |
| POST | `/api/advertisement/{platform}/budget/` | Edit budget |
| POST | `/api/advertisement/{platform}/cpm/` | Edit CPM |
| POST | `/api/advertisement/{platform}/status/` | Edit status (active/stopped/...) |
| POST | `/api/advertisement/{platform}/kktu_codes/` | Edit KKTU codes |
| POST | `/api/advertisement/{platform}/delete/` | Delete |
| POST | `/api/advertisement/{platform}/upload_picture` | Upload изображение |
| GET  | `/api/advertisement/{platform}/{ad_id}/send_to_review` | Отправить на модерацию |
| POST | `/api/advertisement/{platform}/xlsx_creation` | XLSX bulk create |
| POST | `/api/advertisement/{platform}/xlsx_validation` | XLSX validate |
| GET  | `/api/advertisement/{platform}/{account_from}/create_csv` | Generate CSV |
| GET  | `/api/advertisement/{platform}/{account_id}/audiences/` | Get audiences |
| POST | `/api/advertisement/{platform}/{account_id}/audiences/` | Create audience |
| GET  | `/api/advertisement/{platform}/{account_id}/emoji/` | Telegram emoji links |
| GET  | `/api/advertisement/{platform}/{account_id}/validate/` | Validate ad targeting |
| GET  | `/api/advertisement/channels/{platform}/{account_id}/validate/` | Validate channel |
| POST | `/api/advertisement/bots/similar` | Get similar bots |
| GET  | `/api/advertisement/bots/validate` | Validate target bots |
| POST | `/api/advertisement/channels/similar` | Get similar channels |
| POST | `/api/advertisement/move` | Move ads (между кампаниями) |
| POST | `/api/advertisement/statuses/refresh` | Refresh statuses |
| GET  | `/api/advertisement/search-target-query/validate` | Validate search query |
| GET  | `/api/advertisement/search-target-queries/validate` | Validate multiple queries |
| GET  | `/api/advertisement/settings` | Budget/CPM settings |

## Advertising (справочники)

| Method | Path | Описание |
|---|---|---|
| GET | `/api/advertising/countries/telegram` | TG страны |
| GET | `/api/advertising/langs/telegram` | TG языки |
| GET | `/api/advertising/locations/telegram/{account_id}` | TG локации |
| GET | `/api/advertising/topics/telegram` | TG тематики |

## Dashboard / Statistics

| Method | Path | Описание |
|---|---|---|
| GET | `/api/dashboard/balances` | Текущий баланс кабинета |
| GET | `/api/dashboard/balances/all` | Балансы по всем аккаунтам |
| GET | `/api/dashboard/statistics/{period}/{platform}/` | Сводная стата (`period: today/yesterday/week/month`) |
| GET | `/api/dashboard/statistics/expenses/{period}/{platform}/` | Динамика трат |
| GET | `/api/dashboard/statistics/cpm/{period}/{platform}/` | Динамика CPM/CPS |
| GET | `/api/dashboard/campaigns/{status}/count/` | Счётчик кампаний (`active/stopped/deleted/on_hold/declined/in_review`) |
| GET | `/api/dashboard/campaigns/{status}/ad_objects/count/` | Счётчик ad-объектов |
| POST | `/api/v1/file_reports/` | Создать file report |
| GET | `/api/v1/file_reports/{file_id}` | Получить file report |
| POST | `/api/v1/stats/page` | Stats page |

## KKTU

| Method | Path | Описание |
|---|---|---|
| GET | `/api/kktu/` | Все KKTU-коды (для ОРД-маркировки РКН) |

## Pixel Events

| Method | Path | Описание |
|---|---|---|
| GET | `/api/pixel_events/` | События пикселя |
| POST | `/api/pixel_events/` | Создать событие |
| GET | `/api/pixel_events/types` | Типы событий |
| GET | `/api/pixel_events/{account_id}/code_snippet` | JS-snippet пикселя |
| PATCH | `/api/pixel_events/{event_id}` | Edit event title |
| DELETE | `/api/pixel_events/{account_id}/events/{event_id}` | Delete event |
| GET | `/api/pixel_events{account_id}/{event_id}/logs` | Event logs |

## Strategies (авто-управление кампаниями)

| Method | Path | Описание |
|---|---|---|
| GET | `/api/strategies/strategies` | Список стратегий |
| POST | `/api/strategies/strategies` | Создать стратегию |
| GET | `/api/strategies/strategies/{id}` | Деталь |
| PUT | `/api/strategies/strategies/{id}` | Edit |
| DELETE | `/api/strategies/strategies/{id}` | Delete |
| POST | `/api/strategies/strategies/{id}/actions` | Enable/disable |
| POST | `/api/strategies/strategies/{id}/start` | Start objects |
| POST | `/api/strategies/strategies/{id}/stop` | Stop objects |
| POST | `/api/strategies/strategies/{id}/delete` | Unbind objects |
| GET | `/api/strategies/strategies/{id}/objects` | Объекты стратегии |
| GET | `/api/strategies/strategies/all/objects` | Все strategy-объекты |
| POST | `/api/strategies/action-logs` | Logs |
| GET | `/api/strategies/action-logs/{log_id}` | Лог детали |
| GET | `/api/strategies/openapi.json` | OpenAPI стратегий (отдельный) |

## Reports (PDF, send by email)

| Method | Path | Описание |
|---|---|---|
| POST | `/api/report/tgcreate` | Create TG report |
| POST | `/api/report/tgview` | View TG report |
| GET | `/api/report/objects` | Объекты для отчёта |
| GET | `/api/report/status` | Статус генерации |
| GET | `/api/report/get/{file}` | Скачать готовый файл |

## Invoices (для агентств с ОРД)

| Method | Path | Описание |
|---|---|---|
| GET | `/api/invoice_requested/` | Список инвойсов |
| POST | `/api/invoice_requested/create` | Создать инвойс |
| POST | `/api/invoice_requested/preflight` | Preflight check |
| GET | `/api/invoice_requested/{key}/` | Детали инвойса |
| GET | `/api/invoice_requested/{key}/generate_pdf` | Генерировать PDF |
| POST | `/api/invoice_requested/{key}/send_by_email` | Отправить email |

## Support

| Method | Path | Описание |
|---|---|---|
| GET | `/api/v2/support/themes/` | Темы тикетов |
| GET | `/api/v2/support/statuses/` | Доступные статусы |
| GET | `/api/v2/support/events/` | События тикетов |
| GET | `/api/v2/support/ticket/` | Список тикетов |
| POST | `/api/v2/support/ticket/` | Создать тикет |
| GET | `/api/v2/support/ticket/{id}/` | Детали тикета |
| POST | `/api/v2/support/ticket/{id}/` | Добавить комментарий |
| POST | `/api/v2/support/attachment/` | Upload вложение |

## Info / Misc

| Method | Path | Описание |
|---|---|---|
| GET | `/api/info/user` | Инфо о пользователе (email, role, partners, balances) |
| GET | `/api/info/platforms` | Доступные платформы |
| POST | `/api/info/popup` | Popup info |
| GET | `/api/protected/` | Активный пользователь (sanity-check) |
| GET | `/api/category/` | Категории |
| GET | `/api/order/` | Order |
| GET | `/api/proxy/ads` | Proxy: get ads |
| GET | `/api/proxy/cabs` | Proxy: get cabs |
| POST | `/api/promo/open-account` | Open account через промо |
| GET | `/api/v2/users/{user_id}/permissions/` | Permissions |
| POST | `/api/v2/users/onboarding/` | Complete onboarding |

## Известные ограничения

- `period` enum: только `today | yesterday | week | month`. Custom dates через v1 stats или file reports.
- `/api/dashboard/campaigns/{status}/count/`: разрешённые status — `active`, `stopped`, `deleted`, `on_hold`, `declined`, `in_review`. НЕ `paused`, `pending`.
- Все денежные значения в EUR.
- Limit 200 объектов на запрос для большинства list-эндпоинтов; пагинация через `offset` или `cursor`.
