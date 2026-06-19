# 20 — GAP ANALYSIS: AUTH domain

> Author: Principal UX analyst. Date: 2026-06-18. Phase 1 artifact.
> Method: blueprint screen contract (`web/blueprint.json` + `web/src/screens/_data/<id>.json`)
> ↔ Flutter inventory (`11_FLUTTER_INVENTORY.md`) ↔ actual `lib/features` code ↔ mock
> (`12_MOCK_INVENTORY.md`). Decisions cited by id from `jeeb-mind-map/docs/07_DECISIONS_LOG.md`
> and `flow-review/99_LEAD_SYNTHESIS.md`.

Screens in scope (11): `splash`, `walkthrough`, `login`, `sign-up`, `social-login`,
`social-collision-prompt`, `verify-code`, `recover-password`, `auth-set-password`,
`phone-otp-verification`, `biometric-unlock`.

---

## 0. Domain-level headline (read this first)

The blueprint's authoritative auth architecture is **email-first**:

- **sign-up** = Name / Email / Password (+ social), email **not** verified (D21), then a
  **phone-OTP step** because phone is the verified account anchor (D8, G8).
- **login** = Email + Password (+ social + forgot-password) for returning users. Per
  **D23 + LEAD_SYNTHESIS S-4/Q4**, a returning login is **NOT** forced through phone-OTP every
  time — it resolves via long-lived refresh + **biometric-unlock**. Re-OTP only on a new device or
  password change.
- **social** is a *secondary* method layered on the email-first base, still requiring phone (G8),
  with **collision blocking** (D22) when an email is already registered another way.
- **set-password** lets a social-only user add email/password (D65); recovery (recover-password →
  verify-code → auth-set-password) is the email reset chain (D90 governs the return target).

The Flutter app implements a **different, inverted model**: there is exactly **one** auth route,
`/register` (`RegistrationScreen`), which is **phone-OTP-first** — an 8-digit Lebanese phone field
(`+961`) → 6-digit OTP → home. Social (Google/Apple — **no Facebook**) is rendered inline above an
"or" divider. There is **no email/password field anywhere**, no login-vs-signup distinction, no
recover/verify/set-password chain, no collision UI, and biometric-unlock is a literal "coming soon"
placeholder. `splash` is a transient bootstrap host with **no session-aware auto-routing**.

This is the single largest divergence in the engagement: **8 of 11 auth screens are missing or
divergent**, and the divergence is *architectural* (phone-first vs email-first), not cosmetic. It
must be reconciled with an explicit owner decision before building — see §2 OPEN DECISIONS. Until
then this analysis maps each blueprint screen to the blueprint contract as written and flags the
divergence per-screen.

### Cross-cutting blockers (affect every screen here)

- **B1 — Auth never reaches the mock (CTO brief §4).** `DioOtpService`
  (`lib/features/registration/data/dio_otp_service.dart`) sends `POST /v1/auth/otp/request` and
  `/v1/auth/otp/verify`, but the rewrite map in `lib/core/network/mock_gateway_client.dart` only
  keys `/auth/otp`, `/auth/social`, `/auth/refresh` (no `/v1/auth/*`). Prefix-match fails → auth
  never hits `:4010`. FIX (foundation/backenders): add `/v1/auth/* → /auth-service/auth/*` rewrite
  entries OR rename the app paths. This blocks **every** auth screen that talks to the network.
- **B2 — No social handler in the mock.** Rewrite has `/auth/social → /auth-service/auth/social`,
  but `auth-service.ts` defines **no** `/auth/social` route (only `/auth/login` admin, `/auth/otp/*`,
  `/auth/refresh`, `/auth/logout`). Worse, the app's `DefaultSocialAuthService` posts to a *third*
  path `/api/auth/social`. Social auth cannot succeed against the mock today.
- **B3 — No email/password app auth in the mock.** `POST /auth-service/auth/login` is **admin/CMS
  only** (`admin@jeeb.local`), explicitly "NOT for app clients/jeebers". The blueprint's email-first
  login + signup have **no** backing endpoint. Any email-first build needs new mock routes
  (find-or-create by email, password set/verify, recovery code issue/verify).
- **B4 — OTP code length contract.** Mock `verifyOtp` accepts `1234` (4-digit, per smoke tests);
  the Flutter OTP input is **6-digit** (`OmdsOtpInput length: 6`, `_kOtpLength = 6`) and the dev
  `FakeOtpService.validCode = '123456'`. Mismatch already flagged in code. Reconcile against the
  live `/v1/auth/otp/verify` contract.

---

## 1. Per-screen findings

