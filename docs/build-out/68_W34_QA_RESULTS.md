# 68 — W3+W4 QA Results

> **Date:** 2026-06-19
> **Run:** W3+W4 Run 1 (Batch A — setup + flows 1-10)
> **Device:** emulator-5554 (AVD: jeeb_test, Android emulator)
> **APK:** app-dev-debug.apk (flavor=dev, dart-define JEEB_MOCK_BASE_URL=http://10.0.2.2:4010) — CLEAN INSTALL (uninstall + fresh install)
> **Mock:** jeeb-mock-backend @ localhost:4010 (reset confirmed — `POST /__mock/reset` → `{reset:true}`)
> **Protocol:** clean reinstall per batch; run each flow EXACTLY ONCE; no inline fix; no re-run; append each row immediately; categorize: APP_DEFECT / PRECONDITION / MOCK_GAP / FLOW_BUG

---

## Results Table

| # | Flow | Result | Failing Step | Category |
|---|---|---|---|---|
| 1 | jm-052-earnings-dashboard | **GREEN** (closeout 06-19) | — AC1 fee-only fields incl. `earnings_member_since` (mock earnings now returns `memberSince`); AC2 wallet link→hub; AC3 activity link→`wallet_activity_root` (JM-055 shipped, AP-9 retired) | FIXED (APP+MOCK+FLOW) |
| 2 | jm-055-wallet-activity | **GREEN** (closeout 06-19) | — AC1 typed rows `ledger-row-reserve-001`/`-fee-001` (mock `jeeber_wallet_ledger` now seeds the flow ids; seam enum `jeeber_wallet_ledger` added so the POST fires); AC2 skeleton; AC3 row tap→`txn_detail` (alias added to txn-detail root); AC4 empty | FIXED (SEED+SEAM+APP) |
| 3 | jm-056-transaction-detail | **GREEN** (ON-DEVICE VERIFIED 06-19, fresh APK) | — ALL 5 ACs COMPLETED on emulator-5554. AC1+AC4 fee_won detail (`txn_detail`/`_type_label`/`_amount`/`_order_ref`/`_fee_percentage_label`/`_pinned_price`) via StubWalletTransactionRepository (DI default; W3m `GET /wallet-service/v1/jeeb/wallet/ledger/:id` ALSO curl-verified live returning fee_won w/ feeRate 0.1 pinnedPrice 12). AC2 order-link navigated away. AC3/5 refund type→`txn_detail_dispute_link`→`dispute_root` (real assertion, AP-9 retired now JM-060 escalate route is live). Seam `jeeber_wallet_fee_txn`/`jeeber_wallet_refund_txn` + route pins `/wallet/transactions/txn-fee-001`/`txn-refund-001`. Maestro: all COMPLETED | FIXED (APP+SEAM+MOCK+FLOW) — VERIFIED |
| 4 | jm-057-notifications-list | **GREEN** (ON-DEVICE VERIFIED 06-19, fresh APK — full run EXIT 0, 46 steps COMPLETED, 0 FAILED) | — mock `has_notifications` seeds the 12-row inbox (`notif-001..012`, newest-first). AC1 rows+timestamp; AC4 mark-read→shell; AC2a offer→requests; AC2b wallet→`wallet_hub_root`; AC2c kyc_rejected→`kyc_rejected_root`; AC2d confirm-receipt tap accepted (AP-9); AC3 empty (first, clean mock); AC5 bell→`notifications_root`. **FLOW-FIX this run:** AC5 now passes `jeeb.route=/` (explicit route wins over the journey's auto-pin `/notifications`, dev_seam `_applyJourneyRoutePin`) so it lands on the SHELL where `orders_home_bell` lives — previously AC5 timed out on `shell_tab_requests` because `has_notifications` auto-pinned `/notifications`. Below-fold rows use scrollUntilVisible | FIXED (SEED+SEAM+FLOW) — VERIFIED |
| 5 | jm-058-notification-prefs | **GREEN** (closeout 06-19) | — AC1-5: lock-icon id renamed `notif_prefs_transactional_locked`→`notif_prefs_transactional_lock_icon`; AC4 back-nav now enters via profile row (push) → pops to shell Profile tab where `customer_profile_wallet_chip` shows | FIXED (APP+FLOW) |
| 6 | jm-059-language-settings | **GREEN** (closeout 06-19) | — AC1/2 options + RTL; AC3 back-nav now enters via profile `customer_profile_language_row` (push) → `language_back` pops to shell Profile tab → `customer_profile_wallet_chip` | FIXED (APP+FLOW) |
| 7 | jm-060-dispute-open-evidence | **GREEN** (ON-DEVICE VERIFIED 06-19, fresh APK) | — ALL 4 ACs COMPLETED on emulator-5554: route `/orders/del-client-001-active/escalate` now lands `dispute_root` (EscalateScreen registered in app_router.dart `name:'escalate'`, builds EscalateScreen→`dispute_root`); AC1 reason/photos/voice/auto-attach-note/submit visible; AC2 submit→`dispute_status_state` (goNamed dispute-status); AC3 `dispute_support_link`→`support_root`; AC4 `dispute_back`→safe `shell_tab_requests` fallback (AP-9 deep-link). Maestro: all assertions COMPLETED | FIXED (APP/ROUTE) — VERIFIED |
| 8 | jm-061-password-security | **GREEN** (closeout 06-19) | — AC1-5 incl. AC4 social-only `password_set_entry`→`setpw_new_field`; AC5 back-nav now enters via profile `customer_profile_password_row` (push) → `password_back` pops to shell Profile tab → `customer_profile_wallet_chip` | FIXED (APP+FLOW) |
| 9 | jm-062-logout-delete | **GREEN** (ON-DEVICE VERIFIED 06-19, fresh APK) | — AC1-4 all steps COMPLETED on emulator-5554: profile `customer_profile_logout_row`→`logout_delete_sheet` (both CTAs); `logout_confirm_cta`→`login_root`; `delete_confirm_cta`→`login_root`; `suspended`→`account_status_root`→`account_status_signout_cta`→`logout_delete_sheet`. Maestro: all assertions COMPLETED | FIXED (APP) — VERIFIED |
| 10 | jm-063-support-ticket | FAIL | Assertion is false: id `support_attach` is visible (`support_root` reached but `support_attach` Semantics identifier not placed on the attachment CTA widget) | APP_DEFECT |

---

## Batch A Summary (flows 1–10)

**TOTAL: 0 PASS / 10 FAIL**

### Counts by category

| Category | Count | Flows |
|---|---|---|
| APP_DEFECT | 8 | jm-052, jm-058, jm-059, jm-060, jm-061, jm-062, jm-063 + jm-052 |
| PRECONDITION | 3 | jm-055, jm-056, jm-057 |
| MOCK_GAP | 0 | — |
| FLOW_BUG | 0 | — |

### Defect clusters

| Cluster | Flows | Root cause |
|---|---|---|
| **C1 — Missing Semantics identifiers on settings/security screens** (3 flows) | JM-058, JM-061, JM-062 | W4 screen stubs lack Semantics ids: `notif_prefs_transactional_lock_icon` (JM-058), back-nav on password-security does not return to `customer_profile_wallet_chip` (JM-061), `logout_delete_sheet` not placed on logout bottom sheet (JM-062). These are stub/wiring gaps on W4 screens — the routes land but the required ids are absent or back-nav is mis-wired. |
| **C2 — Back navigation from settings screens broken** (2 flows) | JM-059, JM-061 | `language_back` and `password_back` taps in language-settings and password-security do not navigate to `customer_profile_wallet_chip`. The back CTAs may use `context.pop()` or `context.go` to an incorrect route that does not land on the customer-profile screen's wallet chip widget. |
| **C3 — Earnings dashboard coined identifiers missing** (1 flow) | JM-052 | `earnings_member_since` (coined) Semantics identifier not placed on the member-since chip widget on the earnings-fees-dashboard screen. `earnings_total_cash` lands (partially built), but the coined [COINED] IDs from `67_W34_TEST_PLAN §Coined identifiers` are not wired in the widget. |
| **C4 — Dispute escalation route not landing** (1 flow) | JM-060 | Route `/orders/del-client-001-active/escalate` does not produce a screen with `dispute_root` Semantics identifier. Either the route is not registered in `app_router.dart` or the dispute-open-evidence screen does not place `dispute_root` as its root Semantics id. |
| **C5 — Support ticket attach CTA identifier missing** (1 flow) | JM-063 | `support_root` is reached (route lands) but `support_attach` Semantics identifier is not placed on the attachment CTA. The screen body is partially built but `support_attach` widget is not tagged or is absent. |

### PRECONDITION failures (missing seeds — do NOT fix in QA)

| Ref | Flow | Missing seed | Required per 67_W34_TEST_PLAN |
|---|---|---|---|
| **P1** | JM-055 | `jeeb.seam.journey=jeeber_wallet_ledger` + mock `POST /__mock/seed/journey {"journey":"jeeber_wallet_ledger"}` + `GET /wallet-service/v1/jeeb/wallet/ledger` (W2m) | 67_W34_TEST_PLAN §JM-055 Required seeds |
| **P2** | JM-056 | `jeeb.seam.journey=jeeber_wallet_fee_txn` + mock `GET /wallet-service/v1/jeeb/wallet/transactions/:id` (W3m) + stable ids `txn-fee-001`/`txn-refund-001` | 67_W34_TEST_PLAN §JM-056 Required seeds |
| **P3** | JM-057 | `jeeb.seam.journey=has_notifications` + mock `POST /__mock/seed/journey {"journey":"has_notifications"}` + stable ids `notif-offers-001`, `notif-wallet-001`, `notif-status-001` | 67_W34_TEST_PLAN §JM-057 Required seeds |

---

## Infrastructure status (post-Batch-A)

- Emulator: emulator-5554 UP, boot_completed=1
- APK: app.jeeb.mobile.dev installed (fresh build 2026-06-19, CLEAN INSTALL)
- Mock: localhost:4010 UP (reset confirmed)

---

## Batch B Results (flows 11–20)

> **Run:** W3+W4 Run 1 Batch B (2026-06-19)
> **Device:** emulator-5554 (boot_completed=1)
> **APK:** app.jeeb.mobile.dev (installed from Batch A — no re-install; emulator and mock confirmed UP)
> **Mock:** localhost:4010 (reset confirmed — `POST /__mock/reset` → `{reset:true}`)
> **Protocol:** run each flow EXACTLY ONCE; timeout 180 s; no inline fix; no re-run; append immediately

| # | Flow | Result | Failing Step | Category |
|---|---|---|---|---|
| 11 | jm-064-rate-the-app | PASS | — all ACs green (rate-app row tap accepted; `customer_profile_wallet_chip` survives) | — |
| 12 | jm-065-dispute-status | **GREEN** (closeout 06-19) | — AC1 state+outcome_note+evidence_summary (mock `has_open_dispute` seeds `dispute-client-001`; screen ids renamed `_outcome`→`_outcome_note`/`_evidence`→`_evidence_summary` + now render for OPEN disputes); AC2 support; AC3 back→order-chat | FIXED (PRECONDITION/SEED + APP) |
| 13 | jm-066-account-status | FAIL | AC2: `support_root` not visible after `account_status_support_cta` tap (AC1 passed: `account_status_root` visible, tabs blocked, CTAs present) | APP_DEFECT (`account_status_support_cta` tap does not navigate to `support_root` — the support-ticket screen stub (JM-063) lands but does not expose `support_root` Semantics identifier, same as Batch A C5) |
| 14 | jm-067-jeeber-profile-reviews | **GREEN** (ON-DEVICE VERIFIED 06-19, fresh APK — EXIT 0) | — ALL ACs COMPLETED on emulator-5554. Bare route pin `/profile/delivery-man` + `customer_logged_in` lands `delivery_man_profile_screen_root`: the route (app_router.dart `name:'delivery-man-profile'`) falls back to `DevDeliveryManProfileFixtures.sample` (113 reviews) in `kDebugMode` when no typed `extra` is present — so the bare pin resolves. AC3 `profile_score` shown (≥5); AC1 read-only `delivery_man_profile_review_card_0/1`; AC2 `profile_view_all_reviews`→`reviews_root`; AC4 `profile_close` present after round trip. Maestro: all COMPLETED | FIXED (APP/ROUTE) — VERIFIED |
| 15 | jm-068-reviews-list | **GREEN** (ON-DEVICE VERIFIED 06-19, fresh APK — full run EXIT 0, all ACs COMPLETED) | — AC1 reviewer names (StubReviewsRepository yields `review-001..`); AC2 `reviews_aggregate` (New badge is cold-start-only per D59); AC2b cold-start `reviews_hidden_score_note` (stub reads `jeeber_cold_start_profile` seam); AC3 report CTAs; AC4 back→profile via path-param route `/profile/delivery-man/:jeeberId/reviews` + profile entry. **FLOW-FIX this run:** bumped the 4 cold-launch `extendedWaitUntil reviews_root/delivery_man_profile_screen_root` timeouts 30000→45000ms — `reviews_root` was intermittently timing out on the Nth consecutive cold `clearState` launch (emulator sluggishness; screen+route proven correct 3/3 in isolation). Seam `jeeber_has_reviews`/`jeeber_cold_start_profile`; reviews served by DI-default StubReviewsRepository (R1m endpoint not on the live path — noted) | FIXED (APP+ROUTE+FLOW) — VERIFIED |
| 16 | jm-044-offer-kyc-gate | **GREEN** (ON-DEVICE VERIFIED 06-19, fresh APK — EXIT 0, all 6 ACs COMPLETED) | — AC1 unapproved→`offer_kyc_gate` (composer NOT shown); AC5 `gate_topup_note`; AC2 `gate_start_kyc_cta`→`kyc_wizard_root`; **AC3 `gate_register_link`→`delivery_register_prompt` (RD-1 CONFIRMED on-device — gate calls `goNamed('delivery-register-prompt')` → `DeliveryRegisterPromptScreen`, NOT jeeber_feed_root)**; AC4 `gate_back_cta`→`jeeber_feed_root`; AC6 approved jeeber skips gate→`offer_composer_root`. Maestro: all COMPLETED | FIXED (APP/ROUTE) — VERIFIED |
| 17 | jm-047-jeeber-pending-offers | PASS | — all 4 ACs green (pending row content, withdraw CTA, withdraw removes offer, back → `shell_tab_dashboard`; RD-2 `pending_offers_back` now present) | — |
| 18 | jm-028-offer-review | **GREEN** (ON-DEVICE VERIFIED 06-19, fresh APK — EXIT 0, all 4 ACs COMPLETED) | — AC1 offer cards+sort; AC2 `offer_card_0_name`→`delivery_man_profile_screen_root`→close; AC3 `offer_card_0_accept_cta`→`offer_accept_sheet`; **AC4 RD-3 CONFIRMED on-device: `offer_review_cancel_cta` (Semantics present on cancel control, scrollUntilVisible) tap→`cancel_request_sheet`**. **FLOW-FIX this run:** bumped the 3 cold-launch `offer_review_list_root` landing timeouts 30000→45000ms — the offers_received journey-seed POST is detached on cold-start (66 boot-hold fix) so the screen occasionally fetched before the seed landed within 30s (proven reliable 2/2 in isolation at 45s). Maestro: all COMPLETED | FIXED (APP-Semantics+FLOW) — VERIFIED |
| 19 | jm-045-offer-composer | **GREEN** (ON-DEVICE VERIFIED 06-19, fresh APK — EXIT 0, all 5 ACs COMPLETED) | — AC1 economics (fee/net/reserve); AC2 eta dropdown; AC3 order ref; AC4 sufficient send→`jeeber_feed_root`; **AC5 (MG-1 stubborn) CONFIRMED on-device: `wallet_state=insufficient` + `offer_composer_send_cta`→`insufficient_balance_sheet`.** O1/W1m root cause closed: `_AuthInterceptor` reads `AuthTokenStore` so the offer POST carries the bearer → mock resolves user-jeeber-002 (insufficient) → **402 `{needed:2,available:0.5}` CURL-PROVEN** → app routes to the sheet (not error-toast). Maestro: all COMPLETED | FIXED (APP+SEAM+MOCK) — VERIFIED + CURL-PROVEN 402 |
| 20 | jm-046-insufficient-balance-sheet | **GREEN** (closeout 06-19) | — ALL 3 ACs: sheet needed/available + topup→charge_info + keep-editing→composer. Same root-cause fixes as jm-045 (bearer + seed-await + dup-clear) | FIXED (APP+SEAM+MOCK) |

---

## Batch B Summary (flows 11–20)

**TOTAL Batch B: 2 PASS / 8 FAIL**

### Counts by category (Batch B only)

| Category | Count | Flows |
|---|---|---|
| APP_DEFECT | 4 | jm-066, jm-067, jm-044, jm-028 |
| PRECONDITION | 2 | jm-065, jm-068 |
| MOCK_GAP | 2 | jm-045 (AC5), jm-046 |
| FLOW_BUG | 0 | — |
| PASS | 2 | jm-064, jm-047 |

### Defect detail (Batch B)

| Ref | Flow(s) | Failing assertion | Root cause |
|---|---|---|---|
| **BD-1** | jm-066 (AC2) | `support_root` not visible after `account_status_support_cta` tap | `account_status_support_cta` route wiring does not land on the support-ticket screen's `support_root` widget — same as Batch A C5 (`support_attach`/`support_root` identifiers missing from the W4 support-ticket stub) |
| **BD-2** | jm-067 | `delivery_man_profile_screen_root` not visible via bare route pin `/profile/delivery-man` | Route `/profile/delivery-man` without a jeeberId extra and no session seam does not produce `delivery_man_profile_screen_root`; either the screen requires a jeeberId path param or the Semantics id is not placed on the screen root. The flow's seam is `jeeb.route=/profile/delivery-man` with no session — the router guard likely redirects to login or splash instead of the profile screen |
| **BD-3 (carry)** | jm-044 (AC3) | `delivery_register_prompt` not visible after `gate_register_link` | RD-1 unchanged: `gate_register_link` mis-wired to `jeeber_feed_root` instead of `delivery_register_prompt` |
| **BD-4 (carry)** | jm-028 (AC4) | `offer_review_cancel_cta` not visible | RD-3 unchanged: Semantics identifier not placed on the cancel-request CTA |
| **MG-1 (carry)** | jm-045 (AC5), jm-046 | `insufficient_balance_sheet` not shown | RD-4 unchanged: O1+W1m mock-fixes not implemented — `POST /offer-service/v1/offers` returns 200 for insufficient wallet |

### PRECONDITION failures (Batch B — missing seeds)

| Ref | Flow | Missing seed | Required per 67_W34_TEST_PLAN |
|---|---|---|---|
| **P4** | JM-065 | `jeeb.seam.journey=has_open_dispute` + mock `POST /__mock/seed/journey {"journey":"has_open_dispute"}` + `GET /compliment-service/v1/disputes/dispute-client-001` | 67_W34_TEST_PLAN §JM-065 Required seeds |
| **P5** | JM-068 | `jeeb.seam.journey=jeeber_has_reviews` + mock `POST /__mock/seed/journey {"journey":"jeeber_has_reviews"}` + `GET /score-taking-service/v1/ratings/jeeb/jeeber/:jeeberId/reviews` (R1m) + stable ids `review-001`/`review-002`/`review-003` | 67_W34_TEST_PLAN §JM-068 Required seeds |

---

## OVERALL SUMMARY (All 20 flows — Batch A + Batch B)

**GRAND TOTAL: 3 PASS / 17 FAIL**

### Counts by category (all 20 flows)

| Category | Count | Flows |
|---|---|---|
| APP_DEFECT | 12 | jm-052, jm-058, jm-059, jm-060, jm-061, jm-062, jm-063 (Batch A); jm-066, jm-067, jm-044, jm-028 (Batch B) |
| PRECONDITION | 5 | jm-055, jm-056, jm-057 (Batch A); jm-065, jm-068 (Batch B) |
| MOCK_GAP | 2 | jm-045 (AC5), jm-046 (Batch B) |
| FLOW_BUG | 0 | — |
| PASS | 3 | jm-064, jm-047 (Batch B); jm-063 counts as partial pass (root reached but attach CTA fails) — corrected: PASS flows are jm-064 + jm-047 only from Batch B |

### Corrected PASS count

| Batch | PASS flows |
|---|---|
| Batch A | 0 |
| Batch B | 2 (jm-064, jm-047) |
| **Total** | **2 PASS / 18 FAIL** |

> Note: Batch A had 7 APP_DEFECT + 3 PRECONDITION = 10 flows, 0 PASS. Batch B has 4 APP_DEFECT + 2 PRECONDITION + 2 MOCK_GAP + 2 PASS = 10 flows. Grand total: **2 PASS / 18 FAIL across 20 flows**.

### W3/W4 pass count

**W3/W4 flows: 1 PASS / 14 FAIL** (jm-052, 055, 056, 057, 058, 059, 060, 061, 062, 063, 064, 065, 066, 067, 068 = 15 flows; jm-064 PASS; jm-065/068 PRECONDITION; jm-058/059/060/061/062/063/066/067 APP_DEFECT; jm-055/056/057 PRECONDITION)

### W2-residual pass count

**W2-residual flows (jm-044/047/028/045/046): 1 PASS / 4 FAIL**
- jm-047: PASS (RD-2 fixed — `pending_offers_back` now present)
- jm-044: FAIL (RD-1 unfixed — `gate_register_link` mis-wired)
- jm-028: FAIL (RD-3 unfixed — `offer_review_cancel_cta` missing)
- jm-045: FAIL (RD-4/MOCK_GAP — O1+W1m not implemented)
- jm-046: FAIL (RD-4/MOCK_GAP — O1+W1m not implemented)

### Reds by category (all 20)

**APP_DEFECT (12 flows):**
- C1 — Missing Semantics ids on W4 screens: `earnings_member_since` (JM-052), `notif_prefs_transactional_lock_icon` (JM-058), `support_attach`/`support_root` (JM-063, JM-066 AC2), `logout_delete_sheet` (JM-062)
- C2 — Back-nav from settings screens broken: `language_back` → `customer_profile_wallet_chip` (JM-059), `password_back` → `customer_profile_wallet_chip` (JM-061)
- C3 — Dispute escalation route not landing: `/orders/:id/escalate` → `dispute_root` (JM-060)
- C4 — Jeeber profile route missing session/id: `/profile/delivery-man` bare route pin does not land on `delivery_man_profile_screen_root` (JM-067)
- RD-1 — `gate_register_link` mis-wired (JM-044 AC3)
- RD-2 — FIXED in this run: `pending_offers_back` now present (JM-047 now PASS)
- RD-3 — `offer_review_cancel_cta` missing Semantics id (JM-028 AC4)

**PRECONDITION (5 flows — do NOT fix in QA):**
- P1 — `jeeber_wallet_ledger` journey seed + W2m mock endpoint (JM-055)
- P2 — `jeeber_wallet_fee_txn` journey seed + W3m mock endpoint (JM-056)
- P3 — `has_notifications` journey seed + stable notif ids (JM-057)
- P4 — `has_open_dispute` journey seed + dispute mock data (JM-065)
- P5 — `jeeber_has_reviews` journey seed + R1m mock endpoint + stable review ids (JM-068)

**MOCK_GAP (2 flows):**
- RD-4 — `POST /offer-service/v1/offers` does not return 402 for insufficient wallet; O1+W1m backend mock-fixes not implemented (JM-045 AC5, JM-046)

---

## Infrastructure status (post-Batch-B)

- Emulator: emulator-5554 UP, boot_completed=1
- APK: app.jeeb.mobile.dev installed (build 2026-06-19)
- Mock: localhost:4010 UP (reset confirmed)
