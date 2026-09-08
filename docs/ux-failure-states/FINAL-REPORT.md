# UX/API-error programme — final report

Branch `ux/api-error-handling-empty-states`, worktree `ux-api-errors`, base
`origin/main@ab610933`. Commits: `db83ba7a`, `a48444ba`, `7a0c386b`, `ecfd3cc1`.
PR: https://github.com/olivium-dev/jeeb-mobile/pull/335 (**still draft**).

## 1. What the audit found

Source: `analysis/UX-API-AUDIT.md` (12 lens readers, 181 verified P0/P1 findings,
9 refuted, 210 unverified P2/P3, live-gateway-probed RFC 7807 producer).

The kit was fine; the system between the wire and the kit did not exist:

1. **No error model.** 64 catch sites got raw `DioException`, building 53
   exception classes over 43 divergent enums; the same gateway 500 was
   `server` on Orders, `unknown` on Wallet, `invalidInput` on request
   creation. 5xx distinguished in 5/64 handlers, 429 in 4, 503/413/415
   nowhere. RFC 7807 extensions (`errors{}`, `matches[]`, `escalationId`,
   `attemptsRemaining`, `retryAfter`, `upstreamCode`, `traceId`) had zero
   readers.
2. **Failure rendered as emptiness.** Six repositories swallowed
   `DioException` into `return const []` (jeeber feed, submitted offers,
   active deliveries, accepted conversations, client home x3) — a jeeber with
   the gateway down was told "No requests nearby — you're online".
3. **Stuck spinners.** Nine cubits emitted an in-flight flag with no retry on a malformed row.
4. **Fabricated success**: empty-body onboarding submit (UX-05), discarded
   onboarding photo (UX-06), rating swallow-and-go-home (UX-07), account
   deletion always "done" (F3), 422 read as success on receipt confirm
   (DREC-01), door handover treating `{verified:false}` as delivered (F2).
5. **Silent refresh failures** on 7 main-flow screens.
6. **Offline built and unplugged** — `OfflineCubit`/`OfflineBanner` never mounted.
7. **Auth lane holes** — keystore read failure sent requests unauthenticated
   forever (NET-02); one 429 anywhere suppressed every GET app-wide (NET-04).
8. **Copy** — 6 cubits returned raw English sentences; 262 `_pick(en, ar)`
   pairs across 17 `*_l10n.dart` facades bypassed the ARB; "Something went
   wrong" existed as 9 keys with 5 Arabic renderings.
9. **Tests aimed at structure, not failure** — 45/114 error/empty/loading/retry
   identifiers asserted by no test; the only test rendering all 322 catalog
   states was tag-excluded from CI.

**Decision** (§`UX-API-AUDIT.md` "Decision"): one `AppFailure` sealed model, one
Dio→AppFailure mapping point, one presentation contract, one empty-state API,
one loading contract. Ten work packages (WP-0A/0B first, WP-1..8 parallel,
WP-9 ARB dedup last), disjoint file ownership, ruled in `analysis/RULINGS.md`.

## 2. Architecture landed

- **`AppFailure` model** (`lib/core/network/app_failure.dart`, new): sealed
  hierarchy — `NetworkFailure`, `TimeoutFailure`, `ServerFailure`,
  `UnauthorizedFailure`, `ForbiddenFailure`, `NotFoundFailure`,
  `ConflictFailure`, `GoneFailure`, `ValidationFailure`, `RateLimitedFailure`,
  `UnknownFailure`. `AppFailure.of(Object)` is the one mapping entrypoint.
- **`GatewayProblem`** (`gateway_problem.dart`, new): RFC 7807 parser with
  typed getters (`retryAfter`, `attemptsRemaining`, `escalationId`,
  `reasonCode`, `accountStatus`, `field`, `matches`, `upstreamCode`); never
  reads `code`/`error`/`message` (gateway never sends them).
- **Interceptors**: `AppFailureInterceptor` appended last in
  `MockGatewayClient.createDio`; `RetryInterceptor` (bounded, exp backoff +
  jitter, per-path-prefix rate-limit scoping); `X-Request-Id` interceptor;
  `sendTimeout: 30s` added (previously unset — 29 dead branches revived);
  `RateLimitInterceptor` rejects with a typed `RateLimitSuppression` sentinel
  instead of prose.