### 1.1 `splash` — status: **divergent** — P1 / S
- **Blueprint:** full-screen brand logo + loading; **session-aware auto-routing with no UI dwell**
  (D79, D85): first-launch→`walkthrough`; logged-in→last-used tab (D75, `customer-orders-home` or
  `delivery-requests`); biometric-enabled returning→`biometric-unlock`; logged-out returning→`login`;
  suspended/locked→`account-status`.
- **Flutter today:** `BrandedSplash` (`lib/app/branded_splash.dart`) is a **cosmetic bootstrap host**
  shown by `JeebBootstrap` for a ~1.3s floor while `Bootstrap.minimal()` runs. It has the brand logo
  and tagline (good), but **no session check and no auto-routing**. Routing is instead done by the
  GoRouter redirect chain in `app_router.dart` (`_firstRunRedirect`: onboarding gate → `/register`).
- **flutter_target:** `lib/app/branded_splash.dart` + `lib/app/jeeb_bootstrap.dart` (extend the
  bootstrap→route decision); the routing logic lives in `app_router.dart` `_firstRunRedirect`.
- **Gap:** the blueprint's 6 outgoing routing edges are only **partially** realized: onboarding→
  `/register` exists, but there is no last-used-tab restore (D75), no biometric-unlock branch (the
  cubit is a no-op stub, see 1.11), no `login` vs `register` distinction (only `/register`), and no
  `account-status` branch (that screen does not exist at all — out of this domain's build scope but
  the edge originates here).
- **nav_edges_missing:** `splash->walkthrough`, `splash->biometric-unlock`, `splash->login`,
  `splash->account-status`, `splash->delivery-requests (last-used tab restore, D75)`.
- **mock_endpoints:** `GET /user-management/users/me` (resolve session + activeRole for tab
  restore); `POST /auth-service/auth/refresh` (long-lived session resume, D23) — both blocked by B1.
- **decisions:** D79, D85, D75, D23, D8.
- **complexity:** S (logic mostly in the redirect; no new screen UI).

### 1.2 `walkthrough` — status: **exists** (route name differs) — P2 / S
- **Blueprint:** 3 swipeable slides (placeholder art, G14), page dots, Next, Skip (first-launch
  only) → `sign-up`; "Get started" on last slide → `sign-up` (D79).
- **Flutter today:** `OnboardingScreen` (`lib/features/onboarding/presentation/onboarding_screen.dart`)
  at route `/onboarding` is a faithful 3-slide PageView with `OmdsDotIndicator`, Next/Get-started CTA,
  Skip, real SVG art, and an EN/AR toggle (a bonus, FR-P1-2). Functionally complete.
- **flutter_target:** `lib/features/onboarding/presentation/onboarding_screen.dart` (route
  `/onboarding`).
- **Gap:** only the **destination** diverges. Blueprint says walkthrough → `sign-up`; Flutter goes
  `context.go('/register')` (the phone-OTP screen). This is correct *given* the Flutter auth model but
  diverges from the blueprint's email-first `sign-up`. Resolves automatically once §2 decides the
  auth model. Minor: route is named `onboarding` not `walkthrough` (cosmetic).
- **nav_edges_missing:** `walkthrough->sign-up` (currently lands on `/register` not a `sign-up`
  screen).
- **mock_endpoints:** none (pure first-launch UI).
- **decisions:** D79, G14.
- **complexity:** S.

### 1.3 `login` — status: **missing** — P0 / M
- **Blueprint:** Email + Password (masked, eye toggle) → home; "Forgot password?" → `recover-password`;
  social FB/Google/Apple → `social-login`; "Sign up" → `sign-up`. Surfaces biometric unlock for
  returning users; social-only users offered "Set a password" (D22, D23, D65).
- **Flutter today:** **does not exist.** There is no email/password login screen. The only auth route
  is `/register` (phone-OTP). The debug-only "Super Login" sheet
  (`lib/features/registration/presentation/super_login/`) posts userId+passcode but is `kDebugMode`
  only and is **not** the blueprint login.
- **flutter_target:** NEW route `/login` → new `LoginScreen` under `lib/features/auth/` (the
  `lib/features/auth/social/` package already exists and can be reused for the social row).
- **Gap:** entire screen missing. Needs email+password fields, eye toggle, Continue, forgot-password
  link, social row, sign-up link, and the D23 biometric-unlock affordance.
- **nav_edges_missing:** `login->recover-password`, `login->sign-up`, `login->social-login`,
  `login->customer-orders-home`.
- **mock_endpoints:** an **email/password app-login endpoint that does not exist yet**
  (`/auth-service/auth/login` is admin-only, B3) — backenders must add one; `POST
  /auth-service/auth/refresh` (D23 session); `POST /push-notification/v1/devices/register` (post-login
  device token). All blocked by B1/B3.
