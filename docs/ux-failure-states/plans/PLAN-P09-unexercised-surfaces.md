# PLAN P09 — exercise the never-exercised surfaces on the real device

Branch `ux/api-error-handling-empty-states` @ `ecfd3cc1` (worktree
`/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors`, draft PR #335).
Device SM-A336B `RZCT505K7WF`, app `app.jeeb.mobile.dev`, product activity
`com.olivium.jeeb.MainActivity`, Dev Tool alias `com.olivium.jeeb.LegacyDevToolLauncher`.
Live gateway `https://msi.olivium.space/gateway` (RFC 7807 producer, health 200 on 2026-09-05).
Scratchpad `$SP` = `/private/tmp/claude-501/-Users-oudaykhaled-Desktop-olivium-jeeb/6a29e634-9ff5-4e5b-b358-a1a84368ab4f/scratchpad`.
Probe evidence for every claim below: `$SP/p09-probe/` (minted sessions, per-account endpoint bodies, proxy test log).

This plan changes NO repo file unless a defect is found (then: fix + identifier test on the same branch).
Deploys are never executed. Device hygiene: `adb install -r` only, never uninstall, never "Clear Local Data".

---

## 0. Why these were never reached (verified)

| Surface | Why runs 1–3 never reached it | Verified at |
|---|---|---|
| Chat inbox (`ChatTab`) | Not mounted anywhere in the product: `grep -rn "ChatTab" lib` → only `lib/devtool/catalog/entries/batch_11_entries.dart:168-200` + fixtures. Shell tabs are `home/orders/dashboard/earnings/profile` (`lib/features/shell/tabs/`). Its read is `GET /v1/requests` (`lib/features/chat/data/dio_chat_conversations_repository.dart:15`), not a conversations endpoint. | code |
| Chat detail error/empty | Reachable (jeeber dashboard active-delivery banner `onOpenChat` → `/chat/<deliveryId>` at `lib/features/shell/tabs/dashboard_tab.dart:166`; client In-Progress row → `chat-detail` at `lib/features/home_client/presentation/tabs/in_progress_tab.dart:62`) but no run opened a chat. Karim has two 0-message threads. | code + probe |
| Jeeber feed error | Feed is only read when availability is ONLINE (`lib/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart:379-383` → `jeeber_feed_offline_empty_state`), and in a total outage the availability read fails first and replaces the tab with `jeeber_home_error` (`jeeber_home_screen.dart:556-575`). Needs a *path-selective* fault. | code |
| Pending-offers error | Same: needs `/v1/offers` to fail while availability succeeds. | code |
| `wallet_activity_empty` | Jeeber-only (client → `customer-wallet` stub; ledger 403 for a client). Karim TestJeeber has 1 ledger row → never empty. Needs a KYC-verified jeeber with 0 ledger rows. | probe `karim-test-v1_jeeb_wallet_ledger.json` items=1; `client-…` 403 |
| `reviews_empty` | Only product entry = client → offers → jeeber profile → "View all reviews" (`client_offers_screen.dart:499` → `delivery_man_profile_screen.dart:200`). Needs a jeeber with 0 reviews to have offered on the client's request. Karim has 2 reviews. | code + probe |
| Cold-start offline | Never attempted (run 1 `offline/10-coldstart.png` had Wi-Fi ON). | JUDGE-RUN1 gaps |
| Offline on other screens | Only Deliveries with warm cache was run. | JUDGE-RUN1 gaps |
| Client-home sub-tab retries | Sub-tab errors render only on a *partial* failure: `allPrimaryFailed` = requests AND inProgress failed (`lib/features/home_client/domain/client_home_repository.dart:55-56`) → whole-home error; partial → `pendingError/repliesError/inProgressError` (`client_home_cubit.dart:236-248`). Blackhole outage is always total. | code |

**Conclusion:** everything except the ChatTab inbox is reachable with (a) a path-selective fault lever, (b) one extra account (a KYC-verified jeeber with no history), (c) two on-device sessions (jeeber + client) that already exist.

---

## 1. The lever — fault proxy on the Mac, reached over `adb reverse` (PROVEN)

Reconciled (C2): the mitmdump addon below is the PROVEN interim. The repo tool is P08's `tool/fault_proxy/fault_proxy.py`;
once P08 D1 exists use it with the shared conventions (listen `127.0.0.1:8089`, `adb reverse tcp:8089 tcp:8089`, device
override `http://127.0.0.1:8089/gateway`, rule paths `^/gateway/…`, `respond.drop: true` = this plan's `drop`). Every
`{"match":"/x","kind":"503"}` below translates 1:1 into a P08 rule. If you must fall back to mitmdump, still use port 8089
and the `/gateway` override so the runbooks stay identical.

Verified 2026-09-05 (`$SP/p09-probe/fault_addon.py`, `mitm.log`):
- `mitmdump` 18080 → `https://msi.olivium.space` with `/gateway` path re-homing: pass-through `GET /health/ready` 200, `GET /v1/requests` 401 problem+json (Dart UA); a rule `{"match":"/jeebers/me/feed","kind":"503"}` returned `503 application/problem+json`.
- `adb -s RZCT505K7WF reverse tcp:18080 tcp:18080` works (`UsbFfs tcp:18080 tcp:18080`).
- Cleartext to `127.0.0.1` is whitelisted in the dev flavor (`android/app/src/dev/res/xml/network_security_config.xml:6-9`) AND the override bypasses the transport policy anyway (`lib/core/network/mock_gateway_client.dart:116` per memory).
- Cloudflare 1010 blocks only the `Python-urllib` UA — irrelevant to the app (Dart UA passes).

### 1.1 Files (already written, copy as-is)
- `$SP/p09-probe/fault_addon.py` — mitmdump addon. Rules JSON is re-read on EVERY request, so faults flip live without restarting anything.
- Rules file: `$SP/p09-probe/fault_rules.json`, shape:
  ```json
  {"rules":[{"match":"/jeebers/me/feed","kind":"503"},
            {"match":"/deliveries","kind":"drop"},
            {"match":"/requests","kind":"429","retry_after":30}]}
  ```
  `kind`: `503|500|429|404|403|401` → RFC 7807 `application/problem+json` (429 adds `Retry-After` header + `retryAfter`), `drop` → TCP reset (Dio `connectionError` → `NetworkFailure`, connectivity copy). `match` is a substring of the path (query stripped) — keep it specific. Do NOT use `hang` (blocks the proxy loop); for timeouts use the proven blackhole `http://10.255.255.1:9`.
  Empty rules = `{"rules":[]}` → pure pass-through.

### 1.2 Start / stop
```
export FAULT_RULES=$SP/p09-probe/fault_rules.json
echo '{"rules":[]}' > $FAULT_RULES
mitmdump -q --mode reverse:https://msi.olivium.space -p 18080 --set connection_strategy=lazy -s $SP/p09-probe/fault_addon.py > $SP/p09-probe/mitm.log 2>&1 &
adb -s RZCT505K7WF reverse tcp:18080 tcp:18080
curl -s -A "Dart/3.10 (dart:io)" -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18080/health/ready   # must print 200
```
On the phone: Dev Tool → **Server URL** → type `http://127.0.0.1:18080` → Save → **Apply & Restart**. Confirm the Dev Tool banner reads "Server URL override active — http://127.0.0.1:18080". Product app then talks to the live gateway through the proxy with the SAME session token (tokens survive the switch).
Stop: restore Server URL to `https://msi.olivium.space/gateway` → Apply & Restart; `adb reverse --remove tcp:18080`; `kill %1`.

### 1.3 Behaviours to expect (so the judge does not misread timing)
- `RetryInterceptor` retries idempotent GETs on 502/503/504 up to `maxAttempts=2` with 300 ms base backoff (`lib/core/network/retry_interceptor.dart:13-15,64-65`) → a persistent 503 renders the error block ~1 s after the read starts. Never make a rule one-shot.
- `RateLimitInterceptor` opens a per-path-scope window from `Retry-After` (default 5 s, max 120 s; `rate_limit_interceptor.dart:13-15,30-32`) and rejects later GETs on that scope with a typed `RateLimitSuppression`. After any 429 scenario, wait the window out (or force-stop the app) before reusing the path.
- Realtime socket / Firestore / FCM never follow the REST override (compile-time URLs) — chat live delivery keeps working through a proxy fault; only REST surfaces are affected, which is what we test.
- Copy families (`lib/l10n/app_en.arb`/`app_ar.arb`, resolver `lib/core/widgets/jeeb/app_failure_copy.dart:19-99`):
  - airplane / radios OFF → **"No connection" / "Check your connection and try again."** (AR "لا يوجد اتصال" / "تحقّق من اتصالك وحاول مجددًا.")
  - `drop` (TCP reset while the device is online) → Reconciled (C3): on a build with P13 → **"Can't reach Jeeb" / `errorUnreachableBody`** (AR "تعذّر الوصول إلى جيب…"); on `ecfd3cc1` → the "No connection" pair. Record the head SHA.
  - `503` → **"Something went wrong" / "Jeeb is briefly unavailable. Try again in a moment."** (AR "حدث خطأ ما" / "جيب غير متاح مؤقتًا. حاول مجددًا بعد لحظات.")
  - `500` → "Something went wrong" / "We couldn't complete that. Try again in a moment."
  - `429` → **"Too many attempts" / "Try again in N seconds."** (plural set `errorRateLimitedRetryIn*`)
  - `403` → "You don't have access" / "This isn't available on your account." + exit CTA (jeeber surfaces exit to `offer-kyc-gate`, `lib/features/jeeber_request_feed/presentation/jeeber_failure_exit.dart:21-24`)
  - blackhole → "This is taking too long" / "The connection timed out before we got an answer. Try again."
  A surface that shows connectivity copy for a 503 is a DEFECT (R6: only Network/Timeout blame connectivity).

---

## 2. Accounts and data (live state probed 2026-09-05 ~14:00 UTC, `$SP/p09-probe/*.json`)

| Account | userId | Roles / KYC | Live data | Use for |
|---|---|---|---|---|
| **Karim TestJeeber** | `106078a3-4758-45c1-9d31-71b503a3fce4` | client+jeeber, KYC `Verified` | 5 active deliveries (`fd91232f`, `13b8bca2`, `352d03a1`, `4227d276`, `7f46b377`), 5 submitted offers (1 `pending` on `defb1f07`), ledger **1** row, reviews **2**, notifications 31 | feed error, pending-offers error, chat detail (resolution/history/empty/send-failed), offline matrix (jeeber) |
| **devtool_client_1788592148874** | `de520a28-a7a4-4e49-8da0-e92b6a1b7284` | client only, KYC 404 | 1 pending request **`defb1f07-efa5-4b8f-bc1a-09d6fcd1140b`** with **1 offer from Karim** (expires 2026-09-06 11:21 UTC), 3 cancelled, `/deliveries?stage=active` → 1 row (conv `80e1018a…`, 0 msgs), notifications 2 | client-home sub-tab retries, offers → jeeber profile → reviews, offline matrix (client), cold-start offline |
| **NEW: "P09 EmptyJeeber"** | minted in step 2.1 | jeeber, KYC → `Verified` via AutoApprove | ledger 0, reviews 0, offers 0, notifications 0, feed 0 | `wallet_activity_empty`, `jeeber_pending_offers_empty_state`, `reviews_empty` (as the 0-review offerer), `earnings_empty` |
| demo "Karim" (`d1000000-…-0002`) | — | **DO NOT USE**: `GET /v1/users/me` → **502**, KYC 404 (`karim-demo-v1_users_me.json`) | | |

Session switching on the phone: Dev Tool → Super Login → **Super Login Plus** → search name → tap row → force-stop → `am start -n app.jeeb.mobile.dev/com.olivium.jeeb.MainActivity`. Trap (run-2 report): the "Scenario Users" row sits under the nav bar — scroll the Dev Tool list first, tap at y≈2020.

### 2.1 Mint the empty jeeber (once; ~10 min real UI, or ~2 min curl fallback)
Mechanism verified in gateway `origin/main@6679f6ee`: `POST /dev/seed/user {role,phone,displayName}` (`src/JeebGateway/Controllers/DevController.cs:97-111`) creates a UM user with `roles=[customer]`; `GET /v1/kyc/status` → 404 `No KYC submission` → dashboard gate `JeeberKycStatus.none → registerPrompt` (`lib/core/session/jeeber_kyc_status_gate.dart:43`) i.e. "Become a Jeeber", no feed/earn. `POST /v1/kyc/submit` (JSON, `KycSubmissionBffController.cs:239-241`) requires only `id_document_front_url`, `id_document_back_url`, `selfie_with_liveness_url` refs (:44-54) and, with `FeatureFlags:Kyc:AutoApprove` ON on MSI (:47-50, :325-327), returns `state="Verified"` and composes the driver role grant (:375-378).

1. Dev Tool → **Scenario Users** → Scenario "Jeeber" → **Create user**. Record `displayName`/`userId` from the result card (`$SP/device-evidence-4/accounts.md`).
2. Tap **Make online-ready** (`devtool.scenarioUsers.makeOnlineReady`, `lib/devtool/users/scenario_users_page.dart:297-300`). It saves a session for that user into the product token store (`_saveSession`, :171-180), forced `customer+driver` if the normal mint 403s (:162-168). Forced tokens now survive refresh (gateway PR #562).
3. Force-stop → launch product → Profile tab → the "Register as a delivery" row → `kyc-status` (`lib/features/shell/tabs/profile_tab.dart:105`) → KYC wizard: `kyc_tos_accept` → `kyc_id_front_upload`, `kyc_id_back_upload`, `kyc_selfie_upload` (camera only: `lib/features/kyc/application/kyc_wizard_cubit.dart:357`) → `kyc_submit_cta` → `kyc_submitting_state` → status view shows Verified (`kyc_status_feed_cta`). Photograph anything (a card on the desk); the dev gateway does not inspect content.
   **Curl fallback (data seeding via super-login, allowed by the task):** mint `POST $G/auth/tokens {"userId":"<id>","roles":["customer","driver"]}` (OpenMode ON, no key needed — proven in `$SP/p09-probe/mint-*.json`), then
   `curl -X POST $G/v1/kyc/submit -H "Authorization: Bearer $T" -H 'content-type: application/json' -d '{"id_type":"national_id","id_number":"P09-0001","id_document_front_url":"seed://p09/front","id_document_back_url":"seed://p09/back","selfie_with_liveness_url":"seed://p09/selfie","tos_accepted_version":"jeeb_tos_v1"}'` → expect 201 with `state:"Verified"`; then `GET $G/v1/kyc/status` → `Verified`. If the submit 4xxs on the ref format, fall back to the real-UI path.
4. Cold-start the product app once (gateway authority-first `active_role` self-heals the session). Assert: Requests tab shows `jeeber_home_root` + `jeeber_feed_offline_empty_state` (duty offline), Earn tab `earnings_empty`, Profile shows the new name. Probe with its token: ledger `items=0`, reviews `totalCount=0`, offers `items=0`, notifications `items=0` → save as `$SP/device-evidence-4/accounts/emptyjeeber-*.json`.

---

## 3. Per-surface runbooks

Evidence dir: `$SP/device-evidence-4/<surface>/NN-step.png` + `.xml` (uiautomator dump; helper `$SP/ui.sh`). Each surface ends with a `REPORT.md` assertion table in the run-2 format (id seen / file / PASS-FAIL). Every assertion is by `resource-id` (semantics identifier) — never by pixel. Copy is asserted from `content-desc`. Build under test: `ecfd3cc1` (rebuild only if the branch moves; recipe in `$SP/device-evidence-2/build/REPORT.md` — copy `google-services.json` ×2 from the main clone, pass `-PMAPS_API_KEY`, `-Pjeeb.devtool=true --dart-define=JEEB_DEVTOOL_ENABLED=true`).

### S1 — Chat (session: Karim; proxy ON with empty rules)
Thread facts (probe `$SP/p09-probe/karim-test-*`): delivery `fd91232f` ↔ conversation `f610caaf…` **0 messages**; `4227d276` ↔ `14341af9…` **0 messages**; `352d03a1` ↔ `3bd25d45…` 9; `7f46b377` (AtDoor) ↔ `0b077dbc…` 4.
Resolution reads: `GET /v1/conversations?correlationKey=<id>` (`lib/features/deep_link_targets/chat_detail_screen.dart:646`), fallback `GET /v1/conversations/<id>/messages` (:688); `classifyLookupFailure` (`lib/features/chat/domain/conversation_lookup.dart:27-35`): 400/404/410 → absent (compose), anything else / no status → **unavailable** → `_resolutionUnavailable=true` (:752) → `chat_resolution_error` (:1776) + `chat_detail_resolution_retry` (:2011). History: `GET /v1/conversations/$id/messages` (`lib/features/chat/data/dio_chat_gateway.dart:62-67`) failure → `historyLoadFailed` (`chat_cubit.dart:~325`) → `chat_history_error` + `chat_history_error_retry` (`chat_screen.dart:1160-1166`). Empty thread → `chat_screen_empty` (`chat_screen.dart:1220`). Send failure → `MessageStatus.failed` (`chat_cubit.dart:817`) → `chat_detail_message_failed` + `chat_detail_message_retry` (`chat_message_bubble.dart:202,138`).

| # | Steps | Assert (ids) |
|---|---|---|
| S1.1 empty thread | Requests tab → active-deliveries banner `jeeber_active_deliveries_view_all` → open delivery `fd91232f` (or `4227d276`) → its chat CTA (`mark_delivered_open_chat_cta` / banner `onOpenChat`) | `chat_screen_empty` present; NO `chat_history_error`; header shows the counterpart name; composer enabled |
| S1.2 resolution error | Back out. Rules → `[{"match":"/v1/conversations","kind":"503"}]`. Re-open the same chat. | `chat_resolution_error` + `chat_detail_resolution_retry` within ~3 s; NO `chat_screen_empty`, NO composer; copy = 503 family (NOT "No connection") |
| S1.3 resolution retry | Rules → `[]`. Tap `chat_detail_resolution_retry`. | `chat_screen_empty` (or `chat_detail_message_list` for a populated thread) — recovered without leaving the screen |
| S1.4 history error | Open the 9-message thread (`352d03a1`) with rules `[{"match":"/messages","kind":"503"}]` (the correlationKey lookup still resolves). | `chat_history_error` + `chat_history_error_retry`; 503 copy; then rules `[]` + tap retry → `chat_detail_message_list` with 9 bubbles |
| S1.5 send failed | Rules `[]`; open the empty thread; Wi-Fi+data OFF (`svc wifi disable; svc data disable`); type "p09" → send. | bubble `chat_detail_message_failed` + `chat_detail_message_retry`; `offline_banner` present. Radios ON → tap retry → `chat_detail_message_sent`. Delete nothing; the message is real test data — note it in REPORT |
| S1.6 inbox (catalog only) | Dev Tool → Screen Catalog → feature `shell`, screen `ChatTab` → states "Error — gateway down (503)", "Error — offline", "Empty — a real 200 with zero rows", "Refresh failed — rows stay up" (`batch_11_entries.dart:170-198`) | `chat_tab_error` + `chat_tab_retry_cta` with 503 copy; offline state with network copy; `chat_tab_empty` "No conversations yet"; `chat_tab_refresh_error` above rows. REPORT must say "catalog, not product" |

### S2 — Jeeber feed error (session: Karim; must be ONLINE)
Reads: availability `GET /jeebers/me/availability` (`dio_availability_gateway.dart:41`) — must succeed; feed `GET /v1/jeebers/me/feed?status=pending` (`dio_request_feed_repository.dart:35`, throws `AppFailure` :58-59). Cubit `request_feed_cubit.dart:166-178`: cold (no rows) → `RequestFeedStatus.error` → `jeeber_feed_error` + `jeeber_feed_retry_cta` (+ `jeeber_feed_exit_cta` on Forbidden) via `_FeedFailureBody` (`jeeber_feed_tab_view.dart:805-826`); warm → `jeeber_feed_refresh_failed_note` (:858).

| # | Steps | Assert |
|---|---|---|
| S2.0 | Requests tab, toggle `jeeber_home_accept_orders_switch` ON → | `jeeber_feed_empty_state` (online, 0 rows) — NOT the offline empty |
| S2.1 cold 503 | Force-stop. Rules `[{"match":"/jeebers/me/feed","kind":"503"}]`. Launch → Requests tab. Dump at t≈2 s, 5 s. | `jeeber_home_root` stays (availability OK); `jeeber_feed_error` + `jeeber_feed_retry_cta`; 503 copy; NO `jeeber_feed_empty_state`, NO `jeeber_home_error`, NO "Become a Jeeber" |
| S2.2 retry | Rules `[]` → tap `jeeber_feed_retry_cta` | `jeeber_feed_empty_state` (or rows) |
| S2.3 cold drop | Rules `[{"match":"/jeebers/me/feed","kind":"drop"}]`, pull-to-refresh on the empty feed | error block with the `NetworkFailure` copy — Reconciled (C3): `errorUnreachableBody` on a P13 build (device online), `errorNetworkBody` on `ecfd3cc1`; radios-OFF rows (S6/S7) are the only ones that may say "No connection" on a P13 build |
| S2.4 warm refresh failure | Create a request from the client session on a 2nd pass, or reuse `defb1f07` if not expired, so the feed has ≥1 row; rules 503; pull-to-refresh | rows stay; `jeeber_feed_refresh_failed_note`; no full-screen error |
| S2.5 429 (bonus) | Rules `[{"match":"/jeebers/me/feed","kind":"429","retry_after":20}]`, pull-to-refresh on 0 rows | "Too many attempts" + "Try again in N seconds" countdown copy; retry inside the window still shows rate-limited copy (typed suppression, no connectivity blame); after 20 s + rules `[]` → recovers |
| S2.6 403 (bonus) | Rules `[{"match":"/jeebers/me/feed","kind":"403"}]` | `jeeber_feed_error` with Forbidden copy AND `jeeber_feed_exit_cta` (KYC gate), NOT an inert Retry |
| S2.7 AR | Settings → Arabic (`settings_language_ar_option`; verify id in the settings dump) → repeat S2.1 | same ids, AR copy "حدث خطأ ما" / "جيب غير متاح مؤقتًا…"; RTL layout |

### S3 — Pending-offers error (session: Karim; in-shell surface)
Read: `GET /v1/offers?jeeberId=<id>` (`dio_submitted_offers_repository.dart:21-36`); `SubmittedOffersCubit.load` on first tap of `jeeber_feed_pending_tab` (`jeeber_feed_tab_view.dart:427-431`). States (:920-975): cold error → `jeeber_pending_offers_error` + `jeeber_pending_offers_retry_cta`; warm → `jeeber_pending_offers_refresh_failed_note`; empty → `jeeber_pending_offers_empty_state`. Karim has 5 offers → the block is only cold-reachable if the rule is set BEFORE the first tab open after a cold start.

| # | Steps | Assert |
|---|---|---|
| S3.1 cold 503 | Force-stop. Rules `[{"match":"/v1/offers","kind":"503"}]`. Launch → Requests tab → tap `jeeber_feed_pending_tab`. | `jeeber_pending_offers_loading` then `jeeber_pending_offers_error` + `jeeber_pending_offers_retry_cta`; 503 copy; NO `jeeber_pending_offers_empty_state` |
| S3.2 retry | Rules `[]` → tap retry | Karim's offer rows (`pending_offer_row_*`) — Reconciled (C7): 4 rows, because P04 Part A withdraws `8bbea040` on `defb1f07` before this run |
| S3.3 warm | Rules 503 → pull-to-refresh | rows stay + `jeeber_pending_offers_refresh_failed_note` |
| S3.4 empty | Switch to EmptyJeeber (online) → Pending tab | `jeeber_pending_offers_empty_state` |
| S3.5 standalone route (P2) | `adb shell am start -a android.intent.action.VIEW -d "jeeb://jeeber/pending-offers" app.jeeb.mobile.dev` (host folded into the path by `normalizeJeebSchemeDeepLink`, `app_router.dart:331`) with rules 503 | `pending_offers_error` (`jeeber_pending_offers_screen.dart:257`) + derived `pending_offers_retry_cta`; mark "deep link, not product navigation" |

### S4 — Wallet activity empty (+ error) (session: EmptyJeeber; then Karim for the non-empty control)
Route `/wallet/activity` (`app_router.dart:1789`). Product entry: Earn tab (`EarningsDashboardScreen`, `earnings_tab.dart:86`) → `earnings_activity_link` (`earnings_dashboard_screen.dart:713-722`) → wallet-activity; or `earnings_wallet_link` (:809-815) → `/wallet` hub → `wallet_see_all_activity` (`wallet_hub_screen.dart:394`). Read `GET /v1/jeeb/wallet/ledger?page=1&pageSize=20` (`dio_wallet_ledger_repository.dart:11`). States (`wallet_activity_list_screen.dart:179-186, 281`): `wallet_activity_loading` / `wallet_activity_error` (+`wallet_activity_retry_cta`, `wallet_activity_exit_cta`) / `wallet_activity_empty`.

| # | Steps | Assert |
|---|---|---|
| S4.1 empty | EmptyJeeber → Earn → `earnings_activity_link` (if the empty earnings layout hides it, use `earnings_wallet_link` → hub → `wallet_see_all_activity`) | `wallet_activity_loading` (t≈0.5 s) then `wallet_activity_empty`; NO `wallet_activity_error`; ledger probe for this user `items=0` filed alongside |
| S4.2 error | Rules `[{"match":"/jeeb/wallet/ledger","kind":"503"}]` → back → re-enter | `wallet_activity_error` + `wallet_activity_retry_cta`; 503 copy; NOT `wallet_activity_empty` |
| S4.3 retry | Rules `[]` → retry | `wallet_activity_empty` |
| S4.4 control | Karim → same path | 1 row (`wallet_activity_row_*`/ledger card) — proves S4.1's empty is a real zero, not a parse drop (`wallet_activity_unrenderable_note` must be ABSENT in both) |
| S4.5 hub offline | Wallet hub with radios OFF | `wallet_load_error` (`wallet_hub_screen.dart:203`) + derived `wallet_load_retry_cta`, network copy, `offline_banner` |

### S5 — Reviews empty (two-account flow) (+ inline profile empty, + error)
Read `GET /v1/ratings/jeeb/reviews?jeeberId=<id>&page=1&pageSize=20` (`dio_reviews_repository.dart:24`). Product path (client): Home → Replies → `replies_check_offers_cta` (`replies_card.dart:231`) → `/requests/:id/offers` (`offer-review`, `app_router.dart:910`) → `offer_card_<jeeberId>_name` (`offer_card.dart:223`) → `delivery-man-profile` (`client_offers_screen.dart:499`) → `_ReviewsBand` `delivery_man_profile_reviews_loading|error|empty` (`delivery_man_profile_screen.dart:222-231`, `delivery_reviews_list.dart:58`) → `profile_view_all_reviews` (`delivery_reviews_header.dart:128`, always rendered) → `reviews-list` → `reviews_loading` / `reviews_error` / `reviews_empty` (`reviews_list_screen.dart:451,419,476`).

| # | Steps | Assert |
|---|---|---|
| S5.0 seed | EmptyJeeber online → feed shows client request `defb1f07` (if expired: from the client session create a new request first — 1 min, recipe in `$SP/device-evidence-2/cancel/REPORT.md`) → `feed_make_offer_cta` → submit an offer. Probe `GET /v1/offers?requestId=<id>` → 2 offers (Karim + EmptyJeeber). | offer submitted (`jeeber_pending_offers` row) |
| S5.1 inline empty | Client session → Home → `replies_check_offers_cta` → tap `offer_card_<EmptyJeeberId>_name` | `delivery_man_profile_reviews_empty` on the profile; `offer_card_no_ratings` was shown on the card |
| S5.2 list empty | Tap `profile_view_all_reviews` | `reviews_loading` → `reviews_empty`; NO `reviews_error`; `reviews_back` returns to the profile |
| S5.3 control | Back → tap Karim's card name → view all | `reviews_aggregate` + 2 review rows (Karim has 2) |
| S5.4 error | Rules `[{"match":"/ratings/jeeb/reviews","kind":"503"}]` → open EmptyJeeber's profile again | `delivery_man_profile_reviews_error` + `delivery_man_profile_reviews_retry_cta`; then view-all → `reviews_error` + derived `reviews_retry_cta`; rules `[]` + retry → `reviews_empty` |
| S5.F fallback (only if S5.0 is impossible) | `am start -a android.intent.action.VIEW -d "jeeb://profile/delivery-man/<EmptyJeeberId>/reviews" app.jeeb.mobile.dev` (route `reviews-list-by-id`, `app_router.dart:1868`) | `reviews_empty`; REPORT says "deep link" |

### S6 — Cold start while offline (both sessions)
Bootstrap has no network dependency (`lib/app/bootstrap.dart:27-60`: DevSeam, SharedPreferences, session seam); `_BootstrapErrorApp` only on a thrown bootstrap error (`jeeb_bootstrap.dart:195`) — offline must NOT show it. Connectivity seed `bindSource(source.onlineStates(), seed: source.currentlyOnline())` (`lib/app/app.dart:415-423`) → `_observe(false)` with `previous == null` emits offline (`network_reachability_signals.dart:82-88`) → `OfflineCubit.setOffline` → banner via `OfflineBannerHost` (`app.dart:825`).

| # | Steps | Assert |
|---|---|---|
| S6.1 jeeber | Server URL back to `https://msi.olivium.space/gateway` (proxy not involved). Force-stop. Radios OFF (verify `ping 8.8.8.8` DOWN). `am start` product. Dump at t≈2 s, 5 s, 15 s. | t≤5 s: `offline_banner` present (content-desc "You're offline…") and `offline_banner_dismiss_cta`; `jeeber_home_loading` → `jeeber_home_error` + `jeeber_home_load_error_retry_cta` with **network** copy; NEVER `jeeber_dashboard_empty_state`/"Become a Jeeber"; no `bootstrap_error`; greeting shows no "Welcome back"/"?" placeholder |
| S6.2 tabs offline-cold | Still offline: Deliveries, Earn, Profile, Settings, Notifications | `order_history_error`, `earnings_error`, `customer_profile_load_error`, `live_settings_error`, `notifications_error` — each with its `_retry_cta` and network copy; none of `order_history_empty_active`/`earnings_empty`/`notifications_empty`/"Add your name" |
| S6.3 reconnect | Radios ON, no tap. Poll 2 s × 10. | `offline_banner` gone ≤10 s; tap `jeeber_home_load_error_retry_cta` → `jeeber_home_root` with "Ahlan, Karim" + `View all (5)` |
| S6.4 client | Same with the client session | `client_home_error` + `client_home_retry_cta` (network copy), NOT `_request_empty_state_root`; greeting "Hello, devtool_client_…" intact; reconnect → retry → pending row `pending_requests_item_defb1f07…` (if not expired) |
| S6.5 AR | Repeat S6.1 in Arabic | banner AR text (from `offlineBannerMessage` AR), `jeeber_home_error` AR copy, RTL |

### S7 — Offline on screens other than Deliveries (warm + cold)
Matrix (each = radios OFF → action → dump; then radios ON → assert clearance). Warm = screen loaded online first, then offline + pull-to-refresh.

| Screen (session) | Cold-offline id | Warm-offline (refresh) id | Notes |
|---|---|---|---|
| Client Home (client) | `client_home_error` + `client_home_retry_cta` | `client_home_refresh_failed_note` (`client_home_screen.dart:1780`), rows kept | banner present |
| Notifications (both) | `notifications_error` + `notifications_retry_cta` (`notifications_list_screen.dart:324`) | refresh note/snack per screen | no `notifications_empty` while offline |
| Profile (both) | `customer_profile_load_error` + `customer_profile_retry_cta` | — | no placeholders (F4 regression guard) |
| Settings (both) | `live_settings_error` + `live_settings_retry_cta` | — | `live_settings_sign_out_cta` still present |
| Earn (jeeber) | `earnings_error` + `earnings_retry_cta` | `earnings_refresh_failed_note` (:248/309) | not `earnings_empty` |
| Wallet hub (jeeber) | `wallet_load_error` + `wallet_load_retry_cta` | `wallet_refresh_failed_note` (:307) | |
| Wallet activity (jeeber) | `wallet_activity_error` | `wallet_activity_refresh_failed_note` (:275/385) | |
| Requests (jeeber, online duty) | `jeeber_home_error` (availability read) | `jeeber_feed_refresh_failed_note` only if ≥1 row | duty-offline shows `jeeber_feed_offline_empty_state` — do not confuse with connectivity |
| Chat detail (jeeber) | `chat_resolution_error` | send → `chat_detail_message_failed` | S1.5 |
For every row: `offline_banner` present while offline; after radios ON: banner gone ≤10 s, any `*_refresh_failed_snack` gone (F6), `<screen>_retry_cta` recovers. Machine-grep every dump for `Exception|Dio|Socket|10.255|127.0.0.1|status ?code` → must be empty.

### S8 — Client-home sub-tab retries (session: client; proxy ON)
Reads (`dio_client_home_repository.dart`): `GET /requests?status=active&role=client` (:272-283) and `GET /requests?role=client` (:344-353) → `_Bucket.requests`; `GET /deliveries?stage=active&limit=50` (:304-311) → `_Bucket.inProgress`. Partial-failure branch `client_home_cubit.dart:236-248` sets `pendingError`/`repliesError` = requests failure, `inProgressError` = deliveries failure. Render: `pending_error_state` + `pending_retry_cta` (`pending_requests_tab.dart:121-128`), `replies_error_state` + `replies_retry_cta` (`replies_tab.dart:182-189`), `in_progress_error_state` + `in_progress_retry_cta` (`in_progress_tab.dart:143-150`). Retry = `ClientHomeCubit.load()` (whole snapshot).

| # | Steps | Assert |
|---|---|---|
| S8.1 requests bucket dead | Force-stop. Rules `[{"match":"/requests","kind":"503"}]` (does not match `/deliveries`). Launch. | `client_home_root` (NOT `client_home_error`); merged list shows `pending_error_state` + `pending_retry_cta` (and `replies_error_state` + `replies_retry_cta` if the Replies section is visible — `hideWhenEmpty` collapses it only when no error); 503 copy; NO `_request_empty_state_root` |
| S8.2 retry | Rules `[]` → tap `pending_retry_cta` | `pending_loading_state` → pending row `pending_requests_item_defb1f07…` (or `_request_empty_state_root` if it expired — that is then a TRUE empty, note it) |
| S8.3 deliveries bucket dead | Force-stop. Rules `[{"match":"/deliveries","kind":"503"}]`. Launch → `orders_filter_open` → In Progress. | `in_progress_error_state` + `in_progress_retry_cta`; Pending bucket still rendered normally |
| S8.4 retry | Rules `[]` → tap `in_progress_retry_cta` | `in_progress_loading_state` → `in_progress_empty_state` or the active row |
| S8.5 warm partial | Healthy load; rules 503 on `/requests`; pull-to-refresh | rows kept; `client_home_refresh_failed_note`; NO sub-tab error block replaces existing rows (R6 warm rule, `client_home_cubit.dart:203-234`) |
| S8.6 429 on requests (bonus) | Rules `[{"match":"/requests","kind":"429","retry_after":15}]` cold | `pending_error_state` with "Too many attempts / Try again in N seconds"; retry within window → still rate-limited copy, no connectivity blame; after 15 s + `[]` → recovers |
| S8.7 total | Rules 503 on both `/requests` and `/deliveries` | `client_home_error` + `client_home_retry_cta` (control: proves the partial/total split) |

Trap: `match` is a substring; `/requests` also hits `/v1/requests/<id>` (request detail) — only run S8 rules while on the home. Trap: the request-list reads are coalesced (`_coalescer.get`, :934) — dump ≥1 s after launch.

---

## 4. Judge rubric (what a PASS requires, per surface)
1. Error branch before empty branch: no `*_empty*` id present in any dump taken while a fault/offline is active.
2. Copy family matches the fault kind (503 → server family; drop/airplane → network family; 429 → rate-limited; 403 → forbidden + exit CTA). Connectivity blame under a 503 = FAIL.
3. Retry CTA id per grammar (`<screen>_retry_cta`, or the frozen overrides listed above) present, tappable (`clickable=true`), and recovers to the loaded/empty state after the fault is lifted.
4. Loading id shown between retry tap and result (t≈0.5–1 s dump) — never the empty id.
5. Offline banner (`offline_banner`, `offline_banner_dismiss_cta`) present while offline on every screen, gone ≤10 s after reconnect, no tap.
6. AR: at least S2.7 + S6.5 (+ one chat state) in Arabic with the AR strings above.
7. Machine copy-leak grep clean across all dumps.
8. REPORT.md per surface + `$SP/device-evidence-4/JUDGE-RUN4.md` in the run-1 JSON shape (pass/failures/gaps/summary), judged by a separate agent from dumps only.

## 5. Owner decisions
- **D-P09-1 — MERGED into OD-9 (P12's question "Delete `ChatTab` and its conversations stack — YES/NO"), Reconciled (C6). Run S1.6 BEFORE P12 Change B; if the owner answers YES, S1.6 becomes "n/a — deleted" once P12-B lands.** `ChatTab` is dead code in the product. Options: (a) mount it (Messages entry in the shell/header) — then its read must move off `GET /v1/requests` onto a conversations endpoint (`JeebConversationsController.cs:163` `GET /v1/conversations` lists nothing without a key — a new gateway list route would be needed); (b) delete `lib/features/shell/tabs/chat_tab.dart` + `DioChatConversationsRepository` + catalog entry (catalog never-delete rule R2 says keep entries → so (b) needs an explicit ruling). Until ruled, the catalog proof is the ceiling.
- **D-P09-2: KYC seeding method for the throwaway jeeber** — real camera UI (owner real-flow mandate) vs the `POST /v1/kyc/submit` curl (data seeding via super-login). Default in this plan: real UI first, curl only if the camera flow blocks.
- **D-P09-3:** leave the throwaway account and the test chat message/offer on the dev gateway (recommended; document ids) or clean up via CMS (`PATCH /admin/users/{id}/suspend`).

## 6. Risks / traps
- `defb1f07` expires **2026-09-06 11:21 UTC**; after that S5.0/S8.2 need a fresh client request (1 min).
- Super Login Plus re-mints roles from the UM profile; for EmptyJeeber always re-enter via **Make online-ready** (forced roles) if availability 403s again — verify with a `GET /jeebers/me/availability` probe before blaming the app.
- `/data/local/tmp/jeeb-dev-seam.json` stale-token trap: check it does not exist before starting (`adb shell ls /data/local/tmp/`).
- Apply & Restart re-reads the seam; the Server URL override persists across force-stops — ALWAYS restore it at the end (`58-final-baseurl.xml`-style proof).
- `adb reverse` dies with the adb server / cable re-plug → every proxy scenario starts with the `curl … 18080/health/ready` check.
- Retry interceptor doubles 503 reads; rate-limit windows persist per path scope — sequence 429 scenarios last.
- Cloudflare 1010 only for `Python-urllib` UA; never probe through the proxy with urllib.
- Radios: `settings get global mobile_data` keeps reporting 1 under `svc data disable` — use `ping 8.8.8.8` as the truth (run-2 note).
- Karim must be set back to **Offline** at the end (was offline before run 3); EmptyJeeber offline too, so neither sees production-ish requests.

## 7. Restore checklist (end of run)
1. Rules `[]`, Server URL → `https://msi.olivium.space/gateway` → Apply & Restart → dump proving the Dev Tool banner shows the MSI URL.
2. `adb -s RZCT505K7WF reverse --remove tcp:18080`; kill mitmdump; radios ON, `ping` UP.
3. Karim + EmptyJeeber duty Offline; last session on the phone = Karim (as run 3 left it); language back to EN.
4. `$SP/device-evidence-4/accounts.md` lists EmptyJeeber ids, the offer id, the chat message, any created request (with expiry).
5. No uninstall, no Clear Local Data happened (state it in every REPORT).

## 8. If a defect is found
Fix on `ux/api-error-handling-empty-states` in the owning file (no interface signature changes — R3 `implements` trap; never touch the PR #330 token-refresh lane — the 401→refresh→retry interceptor, its dedicated retry Dio and cooldown, per memory `jeeb-token-refresh-fix-2026-09-03.md`), add a widget test asserting by `find.bySemanticsIdentifier` in EN+AR under `test/features/<feature>/…`, run `dart analyze --fatal-infos .` and `flutter test --exclude-tags capture` (baseline 10539/0/109, coverage ≥79%), `git add` new files before testing, re-run the failing surface on the device, append to the PR #335 body. Comments ≤2 lines.

## 9. Effort
L — ~1 h setup (proxy + EmptyJeeber), ~4–5 h device runs (S1–S8 incl. AR), ~1 h reports + judge. Single implementer on the Mac with the phone on USB; no second physical device needed (two accounts on one phone via Super Login Plus; chat "second party" is asynchronous — messages persist on the gateway).

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C7): `defb1f07` is cancelled by P04 Part A first. S2.4, S5.0 and S8.2 create a fresh client request through
  the real UI as their PRIMARY path (the "if expired" fallback text is now the main path); `record` it, the EmptyJeeber
  `session`, its offer and the S1.5 chat message in `device-evidence-4/CREATED.jsonl`, and end with `sweep` + `audit
  de520a28-… 106078a3-… <EmptyJeeberId>` (P04 rule). Immutable residue (chat message, inbox rows) is listed, not deleted.
- Reconciled (C6): S1.6 (catalog ChatTab states) must run before P12 Change B; the ChatTab ruling is OD-9.
- Reconciled (C2/C3): lever = P08 proxy (interim mitmdump allowed), conventions above; copy expectations for `drop`
  depend on whether P13 is on the build. §4 rubric item 2 reads: 503 → server family; radios-OFF → network family;
  `drop` on a P13 build → unreachable family; 429 → rate-limited; 403 → forbidden + exit CTA.
- Reconciled (C12/C13): evidence dirs `scratchpad/device-evidence-4/p09/<surface>/` + `p09/JUDGE-RUN4.md`; this is the
  longest device run — schedule it after P08 and P07 in the serial queue. Never use the `401` rule kind here.
- Owner decisions renumbered: OD-9 (ChatTab, shared with P12), OD-10 (KYC seeding via curl fallback), OD-11 (leave the
  throwaway data vs CMS cleanup).