- **Kit widgets** (`lib/core/widgets/jeeb/`): `JeebFailureBlock`
  (+ `.compact`), `showJeebErrorSnack`/`showJeebSnack`/`showJeebSuccessSnack`,
  `JeebRefreshFailedNote`, `JeebStateHost`, `JeebEmptyState` extended with
  `reason`, `secondaryAction`, `liveRegion`. `app_failure_copy.dart` is the
  one EN/AR copy resolver — only Network/Timeout blame connectivity;
  unrecoverable kinds get an exit CTA, never inert Retry.
- **Cubit contract**: `status {initial, loading, loaded, failed}` + nullable
  typed error; `refresh()` never flips `loaded` back to `loading`; failed
  refresh renders via `JeebRefreshFailedNote`, not silently.
- **Offline plumbing**: `OfflineCubit` provided above the router in
  `app.dart`, driven by `NetworkReachabilitySignals`; `OfflineBanner` mounted
  via new `OfflineBannerHost` in the `MaterialApp.builder` slot.
- **Guardrails**: ratchet tests measuring today's count of banned patterns
  (`showOmdsErrorSnackbar`, raw `ScaffoldMessenger.showSnackBar` in features,
  bare `OmdsPullToRefresh`, `OmdsErrorState`/`OmdsLoadingState`) and asserting
  count <= floor; `test/previews/preview_structure_test.dart` floor raised,
  never lowered; `tool/check_design_tokens.sh` wired into CI for the first
  time (`db83ba7a`).
- **CI**: `dart analyze --fatal-infos .` + `flutter test --exclude-tags
  capture` + l10n parity + AR plurals + design-token check + 79% coverage
  floor, all wired as the Stage-2 gate.

## 3. Per-stage commits

| Commit | Subject | Files | +/- |
|---|---|---|---|
| `db83ba7a` | AppFailure model, Dio failure mapper, retry/offline plumbing, failure kit + copy family (stage 0) | 74 | +9088/-370 |
| `a48444ba` | migrate all screens to AppFailure + failure/empty/loading contract (stage 1+2) — WP-1..8a/8b | 802 | +51125/-7700 |
| `7a0c386b` | device-validated fixes F1-F9 (run-1 defects) | 49 | +3151/-252 |
| `ecfd3cc1` | profile/greeting placeholder fix + notification snack-and-stay (run-2 residuals) | 16 | +738/-51 |
| **Total** `ab610933..ecfd3cc1` | | **887** | **+63985/-8256** |

## 4. Gate figures

| Stage | analyze | tests | coverage | source |
|---|---|---|---|---|
| Baseline (worktree, pre-programme) | clean | **8257 pass / 0 fail** | — | `analysis/RULINGS.md` R6 |
| Stage-2 integration, first run (post `a48444ba`) | clean | 10481 pass / 0 fail / 109 skip | — | `stage1/fix1/GATE.md` §"Gate commands" run 1 (`fix1/logs/test-final.log`) |
| Stage-2 review-fix pass → **`7a0c386b`** | clean | **10491 pass / 0 fail / 109 skip** | **84.64%** (LH 56706/LF 67000) | `fix1/GATE.md` §"Gate re-run" (`fix1/logs2/`) |
| Fix-2 integration, first run | clean | 10515 pass / 0 fail / 109 skip | 84.64% (LH 56723/LF 67016) | `fix2/GATE.md` §"Gate results" run 1 (`fix2/logs/test.log`) |
| Fix-2 review-fix pass #2 → **`ecfd3cc1`** | clean | **10539 pass / 0 fail / 109 skip** | **84.65%** (LH 56737/LF 67027) | `fix2/GATE.md` §"Gate re-run (full, after `git add -A`)" |

All gates also green throughout: `l10n_parity_check.sh --analyze` (all strict
counters 0, 1132 orphan getters warn-only pre-existing), `ar_plurals_check.sh`
(21 plural sets, 0 missing AR forms; 76 numeric keys outside plural sets
warn-only pre-existing), `tool/check_design_tokens.sh`. CI coverage floor is
79%; landed at 84.63-84.65%. Toolchain: Flutter 3.44.2 stable / Dart 3.10.2.

## 5. Device validation — 3 runs, 9 defects

Device: SM-A336B (RZCT505K7WF), Android 14, real gateway via
`dev.base_url_override`. No uninstall, no Clear Local Data across all 3 runs.