- **decisions:** D22, D23, D65, D85.
- **complexity:** M.

### 1.4 `sign-up` — status: **divergent** — P0 / M
- **Blueprint:** Name / Email / Password (masked + eye + strength hint), email **not** verified (D21),
  "Sign up" → `phone-otp-verification` (phone required, G8); social row → `social-login`; "Already have
  an account? Login" → `login`. Email-first (D22/D65).
- **Flutter today:** `/register` (`RegistrationScreen`) is **phone-first**: a single `+961` phone
  field → "Send code" → 6-digit OTP. It has the social row (Google/Apple) and a branded hero, but
  **no Name, no Email, no Password** fields, **no strength hint**, **no Login link**, and **no
  Facebook**. It collapses sign-up + OTP into one flow and omits the email-first identity entirely.
- **flutter_target:** `lib/features/registration/presentation/registration_screen.dart` (route
  `/register`) — extend to the email-first contract OR keep as the OTP step and add a separate
  `sign-up` screen ahead of it (decision §2).
- **Gap:** divergent identity model. Missing: Name/Email/Password fields, password eye toggle +
  strength hint (D21), Login link, Facebook button, the social→`social-login` and
  collision→`social-collision-prompt` edges.
- **nav_edges_missing:** `sign-up->phone-otp-verification`, `sign-up->social-collision-prompt`,
  `sign-up->login`.
- **mock_endpoints:** email-first signup needs a **find-or-create-by-email** route (does not exist,
  B3); `POST /auth-service/auth/otp/request` (the phone step, D8) blocked by B1.
- **decisions:** D8, D21, D22, D65, G8.
- **complexity:** M.

### 1.5 `social-login` — status: **partial** — P1 / M
- **Blueprint:** native OAuth (FB/Google/Apple); phone still required after social auth (G8); →
  `phone-otp-verification`; second method on an already-registered email → `social-collision-prompt`.
  Likely native sheet, empty in-app outline.
- **Flutter today:** `lib/features/auth/social/` is a real package — `SocialAuthCubit`,
  `DefaultSocialAuthService` (native Google + Apple), `SocialSignInSection`, secure token store. It is
  embedded inline in `RegistrationScreen` (no dedicated `social-login` screen, which matches the
  "native sheet" nature). **Gaps:** (a) **no Facebook** provider (`SocialProvider` = google|apple
  only) though the blueprint and D-set name FB/Google/Apple; (b) after social success it goes straight
  to `/` (home) — it does **not** enforce the phone-OTP step (G8) nor handle collision (D22); (c) the
  service posts to `/api/auth/social` which has no mock handler (B2).
- **flutter_target:** `lib/features/auth/social/` (extend providers + post-auth phone/collision
  routing); wire it into `login`/`sign-up` rather than only `/register`.
- **Gap:** missing FB provider, missing post-social phone-OTP enforcement, missing collision routing,
  no working mock.
- **nav_edges_missing:** `social-login->phone-otp-verification`, `social-login->social-collision-prompt`.
- **mock_endpoints:** `POST /auth-service/auth/social` (must be **created**, B2) — the app currently
  targets `/api/auth/social`, so app+mock must be reconciled.
- **decisions:** D8, D22, G8.
- **complexity:** M.

### 1.6 `social-collision-prompt` — status: **missing** — P1 / S
- **Blueprint:** collision warning (email already registered); link-accounts/continue → `login`;
  use-a-different-email → `sign-up` (D22 — block the second method, tell user to use the original).
  Likely an inline error/sheet.
- **Flutter today:** **does not exist.** `SocialAuthError` has `accountDisabled`/`invalidToken`/
  `network` but **no collision case**; there is no UI for "email already registered via another
  method".
- **flutter_target:** NEW — a sheet/dialog under `lib/features/auth/` surfaced from `sign-up` /
  `social-login` on a 409-collision response.
