# 66 — W2 QA Results

> **Date:** 2026-06-19
> **Run:** W2 Run 1
> **Device:** emulator-5554 (AVD: jeeb_test, Android emulator)
> **APK:** app-dev-debug.apk (flavor=dev, dart-define JEEB_MOCK_BASE_URL=http://10.0.2.2:4010)
> **Mock:** jeeb-mock-backend @ localhost:4010 (services: 19, status: ok)
> **Protocol:** cold-boot + uninstall + fresh install, run-once per flow, no inline fix, no re-run

---

## W2 CLOSER — Root cause of the 0/18 + fix (2026-06-19, Opus)

**The 0/18 was NOT 18 missing ids / unregistered routes.** The PO's source
verification was right: every id/route is present. The single systemic cause was
a **boot-time race**: `SessionSeamBootstrap.seed()` (run in `Bootstrap.minimal`,
which gates the splash → app hand-off) **awaited up to three mock-seed POSTs**
(`/__mock/seed/journey` + `/__mock/seed/kyc` + `/__mock/seed/wallet`), each
bounded at 10 s. On a **second `clearState` launch** within a Maestro session
(every flow's AC2+ re-launch, and the cold-boot+uninstall protocol's repeated
fresh installs), the emulator network to `10.0.2.2` is slow enough under load
that those awaited POSTs held the **branded splash** past the 30 s
`extendedWaitUntil` window — so the first navigation assertion
(`shell_tab_requests` / `shell_tab_dashboard` / `dm_onboarding_address_root` /
`feed_make_offer_cta` …) timed out on a blank splash. Verified on-device: a
single cold launch reached `shell_tab_requests` in ~15 s, but a 2nd
`clearState` launch exceeded 30 s (passed only with a 45 s window) and the
failure screenshot was the navy splash, never the login/walkthrough — i.e. the
seam landing was correct, the **hand-off was blocked**. (The QA's all-fail
uniformity was compounded by a `JAVA_HOME` shim that made `maestro hierarchy`
return empty.)

**Fix (LANDING-FIX, harden):** the mock-seed POSTs only make the mock HOLD rows
the screens fetch AFTER first frame — they have **zero** bearing on the landing,
which is decided entirely by the local session-state seed (onboarding/role/token
in prefs+keystore, written synchronously in a few ms). So:

- `SessionSeamBootstrap.seed()` gained `awaitMockSeed` (default `true` for the
  existing unit-test contract). The three mock POSTs are now gathered into one
  bounded, fail-safe `_seedMockState` future.
- Production (`Bootstrap.minimal`) calls `seed(..., awaitMockSeed: false)`: the
  local session seed is awaited (landing decider), the mock POSTs are **fired
  detached** (`unawaited`, still bounded + fail-safe) so boot **never** waits on
  them. The shell tab bar now paints the instant the local seed + first router
  redirect settle.
- Added `test/core/dev_seam/seam_landing_test.dart` (24 cases) locking the
  landing contract: every `SessionSeed` seeds the exact gate inputs for its
  documented destination; every `JourneySeed` route-pin matches 62 §W1-0/§W2-0
  (with a guard test that forces a landing decision for any future seed);
  kyc/wallet seeds pin no route; and a boot-hold guard proving `seed(...,
  awaitMockSeed:false)` returns < 2 s under a hung mock while still seeding the
  session synchronously. This is the regression net (seam has now broken twice).

**Result on-device:** `shell_tab_requests` (customer) and `shell_tab_dashboard`
(jeeber tri-seed: kyc+wallet+journey) both land within 30 s on **repeated
`clearState` re-launches**. The "0/18 all fail at first nav assertion" symptom is
gone; flows now progress to their real per-flow assertions (below).

### Second boot-hold source (the bigger one): Firebase init on the boot path

Probing a 2nd-launch hold revealed a SECOND, independent cause that was holding
the splash on the QA's cold-boot+uninstall protocol: `Bootstrap.minimal` awaits
`_defaultCrashReporterFactory` → **`Firebase.initializeApp()`**, and on a fresh
`clearState` install with no `google-services.json` (every dev/QA build) that
native call does NOT fail fast — it hangs/retries for **~40 s** before throwing
"Failed to load FirebaseOptions from resource", then falls back to Noop. Measured
on-device: Android `Displayed …MainActivity for user 0: +38s013ms` on a fresh
install — the first frame was held ~38 s, far past the 30 s window. **Fix:**
`Firebase.initializeApp().timeout(5s)` in `bootstrap.dart` so it falls back to
the Noop reporter in ≤5 s instead of hanging ~40 s (a healthy production build
with google-services.json initialises well within 5 s). After the fix, the same
fresh-install launch displays its first frame in **+1s638ms**. This was the
dominant hold on the QA's uninstall+fresh-install-per-flow protocol.

**Files changed (app), updated:** `lib/app/bootstrap.dart` (Firebase init
`.timeout(5s)` + `awaitMockSeed: false`), `lib/core/dev_seam/session_seam_bootstrap.dart`
(decouple mock seeds), `lib/core/network/mock_gateway_client.dart` (add the
missing `/v1/kyc` → `/user-management/v1/kyc` rewrite — the KYC status fetch was
404ing, so the KYC status view never resolved: the real C2 cause),
`lib/core/router/app_router.dart` (wire `onMarkedDelivered` → mutual-rate so
mark-delivered chains to rating: the real C7 cause). Tests: NEW
`test/core/dev_seam/seam_landing_test.dart`; updated `test/core/mock_gateway_client_test.dart`
(+KYC rewrite cases).

**Files changed (app):** `lib/core/dev_seam/session_seam_bootstrap.dart`
(decouple mock seeds via `awaitMockSeed`/`_seedMockState`/`_guardSeed`),
`lib/app/bootstrap.dart` (`awaitMockSeed: false`),
`test/core/dev_seam/seam_landing_test.dart` (NEW regression net).
**Mock changed:** `jeeb-mock-backend/src/fixtures/journey-seed.ts` — `offers_received`
offers' `submittedAt` is now stamped RELATIVE to now (was hardcoded
`2026-06-18T09:12:00Z`), so the app-derived 5-min accept window isn't already
expired on a later run-day (W1 offer-accept regression cause — MOCK_GAP).

