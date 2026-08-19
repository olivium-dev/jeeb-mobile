# Real App E2E Studio Run

Date: 2026-06-20

Target backend: iMac gateway `http://192.168.2.7:10090`

Mobile base used by APK: `http://10.0.2.2:11090` through SSH tunnel `127.0.0.1:11090 -> 127.0.0.1:10090`

Build:

```sh
flutter build apk --debug --flavor dev \
  --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:11090 \
  --dart-define=JEEB_USE_MOCK_PREFIXES=false
```

APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`

Seed/live user used for customer + jeeber journeys:

`c23efd76-6fa4-40cf-814c-116f67ea5e95`

DB user row:

- `Username`: `jeeb-kamal-seed`
- `Email`: `kamal+seed@jeeb.internal`
- `AvailableRoles`: `{customer,driver}`
- `ActiveRole`: `driver`
- `ActiveRoleChangedAt`: `2026-06-20 22:42:31.136594+02`

## Verdict

Most screens are real-app, live-gateway, DB-confirmed green. Two request/order surfaces are not DB-green: the live gateway returns the pending request, and the app no longer uses fixtures for it, but the exact request id/text was not found in Postgres, Redis, or Mongo dbpath strings. I am marking those as backend persistence/source-of-truth gaps, not app fixture regressions.

## Fixes Applied

- Merged/used PR #56 seam path locally: `super_login_plus` writes a real gateway JWT/user id into `AuthTokenStore`.
- Added role override support for `super_login_plus` so the same real user can cold-start as customer or jeeber.
- Removed profile fixture fallback from the shell profile tab; no more `Sami Fawaz` fallback.
- Added live settings screen: `GET /v1/users/me`, role mapping for `driver`/`jeeber`, and live `POST /v1/users/me/role/switch`.
- Fixed notifications to use the authenticated live user id instead of hardcoded seam ids.
- Fixed jeeber availability to use live `GET/PATCH /jeebers/me/availability`.
- Fixed customer/jeeber request routes to live `/requests` and parsed the live bare-list response.
- Fixed jeeber/customer id usage in availability, submitted offers, and earnings to read `AuthTokenStore.userId`.
- Fixed earnings parser for live gateway shape: `entries`, `rowCount`, `totalGross`, `totalCommission`, `totalNet`.
- Removed stale visible earnings copy that claimed a flat 10% fee while live rows have 15%/20% commission percentages.

## Screen Matrix

| Journey | Screen | Device | Screenshot | Real data? | DB-confirmed? | Verdict |
|---|---|---:|---|---|---|---|
| Customer | Login/session -> home | 5554 | [home](screens/emulator-5554.png) | Yes. Real JWT via `super_login_plus`, live `/v1/users/me`, app shows `jeeb-kamal-seed`. | Yes, `jeeb-user-management.Users` row matches user/name/email/roles. | Green |
| Customer | Home pending requests | 5554 | [home](screens/emulator-5554.png) | Live gateway `/requests` data; no app fixture fallback found. Shows `Deliver a small package...`, `Downtown Office, Beirut`, `Standard`. | No. Exact request id/text/address was not found in any Postgres DB dump, Redis scan, or Mongo dbpath string search. | Not DB-green; backend persistence/source gap |
| Customer | Orders/delivery | 5554 | [delivery](screens/emulator-5554-delivery.png) | Live gateway `/requests` data. Shows `Hamra Cafe, Beirut`, `Downtown Office, Beirut`, `Pending`, `Standard`, `$0.00`. | No, same request persistence gap as home/feed. | Not DB-green; backend persistence/source gap |
| Customer | Wallet | 5556 | [wallet](screens/emulator-5556.png) | Yes. Shows wallet amount `250.00`. | Yes for amount: `jeeb-wallet.walletholder/wallets` has holder `jeeb-kamal-seed`, amount `250.00`, wallet `main`, `currencyid=1`. Currency label is only partially confirmed because the API/UI rendered `SAR` while DB exposes numeric `currencyid`. | Green for amount; currency contract needs explicit code |
| Customer | Notifications | 5558 | [notifications](screens/emulator-5558.png) | Yes. Shows `Identity verified` and `Your delivery is on the way` / `JB-1001`. | Yes via Mongo dbpath: `collection-7--2384092833811663365.wt` contains both notification ids, titles, body text, and the user id. Postgres `push_notification` has 0 rows for this user. | Green, DB source is Mongo-backed |
| Customer | Profile | 5554 | [profile](screens/emulator-5554-profile.png) | Yes. Shows `jeeb-kamal-seed`, `kamal+seed@jeeb.internal`, not fixture `Sami Fawaz`. | Yes, `jeeb-user-management.Users` row matches. Review count is also DB-confirmed empty. | Green |
| Customer | Ratings/reviews | 5562 | [reviews](screens/emulator-5562.png) | Yes. Shows empty `No reviews yet`. | Yes. `jeeb_state.ratings` count is `0`; `feedback_service.BlindRating` count is `0`. | Green |
| Customer/Jeeber | Role switch | 5560 | [client selected](screens/emulator-5560-settings-role-client.png), [jeeber selected](screens/emulator-5560-settings-role-jeeber-after.png) | Yes. Live settings role control switches between client and jeeber. | Yes. Final DB row `ActiveRole=driver`, `AvailableRoles={customer,driver}`, changed at `2026-06-20 22:42:31.136594+02`. | Green |
| Jeeber | Availability | 5564 | [jeeber feed](screens/emulator-5564.png) | Yes at data level. The dashboard/feed rendered only after live availability was online. | Yes. `delivery.jeeber_availability` row has `is_online=t`, `vehicle_type=car`, `last_lat=33.5138`, `last_lng=36.2765`. | Green DB state; UI does not visibly label online state on the feed screen |
| Jeeber | Request feed | 5564 | [feed](screens/emulator-5564.png) | Live gateway `/requests?status=pending`; app shows the same pending request text and tier as customer. | No. Same missing persisted request row as customer home/orders. | Not DB-green; backend persistence/source gap |
| Jeeber | Earnings | 5564 | [earnings fixed](screens/emulator-5564-earnings-fixed.png) | Yes. Shows weekly `137.50 USD`, fees `22.13 USD`, net/offer `38.46 USD`, `3` deliveries, rows `2222...`, `1111...`, `3333...`. | Yes. `jeeb-wallet.jeeberearnings` has 3 rows: gross `137.50`, commission `22.13`, net `115.37`; delivery rows match screenshot. | Green after parser/copy fix |

## DB Confirmation Details

Confirmed Postgres rows:

- `jeeb-user-management.Users`: user/name/email/roles for `c23efd76-6fa4-40cf-814c-116f67ea5e95`.
- `jeeb-wallet.wallets`: amount `250.00`, wallet `main`, holder `jeeb-kamal-seed`.
- `jeeb-wallet.jeeberearnings`: `seed-tx-1`, `seed-tx-2`, `seed-tx-3`; totals gross `137.50`, commission `22.13`, net `115.37`.
- `delivery.jeeber_availability`: online `true`, vehicle `car`, coordinates `33.5138,36.2765`.
- `jeeb_state.ratings`: 0 rows for this user.
- `feedback_service.BlindRating`: 0 rows for this user.

Confirmed Mongo-backed notification data:

- Mongo data file `collection-7--2384092833811663365.wt` contains:
  - `01c69a31-57a3-4cc6-a000-d84323b283fb`
  - `Identity verified`
  - `b6818549-3c40-4142-970d-53ed0acea31f`
  - `Your delivery is on the way`
  - `Your package #JB-1001 is out for delivery and will arrive shortly.`
  - user id `c23efd76-6fa4-40cf-814c-116f67ea5e95`