- **Gap:** entire collision-handling UX missing (decision D22 unrepresented).
- **nav_edges_missing:** `social-collision-prompt->login`, `social-collision-prompt->sign-up`.
- **mock_endpoints:** depends on signup/social endpoints returning a **409 collision** signal (those
  endpoints don't exist yet, B2/B3).
- **decisions:** D22.
- **complexity:** S.

### 1.7 `verify-code` — status: **missing** — P1 / M
- **Blueprint:** "Verify Code" + back; multi-digit code input; wrong/expired error; Resend; "Verify"
  → `auth-set-password`. This is the **email password-recovery** code (distinct from phone-OTP).
- **Flutter today:** **does not exist as a recovery step.** The only code-entry UI is
  `OtpVerificationScreen` (phone-OTP under `/register`), which verifies the phone anchor and routes to
  home, not to a set-password screen. No recovery code flow exists.
- **flutter_target:** NEW route (e.g. `/recover/verify`) → new screen under `lib/features/auth/`. The
  `OmdsOtpInput` + countdown patterns from `otp_verification_screen.dart` are reusable.
- **Gap:** entire recovery code-verify step missing; must route forward to `auth-set-password`.
- **nav_edges_missing:** `verify-code->auth-set-password`, `verify-code->recover-password` (back).
- **mock_endpoints:** a **recovery-code verify** route (does not exist, B3). Reuse of
  `/auth-service/auth/otp/verify` is not appropriate (that anchors the phone, not email recovery).
- **decisions:** (none cited on the screen; governed by the recovery chain + D90 on exit).
- **complexity:** M.

### 1.8 `recover-password` — status: **missing** — P1 / S
- **Blueprint:** "Recover Password" + back; Email field; "Recover" → `verify-code` (code emailed);
  "Sign up" link; "Back to sign in" (→ `login`).
- **Flutter today:** **does not exist.** No forgot/recover-password entry anywhere (there is no login
  screen to launch it from, see 1.3).
- **flutter_target:** NEW route (e.g. `/recover`) → new screen under `lib/features/auth/`.
- **Gap:** entire screen missing.
- **nav_edges_missing:** `recover-password->verify-code`, `recover-password->sign-up`,
  `recover-password->login`.
- **mock_endpoints:** a **request-recovery-code** route (does not exist, B3).
- **decisions:** (recovery chain; D85 for the back-to-sign-in edge target).
- **complexity:** S.

### 1.9 `auth-set-password` — status: **missing** — P1 / M
- **Blueprint:** "Set Password" + back; New password + Re-type (both with eye toggle); mismatch/
  strength validation; "Set password" → `login` (recovery path) OR → `customer-profile` (in-app social
  user adding a password) per **D90**. Also reachable from `password-security` (shared domain) for
  social-only accounts (D65).
- **Flutter today:** **does not exist.** No set/confirm-password UI. (The shared `password-security`
  screen, which would also link here, is likewise absent — out of this domain's scope but the inbound
  edge originates there.)
- **flutter_target:** NEW route (e.g. `/set-password`) → new screen under `lib/features/auth/`, with a
  `mode` (recovery|in-app-social) param to pick the D90 exit target.
- **Gap:** entire screen missing; must implement the D90 dual exit (recovery→`login`, in-app
  social→`customer-profile`/Profile).
- **nav_edges_missing:** `auth-set-password->login`, `auth-set-password->customer-profile`.
- **mock_endpoints:** a **set-password** route (does not exist, B3); `POST
  /auth-service/auth/refresh` (D23 revoke-all-on-password-change → re-establish session).
- **decisions:** D65, D90, D23.
- **complexity:** M.

### 1.10 `phone-otp-verification` — status: **partial (divergent placement)** — P0 / S
- **Blueprint (role=shared):** phone entry/confirmation; multi-digit OTP; Resend + countdown; Verify;
  wrong/expired error; phone is the account anchor (D8). It is the **post-sign-up verification step**
  (reached from `sign-up` and `social-login`), → `customer-orders-home` (account active).
- **Flutter today:** `OtpVerificationScreen`
  (`lib/features/registration/presentation/otp_verification_screen.dart`) is a **faithful, complete
  OTP UI**: 6-digit `OmdsOtpInput`, resend countdown, attempts-remaining, lockout banner, change-phone,
  error states. Backed by `RegistrationCubit` + `DioOtpService`. This is the **best-implemented auth
  screen.** Divergence is **placement**: it is the *primary* entry (reached directly from
  `/register`/walkthrough as step 2 of phone-first signup), not a step *after* an email-first `sign-up`
  / `social-login`. Returning users hit it too (no biometric/refresh bypass), contradicting D23
  (LEAD_SYNTHESIS S-4).
- **flutter_target:** `lib/features/registration/presentation/otp_verification_screen.dart` — reuse
  as-is; re-parent it behind `sign-up`/`social-login` once §2 resolves the model, and add the
  returning-user bypass (D23).
- **Gap:** wrong place in the graph + no returning-user OTP bypass; OTP length contract (B4); never
  reaches mock (B1).
- **nav_edges_missing:** `sign-up->phone-otp-verification`, `social-login->phone-otp-verification`
  (inbound, currently absent because those source screens don't exist); the `->customer-orders-home`
  exit currently goes to generic `/` (acceptable).
- **mock_endpoints:** `POST /auth-service/auth/otp/request`, `POST /auth-service/auth/otp/verify`
  (find-or-create + tokens + cookie) — both blocked by B1.
- **decisions:** D8, G8, D23.
- **complexity:** S (screen done; rework is nav placement + bypass).

### 1.11 `biometric-unlock` — status: **partial (placeholder)** — P0 / M
- **Blueprint (role=auth):** Face/Touch ID unlock prompt; Unlock button; "Use password instead" →
  `login`; returning users skip OTP (D23). Unlock success → `customer-orders-home`. Reached from
  `splash` for returning logged-in users with biometric enabled.
- **Flutter today:** route `/lock` exists but `BiometricLockScreen`
  (`lib/features/biometric_auth/presentation/biometric_lock_screen.dart`) is an **"OmdsEmptyStatePage
  — Biometric Lock coming soon"** placeholder. The gating cubit `BiometricLockCubit` is a **no-op
  stub** (`evaluate()` always emits `disabled`), so the router lock gate never engages. A *second*,
  unrouted, more-complete `BiometricPromptScreen` exists under `lib/features/biometric_login/` (has a
  fingerprint prompt + `BiometricCubit.authenticate()`), but it is not wired into the router and has no
  "use password instead" / home-on-success routing.
- **flutter_target:** `lib/features/biometric_auth/presentation/biometric_lock_screen.dart` (route
  `/lock`) — replace placeholder; lift logic from `lib/features/biometric_login/` and make
  `BiometricLockCubit` real (read pref + `BiometricGateway` + `SharedPrefsPinRepository`).
- **Gap:** real biometric prompt missing; "Use password instead" → `login` missing; unlock-success →
  home routing missing; the whole D23 returning-user-skip-OTP path is unrealized (LEAD_SYNTHESIS Q4
  explicitly adds this screen and says login no longer routes through phone-OTP every time).
- **nav_edges_missing:** `biometric-unlock->customer-orders-home`, `biometric-unlock->login`,
  and the inbound `splash->biometric-unlock`.
- **mock_endpoints:** `POST /auth-service/auth/refresh` (resume long-lived session on unlock, D23) —
  blocked by B1. Biometric itself is on-device (no endpoint).
- **decisions:** D23, D8, D79.
- **complexity:** M.

---

## 2. OPEN DECISIONS (raise — do not invent)

> Per CTO brief §6.2, an undecided detail must be raised, not invented. The decisions log + lead
> synthesis answer the *product* questions (email-first, D22/D23/D65; biometric returning login,
> S-4/Q4). What is **undecided** is the *implementation reconciliation* given the shipped Flutter
> phone-first model:

1. **AUTH-OD-1 (P0): email-first vs phone-first.** The blueprint + D22/D65 are email-first with a
   phone-OTP step; the Flutter app is phone-OTP-first with no email/password at all. Confirm the
   target: (a) rebuild to blueprint email-first (adds `login`, `sign-up` email fields, recovery chain,
   set-password, collision — large surface, needs B3 mock routes), or (b) formally re-decide to keep
   phone-first as an intentional supersede of D22/D65 (then most "missing" auth screens become "won't
   build" and the blueprint must be annotated). This is the gating decision for 7 of the 11 screens.
2. **AUTH-OD-2 (P1): Facebook provider.** Blueprint + D-set say FB/Google/Apple; the app ships
   Google/Apple only. Confirm whether Facebook is in MVP scope (affects `login`, `sign-up`,
   `social-login`).
3. **AUTH-OD-3 (P1): mock auth surface.** Email-first requires login/signup/recovery/set-password
   endpoints that do **not** exist (B3) and a working social endpoint (B2). Owner-gate the mock
   additions vs reusing the OTP-only surface.
4. **AUTH-OD-4 (P0, foundation): the B1 `/v1/auth/*` rewrite blocker** and B4 OTP-length contract —
   already on the foundation backlog; restated here because no auth screen functions end-to-end until
   B1 is fixed.

## 3. Priority roll-up

| blueprint_id | status | priority | complexity |
|---|---|---|---|
| splash | divergent | P1 | S |
| walkthrough | exists | P2 | S |
| login | missing | P0 | M |
| sign-up | divergent | P0 | M |
| social-login | partial | P1 | M |
| social-collision-prompt | missing | P1 | S |
| verify-code | missing | P1 | M |
| recover-password | missing | P1 | S |
| auth-set-password | missing | P1 | M |
| phone-otp-verification | partial | P0 | S |
| biometric-unlock | partial | P0 | M |