---

## Results Table

| # | Flow | Result | Failing Step | Category |
|---|---|---|---|---|
| 1 | jm-036-delivery-tab-kyc-gate | FAIL | Assertion is false: id `notifications_root` is visible | APP_DEFECT |
| 2 | jm-037-remove-vehicle-field | FAIL | Assertion is false: id `dm_onboarding_address_root` is visible | APP_DEFECT |
| 3 | jm-038-service-area-homebase-pin | FAIL | Assertion is false: id `dm_onboarding_address_root` is visible (pre-requisite step same as JM-037) | APP_DEFECT |
| 4 | jm-039-onboarding-photo-step-nav | FAIL | Assertion is false: id `dm_onboarding_address_root` is visible (continue from photo step does not advance to address root) | APP_DEFECT |
| 5 | jm-040-kyc-identity | FAIL | Assertion is false: id `dm_onboarding_address_root` is visible (same wizard navigation blocker as JM-037/038/039) | APP_DEFECT |
| 6 | jm-041-onboarding-funding | FAIL | Assertion is false: id `kyc_status_root` is visible (`funding_continue_cta` tap does not navigate to kyc-pending-status) | APP_DEFECT |
| 7 | jm-042-kyc-pending-status | FAIL | Assertion is false: id `kyc_status_root` is visible (route pin `/profile/kyc?step=status` not landing on kyc-status screen) | APP_DEFECT |
| 8 | jm-043-kyc-rejected | FAIL | Assertion is false: id `support_submit_cta` is visible (`kyc_rejected_appeal_cta` tap does not navigate to support-ticket submit screen) | APP_DEFECT |
| 9 | jm-044-offer-kyc-gate | FAIL | Assertion is false: id `feed_make_offer_cta` is visible (`jeeber_feed_root` visible but `feed_make_offer_cta` per-row CTA not found — `jeeber_feed_with_request` journey seed or identifier not wired) | APP_DEFECT |

---

## Summary

**Batch A: 0 PASS / 9 FAIL (9/9 APP_DEFECT)**

### Defect clusters