Not DB-confirmed:

- Request `a1e8bb82-573f-4723-b69d-24902326e07f`
- Text/address markers `Deliver a small package`, `Hamra Cafe`, `Downtown Office`

Searches performed for the request markers:

- All non-template Postgres DBs via read-only aggregate queries against the live schema.
- Redis `--scan` across string/hash/list/set/zset values.
- Mongo dbpath string search under `/Users/oudaykhaled/mongodb-data`.

No matching persisted row/value was found.

## Parallel Emulator Fan-out

- `emulator-5554`: customer home -> delivery/orders -> profile.
- `emulator-5556`: wallet.
- `emulator-5558`: notifications.
- `emulator-5560`: settings/role-switch.
- `emulator-5562`: reviews/ratings.
- `emulator-5564`: jeeber feed/availability/earnings.

## Verification

- `dart analyze` on all changed Dart files: passed, no issues.
- `flutter test test/earnings_cubit_test.dart`: passed.
- `flutter build apk --debug --flavor dev --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:11090 --dart-define=JEEB_USE_MOCK_PREFIXES=false`: passed.

## Honest Remaining Gaps

- Pending request/order/feed is live-gateway data but not DB-confirmed. This needs a backend source-of-truth fix or a documented DB/collection for `/requests`.
- Wallet currency is not fully DB-confirmed from a code; DB exposes `currencyid=1` and the UI renders `SAR`. The gateway should expose a currency code if strict screen equality is required.
- Mongo namespace could only be partially mapped from `_mdb_catalog.wt` (`jeeb_notifica...`) because no `mongosh`/Mongo client is installed on the iMac. The raw persisted notification strings are present in the Mongo dbpath.
