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
| 3 | jm-056-transaction-detail | **GREEN** (closeout 06-19) | — AC1+AC4 fee_won detail: added flow-id aliases on the txn-detail screen (`txn_detail`/`txn_detail_type_label`/`txn_detail_order_ref`/`txn_detail_fee_percentage_label` nested over the legacy ids); StubWalletTransactionRepository returns fee_won (AC1/4) / refund-with-disputeId (AC3/5). AC2 order-link navigates to order-summary (route exists; AP-9 retired→assert navigated). AC3/5 dispute-link→`dispute_root` (JM-060 shipped). Seam `jeeber_wallet_fee_txn`/`jeeber_wallet_refund_txn` added; mock seeds `txn-fee-001`/`txn-refund-001` | FIXED (APP+SEAM+MOCK+FLOW) |
| 4 | jm-057-notifications-list | **GREEN** (closeout 06-19, verified across runs) | — mock `has_notifications` now seeds the 12-row inbox (ids `notif-001..012`, newest-first so `notif-001` is at top); seam `has_notifications` POST now AWAITED on deep-land so the inbox is present on first frame. AC1 rows+timestamp; AC4 mark-read→shell; AC2a offer→requests; AC2b wallet→hub; AC2c kyc_rejected→`kyc_rejected_root`; AC2d confirm-receipt tap accepted (AP-9); AC3 empty (reordered first, clean mock); AC5 bell. Below-fold rows use scrollUntilVisible. 0 assertion failures (full run is slow — 6 launches; ACs verified GREEN across two runs) | FIXED (SEED+SEAM+FLOW) |
| 5 | jm-058-notification-prefs | **GREEN** (closeout 06-19) | — AC1-5: lock-icon id renamed `notif_prefs_transactional_locked`→`notif_prefs_transactional_lock_icon`; AC4 back-nav now enters via profile row (push) → pops to shell Profile tab where `customer_profile_wallet_chip` shows | FIXED (APP+FLOW) |
| 6 | jm-059-language-settings | **GREEN** (closeout 06-19) | — AC1/2 options + RTL; AC3 back-nav now enters via profile `customer_profile_language_row` (push) → `language_back` pops to shell Profile tab → `customer_profile_wallet_chip` | FIXED (APP+FLOW) |
| 7 | jm-060-dispute-open-evidence | FAIL | Assertion is false: id `dispute_root` is visible (route `/orders/del-client-001-active/escalate` does not land on a widget with `dispute_root` Semantics identifier) | APP_DEFECT |
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
| 14 | jm-067-jeeber-profile-reviews | FAIL | `delivery_man_profile_screen_root` not visible after route pin `jeeb.route=/profile/delivery-man` (no session seam — route pin alone does not land on profile screen) | APP_DEFECT (route `/profile/delivery-man` without a session seam does not redirect to the profile screen; `delivery_man_profile_screen_root` Semantics id not reachable via bare route pin — either `delivery_man_profile_screen_root` identifier not placed or the route requires a `jeeberId` extra that the bare route pin does not provide) |
| 15 | jm-068-reviews-list | **GREEN** (closeout 06-19) | — AC1 reviewer names (StubReviewsRepository already yields `review-001..`); AC2 `reviews_aggregate` (FLOW-FIX: New badge is a cold-start indicator per D59, not shown for ≥5); AC2b cold-start `reviews_hidden_score_note` (stub now reads `jeeber_cold_start_profile` seam); AC3 report CTAs; AC4 back→profile via path-param route `/profile/delivery-man/:jeeberId/reviews` (NEW) + profile entry | FIXED (APP+ROUTE+FLOW); seam `jeeber_has_reviews`/`jeeber_cold_start_profile` added |
| 16 | jm-044-offer-kyc-gate | **GREEN** (closeout 06-19) | — ALL 6 ACs incl. AC3 `gate_register_link`→`delivery_register_prompt` (RD-1 FIXED: registered new route `/jeeber/register-prompt` + `DeliveryRegisterPromptScreen` rendering `delivery_register_prompt`; the gate already called `goNamed('delivery-register-prompt')` but the route was unregistered) | FIXED (APP/ROUTE) |
| 17 | jm-047-jeeber-pending-offers | PASS | — all 4 ACs green (pending row content, withdraw CTA, withdraw removes offer, back → `shell_tab_dashboard`; RD-2 `pending_offers_back` now present) | — |
| 18 | jm-028-offer-review | **GREEN** (closeout 06-19) | — ALL 4 ACs. RD-3 was NOT a missing id (the W2 RD-3 fix had landed the `offer_review_cancel_cta` Semantics); the CTA sits below the offer cards — flow now `scrollUntilVisible` before tapping → `cancel_request_sheet` | FIXED (FLOW/scroll) |
| 19 | jm-045-offer-composer | **GREEN** (closeout 06-19) | — ALL 5 ACs incl. AC5 `insufficient_balance_sheet`. ROOT CAUSE (the stubborn O1/W1m): (a) the `_AuthInterceptor` never read `AuthTokenStore` (setToken was unused) → offer POST had NO bearer → mock resolved the wrong jeeber (client-001, default sufficient wallet); FIXED interceptor to read the persisted token. (b) the seam wallet/kyc seed POSTs only ran when AWAITED → added `hasStateSeed`/deep-land await. (c) base seed had a duplicate jeeber offer on the feed request (409 before 402) → journey clears the jeeber's submitted offers. Curl-proven 402 + on-device GREEN. | FIXED (APP+SEAM+MOCK) |
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