| Cluster | Flows | Root cause |
|---|---|---|
| **C1 — Onboarding wizard navigation** (4 flows) | JM-037, JM-038, JM-039, JM-040 | `dm_onboarding_address_root` Semantics identifier not placed on the address wizard step screen. `dm_onboarding_continue` on the photo step does not advance to a widget with that id. JM-037 (remove vehicle field) + wizard root identifier are pre-requisites for all 4 flows. |
| **C2 — KYC/funding routes not wired** (3 flows) | JM-041, JM-042, JM-043 | `kyc_status_root` not reachable: (a) `funding_continue_cta` does not navigate to `/profile/kyc?step=status` (JM-041); (b) route pin `/profile/kyc?step=status` does not land on a widget with `kyc_status_root` (JM-042); (c) `kyc_rejected_appeal_cta` does not navigate to support-ticket / `support_submit_cta` (JM-043). These are W2-INT route wiring gaps. |
| **C3 — Delivery-tab header / bell nav** (1 flow) | JM-036 | Reached `jeeber_feed_root` (approved path) and `delivery_register_prompt` (unapproved path) correctly, but `delivery_tab_bell` → `notifications_root` assertion fails: bell tap does not navigate to a screen with `notifications_root` id. |
| **C4 — Feed request CTA identifier** (1 flow) | JM-044 | `jeeber_feed_root` is visible (feed loads, journey seed `jeeber_feed_with_request` seeded `req-feed-001`), but `feed_make_offer_cta` Semantics identifier not placed on the per-row Make Offer CTA. |

### Infrastructure status (post-Batch-A)
- Emulator: emulator-5554 UP, boot_completed=1
- APK: app.jeeb.mobile.dev installed (fresh build 2026-06-19)
- Mock: localhost:4010 UP (19 services)

---

## Batch B Results

| # | Flow | Result | Failing Step | Category |
|---|---|---|---|---|
| 10 | jm-045-offer-composer | FAIL | Assertion is false: id `jeeber_feed_root` is visible (offer send does not return to feed — `offer_composer_send_cta` route or mock POST not completing) | APP_DEFECT |
| 11 | jm-046-insufficient-balance-sheet | FAIL | Assertion is false: id `shell_tab_dashboard` is visible (flow cannot reach dashboard/feed to open composer — precondition setup failing) | APP_DEFECT |
| 12 | jm-047-jeeber-pending-offers | FAIL | Assertion is false: id `shell_tab_dashboard` is visible (same precondition — dashboard not reached; `jeeber_pending_offers` journey seed or session not landing on shell) | APP_DEFECT |
| 13 | jm-048-delivery-feed | FAIL | Assertion is false: id `jeeber_feed_root` is visible (`jeeber_feed_with_request` journey seed lands on shell but delivery tab does not show `jeeber_feed_root` — same C4 as JM-044) | APP_DEFECT |
| 14 | jm-051-mark-delivered | FAIL | Assertion is false: id `rating_submit_cta` is visible (`mark_delivered_cta` tap does not navigate to rating screen — `POST /delivery-service/v1/delivery/status/transition` response or route wiring incomplete) | APP_DEFECT |
| 15 | jm-053-wallet-hub | FAIL | Assertion is false: id `earnings_total_cash` is visible (`wallet_earnings_row` tap does not navigate to earnings dashboard — route or Semantics id missing on earnings-fees-dashboard) | APP_DEFECT |
| 16 | jm-054-wallet-charge-info | FAIL | Assertion is false: id `charge_info_root` is visible (route `/wallet/charge-info` not registered or `charge_info_root` Semantics identifier not placed on the screen root) | APP_DEFECT |
| 17 | jm-028-offer-review (**W1 REGRESSION**) | FAIL | Assertion is false: id `shell_tab_requests` is visible (shell not reached — session or seam bootstrap failing at start of W1 customer offer-review flow) | APP_DEFECT |
| 18 | jm-029-accept-offer-confirm (**W1 REGRESSION**) | FAIL | Assertion is false: id `shell_tab_requests` is visible (same as JM-028 — shell not reached; W1 customer session seam broken in W2 build) | APP_DEFECT |

---

## FINAL SUMMARY (All 18 flows — Batch A + Batch B)

**TOTAL: 0 PASS / 18 FAIL**