### Run 1 (`device-evidence/JUDGE-RUN1.md`, against `a48444ba`) — **FAIL, 9 defects**

1. **F1** Order history: outage rendered as `order_history_empty_active`
   ("No deliveries yet") for the whole ~25s in-flight window and on every
   retry; `order_history_loading` never appeared.
2. **F2** Jeeber dashboard: outage rendered `jeeber_dashboard_empty_state`
   ("Become a Jeeber / Start now") to an approved jeeber with 5 active
   deliveries — never flipped to error/retry.
3. **F3** Earnings tab: same false-empty pattern as F2.
4. **F4 (part A)** Profile: error block coexisted with fabricated placeholder
   data (name="Add your name", rating="No reviews yet", avatar "?", plus a
   "Register as a delivery" row) for an account that is really "Karim
   TestJeeber / 2 Reviews" — run-1's own report had wrongly PASSed this.
5. **F5 (offline banner semantics)**: banner painted visually but exposed NO
   semantics node — screen-reader-invisible, untestable by id.
6. **F6 (stale refresh snack)**: `order_history_refresh_failed_snack` stayed
   on screen ≥34s after reconnect, only cleared on manual Retry.
7. **F7 (notification cross-account leak)**: a fresh client saw 4 unread rows
   belonging to Karim's jeeber account (byte-identical ids) —
   `notifications_empty` unreachable on a fresh account.
8. **F8 (stale notification tap)**: tapping a stale/foreign notification
   silently landed on client-home-empty, no snack/dialog.
9. **F9 (cancel-request stale list)**: after confirming cancel, the request
   still listed "Broadcasting" until a manual pull-to-refresh.

Also flagged as gaps: no REPORT.md for auth/offline/build/devtool scenarios;
chat/jeeber-feed/offers errors and wallet/reviews/notifications empties never
exercised; outage only simulated as connect-timeout; AR never checked on any
failure state; create-request accepted "C4 explosives and a loaded handgun"
and a 1-char description (no content/min-length validation) — out of scope.

### Run 2 (`device-evidence-2/{cancel,notifications,offline-a11y,outage-jeeber,build}/REPORT.md`, against `7a0c386b`)

F1/F2/F3/F6/F7/F9 fixes confirmed PASS on-device (outage-jeeber alone: 23
assertions, 22 PASS). Offline-a11y: 12/12 PASS — banner now exposes
`offline_banner`/`offline_banner_dismiss_cta` with correct `content-desc`,
reconnect clears both banner and refresh-failed snack with no tap. Cancel:
7/7 PASS via `CancelledRequestSignals`. Notifications: F7/F8 PASS (0
cross-account leakage; unresolvable target snacks and stays).

**1 residual FAIL: F4.3** — the profile-placeholder fix held on *first* load
but not on *retry*: tapping `customer_profile_retry_cta` during an outage
re-rendered the full profile chrome bound to an empty default object (`?`
avatar, "Add your name", "No reviews yet") for ~30s before resolving to the
error card. Root cause: the retry path reset the view-model to a default
profile before setting `loading`, unlike first-load.

### Run 3 (`device-evidence-3/REPORT.md`, against `ecfd3cc1`)

**Scenario A (F4, 10/10 PASS)**: profile shows bare `customer_profile_loading`
with zero placeholder text/avatar on first load AND on retry (t≈2s/t≈10s
sampled); jeeber-home greeting shows no "Welcome back"/`?` avatar while
loading. Both recover correctly to real identity.

**Scenario B (F8, snack-and-stay half: 12/12 PASS, 6 notification kinds)**:
every unresolvable tap (offer-accepted, new-request, availability,
new-message, delivery-cancelled rows) snacks with `notifications_cannot_open`
and stays on the list; no navigation to any home root.

**Scenario B control ("resolves and navigates"): NOT DEMONSTRABLE — see
OWNER-CONFIRM (b).** A real live request was created to supply a resolvable
target; it still snacked, because the gateway never emits a target id.

## 6. Two Flutter framework facts discovered mid-fix

