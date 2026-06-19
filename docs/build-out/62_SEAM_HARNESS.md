# 62 — Dev-Seam Session Harness (the FINAL `jeeb.seam.*` contract)

> **Author:** Senior Principal Flutter Engineer (Opus — DEV-SEAM SESSION HARNESS).
> **Date:** 2026-06-18. **Status:** LANDED. Closes RC-1 (PRECONDITION, 9 flows) in
> `61_W0_QA_RESULTS.md`.
>
> This is the **authoritative contract** for the debug-only test harness that lets a Maestro
> flow deterministically start mid-journey. Every `jeeb.seam.*` key, its accepted values, the
> exact app/mock state each seeds, and the resulting start destination are below. The flow-fix
> QA codes to this; future waves (customer/jeeber role + `kycStatus` states) extend it by adding
> a `SessionSeed` enum value + a seed branch (see §6).
>
> **DEBUG-ONLY / RELEASE-INERT.** Every entry point is `kDebugMode`-gated AND `DevSeam.resolve`
> short-circuits to `DevSeamConfig.empty` in release, so `DevSeam.current` is empty and every
> seam is a no-op. Release builds ignore all of it (and it is tree-shakeable).

---

## 0. TL;DR — the contract at a glance

| `jeeb.seam.*` key | Accepted value(s) | What it seeds | Start destination (root id) |
|---|---|---|---|
| `jeeb.seam.session` | `customer_logged_in` | onboarding done · token · role=client | shell `/` → **`shell_tab_requests`** |
| `jeeb.seam.session` | `jeeber_logged_in` | onboarding done · token · role=jeeber | shell `/` → **`shell_tab_dashboard`** (see §3 note) |
| `jeeb.seam.session` | `logged_out_returning` | onboarding done · NO token | **`login_root`** (`login_email_field`) |
| `jeeb.seam.session` | `biometric_enrolled` | onboarding done · token · biometric LOCKED | **`biometric_unlock_prompt`** (`/lock`) |
| `jeeb.seam.session` | `biometric_enrolled_logged_out` | onboarding done · NO token · biometric enabled | **`login_root`** + `login_biometric_affordance` visible |
| `jeeb.seam.session` | `suspended` | onboarding done · token · account blocked flag | **`account_status_root`** (`/account-status`) |
| `jeeb.seam.otp_code` | `"123456"` | nothing (mock dev code) | n/a — flow TYPES the code |
| `jeeb.seam.otp_countdown_expired` | `"true"` | zeroes the app-driven resend cooldown | n/a — `phone_otp_resend_cta` tappable on first frame |
| `jeeb.seam.signup_collision` | `"true"` | nothing (mock 409s on duplicate email) | n/a — flow drives the 2-step collision (see §4.3) |
| `jeeb.seam.social_login` | `facebook_no_phone` | deterministic social success, NO phone | tap social → **`phone_otp_input`** (G8 → OTP) |
| `jeeb.seam.social_login` | `collision_409` | deterministic social 409 | tap social → **`social_collision_sheet`** |
| `jeeb.seam.recovery_code` | `"654321"` | nothing (mock dev code) | n/a — flow TYPES the code |
| `jeeb.seam.recovery_countdown_expired` | `"true"` | nothing (no app countdown today) | n/a — `verify_code_resend_cta` already always tappable |
| `jeeb.seam.set_password_mode` | `in-app-social` \| `recovery` | nothing (read off the route's `?mode=`) | used with `jeeb.route=/set-password?mode=…` |

Unknown/absent values are inert (no seeding → walkthrough). A typo never crashes startup.

---

## 1. How a flow passes these (Maestro)

The seam keys are Android **intent extras** passed via `launchApp.arguments` — NOT dart-defines.
They are read natively in `MainActivity.kt` (`seamKeys` whitelist) over the `app.jeeb.mobile/dev_seam`
MethodChannel, parsed into `DevSeamConfig.fromMap()`, merged by `DevSeam.resolve()`, and applied by
`SessionSeamBootstrap.seed()` before the first frame.

```yaml
# JM-005 example — start on the biometric lock screen.
- launchApp:
    arguments:
      jeeb.seam.session: "biometric_enrolled"
- extendedWaitUntil:
    visible:
      id: "biometric_unlock_prompt"
    timeout: 25000
```

```yaml
# Combine a route pin with a per-flow seam (JM-022 in-app-social).
- launchApp:
    arguments:
      jeeb.seam.session: "customer_logged_in"     # so the set-password route is reachable
      jeeb.route: "/set-password?mode=in-app-social"
      jeeb.seam.set_password_mode: "in-app-social" # documents intent; route's ?mode= drives it
```

> The legacy capture knobs (`jeeb.route`, `jeeb.state`, `jeeb.locale`, `jeeb.home_tab`,
> `jeeb.feed`, `jeeb.hold_splash`) are unchanged and still merge field-by-field with the new
> `jeeb.seam.*` keys (an intent setting only `jeeb.seam.session` still inherits a route from a
> device file / dart-define, and vice-versa).

---

## 2. The wiring (end-to-end, the 4 layers RC-1 was missing)

```
Maestro launchApp.arguments
        │  (Android intent extras)
        ▼
MainActivity.kt  seamKeys whitelist  ──►  readSeamExtras() over MethodChannel
        │
        ▼
IntentExtrasSource.read() ─► DevSeamConfig.fromMap()  (typed fields, kDebugMode-gated)
        │
        ▼
DevSeam.resolve()  (merge intent ▸ device-file ▸ dart-define)  ─► DevSeam.current
        │
        ▼   (Bootstrap.minimal, BEFORE first frame + BEFORE the router redirect)
SessionSeamBootstrap.seed(prefs)  ─► seeds the REAL stores the root cubits read
        │
        ▼
JeebApp builds OnboardingCubit / RoleCubit / SessionCubit / BiometricLockCubit /
SeededAccountStatusGate over those SAME stores ─► app_router._firstRunRedirect lands
the flow at the right start destination on the FIRST redirect (no flash, no race).
```

**Ordering is load-bearing.** `SessionSeamBootstrap.seed()` runs inside `Bootstrap.minimal()`
right after `SharedPreferences.getInstance()` and `DevSeam.resolve()`, and BEFORE the root widget
tree is built. The cubits read their persisted prefs in their constructors (`OnboardingCubit`,
`RoleCubit`), in `..evaluate()` (`BiometricLockCubit`, kicked from `app.dart`), and in `refresh()`
(`SessionCubit`, kicked from `JeebApp.initState` post-first-frame). Seeding the underlying stores
first means the very first router redirect already sees the seeded state.

### Files changed / created

| File | Change |
|---|---|
| `android/app/src/main/kotlin/app/jeeb/mobile/MainActivity.kt` | Added all 8 `jeeb.seam.*` keys to the `seamKeys` whitelist so the intent-extras pass through the channel. |
| `lib/core/dev_seam/dev_seam_config.dart` | Added typed fields `sessionSeed` (typed `SessionSeed` enum) · `otpCode` · `otpCountdownExpired` · `signupCollision` · `socialLogin` · `recoveryCode` · `recoveryCountdownExpired` · `setPasswordMode`; mapped all in `fromMap()`; folded into `isEmpty`/`==`/`hashCode`/`toString`. |
| `lib/core/dev_seam/dev_seam.dart` | `_mergePreferring()` merges the 8 new fields field-by-field. |
| `lib/core/dev_seam/session_seam_bootstrap.dart` (NEW) | `SessionSeamBootstrap.seed()` — seeds onboarding/role/token+userId/biometric/account-status from `jeeb.seam.session`. Also hosts `SeededAccountStatusGate` (the debug `AccountStatusGate` driven by the seeded flag). |
| `lib/core/dev_seam/social_auth_seam.dart` (NEW) | `SocialAuthSeam.resolver` — maps `jeeb.seam.social_login` to a deterministic `SocialAuthResult` (no live OAuth). |
| `lib/app/bootstrap.dart` | Calls `SessionSeamBootstrap.seed(prefs: preferences)` in `Bootstrap.minimal()` (after `DevSeam.resolve()` + prefs load, before first frame). |
| `lib/app/app.dart` | Wires `SeededAccountStatusGate` (debug) / `AlwaysActiveAccountStatusGate` (release) into `AppRouter.create(accountStatus:)`; builds the real `SessionCubit` over `AuthTokenStore`; builds `BiometricLockCubit` over the prefs-backed preference + PIN repos. |
| `lib/features/registration/presentation/registration_screen.dart` | `jeeb.seam.otp_countdown_expired` → debug-only zero-cooldown `RegistrationAttemptPolicy`; wired `SocialAuthSeam.resolver` on the `DefaultSocialAuthService`. |
| `lib/features/auth/presentation/login_screen.dart` | Wired `SocialAuthSeam.resolver` on the `DefaultSocialAuthService`. |
| `lib/features/auth/presentation/sign_up_screen.dart` | Wired `SocialAuthSeam.resolver` on the `DefaultSocialAuthService`. |

The real stores already exposed their public keys for single-source-of-truth seeding (no parallel
state): `OnboardingCubit.completedKey`, `RoleCubit.rolePrefKey`,
`BiometricPreferenceRepositoryImpl.kEnabledKey`, `SharedPrefsPinRepository.kPinKey`,
`AuthTokenStore` (secure keystore).

---

## 3. `jeeb.seam.session` — the six session branches (the RC-1 unblock)

`jeeb.seam.session` parses into the typed `SessionSeed` enum (`dev_seam_config.dart`). The bootstrap
switch is exhaustive. Every seed first calls `_resetSeededState()` (clears all seam-owned keys + the
token store) so a re-launch in the same Maestro session can't leak prior state, then seeds:

| value (`SessionSeed`) | onboarding | role (`app.role`) | auth token (keystore) | biometric | account-blocked flag | First-redirect destination |
|---|---|---|---|---|---|---|
| `customer_logged_in` | ✅ `true` | `client` | ✅ `user-client-001` | — | — | shell `/` → **Requests tab** (`shell_tab_requests`) |
| `jeeber_logged_in` | ✅ `true` | `jeeber` | ✅ `user-jeeber-002` | — | — | shell `/` → **first jeeber tab** (`shell_tab_dashboard`, see note) |
| `logged_out_returning` | ✅ `true` | — | ❌ none | — | — | **`/login`** (`login_root` / `login_email_field`) |
| `biometric_enrolled` | ✅ `true` | `client` | ✅ `user-client-001` | enabled + PIN `0000` | — | **`/lock`** (`biometric_unlock_prompt`) |
| `biometric_enrolled_logged_out` | ✅ `true` | — | ❌ none | enabled + PIN `0000` | — | **`/login`** + `login_biometric_affordance` visible |
| `suspended` | ✅ `true` | `client` | ✅ `user-client-001` | — | ✅ `seam.account_blocked=true` | **`/account-status`** (`account_status_root` / `account_status_support_cta`) |

**Why these stores produce these destinations** (`app_router._firstRunRedirect`, layered):
1. **onboarding** — `completed=true` means the onboarding gate is satisfied (no `/onboarding`).
2. **session** — a present token → `SessionCubit` classifies `authenticated`; absent → `unauthenticated`
   → redirect to `/login`. The token is `mock-jwt-access-<userId>` (the mock's shape; not a parseable
   JWT, so `SessionCubit` authenticates by presence — the real logged-in path).
3. **account-status** — `seam.account_blocked=true` → `SeededAccountStatusGate.isBlocked` → `/account-status`
   (only evaluated once a session exists; a blocked account is by definition authenticated).
4. **biometric** — `BiometricLockCubit.evaluate()` sees `enabled && (available || hasPin)` →
   `BiometricLockPhase.locked` → the router holds `/lock`. The PIN (`0000`) makes `canChallenge` true
   on the production `UnavailableBiometricGateway`, so the lock actually holds on the emulator.
5. **role/tab** — tabs are NOT routes (CTO brief §4). The gate lands authenticated users at `/`; the
   `ShellScreen` reads `RoleCubit` and renders the role's tab set; the first tab is the start tab.

> **⚠️ QA reconciliation — `jeeber_logged_in` destination id.** `60_W0_TEST_PLAN §3` lists the
> jeeber landing as `shell_tab_delivery`. The shipped `ShellScreen` jeeber tab set is
> **`dashboard` / `earnings` / `profile`** (customer's set is `requests` / `delivery` / `profile`).
> So a jeeber's **first/landing** tab id is **`shell_tab_dashboard`**, and there is **no
> `shell_tab_delivery` in the jeeber shell** (`delivery` is the customer's *second* tab = OrdersTab).
> The seam correctly seeds `role=jeeber`; the JM-006 flow's jeeber-branch assertion should target
> **`shell_tab_dashboard`** (or `shell_tab_earnings`/`shell_tab_profile`), not `shell_tab_delivery`.
> This is a flow-YAML id fix on the QA side, not an app change.

**`userId` is real and persisted** (`AuthTokenStore` `auth.userId`). The future JM-006 account-status
cubit reads `GET /users/:id` by this persisted id (NOT `/users/me`, which the mock `authStub`
resolves to `user-client-001` regardless of token — `42 W-1 FLOOR`). The seeded ids
(`user-client-001`, `user-jeeber-002`) match `jeeb-mock-backend/src/fixtures/seed.ts`.

---

## 4. Per-flow seams (what genuinely needs app/mock seeding vs not)

### 4.1 `jeeb.seam.otp_code` / `jeeb.seam.recovery_code` — NO app seeding needed

The mock accepts fixed dev codes (`42 W-1 FLOOR CLOSED`): OTP `123456`, recovery `654321`. The flow
simply **types the fixed code** into `phone_otp_input` / `verify_code_input`; the mock approves it.
These keys are kept as typed fields for contract parity and so a flow can read the value rather than
hardcode it, but they seed **nothing** in the app or mock.

### 4.2 `jeeb.seam.otp_countdown_expired` — app-driven, override IMPLEMENTED

The phone-OTP **resend** countdown IS app-driven (`RegistrationCubit` runs a 1 Hz ticker off
`RegistrationAttemptPolicy.resendCooldown`, default 60 s; `phone_otp_resend_cta` is only rendered when
`resendSecondsRemaining <= 0`). So this seam is a genuine app override: when set, the registration
screen constructs the cubit with a **zero-cooldown** `RegistrationAttemptPolicy(resendCooldown:
Duration.zero)`, so `phone_otp_resend_cta` is tappable on the first OTP frame. `kDebugMode`-gated;
release always uses the default 60 s. (`recovery_countdown_expired` has no equivalent — see 4.5.)

### 4.3 `jeeb.seam.signup_collision` — MOCK-driven, 2-step flow

The signup 409 is **mock-driven**: `POST /auth/signup` returns `409 email_collision` when the email
matches an existing LIVE user (`auth-service.ts`). The seeded users have NO email, so the
deterministic trigger is a **two-step flow in one Maestro session**:

```yaml
# JM-008 / JM-019 collision path (no app seeding — the mock owns the 409):
# 1. Sign up with a fresh email  → 201, creates the user WITH that email.
- tapOn: { id: "signup_email_field" }
- inputText: "collision-probe@example.com"
- ...                                  # fill name + password, submit → phone-OTP
# 2. Return to sign-up and submit the SAME email → 409 email_collision
- tapOn: { id: "signup_email_field" }
- inputText: "collision-probe@example.com"
- tapOn: { id: "signup_submit_cta" }
- extendedWaitUntil: { visible: { id: "social_collision_sheet" }, timeout: 15000 }
```

`jeeb.seam.signup_collision="true"` documents the flow's intent and is retained as a typed flag, but
seeds nothing — the mock's duplicate-email 409 is the source of truth (`AuthFailure.emailCollision`
→ the sign-up screen routes to `social_collision_sheet`, JM-019).

### 4.4 `jeeb.seam.social_login` — deterministic resolver IMPLEMENTED (no live OAuth)

The mock's `POST /auth/social` only accepts `provider ∈ {google, apple}` (401 for `facebook`) and
mints a *new* identity per idToken — so neither `facebook_no_phone` (needs a no-phone success on the
Facebook button) nor `collision_409` (needs a 409) is reachable through the real path. The simplest
deterministic path is therefore a **debug-only short-circuit**: `SocialAuthSeam.resolver`
(`lib/core/dev_seam/social_auth_seam.dart`) is injected into `DefaultSocialAuthService.seamResolver`
at all three construction sites (login / sign-up / registration). When the user taps a social button:

| value | resolver returns | `SocialAuthCubit` → | Destination |
|---|---|---|---|
| `facebook_no_phone` | `SocialAuthSuccess(session: recentlyCreated=true, phone=null)` | `authenticated` + `requiresPhoneVerification` | host routes to **`phone_otp_input`** (G8 → JM-009) |
| `collision_409` | `SocialAuthFailure(SocialAuthError.collision)` | `collision` | host raises **`social_collision_sheet`** (JM-019) |

`kDebugMode`-gated; `null` (real native + `/v1/auth/social` path) in release, on an unrecognised
value, or when the seam is absent. JM-018 should pass `jeeb.seam.social_login=facebook_no_phone` and
tap `login_social_facebook`; JM-019 (collision via social) should pass `collision_409`.

### 4.5 `jeeb.seam.recovery_countdown_expired` — NO-OP today

The verify-recovery-code screen has **no app-driven countdown** — `verify_code_resend_cta` is always
tappable. The key is retained as a typed flag for contract parity / future use, but seeds nothing. If
a recovery resend cooldown is added later, wire it here exactly like 4.2.

### 4.6 `jeeb.seam.set_password_mode` — read off the route, NOT seeded

`/set-password` reads its mode from the route query (`?mode=recovery|in-app-social`,
`SetPasswordMode.fromQuery`, default `recovery`). A flow deep-links via
`jeeb.route=/set-password?mode=in-app-social`. `jeeb.seam.set_password_mode` documents the intended
mode (and is available to the flow as a typed field) but does not itself seed state — the route's
`?mode=` is the source of truth. Recovery mode submit → `login_root`; in-app-social submit →
`customer_profile_wallet_chip` (JM-022 dual exit, D90).

---

## 5. Destination root ids (assert on these — i18n-safe, §41 rule)

| Destination | Root / signature id | Route |
|---|---|---|
| Walkthrough (first launch, no seed) | `walkthrough_slide_1` | `/onboarding` |
| Login | `login_root` / `login_email_field` | `/login` |
| Login + biometric affordance | `login_biometric_affordance` (in addition to `login_root`) | `/login` |
| Sign-up | `signup_name_field` | `/sign-up` |
| Phone-OTP verify | `phone_otp_root` / `phone_otp_input` | `/register` (re-parented) |
| Biometric lock | `biometric_unlock_prompt` | `/lock` |
| Account status | `account_status_root` / `account_status_support_cta` | `/account-status` |
| Customer shell home | `shell_tab_requests` | `/` (role=client) |
| Jeeber shell home | `shell_tab_dashboard` (NOT `shell_tab_delivery` — §3 note) | `/` (role=jeeber) |
| Social collision sheet | `social_collision_sheet` | sheet over login/sign-up |
| Recover password | `recover_email_field` | `/recover` |
| Verify recovery code | `verify_code_input` | `/recover/verify` |
| Set password | `setpw_new_field` | `/set-password` |
| Customer profile (set-pw in-app-social exit) | `customer_profile_wallet_chip` | `/profile/customer` |

---

## 6. Storage keys seeded (single source of truth — no parallel state)

| State | Store | Key | Seeded value |
|---|---|---|---|
| onboarding complete | `SharedPreferences` (read by `OnboardingCubit`) | `app.onboarding.completed` | `true` |
| active role | `SharedPreferences` (read by `RoleCubit`) | `app.role` | `client` \| `jeeber` |
| access token | `AuthTokenStore` secure keystore (read by `SessionCubit`) | `auth.accessToken` | `mock-jwt-access-<userId>` |
| refresh token | `AuthTokenStore` secure keystore | `auth.refreshToken` | `mock-jwt-refresh-<userId>` |
| userId | `AuthTokenStore` secure keystore | `auth.userId` | `user-client-001` \| `user-jeeber-002` |
| biometric enabled | `SharedPreferences` (read by `BiometricPreferenceRepositoryImpl` + login affordance) | `biometric.enabled` | `true` |
| biometric PIN (challenge fallback) | `SharedPreferences` (read by `SharedPrefsPinRepository`) | `biometric.pin` | `0000` |
| account blocked (debug gate) | `SharedPreferences` (read by `SeededAccountStatusGate`) | `seam.account_blocked` | `true` |

All keys are the cubits'/repos' **own public constants** — the harness seeds the SAME key each cubit
reads in its constructor, so there is no second store to drift.

### Extending to future waves (customer/jeeber role + kycStatus)

The design extends cleanly: add a value to the `SessionSeed` enum (`dev_seam_config.dart`) with its
`wireValue`, then add a seed branch in `SessionSeamBootstrap.seed()` that writes the relevant stores
(e.g. a `jeeber_kyc_pending` value would `_completeOnboarding` + `_setRole(jeeber)` + `_logIn` +
seed a `kycStatus` store once that store lands). The router redirect + destination assertion follow
automatically. When the real JM-006 account-status cubit (`GET /users/:id`) lands, it REPLACES
`SeededAccountStatusGate` in `app.dart`; the seam contract (blocked account → `/account-status`) is
unchanged.

---

## 7. Verification

- `flutter analyze` — **clean of new errors**. Zero issues in any changed/created file
  (`dev_seam/*`, `registration_screen.dart`, `login_screen.dart`, `sign_up_screen.dart`,
  `social_auth_service.dart`, `MainActivity.kt`). The only `lib/` lints are pre-existing
  `info`-level (sort_constructors_first, doc-comment formatting) in unrelated features; the only
  `error`s are pre-existing `FontWeight` const-map issues in `test/inter_font_weight_test.dart`.
- Per the work order, the emulator/Maestro run is a later phase (not run here).

---

# W1 journey seam — `jeeb.seam.journey` (mid-journey start)

> **Author:** W1 Test-Harness + Backend (Opus). **Date:** 2026-06-18. **Status:** LANDED.
> Closes the seam half of every `jeeb.seam.journey=*` blocker in `63_W1_TEST_PLAN §6`.
>
> This is the **authoritative contract** for the Wave-1 journey seam: the debug-only key that
> lets a W1 customer-journey flow deterministically start mid-journey (a pending request, an
> offers-received request, an accepted order, an active/delivered delivery, a pending rating,
> or saved addresses). It **layers on top of** `jeeb.seam.session` (§3) — a flow always passes
> BOTH `jeeb.seam.session=customer_logged_in` (or `jeeber_logged_in`) AND
> `jeeb.seam.journey=<value>`.
>
> **DEBUG-ONLY / RELEASE-INERT** by the same construction as the session seam: every entry point
> is `kDebugMode`-gated and `DevSeam.resolve` short-circuits to empty in release, so `journeySeed`
> is `JourneySeed.none` and the seam is a no-op.

## W1-0. TL;DR — the journey contract at a glance

| `jeeb.seam.journey` | What the mock seeds (for `user-client-001` unless noted) | Stable ids | Route the app lands on | Flows |
|---|---|---|---|---|
| `pending_request` | 1 request `status=pending`, `notifiedCount=4`, + empty broadcasting conversation | `req-client-001-pending` · `conv-journey-pending` | `/requests/req-client-001-pending/waiting` | jm-023, jm-026, jm-030 |
| `pending_request_no_coverage` | same, but `notifiedCount=0` (no-coverage variant) | `req-client-001-pending` | `/requests/req-client-001-pending/waiting` | jm-026 AC1b |
| `offers_received` | 1 request `status=offers-received` + **3** offers (`offer-001`, `offer-002`, `offer-003`) from distinct jeebers (price/ETA/name/rating) + broadcasting conversation w/ one `offer_card` per offer | `req-client-001-offers` · `offer-001` · `offer-002` | *(none — lands on shell, flow navigates via Replies/waiting)* | jm-026, jm-027, jm-028, jm-029 |
| `order_accepted` | 1 request `status=matched` + winning `offer-001` (`status=accepted`) + 1:1 accepted conversation + 1 delivery `Ordered` | `req-client-001-accepted` · `del-client-001-active` · `conv-journey-accepted` · `offer-001` | `/chat/conv-journey-accepted` | jm-025, jm-029, jm-031 |
| `active_delivery` | the `order_accepted` set, delivery advanced to `InTransit` | `del-client-001-active` · `req-client-001-accepted` | `/orders/del-client-001-active/tracking` | jm-025, jm-032 |
| `delivery_marked_done` | the `active_delivery` set, delivery at `AtDoor` (receipt-pending) with a **proof-photo URL** | `del-client-001-delivered` (+ `del-client-001-active`) · `req-client-001-accepted` | `/orders/del-client-001-delivered/receipt` | jm-032, jm-033, jm-034 |
| `jeeber_rating_pending` | 1 delivery `Done` for **`user-jeeber-002`**, no rating row yet (mutual-rate reachable) | `del-jeeber-002-delivered` | `/orders/del-jeeber-002-delivered/mutual-rate?mode=jeeber` | jm-034 AC3 |
| `has_saved_addresses` | 2 saved addresses (Home `isDefault=true`, Office) for `user-client-001` | `addr-client-001-home` · `addr-client-001-office` | *(none — lands on shell, flow navigates via profile/location-select)* | jm-049 |

Unknown/absent values are inert (`JourneySeed.none` → no seeding, no route pin). A typo never crashes startup.

## W1-1. How a flow passes it (Maestro)

```yaml
# jm-033 — start on the delivered-receipt screen.
- launchApp:
    clearState: true
    arguments:
      jeeb.seam.session: "customer_logged_in"   # base session (onboarding + token + role=client)
      jeeb.seam.journey: "delivery_marked_done" # mock holds the AtDoor delivery + proof; app pins /receipt
- extendedWaitUntil:
    visible: { id: "receipt_prompt" }
    timeout: 30000
```

## W1-2. The wiring (end-to-end — extends the 3-layer session seam)

```
Maestro launchApp.arguments  (jeeb.seam.session + jeeb.seam.journey)
        │  Android intent extras
        ▼
MainActivity.kt seamKeys  (now includes "jeeb.seam.journey")  ──► readSeamExtras()
        │
        ▼
DevSeamConfig.fromMap()  → typed `journeySeed` (JourneySeed enum)   [kDebugMode-gated]
        │
        ▼
DevSeam.resolve()  → merges journeySeed, then `_applyJourneyRoutePin()` folds the journey's
        │            deep route into DevSeamConfig.route (only when no explicit jeeb.route was set)
        ▼   (Bootstrap.minimal, BEFORE first frame + BEFORE the router redirect)
SessionSeamBootstrap.seed():
        │   1. applies the jeeb.seam.session base seed (role/token/biometric/account-status, §3)
        │   2. POST /__mock/seed/journey { journey } over a Dio (MockGatewayClient base+rewrite),
        │      AWAITED so the mock holds the rows before any screen fetch
        ▼
app_router `_devRoute` route-pin lands the flow on the journey's deep route on the FIRST redirect
(for journeys with a route pin); journeys without a pin land on the shell `/` and the flow navigates.
```

**No `app_router.dart` edit.** The journey route pin reuses the EXISTING `_devRoute` route-pin
machinery (which already lands an onboarded+authenticated session on `DevSeam.current.route`). The
journey simply *provides* that route via `DevSeam.resolve()`’s post-merge fold, so the integrator’s
router is untouched. An explicit `jeeb.route` still wins (a flow can override the default landing).

### Files changed / created (app)

| File | Change |
|---|---|
| `android/app/src/main/kotlin/app/jeeb/mobile/MainActivity.kt` | Added `jeeb.seam.journey` to the `seamKeys` whitelist. |
| `lib/core/dev_seam/dev_seam_config.dart` | Added the typed `JourneySeed` enum (wireValue + `routePin` per value) + a `journeySeed` field; mapped `jeeb.seam.journey` in `fromMap()`; folded into `isEmpty`/`==`/`hashCode`/`toString`; added `hasJourneySeed`. |
| `lib/core/dev_seam/dev_seam.dart` | `_mergePreferring()` merges `journeySeed`; new `_applyJourneyRoutePin()` folds the journey’s route pin into `route` after merge (explicit route wins; no-pin journeys leave `route` empty). |
| `lib/core/dev_seam/session_seam_bootstrap.dart` | `seed()` now also runs on a journey-only launch; after the session seed it `POST /__mock/seed/journey { journey }` over an injectable Dio (default `MockGatewayClient.createDio()`), awaited, fail-safe (never throws). |

### Storage / state seeded (single source of truth)

The journey seam seeds **mock-side** state (request/offer/delivery/conversation/saved-location rows)
plus, for the deep-landing journeys, **one client-side value**: `DevSeamConfig.route` (the route pin,
consumed by the existing router pin). The `jeeb.seam.session` base seed continues to own the
SharedPreferences/keystore session keys (§6). There is no parallel journey state on the client — the
journey rows live only in the mock, where the screens read them over `:4010`.

## W1-3. The mock seed endpoint(s)

Owned by `jeeb-mock-backend` (additive; no existing route modified).

| Endpoint | Body | Response | Notes |
|---|---|---|---|
| `POST /__mock/seed/journey` | `{ "journey": "<value>" }` | `200 { seeded: true, journey, ids: {…} }` · `400` on unknown value | Dev-only (`/__mock/*` namespace). **Idempotent** — re-applying overwrites by stable id (e.g. `offers_received` always yields exactly 3 offers). Seeds are **layered on the base fixture** (they do not wipe it); a flow’s `clearState`/`__mock/reset` resets to the base, then the seam re-applies the journey. Implemented in `src/fixtures/journey-seed.ts` (`seedJourney()`), mounted in `src/server.ts`. |

The `ids` echoed back are the stable constants in `63 §4.3` (`req-client-001-pending`,
`req-client-001-offers`, `req-client-001-accepted`, `del-client-001-active`,
`del-client-001-delivered`, `del-jeeber-002-delivered`, `offer-001`/`offer-002`). The app seam logs
them; flows can read them for deep-linking but generally rely on the route pin instead.

**Rewrite note:** `/__mock/seed/journey` is an `/__mock/*` admin path — it matches **no** key in the
app’s `_pathToServicePrefix` rewrite map, so it passes through unchanged to the base URL (`:4010`).
No rewrite-map edit is needed.

## W1-4. Per-journey SM-1 / state notes (why these states)

- **Receipt-pending = `AtDoor`, not `Done`.** SM-1 (`delivery-service.ts`) allows `AtDoor → Done`;
  the customer’s receipt-confirm (JM-033) is what drives that terminal transition. So
  `delivery_marked_done` stops the delivery at `AtDoor` (+ stamps `evidenceUrl`/`proofPhotoUrl`), the
  receipt-pending state the app surfaces — the flow then taps `receipt_confirm_cta` to reach `Done`.
- **`offers_received` seeds 3 offers** (the two stable `offer-001`/`offer-002` + a third) so the
  sort control (`offer_review_sort_price`) has >1 distinct price and `offer_card_0` is deterministic.
- **`order_accepted` / `active_delivery` share `del-client-001-active`** — the accepted order and the
  in-flight delivery are the same row at different SM-1 states, so the pinned summary (JM-031) and the
  tracking stepper (JM-032) read one consistent delivery.
- **`jeeber_rating_pending` uses `user-jeeber-002`** (the `jeeber_logged_in` session id), with
  `user-client-001` as the rated counterpart, and seeds **no** rating row so the mutual-rate screen is
  reachable (score-taking `GET /:deliveryId/status` returns un-rated).

## W1-5. Verification

- **App:** `flutter analyze` clean on every changed/created file (`lib/core/dev_seam/*`,
  `MainActivity.kt`, the new `test/core/dev_seam/session_seam_journey_test.dart`). Unit tests:
  `dev_seam_config_test.dart` (+JourneySeed round-trip/route-pin cases), `dev_seam_test.dart`
  (+journey merge + route-pin fold + explicit-route-wins + no-pin cases), and the new
  `session_seam_journey_test.dart` (the POST path/body, journey-only launch, no-journey no-POST,
  session+journey co-seed, fail-safe) all GREEN; the existing route-pin + first-run-gating suites
  still GREEN (no regression).
- **Mock:** `npm run build` (tsc) clean; `npm test` (vitest) **274/274** — the prior 260 plus 14 in
  `src/w1-journey-seam.test.ts` (every journey value’s seeded rows + stable ids + idempotency, T1’s
  5-tier catalog, D1m’s proof-photo sink). The pre-existing tier test in `smoke.test.ts` was updated
  from “3 tiers” to the T1 5-tier assertion.
- Per the work order, the emulator/Maestro run is a later phase (not run here).

---

# W2 jeeber seam — `jeeb.seam.kyc_status` · `jeeb.seam.wallet_state` · 4 new `jeeb.seam.journey` values

> **Author:** W2 Test-Harness Seam (Opus). **Date:** 2026-06-19. **Status:** LANDED (app side).
> Closes the seam half of every Wave-2 jeeber blocker in `65_W2_TEST_PLAN §3`.
>
> This is the **authoritative contract** for the Wave-2 jeeber seam: the debug-only keys that let
> a W2 jeeber flow deterministically (a) drive the KYC gate state the DELIVERY tab + offer flow
> read (`jeeb.seam.kyc_status`), (b) drive the wallet affordability the wallet hub + offer composer
> read (`jeeb.seam.wallet_state`), and (c) start mid-jeeber-journey (4 new `jeeb.seam.journey`
> values). It **layers on** `jeeb.seam.session=jeeber_logged_in` (§3) — every W2 jeeber flow passes
> that base session plus the W2 keys its AC needs.
>
> **DEBUG-ONLY / RELEASE-INERT** by the same construction as §3/W1: every entry point is
> `kDebugMode`-gated and `DevSeam.resolve` short-circuits to empty in release, so all three are
> `none` and inert.

## W2-0. TL;DR — the contract at a glance

| `jeeb.seam.*` key | Accepted value(s) | What it seeds (state) | Landing screen / effect |
|---|---|---|---|
| `jeeb.seam.kyc_status` | `none` | jeeber KYC not started; mock `GET …/kyc`+getMe report `none` | (no own pin) DELIVERY tab → `delivery_register_prompt`; offer flow → `offer_kyc_gate` (JM-036/044/048) |
| `jeeb.seam.kyc_status` | `pending` | KYC under review | funding/pending-status context (JM-041/042); gate still NOT approved |
| `jeeb.seam.kyc_status` | `approved` | KYC approved | DELIVERY tab → `jeeber_feed_root`; offer flow → `offer_composer_root` (gate skipped) |
| `jeeb.seam.kyc_status` | `rejected` | KYC rejected | rejected context (JM-042/043); gate NOT approved |
| `jeeb.seam.wallet_state` | `sufficient` | mock wallet: `availableBalance > reserve`, affordability "enough" | composer send → `jeeber_feed_root` (JM-045/053) |
| `jeeb.seam.wallet_state` | `insufficient` | mock wallet: `availableBalance < reserve`, affordability "low/empty"; offer 402 path reachable | composer send → `insufficient_balance_sheet` (JM-045 AC5/046/053) |
| `jeeb.seam.wallet_state` | `empty` | mock wallet: `availableBalance = 0`, affordability "all_reserved/empty" | wallet hub empty/all-reserved copy (JM-053) |
| `jeeb.seam.journey` | `jeeber_kyc_submitted` | mock: user-jeeber-002 KYC just submitted (pending), no delivery/request row | **pins `/jeeber/onboarding/funding`** → `funding_explainer` (JM-041) |
| `jeeb.seam.journey` | `jeeber_feed_with_request` | mock: 1 open request in the jeeber feed (`req-feed-001`) | no pin → jeeber shell (`shell_tab_dashboard`); flow → `jeeber_feed_root` → `feed_make_offer_cta` (JM-044/045/046/048) |
| `jeeb.seam.journey` | `jeeber_pending_offers` | mock: 1 submitted offer awaiting customer (`pending-offer-jeeber-001`) | no pin → shell; flow → `jeeber_feed_pending_tab` → `pending_offer_0` (JM-047/048 AC3) |
| `jeeb.seam.journey` | `jeeber_active_delivery` | mock: 1 in-transit delivery + 1:1 chat (`del-jeeber-002-active`) | **pins `/jeeber/deliveries/del-jeeber-002-active/active`** → `mark_delivered_root` (JM-051) |

Unknown/absent values are inert. A typo never crashes startup.

> **Note on the KYC route-pinned flows (JM-042/043) and the wallet hub (JM-053):** these pass an
> explicit `jeeb.route` (`/profile/kyc?step=status`, `/kyc/rejected`, `/wallet`) ALONGSIDE the
> kyc/wallet seam — the seam seeds the screen's CONTENT (status/balance), the explicit route pins
> WHERE it lands. `jeeb.seam.kyc_status` / `jeeb.seam.wallet_state` therefore deliberately have NO
> route pin of their own; they are state seeds, not landing seeds. (JM-036/044/045/046/048 land on
> the jeeber shell `shell_tab_dashboard` — the `jeeber_logged_in` destination — and navigate.)

## W2-1. How a flow passes them (Maestro)

```yaml
# JM-045 sufficient — start as an approved jeeber with money, on the feed.
- launchApp:
    clearState: true
    arguments:
      jeeb.seam.session: "jeeber_logged_in"        # base session (§3)
      jeeb.seam.kyc_status: "approved"             # DELIVERY-tab/offer gate → ungated
      jeeb.seam.wallet_state: "sufficient"         # mock wallet affords the reserve
      jeeb.seam.journey: "jeeber_feed_with_request" # mock holds req-feed-001 in the feed
- extendedWaitUntil: { visible: { id: "shell_tab_dashboard" }, timeout: 30000 }
```

```yaml
# JM-051 — start on the jeeber mark-delivered screen (journey route pin lands it).
- launchApp:
    clearState: true
    arguments:
      jeeb.seam.session: "jeeber_logged_in"
      jeeb.seam.kyc_status: "approved"
      jeeb.seam.journey: "jeeber_active_delivery"  # pins /jeeber/deliveries/del-jeeber-002-active/active
- extendedWaitUntil: { visible: { id: "mark_delivered_root" }, timeout: 30000 }
```

## W2-2. The wiring (end-to-end — extends the 3-layer §3 + W1 pattern)

```
Maestro launchApp.arguments  (jeeb.seam.session + kyc_status + wallet_state + journey)
        │  Android intent extras
        ▼
MainActivity.kt seamKeys  (now also "jeeb.seam.kyc_status", "jeeb.seam.wallet_state")  ──► readSeamExtras()
        │
        ▼
DevSeamConfig.fromMap()  → typed `kycStatusSeed` (KycStatusSeed) + `walletStateSeed` (WalletStateSeed)
        │                    + the 4 new JourneySeed values   [kDebugMode-gated]
        ▼
DevSeam.resolve()  → merges both fields; `_applyJourneyRoutePin()` folds the journey route pin
        │            (jeeber_kyc_submitted / jeeber_active_delivery) into DevSeamConfig.route
        ▼   (Bootstrap.minimal, BEFORE first frame + BEFORE the router redirect)
SessionSeamBootstrap.seed():
        │   1. applies the jeeb.seam.session base seed (§3)
        │   2. POST /__mock/seed/journey { journey }        (W1, awaited+bounded)
        │   3. POST /__mock/seed/kyc    { kycStatus, userId } (W2, awaited+bounded)
        │   4. POST /__mock/seed/wallet { state, userId }     (W2, awaited+bounded)
        ▼
• DELIVERY-tab gate (JM-036) + offer gate (JM-044) read `DevSeam.current.kycStatusSeed`
  SYNCHRONOUSLY on first frame via `SeamJeeberKycStatusGate`
  (lib/core/session/jeeber_kyc_status_gate.dart) — no client store, no race.
• The route pin (jeeber_kyc_submitted / jeeber_active_delivery) lands the deep route via the
  EXISTING router `_devRoute` pin (no app_router edit).
• The wallet hub + offer composer fetch the seeded balance from the mock.
```

**Single source of truth — NO client-side parallel state.** The KYC gate reads the seam field
(`DevSeam.current.kycStatusSeed`) directly through the integrator's `SeamJeeberKycStatusGate`, so
the seam writes **no** SharedPreferences/store value for it — there is nothing to drift, and the
gate is correct on the very first synchronous build (no spinner flash, no race) even if the mock
POST is slow/unreachable. The mock-side `POST /__mock/seed/kyc` exists ONLY so the LIVE getMe/kyc
path agrees once the JM-036 engineer swaps `SeamJeeberKycStatusGate` for the real getMe-backed gate
(U1). `jeeb.seam.wallet_state` is mock-side only by design (no client wallet store the seam owns).
The journey rows live only in the mock (as in W1).

### Files changed / created (app)

| File | Change |
|---|---|
| `android/app/src/main/kotlin/app/jeeb/mobile/MainActivity.kt` | Added `jeeb.seam.kyc_status` + `jeeb.seam.wallet_state` to the `seamKeys` whitelist. |
| `lib/core/dev_seam/dev_seam_config.dart` | Added typed `KycStatusSeed` (`none`/`pending`/`approved`/`rejected` + inert `none`) + `WalletStateSeed` (`sufficient`/`insufficient`/`empty` + inert `none`) enums + `kycStatusSeed`/`walletStateSeed` fields; mapped both in `fromMap()`; added `hasKycStatusSeed`/`hasWalletStateSeed`; folded into `isEmpty`/`==`/`hashCode`/`toString`. Added the 4 new `JourneySeed` values (`jeeberKycSubmitted` w/ pin `/jeeber/onboarding/funding`; `jeeberFeedWithRequest` no pin; `jeeberPendingOffers` no pin; `jeeberActiveDelivery` w/ pin `/jeeber/deliveries/del-jeeber-002-active/active`). |
| `lib/core/dev_seam/dev_seam.dart` | `_mergePreferring()` merges `kycStatusSeed`/`walletStateSeed`; `_applyJourneyRoutePin()` carries them through. The new journey route pins fold automatically via the existing machinery. |
| `lib/core/dev_seam/session_seam_bootstrap.dart` | `seed()` now also runs on a kyc/wallet-only launch; after the session+journey seed it `POST`s `/__mock/seed/kyc { kycStatus, userId }` and `/__mock/seed/wallet { state, userId }` over the injectable Dio, each awaited, bounded by `_journeySeedTimeout` (≤10s), fail-safe (never throws). The seeded `userId` is `user-jeeber-002` (the `jeeber_logged_in` id; `user-client-001` only if a customer session ever pairs with these seams). |
| (consumed, not owned) `lib/core/session/jeeber_kyc_status_gate.dart` | The integrator's `SeamJeeberKycStatusGate` reads `DevSeam.current.kycStatusSeed` — this seam owns that field; the gate owns the screen wiring. Not edited here. |

## W2-3. The mock seed endpoint(s) the app calls

Owned by `jeeb-mock-backend` (the Backend agent provides the seed handlers + data). All are
`/__mock/*` admin paths that the app gateway rewrite map does NOT touch (no prefix matches), so they
reach the Express mock verbatim at `:4010` (emulator `10.0.2.2:4010`).

| Endpoint (app calls) | Body the app POSTs | Drives | Owner |
|---|---|---|---|
| `POST /__mock/seed/journey` | `{ "journey": "<wireValue>" }` | the 4 new jeeber journey rows (`req-feed-001`, `pending-offer-jeeber-001`, `del-jeeber-002-active`, jeeber_kyc_submitted=pending) — added to `seedJourney()` | Backend |
| `POST /__mock/seed/kyc` | `{ "kycStatus": "none\|pending\|approved\|rejected", "userId": "user-jeeber-002" }` | `GET /user-management/users/:userId/kyc` + getMe `kycStatus` (U1) | Backend |
| `POST /__mock/seed/wallet` | `{ "state": "sufficient\|insufficient\|empty", "userId": "user-jeeber-002" }` | `GET /wallet-service/v1/jeeb/wallet` balance/affordability/reserved-now (W1m); the offer 402 path (O1) for `insufficient` | Backend |

> The kyc/wallet POSTs are **bounded** (≤10s, same ceiling as the journey POST) so a slow/unreachable
> mock can never hold the first frame. The KYC GATE never depends on the POST (it reads the seam
> field synchronously); the POST is for the LIVE getMe/kyc + wallet fetch only. A POST failure
> degrades to "no seed" (caught, logged) and the screen shows its own loading/empty state.

## W2-4. Verification

- **App:** `flutter analyze` clean on every changed/created file (`lib/core/dev_seam/dev_seam.dart`,
  `dev_seam_config.dart`, `session_seam_bootstrap.dart`, `MainActivity.kt`, the consumed
  `jeeber_kyc_status_gate.dart`, and the new `test/core/dev_seam/session_seam_w2_test.dart`).
  Unit tests: the new `session_seam_w2_test.dart` (KycStatusSeed/WalletStateSeed round-trip +
  fromMap + the 4 new JourneySeed pins/wires; kyc POST body+path; wallet POST body+path;
  `SeamJeeberKycStatusGate` status mapping; JM-045-shaped tri-seed launch fires all 3 POSTs;
  no-W2-seam → no kyc/wallet POST; kyc/wallet-only launch; fail-safe) all GREEN; the full
  `test/core/dev_seam/` suite (59 tests incl. the W0/W1 cases) GREEN — no regression. The W1
  `session_seam_journey_test.dart` "hung mock bounded" ceiling was corrected from `< 10s` (which
  raced the seam's own 10s `.timeout`) to `< 15s` (still well below the 30s raw-Dio default it
  guards against).
- The full-tree `flutter test` currently has compile errors in OTHER W2 agents' in-flight screens
  (`kyc_rejected_screen.dart`, `onboarding_funding_screen.dart` referencing not-yet-added l10n
  getters) — outside this seam's scope; the seam files + their dev_seam suite compile and pass.
- **Mock seed endpoints** (`/__mock/seed/kyc`, `/__mock/seed/wallet`, the 4 new journey values) are
  the Backend agent's to implement; the app side calls them per W2-3.
- Per the work order, the emulator/Maestro run is a later phase (not run here).

---

# W3/W4 shared seam — 4 new `jeeb.seam.journey` values (notifications · dispute · reviews · ledger)

> **Author:** FINAL-WAVE Test-Harness Seam (Opus). **Date:** 2026-06-19. **Status:** LANDED (app side).
> Closes the seam half of the Wave-3/Wave-4 shared blockers in `30_BACKLOG` (JM-052/055/056 +
> JM-057/065/067/068) and the W1/W2 AP-9-deferred legs (notifications/dispute/reviews/earnings) that
> the final hardening must close.
>
> This adds **no new seam KEY** — it layers four new VALUES onto the existing `jeeb.seam.journey`
> contract (already whitelisted in `MainActivity.kt`, already POSTed to `/__mock/seed/journey` by
> `SessionSeamBootstrap`). Each value is layered on a `jeeb.seam.session` base seed exactly as W1/W2.
>
> **Account-suspended is ALREADY covered** by `jeeb.seam.session=suspended` (§0/§3 → `/account-status`,
> `account_status_root`); no new value is needed for JM-066. Confirmed against the shipped
> `SessionSeed.suspended` branch + `SeededAccountStatusGate` + the §1 landing test.
>
> **DEBUG-ONLY / RELEASE-INERT** by the same construction as §3/W1/W2: `kDebugMode`-gated end to end
> and `DevSeam.resolve` short-circuits to empty in release, so `journeySeed` is `JourneySeed.none`.

## W34-0. TL;DR — the contract at a glance

| `jeeb.seam.journey` | Base session | What the mock seeds (backend `seedJourney`) | Stable ids | Route the app lands on | Flows / JM |
|---|---|---|---|---|---|
| `has_notifications` | `customer_logged_in` (or `jeeber_logged_in`) | a populated notifications inbox for the user: >=1 typed row per dispatch class (offer · accepted · status · low-balance · fee · refund-penalty · topup · kyc) | `notif-client-001-*` | **`/notifications`** (`notifications_root`) | JM-057 |
| `dispute_open` | `customer_logged_in` | 1 OPEN dispute on the accepted order (+ the chat snapshot it summarises) | `dispute-client-001-open` (on `req-client-001-accepted`/`conv-journey-accepted`) | **`/disputes/dispute-client-001-open`** (`dispute_status_state`) | JM-065 (+JM-060 evidence) |
| `jeeber_has_reviews` | `customer_logged_in` | >=5 reviews for jeeber `user-jeeber-002` (clears the cold-start hide, D59) + the offer-card entry rows to reach the profile | `review-jeeber-002-*` · `user-jeeber-002` | *(none — shell; flow taps `offer_card_<id>_name` → `delivery_man_profile_screen_root`, then `profile_view_all_reviews` → reviews-list)* | JM-067, JM-068 |
| `wallet_with_ledger` | `jeeber_logged_in` (+ `jeeb.seam.wallet_state` for the hub balance) | a populated wallet ledger for `user-jeeber-002`: >=1 typed row per ledger type (reserve · fee_won · released · refund · penalty · topup · gift) + earnings totals | `txn-jeeber-002-*` | *(none — jeeber shell; flow navigates via the wallet hub: `wallet_see_all_activity` → activity-list, `wallet_earnings_row` → earnings-dashboard)* | JM-052, JM-055, JM-056 |

Unknown/absent values are inert (`JourneySeed.none` → no seeding, no route pin). A typo never crashes startup.

> **Why notifications & dispute pin a route, but reviews & ledger do not.** `/notifications` and
> `/disputes/:id` are standalone routes the W4 integrator registers (`21_NAV_PLAN §B W4`), so the
> seam can deep-land them via the EXISTING `_devRoute` pin. The jeeber **public profile**
> (`delivery-man-profile`, `21 §A`) takes its identity via `extra` from the offer card today (it is
> not yet an id-addressable route), and the **wallet ledger/earnings** screens are reached from the
> wallet hub — so both land on the shell and the flow navigates the one tap in (the `offers_received`
> / wallet-hub entry the backend co-seeds), exactly the `offers_received` / `has_saved_addresses`
> pattern. A flow can still deep-land a ledger screen with an explicit
> `jeeb.route=/wallet/activity` (or `/wallet/transactions/<id>`) alongside `wallet_with_ledger`.

## W34-1. How a flow passes them (Maestro)

```yaml
# JM-057 — start on the notifications inbox with typed rows.
- launchApp:
    clearState: true
    arguments:
      jeeb.seam.session: "customer_logged_in"     # base session (§3)
      jeeb.seam.journey: "has_notifications"      # mock holds the inbox; app pins /notifications
- extendedWaitUntil: { visible: { id: "notifications_root" }, timeout: 30000 }
```

```yaml
# JM-065 — start on the dispute-status screen (Open).
- launchApp:
    clearState: true
    arguments:
      jeeb.seam.session: "customer_logged_in"
      jeeb.seam.journey: "dispute_open"           # pins /disputes/dispute-client-001-open
- extendedWaitUntil: { visible: { id: "dispute_status_state" }, timeout: 30000 }
```

```yaml
# JM-055/056 — start as an approved jeeber with money + a ledger, then open the wallet hub.
- launchApp:
    clearState: true
    arguments:
      jeeb.seam.session: "jeeber_logged_in"
      jeeb.seam.kyc_status: "approved"
      jeeb.seam.wallet_state: "sufficient"
      jeeb.seam.journey: "wallet_with_ledger"     # mock holds the typed ledger rows
- extendedWaitUntil: { visible: { id: "shell_tab_dashboard" }, timeout: 30000 }
# … flow navigates wallet chip → wallet_see_all_activity → wallet_activity_row_<id> → txn_detail
```

## W34-2. The wiring (end-to-end — reuses the §3 + W1 + W2 machinery verbatim)

```
Maestro launchApp.arguments  (jeeb.seam.session + jeeb.seam.journey=<W3/W4 value>)
        │  Android intent extras  (jeeb.seam.journey ALREADY whitelisted, MainActivity.kt — no native edit)
        ▼
DevSeamConfig.fromMap()  → typed `journeySeed` (the 4 new JourneySeed values)   [kDebugMode-gated]
        ▼
DevSeam.resolve()  → merges journeySeed; `_applyJourneyRoutePin()` folds the route pin
        │            (has_notifications → /notifications · dispute_open → /disputes/…) into route;
        │            jeeber_has_reviews / wallet_with_ledger have NO pin → shell landing
        ▼   (Bootstrap.minimal, BEFORE first frame; mock POST detached, awaitMockSeed:false — the 66 fix)
SessionSeamBootstrap.seed():
        │   1. local session seed (role/token, §3) — the landing decider, awaited (~ms)
        │   2. POST /__mock/seed/journey { journey } — DETACHED (66 boot-hold fix), bounded, fail-safe
        ▼
app_router `_devRoute` pin lands the deep-route journeys; the shell-landing journeys land on `/`.
```

**No app_router / shell / DI / l10n / mock edit by this seam.** The route pin reuses the EXISTING
`_devRoute` machinery; the route registration (`/notifications`, `/disputes/:id`, `/wallet/activity`,
`/wallet/transactions/:id`, `delivery-man-profile`) is the **W4/W3 integrator's** job (`21 §B`), and
the rows are the **backend's** `seedJourney()` branch. This is the same three-way split as W1/W2: the
seam owns the **value→route contract**, the backend owns the **mock rows**, the integrator owns the
**route registration**. The seam values were authored ahead of those screens exactly as the W1/W2
journey pins were.

### Files changed (app)

| File | Change |
|---|---|
| `lib/core/dev_seam/dev_seam_config.dart` | Added 4 `JourneySeed` values: `hasNotifications` (pin `/notifications`) · `disputeOpen` (pin `/disputes/dispute-client-001-open`) · `jeeberHasReviews` (no pin) · `walletWithLedger` (no pin). `fromWire`/`routePin`/`wireValue` pick them up generically; no enum-switch edit needed. |
| `test/core/dev_seam/seam_landing_test.dart` | Extended `expectedPins` with the 4 new values (so the "every JourneySeed is covered" guard test passes), + a per-journey session-pairing override map (`jeeber_has_reviews`→customer, `wallet_with_ledger`→jeeber). |
| `test/core/dev_seam/dev_seam_config_test.dart` | +W3/W4 route-pin assertions + `fromMap` round-trips for the 4 new wire values. |
| `test/core/dev_seam/session_seam_journey_test.dart` | +a W4 (`has_notifications`) journey-seed POST test. |

`MainActivity.kt` is UNCHANGED — `jeeb.seam.journey` is already in the `seamKeys` whitelist (W1), so
the new values pass through the channel with no native edit. `session_seam_bootstrap.dart` is
UNCHANGED — it already POSTs `{ journey: <wireValue> }` for any non-`none` journey.

## W34-3. The mock seed endpoint (the app calls; the Backend owns the rows)

`POST /__mock/seed/journey { journey: "<wireValue>" }` — the SAME dev-only `/__mock/*` admin endpoint
(rewrite-map-exempt) the app already calls for W1/W2. The Backend agent extends
`jeeb-mock-backend/src/fixtures/journey-seed.ts` (`seedJourney()` + `JourneySeedValue` /
`JOURNEY_VALUES`) with the 4 new branches:

| wireValue | mock seeds | for | stable ids |
|---|---|---|---|
| `has_notifications` | a typed notifications inbox (`store.notifications`) | `user-client-001` | `notif-client-001-*` (one per D84 class) |
| `dispute_open` | an OPEN dispute (`store.disputes`) on `req-client-001-accepted` + the `conv-journey-accepted` snapshot | `user-client-001` | `dispute-client-001-open` |
| `jeeber_has_reviews` | >=5 reviews/ratings (`store.ratings`) for the jeeber + the offers-received entry rows to reach the profile | `user-jeeber-002` | `review-jeeber-002-*` |
| `wallet_with_ledger` | a typed wallet ledger (W2m rows) + earnings totals | `user-jeeber-002` | `txn-jeeber-002-*` |

The mock POST is **detached** on the boot path (`awaitMockSeed:false`, the 66_W2_QA_RESULTS
boot-hold fix) so it can never hold the first frame; the landing is decided entirely by the local
session seed + the route pin. A POST failure degrades to "no seed" (screen shows its own empty state).

## W34-4. Account-suspended (JM-066) — confirmed already covered, no new value

`jeeb.seam.session=suspended` (§3) seeds onboarding + token + `seam.account_blocked=true`, and
`SeededAccountStatusGate.isBlocked` makes `app_router._firstRunRedirect` force **`/account-status`**
(`account_status_root` / `account_status_support_cta`). This is the JM-066 landing; the §1
`seam_landing_test` `suspended → account-blocked flag` case locks it. The W4 work to flesh out the
`/account-status` body + `account_status_signout_cta`/`support_cta` edges does not change the seam
contract (blocked account → `/account-status`).

## W34-5. Verification

- **App:** `flutter analyze lib/core/dev_seam/ test/core/dev_seam/` — **clean, zero issues.**
- **Unit tests:** `flutter test test/core/dev_seam/` — **90/90 GREEN** (the prior 85 plus 5 new:
  the W3/W4 route-pin contract, the W3/W4 `fromMap` round-trips, and the `has_notifications` POST).
  The "every JourneySeed is covered by this contract (no silent additions)" guard test passes,
  proving all 4 new values have an asserted landing; the W0/W1/W2 cases + the boot-hold guard still
  GREEN (no regression). `seam_landing_test` stays green per the work order.
- **Mock seed rows** (the 4 new `seedJourney` branches) are the Backend agent's to implement; the app
  side calls them per W34-3.
- Per the work order, the emulator/Maestro run is a later phase (not run here).