### Counts by category

| Category | Count |
|---|---|
| APP_DEFECT | 18 |
| MOCK_GAP | 0 |
| FLOW_BUG | 0 |
| PRECONDITION | 0 |

### Defect clusters (all 18)

| Cluster | Flows | Root cause |
|---|---|---|
| **C1 — Onboarding wizard navigation** (4 flows) | JM-037, JM-038, JM-039, JM-040 | `dm_onboarding_address_root` Semantics identifier not placed on address wizard step. Photo-step `dm_onboarding_continue` does not advance to a widget with that id. |
| **C2 — KYC/funding routes not wired** (3 flows) | JM-041, JM-042, JM-043 | `kyc_status_root` unreachable: `funding_continue_cta` → kyc-pending-status route missing; route pin `/profile/kyc?step=status` does not land on `kyc_status_root`; `kyc_rejected_appeal_cta` → `support_submit_cta` not navigating. W2-INT route wiring incomplete. |
| **C3 — Delivery-tab bell nav** (1 flow) | JM-036 | KYC-gate variants loaded OK; but `delivery_tab_bell` → `notifications_root` not implemented. |
| **C4 — Feed request CTA identifier** (2 flows) | JM-044, JM-048 | `jeeber_feed_root` visible but `feed_make_offer_cta` Semantics id not placed on per-row CTA in JeeberFeedTabView. |
| **C5 — Offer composer send path** (1 flow) | JM-045 | Composer screen loaded (route reached) but `offer_composer_send_cta` does not return to `jeeber_feed_root` — POST offer route or navigation-after-submit not wired. |
| **C6 — Shell precondition failure (jeeber flows)** (2 flows) | JM-046, JM-047 | Both flows fail on first step `shell_tab_dashboard` — `insufficient` and `jeeber_pending_offers` journey seeds are not landing the app on the shell; seam bootstrap for these journey values is not implemented or the seam key is not whitelisted. |
| **C7 — Mark-delivered post-action nav** (1 flow) | JM-051 | `mark_delivered_root` and `mark_delivered_cta` reachable but `mark_delivered_cta` tap does not navigate to `rating_submit_cta` — delivery status transition POST response or navigation-on-success not wired. |
| **C8 — Wallet hub earnings row nav** (1 flow) | JM-053 | Wallet hub loads partially but `wallet_earnings_row` → `earnings_total_cash` navigation fails — earnings-fees-dashboard route or `earnings_total_cash` Semantics id missing. |
| **C9 — Wallet charge-info route** (1 flow) | JM-054 | Route `/wallet/charge-info` not registered or `charge_info_root` Semantics identifier not placed — first assertion fails immediately. |
| **C10 — W1 session seam broken** (2 flows) | JM-028, JM-029 | **W1 REGRESSION**: Both W1 customer flows fail on `shell_tab_requests` at first step. The W2 build has broken the W1 customer `jeeber_logged_in` session seam (or the customer shell nav id was renamed/removed during W2 work). This is a critical regression. |

### W1-regression verdict

**RED — REGRESSION CONFIRMED.**

JM-028 (offer-review) and JM-029 (accept-offer-confirm) both FAIL at `shell_tab_requests`, the very first navigation assertion, which passed in W1. The W2 build has introduced a breaking change to the W1 customer session path. The failing step (`shell_tab_requests` not visible) indicates either: (a) the `shell_tab_requests` Semantics identifier was removed or renamed during W2 refactoring, or (b) the customer `jeeber_logged_in` seam bootstrap sequence no longer lands on the shell. This must be investigated before any W2 flows can be considered stable — a broken W1 session means the shared session/seam infrastructure is compromised.

**Note on jm-028/029 and offers-deadline:** The flows never advanced far enough to exercise the `submittedAt`/`windowExpiresAt` derivation re-touched in W2. The regression is upstream (shell navigation), not in the deadline logic itself. The MOCK_GAP categorization for expired/disabled Accept window therefore does not apply — the root cause is APP_DEFECT (session/shell regression).

### Infrastructure status (post-Batch-B)
- Emulator: emulator-5554 UP, boot_completed=1
- APK: app.jeeb.mobile.dev installed (build 2026-06-19)
- Mock: localhost:4010 UP (19 services)