1. **A `SnackBar` with a non-null `action` never auto-dismisses on Flutter
   3.44.** `SnackBar.persist` is derived from `action != null`
   (`scaffold.dart:617-624`), and a persisting snack ignores its `duration`
   entirely — this is *why* F6 (the stale "Check your connection… Retry"
   snack) existed. Fix (`jeeb_snack.dart`): explicit `persist: false` + two
   named durations (`kJeebSnackDuration`=4s, `kJeebSnackActionDuration`=8s)
   so an action-bearing snack stays bounded, plus `clearOnReconnect` closing
   the controller on the next `NetworkReachabilitySignals` emission.
2. **A widget painted before the `Navigator` inside `MaterialApp.builder`
   emits zero semantics nodes.** Every route's `ModalBarrier` wraps in
   `BlockSemantics`, erasing earlier siblings' semantics — so a naive
   `Column(children: [banner, content])` painted the offline banner
   pixel-for-pixel with no accessibility node at all. This is *why* F5
   (banner invisible to screen readers, run 1) existed. Fix: new
   `OfflineBannerHost` — `Column(verticalDirection: .up)` so the banner
   paints *last* (survives the barrier) while staying first in reading
   order; a regression test asserts the naive `Column` finds no semantics
   node, "reason: if this ever finds the node, Flutter changed
   BlockSemantics and OfflineBannerHost can go back to a plain Column."

## 7. OWNER-CONFIRM — items needing the owner

a. **DM-onboarding submit route absent on gateway `origin/main`.** Verified
   via `git -C jeeb-gateway show origin/main` (`stage1/OWNER-CONFIRM.md`): no
   DM/jeeber-onboarding controller among ~90 controllers, nothing mentions
   `home_base*`/`service_area`/`out_of_coverage`. Landed the fail-safe
   contract against the *documented* path
   `/form-builder-service/v1/templates/jeeb_jeeber_v1/submit`: 2xx resolves;
   **404/405/501 resolve normally** + `Diag.event('dm_onboarding_submit_route_absent')`
   (an undeployed route must never block the funnel); 409
   `…/errors/out_of_coverage` → typed exception on the service-area step;
   anything else → `DmOnboardingGatewayException`. Owner must confirm or
   replace the path (one-constant change) and confirm the 409 discriminator.
   Until then every real build silently no-ops the submit — same as today,
   now traceable in Diag.

b. **Gateway gap D1 — `/v1/notifications` cannot support navigation, for
   anyone.** Proven live in run 3: every item's body is `{id, type, title,
   body, ts, read, deepLink: "jeeb://notifications"}` — no `requestId`/
   `targetId`/`deliveryId`/`offerId`/`orderId`, `deepLink` a self-referential
   no-op. The client's `_reference` parser (13 id keys) finds none, so every
   `_dispatch` branch falls to `_cannotOpen`. A real, freshly-created live
   request (`defb1f07-…`) was tapped and still snacked — not a stale-data
   artifact. F8 is correct given `ref == null`; closing this needs a
   **gateway change** to emit target ids per item.

c. **Create-request has no content/min-length validation.** Observed run 1:
   a description "Deliver 2kg of C4 explosives and a loaded handgun" was
   accepted and broadcast to jeebers; a 1-character description ("a") also
   enables submit. Out of scope for this branch, flagged anyway.

d. **Test request left pending on live gateway.**
   `defb1f07-efa5-4b8f-bc1a-09d6fcd1140b` ("F8-resolve-probe-parcel"), owned
   by `devtool_client_1788592148874`, created live in run 3 to probe D1.
   Still `pending`, auto-expires 2026-09-06 11:21 UTC.

e. **Guardrail residuals** (ratchet floors, not zeroed — WP-9/Stage-2 scope,
   never done here): 3 remaining `showOmdsErrorSnackbar` call sites, 1
   remaining `OmdsErrorState`/`OmdsLoadingState`-shaped widget in production
   code, 1 remaining title-as-headline instance
   (`onboarding_funding_screen.dart:349`, assigned to WP-5, not confirmed
   closed).

f. **Follow-ups not done:** jeeber-home greeting can still show "Welcome
   back" after a *failed* `/users/me` read outside the run-3 fix scope; AR
   never checked on any failure state on a real device (EN only — AR parity
   is test-only); outage only ever a TCP-blackhole connect-timeout, no
   4xx/5xx/429/RFC 7807 body scenario ran on-device; chat, jeeber feed error,
   pending-offers error, wallet/reviews/notifications-empty never exercised
   on device; **PR #335 is still a draft**, not marked ready for review.