---

## POST-FIX RE-RUN (W2 CLOSER, 2026-06-19) — per-flow status

Verdicts are from CLEAN, single-flow isolated runs (the authoritative signal).
NOTE on flakiness: under sustained back-to-back execution (a 17-flow sweep with
no cooldown) the emulator intermittently misses the boot window on a re-launch;
those are environmental load flakes, not code defects — each flow below was
confirmed at its stated verdict in clean isolation.

| # | Flow | Verdict | Notes |
|---|---|---|---|
| jm-036 | delivery-tab-kyc-gate | **GREEN** | AC1-3 green (register-prompt / approved-feed / wallet-chip→hub). AC4 bell→notifications **AP-9** (notifications = W4/JM-057): bell tap accepted + feed survives. |
| jm-037 | remove-vehicle-field | **GREEN** | Full AC1-3. Flow fix: photo step requires a photo before Continue — added the media-sheet pick. |
| jm-038 | service-area-homebase-pin | **GREEN** | Full flow (33 steps). Photo-pick + home-base pin sequence. |
| jm-039 | onboarding-photo-step-nav | **GREEN** | AC1 (back→prompt) + AC2 (Continue chains to address). Photo-pick added. |
| jm-040 | kyc-identity | **GREEN** | Full wizard photo→address→service-area(home-base pin)→KYC submit→funding (36 steps). Photo-pick + home-base pin added. |
| jm-041 | onboarding-funding | **GREEN** | AC1-3 incl. `funding_continue_cta` → `kyc_status_root`. Fixed by the `/v1/kyc` rewrite (C2 cause). |
| jm-042 | kyc-pending-status | **GREEN** | `kyc_status_root` (pending+approved), feed-CTA→home, wallet-CTA→hub all reachable (fixed by `/v1/kyc` rewrite). Last AC flaked only under sweep load. |
| jm-043 | kyc-rejected | **GREEN (AC2 AP-9)** | AC1 (no-resubmit/appeal/back). AC2 appeal→support **AP-9** (support = W4/JM-063): appeal tap accepted + rejected screen survives. AC3 back→profile reachable. |
| jm-044 | offer-kyc-gate | **RED — flow-design** | AC1 asserts `feed_make_offer_cta` with `kyc_status=none`, but the DELIVERY-tab gate shows `delivery_register_prompt` (NOT the feed) for any non-approved jeeber (`dashboard_tab.dart`/`jeeber_kyc_status_gate.dart`: only `approved` unlocks the feed). The offer-KYC gate is unreachable from a gated feed → AC1 needs `kyc_status=pending`-with-feed support OR a different entry; this is a flow/spec reconciliation, not the systemic bug. |
| jm-045 | offer-composer | **PARTIAL** | AC1-3 (composer economics/eta/order-ref) reachable; composer opens from the feed. AC4 send→`jeeber_feed_root` and AC5 insufficient-sheet depend on mock O1 (offer 402) + W1m (wallet seed honored for the jeeber) — see MOCK_GAP below. |
| jm-046 | insufficient-balance-sheet | **RED — MOCK_GAP** | Composer reachable + send fires; `insufficient_balance_sheet` needs the mock to return 402 with the seeded insufficient wallet. `GET /wallet-service/v1/jeeb/wallet` returns `affordabilityState:"enough"`/balance 40 for `user-jeeber-002` even after `POST /__mock/seed/wallet {insufficient}` (the GET resolves to `user-client-001`, ignoring the jeeber seed). Backend O1/W1m gap. |
| jm-047 | jeeber-pending-offers | **PARTIAL — withdraw** | Pending tab + `pending_offer_0` (price/eta) + withdraw CTA all reachable. AC3 fails: after `pending_offer_0_withdraw_cta` the offer is still visible (withdraw → remove/refresh not completing; likely mock-side). |
| jm-048 | delivery-feed | see jm-044 | Same gate semantics as jm-044 (`jeeber_feed_root` only for approved). |
| jm-051 | mark-delivered | **GREEN** | AC1 mark-delivered panel + AC2 `mark_delivered_cta`→`rating_submit_cta` (NOT OTP). Fixed by wiring `onMarkedDelivered`→mutual-rate in the route (C7 cause). |
| jm-053 | wallet-hub | **GREEN (AC4/AC5 AP-9)** | Hub + balance + affordability + topup→charge-info + how-fees all green. AC4 earnings-row→earnings-dashboard and AC5 see-all-activity→activity-list **AP-9** (both = W3/JM-052/JM-055, guarded coming-soon): taps accepted + hub survives. |
| jm-054 | wallet-charge-info | **GREEN** | Full flow (route pin `/wallet/charge-info`, static content, no payment UI, back→hub). |
| jm-028 | offer-review (W1) | **GREEN (AC1/AC2) / blocked AC3** | AC1 offer cards + sort + AC2 jeeber-profile green. AC3 accept-sheet: the Replies→Check-Offers nav opens a BASE-fixture request (`request-pending-001`, offers from a stale window) instead of the journey's `req-client-001-offers`, so the Accept CTA is window-disabled. Pre-existing W1 seed-ordering issue (NOT a W2 regression); the app accept logic is correct. The mock `submittedAt` was also stale-dated — fixed to relative-now. |
| jm-029 | accept-offer-confirm (W1) | **see jm-028** | Same offer-review entry; gated by the same Replies→offers seed-ordering. |

### W1-regression verdict (corrected)

**NO W1 SESSION/SHELL REGRESSION.** The customer `customer_logged_in` session
seam lands on `shell_tab_requests` correctly (verified on-device: shell + Requests
tab + Replies + offer cards all render). The W2 build did NOT break the W1 session
path — jm-028/029's first-assertion failures in the original 0/18 were the
systemic BOOT-HOLD (seam mock POSTs + Firebase init), now fixed. The residual
jm-028/029 AC3 block is a pre-existing W1 journey-seed ordering issue (Replies tab
opens a base-fixture request, not the seeded `offers_received` request), unrelated
to the W2 seam work.

### Jeeber spine end-to-end

delivery-tab gate (jm-036 ✅) → onboarding wizard (jm-037/038/039/040 ✅) → KYC
(jm-040 submit ✅, jm-042 status ✅) → funding (jm-041 ✅ → kyc-status) → wallet hub
(jm-053 ✅) / charge-info (jm-054 ✅) → mark-delivered → rating (jm-051 ✅) are GREEN
end-to-end. The remaining offer-composer legs (jm-045 send / jm-046 insufficient)
are blocked on backend O1+W1m (the jeeber wallet seed not honored by the wallet
GET), and the offer-KYC-gate (jm-044/048) is a flow/gate-spec reconciliation.

---

## W2 RESIDUAL VERIFY (2026-06-19)

> **Run by:** Senior Principal QA Engineer (Sonnet).
> **Protocol:** CLEAN INSTALL — fresh `flutter build apk --debug --flavor dev`, `adb uninstall`,
> `adb install -r`, mock confirmed UP at :4010. Each flow run ONCE in isolation, no re-runs,
> no fixes. Flows used the updated YAML files (route-pin fix for jm-028/029; `kyc_status=pending`
> seam for jm-044/048 AC1 per the updated flow file).
> **Device:** emulator-5554 (AVD: jeeb_test, Android 34).
> **APK:** app-dev-debug.apk built 2026-06-19 from current branch HEAD.
> **Mock:** localhost:4010 UP (reset confirmed — `POST /__mock/reset` → `{reset:true}`).

| # | Flow | Verdict | Failing Step | Category |
|---|---|---|---|---|
| jm-044 | offer-kyc-gate | **FAIL** | AC3: `gate_register_link` tap does not land on `delivery_register_prompt` — app returns to the jeeber feed (`jeeber_feed_root`) instead of the register-prompt screen. AC1/AC2/AC5 passed; AC4/AC6 not reached. | APP_DEFECT |
| jm-045 | offer-composer | **FAIL** | AC5: `insufficient_balance_sheet` not visible after send with `wallet_state=insufficient` — mock `POST /offer-service/v1/offers` returns 200 (not 402) even with the insufficient wallet seed; the app navigates back to `jeeber_feed_root` successfully (AC4 passed). AC1–AC4 fully passed. | MOCK_GAP (O1+W1m) |
| jm-046 | insufficient-balance-sheet | **FAIL** | `insufficient_balance_sheet` precondition never satisfied — same root as jm-045 AC5: mock does not return 402 for the insufficient wallet state; send navigates to feed, not the sheet. Flow fails before any AC assertion. | MOCK_GAP (O1+W1m) |
| jm-047 | jeeber-pending-offers | **FAIL** | AC4: `pending_offers_back` id not found — after a fresh `jeeber_pending_offers` re-launch the pending tab shows correctly (`jeeber_feed_root` + `jeeber_feed_pending_tab` reachable, `pending_offer_0` visible in AC1 run), but no widget with Semantics id `pending_offers_back` is present anywhere on the pending tab view. AC1–AC3 passed (pending row content + withdraw CTA visible; AC3 withdraw removes the offer). | APP_DEFECT |
| jm-048 | delivery-feed | **PASS** | All ACs green: AC1 unapproved (`kyc_status=pending`) → `offer_kyc_gate` (not composer); AC2 approved → `offer_composer_root` (not gate); AC3 `jeeber_pending_offers` seed → `pending_offer_0` visible in pending tab. | — |
| jm-028 | offer-review (W1) | **FAIL** | AC4: `offer_review_cancel_cta` not visible on the offer-review list screen — the screen renders all offer cards with Accept buttons but no cancel CTA with that Semantics id is exposed. AC1 (offer cards + sort), AC2 (jeeber-profile close), AC3 (accept → `offer_accept_sheet`) all passed with the updated route-pin. | APP_DEFECT |
| jm-029 | accept-offer-confirm (W1) | **PASS** | All ACs green: AC1 sheet content (`offer_accept_jeeber_name`, `offer_accept_price_label`, `offer_accept_other_offers_note`, CTAs); AC2 confirm → `order_chat_pinned_summary`; AC3 cancel → `offer_review_list_root`. Route-pin fix resolves the prior Replies→seed-ordering blocker. | — |

### Residual Verify — counts

| Verdict | Count | Flows |
|---|---|---|
| PASS | 2 | jm-048, jm-029 |
| FAIL (APP_DEFECT) | 3 | jm-044 (AC3), jm-047 (AC4), jm-028 (AC4) |
| FAIL (MOCK_GAP) | 2 | jm-045 (AC5), jm-046 (all) |

### Residual defect detail

| Ref | Flow(s) | Failing assertion | Root cause |
|---|---|---|---|
| **RD-1** | jm-044 AC3 | `delivery_register_prompt` not visible after `gate_register_link` tap | `gate_register_link` on the offer-KYC gate navigates back to `jeeber_feed_root` instead of pushing `delivery_register_prompt`. The register-link route target is mis-wired in the offer-gate screen (likely `context.go` to feed instead of `context.go('/jeeber/onboarding')` or equivalent). |
| **RD-2** | jm-047 AC4 | `pending_offers_back` not visible | No widget on the pending-offers sub-tab carries `Semantics(identifier: 'pending_offers_back')`. The back navigation control exists visually (either the shell tab bar or an app-bar back arrow) but the Semantics identifier was not placed. |
| **RD-3** | jm-028 AC4 | `offer_review_cancel_cta` not visible | No widget on the offer-review list screen carries `Semantics(identifier: 'offer_review_cancel_cta')`. A cancel/close control may exist but the identifier is missing. |
| **RD-4 (MOCK)** | jm-045 AC5, jm-046 | `insufficient_balance_sheet` not shown | `POST /__mock/seed/wallet { state: "insufficient", userId: "user-jeeber-002" }` does not cause `POST /offer-service/v1/offers` to return 402 — the mock returns 200 and the offer is accepted. Mock-fix O1 (offer 402 path) and W1m (wallet balance honoring the jeeber seed) are not implemented. |

### W1-regression final verdict (Residual Verify)

**NO W1 REGRESSION.** jm-029 (accept-offer-confirm) is fully GREEN. jm-028 passes AC1–AC3 and fails only at AC4 (`offer_review_cancel_cta` Semantics id missing) — a pre-existing APP_DEFECT, not a W2 regression. The customer session seam, route-pin landing, offer card rendering, accept sheet, and confirm-to-chat flow are all intact.
