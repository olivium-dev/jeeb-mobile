# 50 — Route / Edge / Key Requests (per-screen engineers → wave integrator)

> Per 40_GUARDRAILS_ARCH §9: per-screen engineers never edit `app_router.dart`,
> `injection_container.dart`, `shell_screen.dart`, or the ARB files. They request
> additions here; the wave integrator batches them. Code against the intended
> name in the meantime.

---

## JM-008 — Sign Up (W0-B engineer)

### l10n KEY REQUEST — dedicated copy currently missing (coded against existing reused keys)
The sign-up screen ships now using the closest **existing** localized keys for
its social row + collision sheet, because no dedicated keys exist yet and ARB is
integrator-owned. Requesting the following dedicated keys (EN + AR, with
`@`-descriptions) so a polish pass can de-overload the reused strings. Maestro
asserts on `Semantics(identifier:)` only, so this is cosmetic copy, not a
behavioural gap.

| intended key | proposed EN value | currently reused | element |
|---|---|---|---|
| `signupSocialDivider` | "or sign up with" | `registrationSocialDivider` ("or") | divider above social row |
| `signupSocialFacebook` | "Continue with Facebook" | brand proper-noun label "Facebook" (Semantics label) | `signup_social_facebook` |
| `socialCollisionTitle` | "Email already in use" | `signupEmailCollision` (body) | `social_collision_sheet` heading |
| `socialCollisionBody` | "An account with this email already exists. Sign in, or use a different email." | `signupEmailCollision` | sheet body |
| `socialCollisionContinueCta` | "Sign in" | `loginContinueCta` ("Sign in") | `social_collision_continue_cta` → /login |
| `socialCollisionOtherEmailCta` | "Use a different email" | `recoverSignupLink` ("Create an account") | `social_collision_other_email_cta` → sign-up |

> Note: Google/Apple social buttons reuse `registrationContinueWithApple` /
> `registrationContinueWithGoogle` (already present). Facebook has no SDK in the
> app yet (JM-018 owns the FB provider wire-up); the sign-up button is present
> per the JM-008 AC + 60_W0_TEST_PLAN §2.4 and triggers the social cubit path
> once JM-018 lands the Facebook provider.

### DEV-SEAM KEY REQUEST — `jeeb.seam.signup_collision`
`60_W0_TEST_PLAN §6` lists `jeeb.seam.signup_collision: "true"` (forces a 409 on
the signup endpoint) but `lib/core/dev_seam/dev_seam_config.dart` does not yet
carry this field (it only models route/state/locale/home_tab/feed/hold_splash/
skip_onboarding). The sign-up cubit already routes a 409 (`AuthFailure.emailCollision`)
to the `social_collision_sheet`, so the jm-008 AC5 flow becomes green the moment
EITHER (a) the dev seam recognises `signup_collision` and the mock honours it,
OR (b) the mock returns 409 for the seeded `existing@jeeb.app`. Both are
core/mock-owned, outside the auth feature folder. **Owner: W0 integrator / Foundation + backenders.**

---

## JM-022 — Set Password (W0-B engineer)

### ROUTE REQUEST — forward `email` + `resetToken` to `SetPasswordScreen` via `extra`
The `/set-password` route builder today constructs
`SetPasswordScreen(mode: SetPasswordMode.fromQuery(state.uri.queryParameters['mode']))`
with no payload. `SetPasswordScreen` now ALSO accepts `email` (String, default `''`)
and `resetToken` (String?, default null) — the existing `mode`-only call still
compiles unchanged. Please forward the recovery `resetToken` (+ `email`) from the
verify-code step so the recovery-mode submit can reach the mock:

```dart
builder: (context, state) {
  final extra = state.extra;
  final payload = extra is SetPasswordArgs ? extra : null; // or read query params
  return SetPasswordScreen(
    mode: SetPasswordMode.fromQuery(state.uri.queryParameters['mode']),
    email: payload?.email ?? '',
    resetToken: payload?.resetToken,
  );
},
```

JM-021's verify screen would then `context.goNamed('set-password',
queryParameters: {'mode': 'recovery'}, extra: SetPasswordArgs(email: enteredEmail,
resetToken: verifyResult.resetToken))`. A typed `SetPasswordArgs { email,
resetToken }` can live in the auth domain (engineer-agnostic — query params work
too).

- why: 42_GUARDRAILS_MOCK W-1 FLOOR — `POST /v1/auth/set-password` requires
  `resetToken` in recovery mode (401 `invalid_token` otherwise). The screen
  compiles + renders without it (in-app-social does not need it), but the
  recovery Maestro path (jm-022 AC1) needs the token forwarded end-to-end.
- cites: 60_W0_TEST_PLAN §2.11 + nav matrix (JM-022→JM-007/JM-035), JM-021, D90.

### SEAM REQUEST — wire `jeeb.seam.set_password_mode`
`60_W0_TEST_PLAN §6` lists `jeeb.seam.set_password_mode: "in-app-social"` (launch
the set-password screen directly with `mode=in-app-social`). `dev_seam_config.dart`
does not yet carry this field, and the router pin does not recognise it. When set
(debug only) the router should land directly on `/set-password?mode=in-app-social`
(analogous to the existing `jeeb.route` pin). Suggested: add a `setPasswordMode`
field to `DevSeamConfig` (keyed `jeeb.seam.set_password_mode`) and, in the router
redirect, force `/set-password?mode=<value>` when non-empty + debug. The screen
already honours `?mode=in-app-social`; only the seam→route pin is missing. jm-022
AC2/AC3/AC4 all enter via this seam. **Owner: W0 integrator / Foundation.**

---

## JM-020 — Recover Password (W0-B engineer)

### l10n KEY REQUEST — dedicated recover error copy currently missing (coded against an existing reused key)
The recover-password screen surfaces a transient transport failure (the only
reachable failure: the recovery request is **non-enumerating** per the W-1 FLOOR
contract — it returns 200 for any email, so there is no "email not found" copy by
design). No recover-scoped error key exists in the ARB (the integrator added 7
`recover*` keys: title/subtitle/emailLabel/emailHint/submitCta/signupLink/
backToSigninLink — none for an error). The screen ships now reusing
`loginNetworkError` (network failure copy, EN+AR present, same auth funnel, same
semantics). Requesting a dedicated key so a polish pass can de-overload it:

| intended key | proposed EN value | currently reused | element |
|---|---|---|---|
| `recoverError` | "Couldn't send the code. Check your connection and try again." | `loginNetworkError` | `recover_error` text (transport failure) |

> Maestro asserts on `Semantics(identifier:)` only, so this is cosmetic copy, not
> a behavioural gap. The `recover_error` Semantics id is an engineer addition
> (not in 60_W0_TEST_PLAN §2.9 — which lists no error element) consistent with the
> D30 four-state contract / 40_GUARDRAILS_ARCH §3; harmless to QA (presence-only).

### EDGE / EXTRA NOTE — recover-verify receives `email` via `extra` (already-registered route, no router change needed)
`recover_submit_cta` success calls `context.goNamed('recover-verify', extra:
<enteredEmail>)` — the `/recover/verify` route is already registered (W0-INT) and
builds `const VerifyRecoveryCodeScreen()`. JM-021 (verify screen, separate
engineer) should read the email with `state.extra as String?` in its route/cubit
so it can call `AuthRepository.verifyRecovery(email:, code:)`. R-F: passing the
email via `extra` is the least-surprising blueprint-consistent payload mechanism
(40_GUARDRAILS_ARCH §5.3); no `app_router.dart` edit is required for JM-020 since
the route exists — this is purely a heads-up to the JM-021 owner. cites:
60_W0_TEST_PLAN §2.10 + nav matrix (JM-020→JM-021), 42_GUARDRAILS_MOCK W-1 FLOOR.

---

## JM-019 — Social/Email Collision Prompt sheet (W0 engineer)

### l10n KEY REQUEST — no new keys; OWNS the `social_collision_sheet`, shares JM-008's `socialCollision*` set
`lib/features/auth/presentation/social_collision_sheet.dart` is the **owner** of
the `social_collision_sheet` widget. The JM-008 sign-up screen and the JM-018
social flow merely *invoke* `SocialCollisionSheet.show(context)` on their 409
paths. The sheet ships now reusing exactly the getters the JM-008 row above
already recorded — body `signupEmailCollision`, continue CTA `loginContinueCta`
("Sign in" -> /login), other-email CTA `recoverSignupLink` ("Create an account"
-> sign-up). No keys beyond the `socialCollisionTitle/Body/ContinueCta/`
`OtherEmailCta` set JM-008 already requested. When the integrator lands those,
swap the three reused getters in `social_collision_sheet.dart`. Maestro keys on
the identifiers (`social_collision_sheet`, `social_collision_continue_cta`,
`social_collision_other_email_cta`), never the text, so this is copy-polish only.

### No ROUTE / EDGE / DI request
The collision prompt is a sheet, not a route (40_GUARDRAILS_ARCH section 5), so
no `GoRoute` is needed. Its two exits target the already-registered `login` and
`sign-up` routes (integrator W0-INT batch) via `context.goNamed(...)` inside the
sheet's own `show()` -- no shared-file edit. The sheet has no async surface, so
no DI registration. Nothing blocked. Cites: JM-019, 60_W0_TEST_PLAN section 2.8 +
Nav-Matrix rows jm-019, D22.

---

## JM-009 — Phone OTP Verification (W0-A engineer)

> No ROUTE request: per 50_EXECUTION_PLAN §"Re-parent (no new route)", phone-OTP
> stays inside `/register` (the reused verify step). No DI request: the OTP path
> is already wired — `injection_container.dart:82` registers
> `OtpService -> DioOtpService(sl<Dio>(), sl<AuthTokenStore>())`, which posts the
> W-1 FLOOR `/v1/auth/otp/request` + `/v1/auth/otp/verify` (B1 rewrite → :4010,
> 6-digit `123456` per B4). No l10n request: the screen reuses the existing
> `registrationOtp*` getters. Only the two heads-ups below.

### SHELL-TAB ID GAP (integrator / S3 owner) — `shell_tab_requests` not yet exposed
JM-009 AC1 + Nav-Matrix row jm-009 assert the verify-success destination is
`shell_tab_requests` (60_W0_TEST_PLAN §2.12). The OTP screen routes there
correctly (`context.go('/')` → role-aware `ShellScreen`, client tab index 0 =
Requests), BUT `lib/features/shell/shell_screen.dart` `_BarItem` currently keys
its bottom-nav Semantics as the legacy leading-underscore
`_request_empty_state_nav_${tab.id}` (e.g. `_request_empty_state_nav_requests`),
NOT the contract `shell_tab_<id>`. Per 41_GUARDRAILS_TESTING §1.1 new ids must be
bare `shell_tab_requests` / `shell_tab_delivery` / `shell_tab_profile` /
`shell_tab_dashboard` / `shell_tab_earnings`; the underscore form is grandfathered
"until its screen is reworked." `shell_screen.dart` is an S3 integrator-owned file
(50_EXECUTION_PLAN §1), so I did NOT edit it. REQUEST: the W1-INT (or a W0 S3
touch-up) integrator migrates the tab Semantics id to `shell_tab_<tab.id>` so the
jm-009 (and jm-005/006/007) verify-destination assertions go green. Until then the
nav leg is honest-but-unassertable on the destination id (AP-9). Cites: JM-009 AC1,
60_W0_TEST_PLAN §2.12 + Nav-Matrix jm-009, 41_GUARDRAILS_TESTING §1.1.

### DEV-SEAM KEY REQUEST — `jeeb.seam.otp_code`, `jeeb.seam.otp_countdown_expired`
60_W0_TEST_PLAN §6 lists `jeeb.seam.otp_code: "123456"` (auto-accept code) and
`jeeb.seam.otp_countdown_expired: "true"` (force resend countdown to 0 so
`phone_otp_resend_cta` is immediately tappable). `dev_seam_config.dart` does not
yet model these fields (same family as JM-008's `jeeb.seam.signup_collision`
request above) — this is dev-flavor seam infrastructure (60_W0_TEST_PLAN §6),
not a feature file. Impact is bounded:
  - `otp_code`: the mock already fixes the dev OTP to the 6-digit `123456` (B4,
    W-1 FLOOR), so jm-009 AC1 is satisfiable against the live mock with the
    default code — the seam is only a convenience override.
  - `otp_countdown_expired`: WITHOUT it, jm-009 AC2 (resend) must wait out the
    60s `RegistrationAttemptPolicy.resendCooldown` before `phone_otp_resend_cta`
    mounts (the CTA replaces the countdown Text only at 0 — kept conditional to
    preserve the shipped widget tests). REQUEST: when the seam infra grows an
    OTP-countdown field, the `RegistrationCubit`/host should seed
    `resendSecondsRemaining = 0` on that seam so AC2 is fast + deterministic.
Cites: 60_W0_TEST_PLAN §6, JM-009 AC2, dev_seam_config.dart.

---

## JM-007 — Login (W0-A engineer)

### l10n KEY REQUEST (REQUIRED — build is red until landed) — `socialContinueWithFacebook`
The login screen renders three social CTAs (`login_social_google`,
`login_social_facebook`, `login_social_apple`). Google/Apple reuse the existing
locale-safe `registrationContinueWithGoogle` / `registrationContinueWithApple`.
The Facebook CTA uses **`l10n.socialContinueWithFacebook`** — the SAME getter the
parallel **JM-018** work already hard-depends on in the shared
`lib/features/auth/social/social_sign_in_button.dart` (lines 100/105). That key
is **NOT yet in the ARBs** (`grep socialContinueWithFacebook app_localizations.dart`
→ 0), so the build is red across the whole auth feature until the integrator adds
it. I standardized on the JM-018 name (rather than a divergent `loginSocialFacebook`)
so all three social surfaces (login / sign-up / shared button) share one key.

| intended key | proposed EN value | proposed AR value | elements |
|---|---|---|---|
| `socialContinueWithFacebook` | "Continue with Facebook" | "المتابعة عبر فيسبوك" | `login_social_facebook`, `signup_social_facebook`, shared `social_sign_in_button` |

> **Integrator action:** add `socialContinueWithFacebook` to `app_en.arb` +
> `app_ar.arb` (with `@`-description) and the matching getter in
> `app_localizations.dart`. This is the single missing key blocking compile for
> JM-007 / JM-008 / JM-018. Maestro keys on the `login_social_facebook` id, never
> the text, so the exact copy is non-blocking once the key exists.

### NOTE (no JM-007 action) — Facebook provider + social routing are JM-018/B2
`SocialProvider` enum has only `google` / `apple`; the mock social handler 401s
for `facebook` (42_GUARDRAILS_MOCK W-1 FLOOR). Per 50_EXECUTION_PLAN the social
flow is a **native sheet (no route)** owned by **JM-018** (+ mock **B2**). The
login Facebook CTA is present + tappable and launches the OS-mediated
`SocialAuthCubit` via the closest available provider until JM-018 extends the
enum and B2 lands; JM-018 also owns the post-auth routing (success → phone-OTP
G8 / 409 → collision sheet). No route registration is required for JM-007.

### SEAM NOTE (no JM-007 feature-file action) — `jeeb.seam.session` biometric branch
`60_W0_TEST_PLAN §6` lists `jeeb.seam.session: "biometric_enrolled_logged_out"`
(AC6: show `login_biometric_affordance`). `DevSeamConfig` does not yet model a
`session` pre-seed field. The login screen gates the affordance on the persisted
biometric-enrolled preference (`BiometricPreferenceRepositoryImpl.isEnabled()`,
the canonical enrollment signal) plus a constructor `biometricEnrolledOverride`
test seam. AC6 turns green the moment the dev-seam `session` plumbing
(integrator / JM-005 / JM-006) sets that preference for the
`biometric_enrolled_logged_out` seam value. Until then it correctly defaults to
hidden for `logged_out_returning` (AC1–5). **Owner: W0 integrator / JM-005/006.**
Cites: 60_W0_TEST_PLAN §2.3 + §6, JM-007 AC6, D23, CTO-D R-F.

### SHELL-TAB ID GAP (integrator-owned, same as JM-009's note above)
JM-007 AC1 asserts the login-success destination is `shell_tab_requests`. The
login screen routes there correctly (`context.go('/')` → role-aware shell, client
tab 0 = Requests, after session refresh). The destination-id assertion depends on
the `shell_screen.dart` bottom-nav Semantics being migrated from the legacy
`_request_empty_state_nav_requests` to the contract `shell_tab_requests` — already
flagged by the JM-009 owner above. `shell_screen.dart` is S3 integrator-owned; not
edited here. Cites: JM-007 AC1, 60_W0_TEST_PLAN §2.12 + Nav-Matrix jm-007.

---

## JM-005 — Biometric Unlock (W0-A)

### NO ROUTE/DI/L10N REQUEST — all prerequisites already in place
`/lock` (name `biometric-lock`) + `/login` routes, the `BiometricLockCubit`
factory + its deps (`BiometricGateway`, `SharedPrefsPinRepository`,
`BiometricPreferenceRepositoryImpl`), and the three `biometricUnlock*` l10n keys
were all landed by the W0 integrator. JM-005 only filled the real cubit behaviour
+ screen body. The screen consumes the **app-level** `BiometricLockCubit` that
`app.dart` provides via `BlocProvider.value` (the SAME instance the router watches
in `refreshListenable`) — NOT a fresh `sl<BiometricLockCubit>()` — so an unlock
actually releases the router gate.

### INLINE DECISION (CTO-D R-F) — biometric unlock is a LOCAL gate, no token refresh
JM-005's "Mock: `POST /auth-service/auth/refresh`" line is NOT exercised by the
AC text (prompt → authenticate → shell; D23 = no OTP). A biometric unlock is a
local re-auth gate over an already-valid session, not a token mint. Calling
`/v1/auth/refresh` on unlock would cross into the session/JWT layer (JM-006's
`SessionCubit` domain) and risk fighting the session gate, so it is intentionally
NOT wired here. `refresh` stays available for JM-006's splash session bootstrap.
Cites: JM-005 AC, D23, CTO-D R-F, 40_GUARDRAILS_ARCH §12 ("don't police a screen's
reachability inside the screen").

### SEAM DEPENDENCY (integrator / JM-006-owned) — `jeeb.seam.session: "biometric_enrolled"`
For the `jm-005` Maestro flow to go GREEN, the `biometric_enrolled` seam value
must (a) make the splash land on `/lock` and (b) auto-approve the platform
biometric. Mapped onto the JM-005 cubit contract that means the seam must set
`BiometricPreferenceRepositoryImpl.isEnabled() == true` (so `evaluate()` emits
`phase == locked` and the router gate holds `/lock`, AC1) AND inject a
`BiometricGateway` whose `authenticate()` returns `true` (so the authenticate CTA
unlocks → `/`, AC2). `DevSeamConfig` does not yet model a `session` pre-seed field
and the DI default is `UnavailableBiometricGateway` (returns false) + the
preference stub (returns false), so without that seam plumbing `evaluate()`
correctly degrades to `disabled` (no `/lock`) and a real `authenticate()` would
fail. The cubit/screen are coded to the `BiometricGateway` + preference contract;
whichever gateway/preference the seam injects flows correctly. **Owner: W0
integrator / JM-006** (dev-seam `session` plumbing). Cites: 60_W0_TEST_PLAN §6,
JM-005 AC1–3, JM-006, D23.

---

## JM-018 — Social Login (W0-B engineer)

> JM-018 extends `lib/features/auth/social/` (FB+Google+Apple) and wires the
> post-auth routing on the login (JM-007) + sign-up (JM-008) screens — the hooks
> those screens explicitly left for JM-018. No new route, no new DI, no SHARED
> file edit beyond the two requests below. Nothing blocks compile (StaticGreen
> stays green) — both requests are additive/cosmetic.

### L10N KEY REQUEST (POLISH ONLY — NOT compile-blocking) — `socialContinueWithFacebook`

The Facebook CTA's VISIBLE label currently reuses the existing locale-safe
`actionContinue` ("Continue") on all three surfaces (login `_SocialRow`, sign-up
`_SocialButton`, shared `social_sign_in_button.dart`) so the build is GREEN today
with no new ARB key. Maestro keys on the `*_social_facebook` identifier, never the
text, so this is pure copy-polish. Requesting a dedicated key so a polish pass can
de-overload "Continue":

| intended key | proposed EN | proposed AR | elements (swap from `actionContinue`) |
|---|---|---|---|
| `socialContinueWithFacebook` | "Continue with Facebook" | "المتابعة عبر فيسبوك" | `login_social_facebook`, `signup_social_facebook`, shared `social_sign_in_button` |

> Supersedes the earlier JM-007 note that called this key "REQUIRED — build red":
> the shared button + login screen now reference `actionContinue`, so the key is
> optional polish, not a compile gate. Swap the three `l10n.actionContinue`
> Facebook-label call sites to `l10n.socialContinueWithFacebook` once the
> integrator lands it.

### SEAM CONTRACT GAP (foundation / dev-flavor seam infra — 60_W0_TEST_PLAN §6)

`jeeb.seam.social_login` (`facebook_no_phone`, `collision_409`) is NOT yet parsed
by `lib/core/dev_seam/dev_seam_config.dart` (it models only
`route|state|locale|home_tab|feed|hold_splash|skip_onboarding`). JM-018 keeps the
seam OUT of its own files via an injectable, debug-only hook on the service:

- `DefaultSocialAuthService` gained an optional
  `SocialAuthSeamResolver? seamResolver`
  (`SocialAuthResult? Function(SocialProvider)`). Default null → always the real
  native-SDK + `/v1/auth/social` path (production unchanged); `kDebugMode`-gated.
- **Request (owner: W0 integrator / Foundation):** when the dev-flavor seam infra
  learns `jeeb.seam.social_login`, pass a resolver at the social-cubit
  construction site (login + sign-up + registration screens) mapping:
  - `facebook_no_phone` → `SocialAuthSuccess(session with phone == null)` (G8 → phone-OTP)
  - `collision_409`      → `SocialAuthFailure(SocialAuthError.collision)` (→ collision sheet)
  This needs **no JM-018 file edit** — only the construction site passes
  `seamResolver:`. ALTERNATIVELY the mock can honor the seam server-side (auto-
  approve `provider:"facebook"` + shape the 200/409). Either satisfies the
  `jm-018-social-login.yaml` ACs. Verified mock today 401s for bare `facebook`
  (42 W-1 FLOOR curl), so one of these two is required for the flow to go GREEN.

### CONTRACT NOTE — `/v1/auth/social` phone field (G8 signal)

The G8 routing keys off `session.hasPhone`. The verified W-1 FLOOR social body is
`{ userId, authToken, refreshToken, expiresIn, recentlyCreated }` and does **not**
document a `phone` field. The parser reads an OPTIONAL `phone`/`phoneNumber`
(null/empty → no phone) so a bundle with no phone → phone-OTP (G8), and a bundle
that DOES carry a phone → straight home. If the mock's social handler should ever
surface a phone for a returning social user, it must include `phone` in the body;
absent it, every social success is treated as "needs phone" (the safe G8 default,
and exactly what the `facebook_no_phone` seam expects). Cites: JM-018 AC1, G8.

---

## JM-029 — Accept Offer Confirmation sheet (W1 engineer)

### l10n KEY REQUEST — dedicated accept-sheet copy currently missing (coded against existing reused keys)

`offer-accept-confirm` (a **sheet, not a route** — `OfferAcceptSheet.show`, no
`app_router.dart` change) ships now reusing the closest **existing** localized
keys, because no dedicated keys exist and the ARB is integrator-owned. Maestro
asserts on `Semantics(identifier:)` only (63 §2.9), so this is cosmetic copy, not
a behavioural gap. Requesting the following dedicated keys (EN + AR, with
`@`-descriptions) so a polish pass can de-overload the reused strings:

| intended key | proposed EN value | currently reused | element (Semantics id) |
|---|---|---|---|
| ~~`offerAcceptTitle`~~ **LANDED** | "Accept {name}'s offer?" / "هل تريد قبول عرض {name}؟" | ~~`chatSystemOfferAcceptedNamed`~~ — the reuse was NOT cosmetic: it put the confirm sheet in the past tense ("…was accepted") above a button still asking the user to confirm | `offer_accept_jeeber_name` |
| `offerAcceptPayCashOnDelivery` | "Pay {amount} {currency} cash on delivery" | `offersCardFee` ("{amount} {currency}") | `offer_accept_price_label` (D11) |
| `offerAcceptOtherOffersClose` | "Accepting this closes all other offers." | `chatOfferAcceptOnlyOne` ("Accept only one offer") | `offer_accept_other_offers_note` (D71) |

> The confirm CTA reuses `chatOfferAccept` ("Accept Offer") / `chatOfferAccepting`
> ("Accepting…") and the cancel CTA reuses `actionCancel` ("Cancel") — all already
> present in both locales, semantically exact, no de-overload needed.

### CONTRACT NOTE — accept response must carry `conversationId` (order-chat target)

JM-029 AC2: confirm captures the fee, closes losers, and routes to `order-chat`.
The mock `POST /v1/offers/:offerId/accept` already returns
`{ offer, handoverCode, conversationId, conversationPhase }` (offer-service.ts) —
verified. The app's `OfferAcceptResult` (client_offers/domain) was extended to
parse `conversationId` (+ snake_case `conversation_id`) alongside the existing
`deliveryId`; the sheet navigates `goNamed('chat-detail', pathParameters: {'id':
conversationId})`, falling back to `requestId` when the gateway omits it
(`ChatDetailScreen` resolves either via `by-request`). No router/DI change needed —
`chat-detail` (`/chat/:id`) is already registered and `OffersRepository` is already
DI-bound (DioOffersRepository) by the W1 integrator. Cites: JM-029 AC2, D11/D71,
40_GUARDRAILS_ARCH §4 (defensive parse).

---

## JM-030 — Cancel Request Confirm sheet (pre-accept, free) [D69] (W1 engineer)

Feature: `lib/features/cancel_request/` (NEW; clean-arch data/domain/application/
presentation). The cancel-confirm is a **modal bottom sheet, not a route**
(40_GUARDRAILS_ARCH §5) — `CancelRequestSheet.show(context, requestId:)`. It is
invoked by the JM-026 waiting screen (`waiting_cancel_cta`) and the JM-028 offer
review screen (`offer_review_cancel_cta`); both are separate W1 engineers. On
confirm it routes to `customer-orders-home` via `context.go('/')` (already
registered root). **No GoRoute request.**

### DI REQUEST — register `CancelRequestRepository`
`injection_container.dart`, in the W1 batch:
```dart
// JM-030: pre-accept cancel (free, D69). POST /v1/delivery/cancel (gateway path).
sl.registerLazySingleton<CancelRequestRepository>(
  () => DioCancelRequestRepository(sl<Dio>()),
);
```
- imports: `package:jeeb_mobile/features/cancel_request/domain/cancel_request_repository.dart`
  + `.../data/dio_cancel_request_repository.dart`.
- The sheet self-resolves `sl<CancelRequestRepository>()` (with a constructor
  test seam + a `FakeCancelRequestRepository` defensive fallback), so it renders
  even before the DI line lands — but the live POST to `:4010` needs this
  registration.

### l10n KEY REQUEST (REQUIRED — feature file is red until landed) — `cancelRequest*`
No existing ARB key carries the D69 "free before accept, nothing charged" copy
(`deliveryCancelDialogBody` says the OPPOSITE — "fees may apply" — so it is NOT a
safe reuse). The sheet references these **intended getters**; add them to
`app_en.arb` + `app_ar.arb` (with `@`-descriptions) and the matching getters in
`app_localizations.dart` (the hand-authored layer). Maestro keys on the
identifiers, never the text, so the exact strings are non-blocking once the keys
exist; the names are the compile gate.

| intended key | proposed EN value | element / id |
|---|---|---|
| `cancelRequestTitle` | "Cancel this request?" | sheet heading |
| `cancelRequestFreeNote` | "It's free to cancel before you accept an offer — nothing will be charged." | `cancel_request_free_note` (D69, load-bearing) |
| `cancelRequestConfirmCta` | "Cancel request" | `cancel_request_confirm_cta` → customer-orders-home |
| `cancelRequestKeepCta` | "Keep my request" | `cancel_request_keep_cta` (dismiss) |
| `cancelRequestError` | "Couldn't cancel right now. Check your connection and try again." | `cancel_request_error` (network-only transient; D30) |

Proposed AR: `cancelRequestTitle`="هل تريد إلغاء هذا الطلب؟",
`cancelRequestFreeNote`="الإلغاء مجاني قبل قبول أي عرض — لن يتم خصم أي مبلغ.",
`cancelRequestConfirmCta`="إلغاء الطلب", `cancelRequestKeepCta`="الاحتفاظ بطلبي",
`cancelRequestError`="تعذّر الإلغاء الآن. تحقّق من اتصالك وحاول مجددًا.".

### EDGE REQUEST(S) — inbound (owned by the SOURCE-screen engineers, not router)
These touch the source feature files (not `app_router.dart`), but are recorded
here so the W1 integrator can confirm the two callers wire them:
```
EDGE — JM-026 (waiting-no-coverage) → JM-030
  control: waiting_cancel_cta
  call:    CancelRequestSheet.show(context, requestId: <pending requestId>)
EDGE — JM-028 (offer-review-list) → JM-030
  control: offer_review_cancel_cta
  call:    CancelRequestSheet.show(context, requestId: <requestId>)
```
The sheet itself owns its terminal edge (`cancel_request_confirm_cta` →
`context.go('/')` = customer-orders-home; `cancel_request_keep_cta` → pop).

### CONTRACT GAP — `POST /v1/delivery/cancel` is delivery-keyed, but pre-accept has no delivery
`delivery-service.ts` `POST /v1/delivery/cancel` (l.204) requires a `deliveryId`
and enforces the SM-1 state machine; a **pending request has no delivery yet** (a
delivery is only created on offer-accept). So a pre-accept cancel:
  - with a `requestId`-only body → **404 `not_found`**;
  - even if a deliveryId existed, a non-`{Ordered,Picked,InTransit}` state → **422
    `transition_not_allowed`**.
Per D69 the pre-accept cancel is **free and always allowed**, so the app treats
404/422 from this endpoint as a benign no-op (releases the request client-side,
routes home) and only blocks on a hard transport (network) error. This keeps the
JM-030 ACs green against the current mock, but the proper backend contract is a
**request-aware cancel** (e.g. `POST /delivery-service/v1/requests/:requestId/cancel`
or accept `requestId` in `/v1/delivery/cancel` and flip the *request* to
`cancelled`) returning 200 with no fee. **Owner: backenders** (additive; tracked
alongside the W1 journey seam — the `pending_request` seed creates a pending
request but no cancellable delivery). Cites: JM-030 AC, D69, 42_GUARDRAILS_MOCK §4.

### EDGE NOTE — how JM-028 (offer-review-list) opens the JM-029 sheet

`OfferAcceptSheet` is a **sheet, not a route** (no `app_router.dart` edge). The
JM-028 engineer wires `offer_card_<id>_accept_cta` (and JM-027's
`replies_accept_cta`) to open it instead of firing inline accept:

```dart
// in client_offers_screen.dart's onAccept(offer) callback (JM-028 call site):
OfferAcceptSheet.show(
  context,
  offer: offer,          // the chosen Offer (name/fee/currency/id come from it)
  requestId: requestId,  // the parent request id the screen already holds
);
// show() owns: confirm → POST /v1/offers/:id/accept (fee captured, losers
// closed) → goNamed('chat-detail', {'id': conversationId ?? requestId});
// cancel → pop back to offer_review_list_root. No extra wiring needed.
```

The inline `ClientOffersCubit.acceptOffer` accept path is now superseded by the
sheet for the customer journey (D11/D71 comprehension gate); the JM-028 engineer
repoints the CTA. `OfferAcceptSheet` self-provides its `OfferAcceptCubit` over
`sl<OffersRepository>()` (constructor `repository:` override for tests), so no DI
change is required. Cites: JM-028 AC2, JM-027 AC, JM-029, 63 §3 nav matrix
(`offer_card_0_accept_cta`/`replies_accept_cta` → `offer_accept_sheet`).

---

## JM-035 — Customer Profile tab (W1 engineer)

`CustomerProfileScreen` (lib/features/customer_profile/) is the real Profile tab
body. It is mounted by the shell (integrator-owned `shell_screen.dart`, already
landed) wrapped in `_HeaderedTab`, which overlays `ShellHeaderActions` (the
shell-owned `customer_profile_wallet_chip` + `customer_profile_bell`). The screen
therefore deliberately does NOT render those two ids (no duplicates) and renders
no app bar / back button (it is a tab body). The constructor signature stays
`CustomerProfileScreen({required data, repository})` — the shell's `const
CustomerProfileScreen(data: DevCustomerProfileFixtures.sample)` call still
compiles (the new `repository` is an optional test seam).

### DI NOTE — repo is SELF-PROVIDED over `sl<Dio>()`; no `injection_container.dart` edit
Per 40_GUARDRAILS §5.4 (screen self-provides) the screen resolves
`DioCustomerProfileRepository(sl<Dio>())` itself when GetIt is configured, and
falls back to fixture-only (null repo, no network) when it is not (bare widget
tests / `w1_routes_resolve_test`). It calls `GET /users/me` (the JM-035 AC's
named endpoint; `MockGatewayClient` rewrites `/users` → `/user-management/users`
→ :4010). No new DI registration is requested. A constructor `repository:`
override is exposed for tests.

### EDGE REQUESTS — the 8 rows (63 §2.15 / §3 nav matrix)
Rows whose target route is REGISTERED today are wired honestly in the feature
file (no shared-file edit):

| control (id) | call | target (registered) |
|---|---|---|
| `customer_profile_register_delivery_row` | `goNamed('jeeber-onboarding')` | `jeeber-onboarding` (`/jeeber/onboarding` → `DmOnboardingScreen`) |
| `customer_profile_notifications_row` | `goNamed('settings-notifications')` | `settings-notifications` (`/settings/notifications` → real `NotificationPreferencesScreen`) |
| `customer_profile_addresses_row` | `goNamed('settings-addresses')` | `settings-addresses` (`/settings/addresses` → real `SavedLocationsScreen`, `saved_address_add_cta`) |

The remaining rows target W4 screens (or a native sheet) NOT yet registered, so
they are GUARDED coming-soon (AP-9: tap accepted via a `shellComingSoon`
SnackBar, tab root survives) — they must NOT `goNamed` an unregistered name
(nav honesty, CTO brief §6.7). Each carries a `// TODO(JM-0NN)` swap-in marker:

| control (id) | swap-in when route lands | JM (wave) |
|---|---|---|
| `customer_profile_password_row` | `goNamed('password-security')` | JM-061 (W4) |
| `customer_profile_language_row` | `goNamed('language-settings')` | JM-059 (W4) |
| `customer_profile_contact_row` | `goNamed('support-ticket')` | JM-063 (W4) |
| `customer_profile_rate_app_row` | native store-review sheet (`in_app_review`) | JM-064 (W4) |
| `customer_profile_logout_row` | logout/delete confirm → `splash` | JM-062 (W4) |

> ROUTE REQUESTS for the W4 integrator (so the TODOs can be swapped, and the
> 63 §3 destination-id assertions go green): register `password-security`
> (`/settings/password`, JM-061), `language-settings` (`/settings/language`,
> JM-059), `support-ticket` (`/support`, JM-063), and a `logout-delete-account`
> entry (JM-062). `notification-prefs`'s `notif_prefs_back` id (JM-058) and the
> onboarding step-1 `dm_onboarding_continue` id (JM-039) land with those items —
> the leg is honest-but-unassertable-on-destination today (AP-9), exactly as the
> 63 test plan notes ("rows light up as targets land").

### l10n KEY REQUEST — reused existing keys; dedicated `customerProfile*` requested
ARB is integrator-owned, so three rows + the rating chip ship now reusing the
closest EXISTING locale-safe getters. Maestro keys on the identifier, never the
text, so this is copy-polish only. Requesting dedicated keys for a later pass:

| intended key | proposed EN | currently reused | element |
|---|---|---|---|
| `customerProfileLanguage` | "Language" | `settingsLanguage` ("Language") | `customer_profile_language_row` |
| `customerProfileAddresses` | "Saved addresses" | `savedAddressesTitle` ("Saved addresses") | `customer_profile_addresses_row` |
| `customerProfileLogout` | "Log out" | `appBarSignOut` ("Sign out") | `customer_profile_logout_row` |
| `customerProfileRatingSummary` | "{rating} · {count} ratings" | `deliveryManProfileRatingSummary` | `customer_profile_rating` (rated) |
| `customerProfileRatingNew` | "No ratings yet" | `deliveryManProfileEmptyReviewsTitle` | `customer_profile_rating` (cold-start) |

> The register / password / notifications / contact / rate-app rows already have
> dedicated keys (`customerProfileRegisterAsDelivery`, `customerProfilePassword`
> `Security`, `customerProfileNotification`, `customerProfileContactUs`,
> `customerProfileRateApp`) — reused as-is. Cites: JM-035 AC1/AC2, 63 §2.15, D6.

---

## JM-026 — Waiting / No-Coverage state (W1 engineer)

### DI REGISTRATION REQUEST — `WaitingRepository` (owner: W1 integrator)
The injection_container §"WAVE 1 (S2)" note explicitly delegates the JM-026
repo registration to this engineer's diff but DI is integrator-owned, so:

```dart
// injection_container.dart, alongside the other W1 Dio repos:
sl.registerLazySingleton<WaitingRepository>(
  () => DioWaitingRepository(sl<Dio>()),
);
```
Types authored in this diff: `lib/features/no_offer_timeout/domain/waiting_repository.dart`
(+ `domain/waiting_request.dart`), `data/dio_waiting_repository.dart`,
`data/fake_waiting_repository.dart`.

**Coded against it in the meantime (no DI edit by me):** the screen's
`_resolveRepository()` mirrors `ClientOffersScreen` — it returns
`sl<WaitingRepository>()` when registered, else constructs
`DioWaitingRepository(sl<Dio>())` directly (real `:4010` Dio, so the screen is
already data-bound today), else a `FakeWaitingRepository` last-resort. Landing
the registration above makes the resolution canonical (no behaviour change).

### l10n KEYS — ADDED in this diff (additive, EN+AR + `@`-descriptions + getters)
Per the integrator note "Per-screen W1 keys remain each JM engineer's to add",
JM-026 added these to `app_en.arb` / `app_ar.arb` + hand-authored getters in
`app_localizations.dart` (all non-sentinel, parity-checked). If the integrator
prefers to re-batch them, the keys are: `waitingTitle`, `waitingCountdownLabel`
(`{time}` placeholder), `waitingNoCoverageTitle`, `waitingNoCoverageBody`,
`waitingReviewOffersCta`, `waitingRetargetCta`, `waitingCancelCta`,
`waitingErrorBody`. The notified-count line reuses the existing i18n-safe plural
`requestSummaryFindingNotifiedCount(int)`; title reuses `requestSummaryFindingTitle`.

### ROUTE PARAM REQUEST — retarget content reuse (D48), P2 polish
`waiting_retarget_cta` routes `context.pushNamed('request-type')` (honest;
satisfies the AC3 `request_type_continue_cta` assertion). D48 wants the original
request content **pre-filled** on re-target, but the `request-type` route takes
no seed param. Requesting either a `?from=:requestId` query param on
`/request-type` (the screen reads it and pre-loads the prior draft) or an `extra:`
RequestDraft hand-off. Until then re-target re-enters the tier picker fresh —
behavioural ACs (count/countdown/no-coverage/review/cancel) are unaffected.

Cites: JM-026 AC1–AC4, 63 §2.6, 40_GUARDRAILS_ARCH §9, D48, D69.

---

## JM-027 — Replies sub-tab CTAs (W1-B engineer)

### EDGE REQUEST (blocked on JM-029) — `replies_accept_cta` → `offer_accept_sheet`
```
EDGE REQUEST — JM-027
  from:    my-orders Replies sub-tab (lib/features/home_client/.../tabs/replies_tab.dart)
  to:      offer-accept-confirm SHEET (offer_accept_sheet) — JM-029, NOT a route (21_NAV_PLAN §117)
  control: replies_accept_cta  (on each RepliesCard)
  call:    onAccept(request) → OfferAcceptSheet.show(context, requestId: request.id)   [intended]
  cites:   21_NAV_PLAN.md §185 (my-orders → offer-accept-confirm), 63 §2.7 + §3 (jm-027 AC2),
           JM-029, D11, D71
```
- **Status:** BLOCKED on JM-029. The `OfferAcceptSheet` (`offer_accept_sheet`) is a sibling W1-B
  leaf that has not landed (no `OfferAcceptSheet` symbol exists in `lib/` yet). Per
  40_GUARDRAILS_ARCH §9 + CTO-D R-F (code against the intended target, never wire a call site to a
  symbol that does not compile, never stall): `RepliesTab` exposes an injectable
  `onAccept(ClientHomeRequest)` callback. Its **interim default** routes to the registered
  `offer-review` route (`/requests/:id/offers`) — where JM-028's `offer_card_<id>_accept_cta` opens
  the very same JM-029 sheet — so the nav is honest today (no dishonest `goNamed` to a missing
  target). The jm-027 AC2 Maestro assertion (`offer_accept_sheet` visible directly off
  `replies_accept_cta`) stays RED until JM-029 ships, exactly as 63_W1_TEST_PLAN §6 declares.
- **Wire-up when JM-029 lands (integrator / JM-029 owner, no JM-027 file edit needed):** pass
  `onAccept:` into `RepliesTab` from the host (`shell/tabs/home_tab.dart` →
  `ClientHomeScreen` → Replies case) so it calls `OfferAcceptSheet.show(context, requestId: ...)`
  (or a per-offer variant). The `onAccept` seam already exists on `RepliesTab` /
  `_RepliesContent` / `_RepliesList` / `RepliesCard`, so only the construction site changes.
- **`replies_check_offers_cta` → `offer-review` is already wired** (no request): `RepliesTab`'s
  default `pushNamed('offer-review', pathParameters: {'id': request.id})` targets the
  integrator-registered `offer-review` route — JM-027 AC1 is satisfiable today against the
  `offers_received` seam (the seam seeds `req-client-001-offers`).

### No l10n / DI / route request
The Accept CTA reuses the existing locale-safe `offersCardAccept` ("Accept" / EN+AR present); Check
Offers reuses `homeRepliesCheckOffersCta`. No new ARB key. JM-027 binds no new repository (the
Replies list is already served by the home-client repo over `/v1/requests`, rewritten to
`/delivery-service/v1/requests` by `MockGatewayClient`); the offer-review route self-provides its
cubit over `sl<OffersRepository>()` (integrator-bound). No `app_router.dart` edit: `offer-review`
exists; the two sheets are `showModalBottomSheet` (no route). Cites: JM-027, 63 §2.7, D82, D11.

---

## JM-025 — Order Chat (compose=broadcast, pinned summary, dispute link) (W1-A engineer)

JM-025 touches ONLY its own feature files — `lib/features/chat/**` (presentation/data/domain) and
the `/chat/:id` deep-link target `lib/features/deep_link_targets/chat_detail_screen.dart`. No
`app_router.dart`, `injection_container.dart`, `shell_screen.dart`, or ARB edit was made. All three
edges target routes the W1 integrator already registered.

### EDGES — all wired in `chat_detail_screen.dart` (no request; routes already exist)
```
EDGE — JM-025 AC1 (compose → broadcast → waiting)
  from:    order-chat (compose state, client)
  to:      waiting-no-coverage           # /requests/:id/waiting  (REGISTERED)
  control: order_chat_composer_send       # first message broadcasts the request
  call:    context.goNamed('waiting-no-coverage', pathParameters: {'id': <reqId>})
  cites:   21_NAV_PLAN §C, 63 §3 (jm-025), JM-026, D83

EDGE — JM-025 AC2 (pinned summary → order-summary)
  from:    order-chat (accepted, client)
  to:      order-summary                  # /orders/:id/summary    (REGISTERED, JM-031 stub)
  control: order_chat_view_summary_link
  call:    context.pushNamed('order-summary', pathParameters: {'id': <deliveryId>})
  cites:   21_NAV_PLAN §C, 63 §2.5/§3 (jm-025 AC2), JM-031, D71, D11

EDGE — JM-025 AC3 (active order → dispute)
  from:    order-chat (accepted/active, client)
  to:      escalate (== dispute-open-evidence)   # /orders/:id/escalate  (REGISTERED)
  control: order_chat_open_dispute
  call:    context.pushNamed('escalate', pathParameters: {'id': <deliveryId>})
  cites:   20_GAP_MAP reconciliation note 8 (escalate IS dispute-open-evidence), JM-060, D53
```

### l10n KEY REQUEST — dedicated copy currently missing (coded against existing reused keys)
The order-chat pinned summary strip + view link ship now using the closest **existing** localized
keys (no dedicated keys exist; ARB is integrator-owned). Maestro asserts on `Semantics(identifier:)`
only (R-B), so this is cosmetic copy, not a behavioural gap. Requesting (EN + AR, with
`@`-descriptions):

| intended key | proposed EN value | currently reused (getter) | element / id |
|---|---|---|---|
| `orderChatViewSummaryLink` | "View summary" | `orderSummaryTitle` ("Order summary") | `order_chat_view_summary_link` |
| `orderChatPayCashOnDelivery` | "Pay cash on delivery" | `orderSummaryTrack` ("Track order") | `order_chat_cash_label` (D11 reminder) |
| `orderChatComposeHint` | "Describe what you need…" | `chatComposerHint` ("Type a message") | compose-state composer hint (optional) |

> The pinned strip's price/ETA/tier/ref labels reuse already-present locale-safe keys:
> tier → `tierSelectionTier{Flash,Express,Standard,OnTheWay,Eco}`, ETA → `deliveryEtaMinutes`,
> ref → the raw `displayId` (no localization), summary heading → `orderSummaryTitle`. The dispute
> app-bar action reuses `escalateTitle` ("Report an Issue") for its tooltip + a11y label.

### DI — NONE (no `injection_container.dart` edit)
Per 40_GUARDRAILS_ARCH §1 (the screen layer is the only place allowed to touch `sl`), the two new
JM-025 repos/services are **self-provided by `chat_detail_screen.dart`** over the route-scoped
`sl<Dio>()` (the SAME pattern the screen already used for `DioChatGateway`), so no shared-DI edit
is needed:
- `OrderChatSummaryRepository` → `DioOrderChatSummaryRepository(dio)` — pinned-summary fetch
  (`GET /v1/delivery/:id`, `GET /v1/requests/:id`, `GET /v1/offers?requestId=`).
- `OrderBroadcastService` → `DioOrderBroadcastService(dio)` — compose→broadcast
  (`POST /v1/matching/find-jeebers`, `POST /v1/matching/broadcast`).

> If the W1 integrator prefers these registered in DI for consistency, the abstract types live in
> `lib/features/chat/domain/{order_chat_summary,order_broadcast_service}.dart` and the Dio impls in
> `lib/features/chat/data/`; a `registerLazySingleton<…>(() => Dio…(sl<Dio>()))` pair would let
> `chat_detail_screen.dart` resolve `sl<T>()` instead of constructing inline. Optional, not required.

---

## JM-031 — Order Summary + Pinned Price widget (W1-B engineer)

JM-031 ships the **reusable `OrderSummaryPinned` header widget** (CTO-D3 primary
rendering) + the real **`/orders/:id/summary`** standalone screen (deep-link
target for JM-056). Files: `lib/features/order_summary/{domain,data,application,
presentation}/…`. The integrator's `OrderSummaryScreen` stub body was replaced
with the real data-driven screen (same file, same route — no `app_router.dart`
edit).

### DI REGISTRATION REQUEST — `OrderSummaryRepository` → `DioOrderSummaryRepository`
The standalone screen + any host that wants the data-bound widget resolves
`sl<OrderSummaryRepository>()`. Please register (W1 DI batch, tagged JM-031):

```dart
// JM-031: order-summary pinned widget + /orders/:id/summary deep-link target.
// Reads GET /v1/delivery/:id (+ best-effort /v1/requests/:id, /v1/offers,
// /users/:id) via the real Dio (MockGatewayClient → :4010).
sl.registerLazySingleton<OrderSummaryRepository>(
  () => DioOrderSummaryRepository(sl<Dio>()),
);
```
Until then the screen falls back to `FakeOrderSummaryRepository` (constructor
seam, never DI), so it compiles + renders a representative summary today; the
data-bound AC validates once the registration lands. No new endpoint — the
delivery/request/offer/user routes all exist on `:4010` and rewrite cleanly.

### l10n KEY REQUEST — dedicated copy currently missing (coded against reused keys)
The integrator batched `orderSummaryTitle` / `orderSummaryOpenChat` /
`orderSummaryTrack`. The field-label + cash-reminder strings are not yet present.
Per the JM-008 precedent, `OrderSummaryPinned` ships now via a feature-local
EN/AR resolver (`order_summary_l10n.dart`) that reuses EXISTING locale-safe
getters where one fits and supplies the rest from a local map. Maestro asserts
on `Semantics(identifier:)` only, so this is cosmetic copy. Requesting (EN+AR,
`@`-described) so the resolver can be deleted:

| intended key | proposed EN value | currently | element |
|---|---|---|---|
| `orderSummaryPriceLabel` | "Price" | local "Price"/"السعر" | `order_summary_price` label |
| `orderSummaryCashLabel` | "Pay cash on delivery" | local "Pay cash on delivery"/"ادفع نقداً عند التسليم" | `order_summary_cash_label` (D11) |
| `orderSummaryEtaLabel` | "ETA" | reused `trackingEtaLabel` | `order_summary_eta` label |
| `orderSummaryEtaMinutes` | "{minutes} min" | reused `trackingEtaMinutes` | ETA value |
| `orderSummaryEtaPending` | "ETA pending" | local "ETA pending"/"الوقت المقدّر قيد التحديد" | ETA placeholder |
| `orderSummaryTierLabel` | "Tier" | reused `deliveryTierLabel` | `order_summary_tier` label |
| `orderSummaryItemLabel` | "Item" | local "Item"/"الطلب" | item line label |

(Tier display names reuse the existing `tierSelectionTier{Flash,Express,…}`
getters; generic error reuses `requestSummaryErrorGeneric`; retry reuses
`trackingGpsLostRetry` — all present in both ARBs.)

### CONTRACT GAP / EDGE REQUEST — JM-025 (chat) + JM-032 (tracking) must render `OrderSummaryPinned`
**This is the load-bearing one (JM-031 AC4 + 63 §2.11 nav matrix).** The
`jm-031` Maestro flow waits for `order_chat_pinned_summary` (chat) / `tracking_stepper`
(tracking), then asserts the **`order_summary_*`** family
(`order_summary_pinned`, `_price`, `_jeeber_name`, `_eta`, `_tier`,
`_cash_label`, and the CTAs `_open_chat` / `_track`) IN BOTH contexts.

- **Chat (JM-025):** `lib/features/chat/presentation/widgets/order_chat_pinned_summary.dart`
  currently renders its OWN strip exposing `order_chat_pinned_summary` +
  `order_chat_view_summary_link` + `order_chat_cash_label` — it does **NOT**
  expose `order_summary_pinned` / `order_summary_price` / `order_summary_jeeber_name`
  / `order_summary_eta` / `order_summary_tier` / `order_summary_cash_label`. So
  the jm-031 AC1 assertions FAIL on the chat screen as-is.
- **Tracking (JM-032):** `live_tracking_screen.dart` mounts no `order_summary_pinned`
  yet (its `DeliveryTrackingInfo` was extended with price/tier/jeeber/item to
  drive it, but no widget carries the id). jm-031 AC3/AC4 FAIL on tracking as-is.

**Resolution (no JM-031 file edit — these are JM-025/JM-032 host edits):** have
each host render the shared `OrderSummaryPinned`
(`lib/features/order_summary/presentation/widgets/order_summary_pinned.dart`)
mapping its already-resolved data into the `OrderSummary` value object, so the
`order_summary_*` ids are co-present with `order_chat_pinned_summary` /
`tracking_stepper`. The widget is a dumb data-in/callbacks-out OMDS strip
(`dense: true` for the header injection); the chat host passes `onTrack` →
`/orders/:id/tracking` (and null `onOpenChat`, already on chat), the tracking
host passes `onOpenChat` → `/chat/:id` (and null `onTrack`, already on tracking).
Mapping helper to add (in the host, ~6 lines):
```dart
OrderSummary(
  deliveryId: …, requestId: …, conversationId: …,
  price: …, currency: …, jeeberName: …, tier: …,
  jeeberRating: …, jeeberRatingCount: …, etaMinutes: …, itemSummary: …,
);
```
Alternatively (if hosts keep their own strips) they add the `order_summary_*`
ids alongside their `order_chat_*` / stepper ids. Either way the ids must
co-exist or QA re-points the jm-031 flow to assert the `order_chat_*` family on
chat — escalated as a QA/JM-025/JM-032 reconciliation, NOT a JM-031 fix.
Cites: 63 §2.11 + §3 (jm-031 nav matrix), JM-031 AC4, CTO-D3, D11/D71/D6.

---

## JM-028 — Offer Review (offer-review-list engineer)

### l10n KEY NOTE — keys landed in-diff (per W1 "each JM engineer adds their own keys")
JM-028 added to BOTH ARBs + the hand-authored `app_localizations.dart`:
- `offerCardCashOnDelivery` ("Pay {amount} {currency} cash on delivery") — the
  D11 cash-on-delivery line on each offer card (`offer_card_<id>_cash_on_delivery_label`).
- `offerReviewCancelCta` ("Cancel request") — the `offer_review_cancel_cta`.

I also had to add **`cancelRequestFreeNote`** (the JM-030 cancel-sheet body,
`cancel_request_free_note`, D69). The already-committed
`lib/features/cancel_request/presentation/cancel_request_sheet.dart` references
`l10n.cancelRequestFreeNote`, but the key was never landed in either ARB or the
getter layer — so the WHOLE app failed to compile (`flutter test`/`analyze` red).
Since JM-028 invokes `CancelRequestSheet.show`, I added the one missing key to
restore green. **Ownership stays with JM-030** — if that engineer prefers
different copy, edit the value (not the key) so the offer-review wiring is
unaffected.

### EDGE — offer_card name → jeeber-profile-reviews: ID MISMATCH to reconcile (JM-067)
`offer_card_<id>_name` calls `context.pushNamed('delivery-man-profile', extra:
DeliveryManProfileViewData(...))` (the registered route; built from the offer's
name/rating/avatar, empty reviews — the target loads reviews via R1m). BUT the
jm-028 Maestro flow (63 §3) asserts the destination id **`profile_view_all_reviews`**,
while the real `DeliveryManProfileScreen` widgets currently expose
**`delivery_man_profile_view_all_reviews`** (+ `delivery_man_profile_close`).
The flow's AC2 assert will FAIL until JM-067 either renames its id to the
plain `profile_view_all_reviews` (matching 63 §2.19 / §3) OR QA re-points the
flow. This is a **JM-067 (W4) id reconciliation**, not a JM-028 fix — flagged
so the integrator/QA align before the W1 suite is graded.

### MOCK — offer-list rows are not name/rating-enriched (backender, O-list-enrich)
`GET /offer-service/v1/offers?requestId=` (the JM-028 list endpoint) returns the
raw offer rows: `{ id, requestId, jeeberId, amount:{value,currency},
price:{value}, etaMinutes, note, status, createdAt }`. It does **NOT** join the
Jeeber's display name / rating / ratingCount (those live only on the chat
`offer_card` message body, per `journey-seed.ts seedOffersReceived`). So the
card currently renders `jeeberName == jeeberId` and a default rating (4.5/0) for
mock data. The repository parses name/rating defensively (so it lights up the
moment the row carries them), but the card copy is only fully honest once the
backender enriches the list row (or the gateway BFF joins user-management).
**Backend work (CTO-D2 / R-A):** enrich each `/v1/offers` row with
`jeeberName`, `rating`, `ratingCount`, `jeeberAvatarUrl`. UI shell + ids are
complete; the data-bound name/rating AC validates once the row is enriched.
Cites: 30_BACKLOG JM-028 mock list (`GET /offer-service/v1/offers?requestId=`),
42_GUARDRAILS_MOCK §1.2, 12_MOCK_INVENTORY (offer-service).

---

## JM-050 — Address Detail Form (W1 engineer, P2)

The real form replaced the integrator stub at
`lib/features/location/presentation/screens/address_detail_form_screen.dart`
(same file, same `address-detail` route — no `app_router.dart` edit). Fields
+ ids per 63 §2.17: `address_form_map_pin`, `address_form_label`,
`address_form_building`, `address_form_floor_apt`, `address_form_delivery_notes`,
`address_form_cod_phone`, `address_form_save_cta` (+ an engineer-added
`address_form_edit_pin_cta`). New feature files (all under the location feature,
my own): `domain/address_form_repository.dart` (abstract +
`AddressFormDraft` + `AddressFormFailure`/exception), `data/dio_address_form_repository.dart`,
`data/fake_address_form_repository.dart`, `application/address_form_cubit.dart`,
`application/address_form_state.dart`, `presentation/screens/address_form_l10n.dart`.
The model `domain/saved_location.dart` gained 4 OPTIONAL fields (`building`,
`floorApt`, `deliveryNotes`, `codPhone`) — backward-compatible (every existing
construction site + JM-049 tests compile unchanged).

### l10n KEY REQUEST — dedicated field-label copy currently missing (feature-local resolver in the meantime)
The integrator batched `addressFormTitle` + `addressFormSaveCta`. The four new
field labels + the pin section have **no ARB key**, and the ARB is
integrator-owned. Per the JM-031 precedent the screen ships now via a
feature-local EN/AR resolver (`address_form_l10n.dart`) and reuses existing
locale-safe getters where one fits (label → `savedAddressLabelLabel` /
`savedAddressLabelHint`; save CTA → `addressFormSaveCta`; save-error toast →
`savedLocationsSaveError`). Maestro keys on the `Semantics(identifier:)`, never
the text, so this is cosmetic copy. Requesting (EN + AR, `@`-described) so the
resolver can be deleted:

| intended key | proposed EN | proposed AR | element (id) |
|---|---|---|---|
| `addressFormBuildingLabel` | "Building" | "المبنى" | `address_form_building` label |
| `addressFormBuildingHint` | "Building name or no." | "اسم أو رقم المبنى" | building hint |
| `addressFormFloorAptLabel` | "Floor / apartment" | "الطابق / الشقة" | `address_form_floor_apt` label |
| `addressFormDeliveryNotesLabel` | "Delivery notes" | "ملاحظات التسليم" | `address_form_delivery_notes` label |
| `addressFormCodPhoneLabel` | "Cash-on-delivery phone" | "هاتف الدفع عند الاستلام" | `address_form_cod_phone` label |
| `addressFormPinSectionTitle` | "Location on the map" | "الموقع على الخريطة" | `address_form_map_pin` section title |
| `addressFormEditPinCta` | "Edit pin" | "تعديل الدبوس" | `address_form_edit_pin_cta` |

### NO DI REQUEST — repo SELF-PROVIDED over `sl<Dio>()` (40_GUARDRAILS_ARCH §5.4)
The screen resolves `DioAddressFormRepository(sl<Dio>())` itself (JM-025/JM-031
self-provide pattern), with a `repository:` constructor test seam and a
`FakeAddressFormRepository` fallback so the `address-detail` route mounts even
with no Dio registered (`w1_routes_resolve_test`). No
`injection_container.dart` edit. If the integrator prefers it registered:
```dart
// JM-050: address-detail-form save (POST/PUT /users/:userId/saved-locations).
sl.registerLazySingleton<AddressFormRepository>(
  () => DioAddressFormRepository(sl<Dio>()),
);
```

### EDGE NOTE — save → `settings-addresses` (already registered; no request)
`address_form_save_cta` success calls `context.goNamed('settings-addresses')`
(the integrator-registered JM-049 manager). Honest today.

### ROUTE/EDGE REQUEST (P3 polish, optional) — forward the edited address via `extra` for the edit path
The `address-detail` route builder forwards only `?id=` (`addressId`). The
screen ALSO accepts an optional `existing` `SavedLocation` (constructor param,
defaults null) to pre-fill the EDIT path. To populate it, JM-049's
`saved_address_<n>_edit` CTA would `goNamed('address-detail', queryParameters:
{'id': loc.id}, extra: loc)` and the router builder would read
`state.extra is SavedLocation ? state.extra as SavedLocation : null`. Until then
the edit path opens with empty fields (the correct `editId` still drives a PUT) —
the add path (the primary P2 AC + jm-050 flow) is unaffected. The screen renders
a graceful empty form when `extra` is absent (40_GUARDRAILS_ARCH §5.3).

### CONTRACT GAP — JM-049 list read path does NOT reach the mock (`/v1/users/me/...` has no rewrite)
**Load-bearing for "list reflects the new address" but NOT for the jm-050 flow.**
The mock POST/PUT/GET saved-locations routes are keyed `:userId`
(`/user-management/users/:userId/saved-locations`). The ONLY gateway rewrite is
`/users` → `/user-management/users` (`mock_gateway_client.dart`); there is **no**
`/v1/users` key. So:
- JM-050's `DioAddressFormRepository` uses `/users/:userId/saved-locations`
  (rewriteable) → the save **reaches the mock** and persists. ✓
- JM-049's `DioSavedLocationRepository` (and the JM-035 profile→addresses leg)
  still speak the legacy `/v1/users/me/saved-locations` (Mockoon :3055 shape) →
  **no rewrite match → never reaches :4010**, so its list is empty/errored
  against the current mock regardless of JM-050.
The jm-050 Maestro flow only asserts `saved_address_add_cta` (the FAB, which
renders independent of the list load) on return, so it passes. But for the
saved-addresses MANAGER to actually SHOW the seeded/just-saved rows, JM-049's
repo must switch to the rewriteable `/users/:userId/saved-locations` form (or the
gateway gain a `/v1/users` → `/user-management/users` rewrite key). **Owner:
JM-049 engineer / W1 integrator** (a one-path-string change in
`dio_saved_location_repository.dart`, or a one-line mock-gateway rewrite key).
Cites: JM-049/JM-050, 42_GUARDRAILS_MOCK §4 (`:userId` saved-locations routes),
`mock_gateway_client.dart` `_pathToServicePrefix`.

### MOCK NOTE — POST spreads `...req.body`, so the new fields persist verbatim (no backend change)
`user-management.ts` `POST /users/:userId/saved-locations` does
`{ id: uuid(), ...req.body, createdAt }`, so `building`/`floorApt`/
`deliveryNotes`/`codPhone`/`isDefault` round-trip unchanged. The
`has_saved_addresses` seam already seeds exactly these field names
(`journey-seed.ts seedHasSavedAddresses`). No backender work for JM-050 save.

---

## JM-033 — Confirm Receipt (Customer) — rewrite (W1 engineer)

### l10n KEY REQUEST (REQUIRED — build is red until landed) — `receipt*` set

The rewritten `delivered-receipt-confirm` screen
(`lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart`) is
the customer-facing prompt; it carries NONE of the old finance-receipt copy
(goods cost / delivery fee / **Commission** — deleted, JM-033 AC4 / D11). No
`receipt*` keys exist in the ARBs (`grep receipt app_localizations.dart` -> 0),
so the whole feature is red until the integrator adds them. Maestro keys on the
`receipt_*` ids, never the text (i18n-safe), so the exact copy is non-blocking
once the keys exist. `receiptCashToJeeber` is a 2-arg method getter (positional
`{amount}` then `{jeeber}`), matching the existing `chatVoiceNoteA11y` pattern.

| intended getter | proposed EN value | proposed AR value | element |
|---|---|---|---|
| `receiptTitle` | "Confirm receipt" | "تأكيد الاستلام" | OMDSAppBar title |
| `receiptPromptHeading` | "Did you receive your order?" | "هل استلمت طلبك؟" | prompt heading (under `receipt_prompt` root) |
| `receiptCashToJeeber` | "Pay {amount} cash to {jeeber}" | "ادفع {amount} نقداً إلى {jeeber}" | `receipt_cash_to_jeeber_label` (D11) |
| `receiptJeeberFallback` | "the Jeeber" | "الجيبر" | name fallback when the gateway omits `jeeberName` |
| `receiptProofPhotoLabel` | "Proof of delivery photo" | "صورة إثبات التسليم" | a11y label on `receipt_proof_photo` (D3) |
| `receiptConfirmCta` | "Yes, I received it" | "نعم، استلمته" | `receipt_confirm_cta` -> rate-jeeber |
| `receiptNotYetCta` | "Not yet" | "ليس بعد" | `receipt_not_yet_cta` -> dispute-open-evidence |
| `receiptRetryAction` | "Retry" | "إعادة المحاولة" | OmdsErrorState retry label |
| `receiptErrorNetwork` | "Couldn't reach the server. Check your connection and try again." | "تعذّر الوصول إلى الخادم. تحقق من اتصالك وحاول مرة أخرى." | network failure (load + confirm) |
| `receiptErrorNotFound` | "We couldn't find this delivery." | "تعذّر العثور على هذا التوصيل." | 404 load failure |
| `receiptErrorTransition` | "We couldn't confirm receipt right now. Please try again." | "تعذّر تأكيد الاستلام الآن. يُرجى المحاولة مرة أخرى." | 422 transition-not-allowed on confirm |
| `receiptErrorGeneric` | "Something went wrong. Please try again." | "حدث خطأ ما. يُرجى المحاولة مرة أخرى." | unknown failure |

> **Integrator action:** add the 12 keys above to `app_en.arb` + `app_ar.arb`
> (each with an `@`-description) and the matching getters in
> `app_localizations.dart` — `receiptCashToJeeber(String amount, String jeeber)`
> as a method getter (`.replaceFirst('{amount}', amount).replaceFirst('{jeeber}',
> jeeber)`), the rest as plain getters. No `receipt_no_commission_line` copy: it
> is a NEGATIVE assertion (AC4) — the screen never renders it.

### DI REQUEST — `DeliveryReceiptRepository`

```
DI REQUEST — JM-033
  interface: DeliveryReceiptRepository
             (lib/features/delivery_receipt/domain/delivery_receipt_repository.dart)
  impl:      DioDeliveryReceiptRepository(sl<Dio>())
             (lib/features/delivery_receipt/data/dio_delivery_receipt_repository.dart)
  register:  sl.registerLazySingleton<DeliveryReceiptRepository>(
               () => DioDeliveryReceiptRepository(sl<Dio>()));  // JM-033
  cites:     40_GUARDRAILS_ARCH section 6, JM-033, D3/D11/D70
```
The repo *type* did not exist when the W1 integrator batch landed (the
integrator note explicitly deferred receipt repo registration to this diff), so
it is not yet bound. **Until the integrator binds it, the screen self-provides**:
it resolves `sl<DeliveryReceiptRepository>()` when registered, else constructs
`DioDeliveryReceiptRepository(sl<Dio>())` directly (the shared Dio is registered
at boot -> real :4010). Binding it in DI is the clean-arch finish; the screen
keeps working either way. `FakeDeliveryReceiptRepository` is a constructor test
seam only — do NOT register it (40_GUARDRAILS_ARCH section 6 DO-NOT).

### EDGE NOTES (no router edit — call sites in this feature file; routes already registered)

- `receipt_confirm_cta` -> **`mutual-rating`** (`/orders/:id/mutual-rate`), the
  registered canonical post-delivery rating terminal (JM-034 reconciles
  `/feedback` vs `/mutual-rate` — mutual is the compliant terminal). Client mode
  is the default (no `?mode=jeeber`). Uses `context.goNamed` (replaces stack) so
  the mandatory rating cannot be backed out of (D56). The `rating_submit_cta` /
  `rating_root` ids the jm-033 flow asserts are owned by JM-034.
- `receipt_not_yet_cta` -> **`escalate`** (`/orders/:id/escalate`), the registered
  `dispute-open-evidence` target (JM-060 extends `EscalateScreen` and exposes
  `dispute_reason`). Uses `context.pushNamed` (non-terminal branch — the customer
  can return to the receipt prompt).
Both routes are ALREADY registered (verified in `app_router.dart` lines 945-976),
so these edges are nav-honest today.
Cites: 63 section 2.13 + 3 (jm-033 nav matrix), JM-033 AC1-4, JM-034, JM-060, D3/D11/D70/D56.

---

## JM-024 — Create-flow location leg (tier → location-select → map-pin → order-chat) (W1-C engineer)

> Files owned: `request_type/presentation/request_type_screen.dart`,
> `location/presentation/client_location_screen.dart`,
> `location/presentation/capture_location_screen.dart` (+ new
> `location/{domain,data,application}/location_select_*` data slice and
> `request_type/presentation/request_type_radio_id.dart`).
> **No route ADD is needed** — every target route already exists (`client-location`,
> `capture-location`, `chat-detail`, `settings-addresses`). The screens self-navigate
> (40_GUARDRAILS_ARCH §10.8). The requests below are (1) a router-builder CLEANUP of
> the divergent W0-era callbacks, (2) l10n polish keys, (3) an optional DI note, and
> (4) the JM-024 → JM-025 order-chat hand-off contract.

### (1) ROUTER CLEANUP REQUEST — drop the divergent `/request-summary` callbacks on `/request-type`

The W0-era `/request-type` builder (`app_router.dart` ~lines 724-754) supplies three
callbacks. JM-024 re-points the create flow to the blueprint graph
(tier → **location-select** → map-pin → order-chat; 20_GAP_MAP customer domain +
30_BACKLOG JM-024 AC1), so two of them are now **divergent + dead**:

- `onTierSelected: (tier) => context.push('/request-summary', …)` — DEAD. The tier-card
  tap now only **selects** (no navigation). The screen NO LONGER invokes this.
- `onContinue: (draft) => context.push('/request-summary', extra: draft)` — DEAD. The
  Continue CTA (`request_type_continue_cta`) now **self-navigates** to `client-location`
  (the screen owns the edge). The screen NO LONGER invokes this.
- `onChangeLocation: () => context.push('/client-location')` — CORRECT (keep, or drop;
  the screen falls back to the same `pushNamed('client-location')` when it is null).

**Nav-honesty note:** the flow is **already honest today** — the screen self-navigates
and never calls the dead closures, so `/request-summary` is unreachable from the create
flow even before this cleanup. The request is to **remove the two dead args** so the
router reads true (no double-meaning), e.g.:

```dart
GoRoute(
  path: '/request-type',
  name: 'request-type',
  builder: (context, state) => const RequestTypeScreen(),
  // (onChangeLocation/onTierSelected/onContinue removed — the screen owns the
  //  tier→location-select edge; JM-024 AC1. /request-summary stays for the
  //  voice-request flow, which still uses it.)
),
```

The `RequestTypeScreen` keeps the three params (typed exactly as before:
`onChangeLocation: VoidCallback?`, `onTierSelected: ValueChanged<Tier>?`,
`onContinue: ValueChanged<RequestDraft>?`) so the **current** builder compiles
unchanged until this cleanup lands — they are inert.

### (2) l10n KEY REQUEST — dedicated create-flow copy (coded against existing reused keys)

Coded now against the closest existing locale-safe getters so the build stays GREEN;
Maestro keys on the `Semantics(identifier:)`, never the text, so these are copy-polish.

| intended key | proposed EN | proposed AR | currently reused | element |
|---|---|---|---|---|
| `locationSelectConfirmCta` | "Confirm location" | "تأكيد الموقع" | `locationConfirm` ("Confirm location") | `location_select_confirm_cta` |
| `locationSelectSavedAddressesRow` | "Saved addresses" | "العناوين المحفوظة" | `savedAddressesTitle` ("Saved addresses") | `location_select_saved_addresses_row` label |

> Both reused keys already exist in both ARBs (verified). When the integrator lands the
> dedicated keys, swap `l10n.locationConfirm` / `l10n.savedAddressesTitle` in
> `client_location_screen.dart`. No compile gate.

### (3) DI NOTE (optional, not blocking) — `LocationSelectRepository`

`ClientLocationScreen` self-provides its cubit: it resolves `sl<LocationSelectRepository>()`
**if registered**, else builds `DioLocationSelectRepository(sl<Dio>())` directly (the same
self-provide idiom as `RequestTypeScreen`/`TierRepository`), else degrades to the in-memory
seam. So **no DI edit is required** for the live flow. If the integrator prefers the
canonical interface registration (40_GUARDRAILS_ARCH §6), add:

```dart
// JM-024: location-select saved-address read (journey-honest /users/:id/saved-locations).
sl.registerLazySingleton<LocationSelectRepository>(
  () => DioLocationSelectRepository(sl<Dio>()),
);
```

### (4) HAND-OFF CONTRACT — JM-024 → JM-025 order-chat compose entry

`location_select_confirm_cta` self-navigates with
`context.pushNamed('chat-detail', pathParameters: {'id': 'new'})` — i.e. it lands on the
order-chat route (`/chat/:id`, name `chat-detail`, already registered) in **compose**
state, carrying the `new` sentinel as the conversation id. **JM-025 (order-chat) owns**
treating `id == 'new'` as the compose=broadcast entry (an empty thread that renders the
composer + `order_chat_composer_send`, the id the jm-024 flow's AC4 asserts). `ChatDetailScreen`
today falls back to an `InMemoryChatGateway` when the id resolves to no conversation, so a
`new` push already renders a composer; JM-025 should formalize the sentinel. **Owner:
JM-025.** This is the single cross-item join for the create flow.

Cites: 63_W1_TEST_PLAN §2.2-§2.4 + §3 (jm-024 nav matrix), 30_BACKLOG JM-024 AC1-5,
20_GAP_MAP customer domain + reconciliation note #4, 21_NAV_PLAN §C (request-type-selection /
location-select edges), CTO-D R-C (5 tiers / T1), Q3, D14.

### CONTRACT GAP flagged for the backender/QA loop — `DioSavedLocationRepository` path mismatch

NOT a JM-024 blocker (JM-024 reads via the new `DioLocationSelectRepository`), but surfaced
for JM-049's owner: the existing CRUD `DioSavedLocationRepository` posts/gets
`/v1/users/me/saved-locations`, which (a) does NOT match the rewrite map (key is `/users`,
not `/v1/users`) and (b) has no `:4010` route (the mock serves
`/user-management/users/:userId/saved-locations`, keyed by **userId**, not `/me`). So the
JM-049 manager will not see the `has_saved_addresses` seed until its repo is repointed to
`/users/:userId/saved-locations`. JM-024's location-select uses the corrected path, so the
seeded addresses surface in the picker today.



---

## JM-032 — Order Tracking (live_tracking) (W1 engineer)

### l10n KEY REQUEST — dispute / no-show / pinned-summary copy (coded against a feature-local resolver)
The order-tracking screen ships now using a feature-local EN/AR resolver
(`lib/features/live_tracking/presentation/live_tracking_l10n.dart`), exactly per
the JM-031 `order_summary_l10n.dart` precedent. It REUSES the existing getters
where one fits (`trackingStepOrdered/Picked/InTransit`, `trackingStepCompleted`
for the 4th "Delivered" step, `trackingEtaLabel/EtaMinutes`, `deliveryTierLabel`,
`tierSelectionTier*`, `orderSummaryOpenChat/Track`) and supplies only the
genuinely-missing copy locally. Maestro asserts on `Semantics(identifier:)`
only, so this is cosmetic copy — swapping to the real getters is a no-call-site
change. Requesting the integrator land these dedicated keys (EN + AR, with
`@`-descriptions); then delete the resolver:

| intended key | proposed EN value | element / id |
|---|---|---|
| `trackingDisputeCta` | "Report a problem" | `tracking_dispute_cta` |
| `trackingNoShowCta` | "Jeeber didn't show up" | `tracking_noshow_cta` |
| `trackingNoShowTitle` | "Jeeber didn't show up?" | no-show sheet title |
| `trackingNoShowBody` | "You can pick another offer for this request, or send it out again to nearby Jeebers." | no-show sheet body |
| `trackingNoShowReassignCta` | "Choose another offer" | `tracking_noshow_reassign_cta` |
| `trackingNoShowRebroadcastCta` | "Send request again" | `tracking_noshow_rebroadcast_cta` |
| `trackingNoShowKeepCta` | "Keep waiting" | `tracking_noshow_keep_cta` (dismiss) |
| `trackingStepDelivered` | "Delivered" | `tracking_step_delivered` (reuses `trackingStepCompleted` today) |
| `orderSummaryPriceLabel` | "Price" | `order_summary_price` label |
| `orderSummaryCashLabel` | "Pay cash on delivery" | `order_summary_cash_label` (D11) |
| `orderSummaryEtaPending` | "ETA pending" | `order_summary_eta` placeholder |

### NOTE — no route / DI / shell edits required (all targets pre-registered)
JM-032 reuses the already-registered `live-tracking` route
(`/orders/:id/tracking`; builds `LiveTrackingScreen` + provides
`LiveTrackingCubit` over the DI-registered `LiveTrackingRepository`), and the
already-registered edge targets: `escalate` (`/orders/:id/escalate`, AC3
dispute), `delivered-receipt` (`/orders/:id/receipt`, AC2 auto-advance),
`offer-review` (`/requests/:id/offers`, AC4 reassign), `waiting-no-coverage`
(`/requests/:id/waiting`, AC4 re-broadcast), `chat-detail` (`/chat/:id`,
pinned-summary open-chat). Every `goNamed` target is registered (nav-honest). No
`app_router.dart` / `injection_container.dart` / `shell_screen.dart` change.

### NOTE — `order_summary_pinned` is sourced from the tracking delivery row (not JM-031's DI repo)
The pinned summary on the tracking surface
(`lib/features/live_tracking/presentation/widgets/order_summary_pinned_header.dart`)
renders price/jeeber/ETA/tier/cash from the SAME delivery row the
`LiveTrackingCubit` already polls (`GET /v1/delivery/:id`), carrying the JM-031
ids (`order_summary_pinned` + `_price` / `_jeeber_name` / `_eta` / `_tier` /
`_cash_label` / `_open_chat`). This avoids a second fetch and the cross-feature
DI coupling that would otherwise need `sl<OrderSummaryRepository>()` — which the
W1 integrator deliberately left UNREGISTERED for JM-031 to define. When JM-031
lands its standalone pinned WIDGET, the two renderings share these ids so the
customer sees one consistent summary; no reconciliation needed for the jm-032
flow (it asserts only `order_summary_pinned` visible).

### CONTRACT — `GET /v1/delivery/:deliveryId` must carry the pinned-summary fields
The tracking repo now reads the delivery row (rewrite key `/v1/delivery` →
`/delivery-service/v1/delivery`, 42_GUARDRAILS_MOCK §1.2) and parses BOTH the
lifecycle `status` (`Ordered/Picked/InTransit/AtDoor/Done`) AND the summary
fields (`amount:{value,currency}`, `tier`, `jeeberName`, `title`, `requestId`,
`conversationId`). The journey-seed `active_delivery` / `delivery_marked_done`
rows already carry these (verified in `journey-seed.ts seedDeliveryRow`). The
terminal delivered status is `Done` (SM-1) — the domain parser maps
`done/delivered/completed` → `TrackingStage.delivered` so the auto-advance fires.
Cites: 30_BACKLOG JM-032 (`GET /delivery-service/v1/delivery/:deliveryId`),
63 section 2.12 + 3 (jm-032 nav matrix), 62_SEAM_HARNESS (active_delivery /
delivery_marked_done), D70/D11/D88/D71.

---

## JM-049 — Saved Addresses Manager (W1 engineer)

`SavedLocationsScreen` (lib/features/location/presentation/saved_locations_screen.dart)
is the real `saved-addresses` manager at `/settings/addresses` (route name
`settings-addresses`, already registered → `const SavedLocationsScreen()`). No
`app_router.dart` / `injection_container.dart` / `shell_screen.dart` edit was
made. Touched ONLY the location feature files + the repo's own test.

### REPO REPOINT — `DioSavedLocationRepository` now hits `/users/:userId/saved-locations` (closes the JM-024 contract gap)
The JM-024 engineer flagged (above, "CONTRACT GAP flagged for the backender/QA
loop") that the CRUD repo posted/got `/v1/users/me/saved-locations`, which (a)
did NOT match the `MockGatewayClient` rewrite map (key is `/users`, not
`/v1/users`) and (b) has no `:4010` route (the mock serves
`/user-management/users/:userId/saved-locations`, keyed by **userId**, not
`/me`) — so the `has_saved_addresses` seed (under `user-client-001`) was
invisible to the manager. JM-049 repoints `DioSavedLocationRepository` to the
journey-honest `/users/:userId/saved-locations` (the SAME path JM-024's
`DioLocationSelectRepository` uses) and resolves `:userId` from the persisted
`AuthTokenStore` (falling back to `user-client-001`, the mock authStub
convention, when absent). The repo gained an **optional** `tokenStore`
constructor param (default `AuthTokenStore()`), so the existing DI line
`DioSavedLocationRepository(sl<Dio>())` (injection_container.dart:273) **compiles
unchanged** — no DI edit requested. Parsing now also tolerates the seam shape
(`geo:{lat,lng}`, `isDefault`/`is_default`, and the JM-050 form fields
`building`/`floorApt`/`deliveryNotes`/`codPhone`) and maps the mock's 422
`limit_reached` (as well as the legacy 409) to `SavedLocationCapReachedException`.

> The repo's own contract test (`test/dio_saved_location_repository_test.dart`)
> was updated to pin the new path + the seam-shape parse — it is the repo's test,
> co-owned by this feature; no shared test touched.

### l10n KEY REQUEST — default-badge label (coded against a feature-local resolver)
There is no dedicated ARB key for the default-address badge and the ARB layer is
integrator-owned, so the single word resolves via a feature-local EN/AR helper
(`_defaultBadgeLabel` in `saved_locations_screen.dart` — the JM-031
`order_summary_l10n.dart` / JM-032 resolver precedent). Maestro asserts on the
`saved_address_default_badge` id, never the text, so this is cosmetic copy.
Requesting the integrator land the dedicated key (EN + AR, with `@`-description);
then swap `_defaultBadgeLabel(...)` → `l10n.savedAddressDefaultBadge` and delete
the helper:

| intended key | proposed EN | proposed AR | element / id |
|---|---|---|---|
| `savedAddressDefaultBadge` | "Default" | "الافتراضي" | `saved_address_default_badge` chip + a11y label |

> The Add CTA reuses the existing locale-safe `savedLocationsAddNew`; the per-row
> edit affordance reuses `savedLocationsEdit`; delete confirm reuses the existing
> `savedLocationsDelete*` / `actionCancel` set — all already present in both ARBs.

### EDGES — both already registered (no request)
```
EDGE — JM-049 → JM-050 (add)
  control: saved_address_add_cta
  call:    context.pushNamed('address-detail')                 # /settings/addresses/edit
EDGE — JM-049 → JM-050 (edit)
  control: saved_address_<n>_edit (whole row also opens it)
  call:    context.pushNamed('address-detail', queryParameters: {'id': <addressId>})
```
`address-detail` (`/settings/addresses/edit`, name `address-detail`, builds
`AddressDetailFormScreen(addressId: ?id)`) is the integrator's registered W1
route — nav-honest today. The manager reloads its list on return from the form
so a newly-saved/edited address surfaces. Inbound entry edges (AC4
`customer_profile_addresses_row`, AC5 `location_select_saved_addresses_row`)
already `goNamed('settings-addresses')` (integrator/JM-035 + JM-024 wired) — no
JM-049 file edit. Cites: 30_BACKLOG JM-049, 63 §2.16 + §3 (jm-049 nav matrix),
62_SEAM_HARNESS (has_saved_addresses), JM-050.

---

## JM-034 — Rating (mutual; remove skip; wire submit)

No NEW route needed — `mutual-rating` (`/orders/:id/mutual-rate`, line ~946) and
`feedback` (`/orders/:id/feedback`, line ~930) are already registered by the
integrator. JM-034 only edits its own feature files
(`lib/features/rating/...`). Two notes for the integrator's awareness (NOT
blocking — coded against the intended shape):

### DI (OPTIONAL refinement, non-blocking) — pass the session token store
`DioRatingRepository` now resolves the caller's `raterId` from the session
(`AuthTokenStore.userId`) because the real score-taking submit endpoint
(`POST /score-taking-service/v1/ratings/jeeb/submit`) REQUIRES `raterId`. To
avoid forcing an `injection_container.dart` edit mid-wave, the repo takes an
OPTIONAL `tokenStore` param defaulting to `AuthTokenStore()` — so the existing
registration `DioRatingRepository(sl<Dio>())` still compiles and works (it reads
the same keychain). When convenient, the integrator MAY tighten it to share the
singleton:
```dart
sl.registerLazySingleton<RatingRepository>(
  () => DioRatingRepository(sl<Dio>(), tokenStore: sl<AuthTokenStore>()),
);
```
This is a cleanliness improvement only; the default already behaves correctly.

### CONTRACT — rating wire format reconciled to the real :4010 score-taking svc
The old `DioRatingRepository` posted `/api/deliveries/{id}/rate` against the
stale Mockoon :3055 contract. JM-034 rewired it to the gateway contract that
`MockGatewayClient` rewrites (`/v1/ratings/jeeb` → `/score-taking-service/v1/
ratings/jeeb`, map confirmed in `mock_gateway_client.dart`):
  - `POST /v1/ratings/jeeb/submit` body `{ deliveryId, raterId, score,
    raterRole, comment?, tags? }` → 200 (403 if not a party to the delivery).
  - `GET /v1/ratings/jeeb/{deliveryId}/status` → `{ state, ratings, ratedCount }`
    (entity parser tolerates the legacy `status`/`stars`/`counterpartRating`
    shape too). Verified against `src/services/score-taking-service.ts`.
No mock change required — the endpoint + seed (`jeeber_rating_pending`,
`delivery_marked_done`) already exist. Cites: 30_BACKLOG JM-034
(`POST /score-taking-service/v1/ratings/jeeb/submit`, `GET .../status`),
63 section 2.14 + 3 (jm-034 nav matrix), 62_SEAM_HARNESS
(`jeeber_rating_pending` → `/orders/del-jeeber-002-delivered/mutual-rate?mode=
jeeber`), D56/D6/D58/D59/D31.

---

## JM-036 — DELIVERY-tab KYC gate (register-prompt vs feed) (W2 engineer)

The JM-036 feature edits placed the three coined screen-level Semantics ids
(65_W2_TEST_PLAN §2 JM-036) on the gate's two branches and chained the
register CTA into the onboarding wizard. No router/ARB change needed — the
`jeeber-onboarding` route + the `delivery_register_now_cta → dm_onboarding_*`
edge already exist (JM-039 owns the wizard's `dm_onboarding_continue` id). Files
touched (feature-owned, NOT shared): `lib/features/shell/tabs/dashboard_tab.dart`
(JM-036 target per 20_GAP_MAP row JM-036), `lib/features/jeeber_home/presentation/
jeeber_home_screen.dart`, `.../widgets/jeeber_unregistered_view.dart`.

### DI SWAP REQUEST — real getMe/kyc-backed `JeeberKycStatusGate` (U1-gated)
`injection_container.dart` currently binds the gate to `SeamJeeberKycStatusGate()`
(integrator default). The Maestro/seeded path is already correct: the seam owner's
`POST /__mock/seed/kyc` makes `GET /user-management/users/:userId/kyc` return the
seeded status, and `SeamJeeberKycStatusGate` reads `jeeb.seam.kyc_status`
synchronously on first frame, so the gate branches `delivery_register_prompt`
(none/pending/rejected) vs `jeeber_feed_root` (approved) deterministically. The
LIVE (non-seeded) path returns the production-safe default `approved` until a real
status source exists.

`GET /user-management/users/:userId/kyc` IS now live (W2 backender, K1 closed),
returning `{ state, rejection_reason?, submitted_at }`. But the gate interface
(`JeeberKycStatusGate.isApproved`, `lib/core/session/jeeber_kyc_status_gate.dart`)
is **synchronous** — read on the first frame of the DELIVERY tab — mirroring
`AccountStatusGate`. A Dio fetch is async, so the real gate needs a status that
is **pre-resolved + cached** at session-resolve time (the same plumbing
`AccountStatusGate`/JM-066 needs from getMe `kycStatus`, U1). That cache + the
one-line DI repoint are integrator/JM-066-owned (they touch
`injection_container.dart` + the session-resolve path, both shared), so JM-036
does NOT bolt an async fetch onto the synchronous gate (would risk a
register-prompt→feed flash on launch, R-F least-surprising).

  REQUEST (when U1 surfaces a synchronously-cached role `kycStatus` via getMe):
    repoint  sl.registerLazySingleton<JeeberKycStatusGate>(
               () => const SeamJeeberKycStatusGate());
    to       () => <RealKycStatusGate backed by the cached getMe.kycStatus>
    — no DashboardTab body edit (it depends on the interface, not the impl).
  cites: 20_GAP_MAP U1 (getMe surfaces role kycStatus), 65_W2_TEST_PLAN §3.4
         (U1 status UNKNOWN — JM-036 seam path GREEN without U1, live path parked),
         30_BACKLOG JM-036 (`GET /user-management/users/:userId/kyc`), D38/D67.

---

## JM-042 — KYC Pending/Result status links (KycStatusView engineer)

### l10n KEY REQUEST — dedicated CTA/note copy currently missing (coded against existing reused keys)
`KycStatusView` (`lib/features/kyc/presentation/kyc_status_view.dart`) now exposes
the JM-042 per-variant CTAs + the pending top-up note. The ARB is integrator-owned
and the l10n owner's W2 batch added wallet-hub / charge-info / funding / offer-gate
/ kyc-rejected / pending-offers groups but **not** the kyc-status CTA labels. The
screen ships now using the closest **existing** localized getters so it compiles
and renders; Maestro asserts on `Semantics(identifier:)` only, so this is cosmetic
copy, not a behavioural gap. Requesting the following dedicated keys (EN + AR, with
`@`-descriptions) so a polish pass can de-overload the reused strings.

| intended key | proposed EN value | proposed AR value | currently reused getter | element (Semantics id) |
|---|---|---|---|---|
| `kycStatusTopupAllowedNote` | "You can still top up your wallet while your verification is in review." | "يمكنك شحن محفظتك بينما تتم مراجعة توثيقك." | `gateTopupNote` (identical EN copy) | `kyc_status_topup_allowed_note` (pending) |
| `kycStatusFeedCta` | "Go to feed" | "الذهاب إلى الطلبات" | `jeeberFeedSectionTitle` ("Available requests") | `kyc_status_feed_cta` (approved) |
| `kycStatusWalletCta` | "Wallet" | "المحفظة" | `shellWalletChipLabel` ("Wallet") | `kyc_status_wallet_cta` (approved) |
| `kycStatusTopupCta` | "Top up" | "شحن" | `walletTopUpCta` ("Top up") | `kyc_status_topup_cta` (pending + approved) |
| `kycStatusViewRejectionCta` | "View rejection details" | "عرض تفاصيل الرفض" | `profileKycViewCta` ("View status") | `kyc_status_view_rejection` (rejected) |

> When the dedicated keys land, swap the `l10n.<reused>` getters in
> `kyc_status_view.dart` (each marked with a `// L10N-REQ:` comment) to the
> intended getters above. No layout/Semantics change — drop-in label swap.

### NOTE — no new route / no new mock; resubmit CTA removed (D52/D87)
- Edges all target **already-registered** route names: `shell` (jeeber-requests-home
  feed), `wallet` (wallet-hub), `wallet-charge-info`, `kyc-rejected`. No router edit.
- Data is the **existing** `KycWizardCubit.loadStatus()` → `KycGateway.fetchStatus()`
  → `GET /v1/kyc/status` (DioKycGateway, real Dio in DI; K1 closed). No new endpoint.
- The old `kyc-status-resubmit` CTA was **removed** from the rejected branch
  (D52/D87 — rejection is FINAL). `test/kyc_wizard_screen_test.dart`'s rejected-case
  assertion was updated in-feature to assert `kyc_status_view_rejection` present +
  resubmit absent. `KycWizardCubit.resubmit()` is now unreferenced by the view but
  left in place (harmless; owned by the wizard, not this view) — flag for cleanup.

---

## JM-051 — Mark Delivered (proof photo + rating chain) (W2 engineer)

`ActiveDeliveryJeeberScreen` (`/jeeber/deliveries/:id/active`, route name
`jeeber-active-delivery`) now drives JM-051: at `AtDoor` it shows the
mark-delivered panel (`mark_delivered_proof_photo` D3 + optional note +
`mark_delivered_cash_note` D11) and a `mark_delivered_cta` that transitions
`AtDoor → Done` (carrying the proof `evidenceUrl`) and then fires a new
`onMarkedDelivered` callback. Per D56 / JM-034, the done transition must route to
**`feedback-rate-delivery` (the mutual blind rating, `mode=jeeber`)**, NOT the OTP
handover. Only `ActiveDeliveryJeeberScreen` + its feature files were touched.

### ROUTE REQUEST (REQUIRED for AC2 nav) — rewire the route's done-callback OTP → rating

The current `/jeeber/deliveries/:id/active` builder
(`app_router.dart` ~l.992) wires `onOpenOtp: () => context.go('/orders/$deliveryId/otp?mode=jeeber')`.
JM-051 removes the OTP handover from the mark-delivered path (D56). The screen
constructor was extended: `onOpenOtp` is now **optional + deprecated** (kept only
so the existing builder still compiles — it is **no longer called** on done), and a
new **`onMarkedDelivered`** (optional `VoidCallback`) fires when the delivery
reaches `Done`. Please update the builder to:

```dart
GoRoute(
  path: '/jeeber/deliveries/:id/active',
  name: 'jeeber-active-delivery',
  builder: (context, state) {
    final deliveryId = state.pathParameters['id'] ?? '';
    return ActiveDeliveryJeeberScreen(
      deliveryId: deliveryId,
      repository: sl<ActiveDeliveryRepository>(),
      onOpenChat: () { if (context.canPop()) context.pop(); },
      // JM-051 AC2 / JM-034 / D56: done → mandatory mutual rating, NOT OTP.
      onMarkedDelivered: () =>
          context.go('/orders/$deliveryId/mutual-rate?mode=jeeber'),
      mapsUrlBuilder: (url) => launchUrl(
        Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  },
),
```

- **target route:** `mutual-rating` (`/orders/:id/mutual-rate`, `mode=jeeber`) is
  **already registered** (`app_router.dart` l.958) and exposes `rating_submit_cta`
  (the `jm-051-mark-delivered.yaml` AC2 assertion target). The blueprint's sole
  edge from `jeeber-mark-delivered` is `feedback-rate-delivery`; JM-034 ruled the
  **mutual** screen is the compliant canonical terminal (`/feedback` is the frozen
  RatingScreen). Either rating route exposes `rating_submit_cta`, but pick
  `mutual-rate` for D56 compliance.
- **why required:** until the builder passes `onMarkedDelivered`, the done
  transition completes (status flips to `Done`) but the screen has no callback to
  route on, so the AC2 nav leg (`mark_delivered_cta` → `rating_submit_cta`) stays
  RED. The screen is honest in the meantime — it does **not** wire to OTP (it never
  calls the deprecated `onOpenOtp`), so there is no nav-dishonesty (CTO brief §6.7);
  the leg is honest-but-unassertable-on-destination (AP-9) until this one-line swap.
- **cleanup (optional):** once swapped, the `onOpenOtp` param + the `'otp-handover'`
  route (`/orders/:id/otp`) are no longer reachable from the jeeber fulfilment path
  (the OTP handover screen `lib/features/otp_handover/` is now orphaned for JM-051;
  it may still back other flows — confirm before removal).
- cites: JM-051 AC2 + AC3, 65_W2_TEST_PLAN §JM-051 (`mark_delivered_cta` →
  `rating_submit_cta`, `phone_otp_verify_cta` assertNotVisible), JM-034, D56, D3,
  D70, 40_GUARDRAILS_ARCH §5.2/§9.

### l10n KEY REQUEST (POLISH ONLY — not compile-blocking) — dedicated mark-delivered copy

The mark-delivered panel ships now reusing the closest **existing** locale-safe
getters (Maestro keys on the `mark_delivered_*` identifiers, never the text, so
this is cosmetic). Requesting dedicated keys (EN + AR + `@`-descriptions + getters)
so a polish pass can de-overload them:

| intended key | proposed EN value | proposed AR value | currently reused getter | element (Semantics id) |
|---|---|---|---|---|
| `markDeliveredProofPhotoCta` | "Add proof of delivery photo" | "أضف صورة إثبات التسليم" | `escalatePhotoLabel` ("Add photos") | `mark_delivered_proof_photo` capture label |
| `markDeliveredCashNote` | "The customer confirms receipt and pays {amount} cash on delivery." | "يؤكد العميل الاستلام ويدفع {amount} نقداً عند التسليم." | `receiptCashToJeeber` ("Pay {amount} cash to {jeeber}") | `mark_delivered_cash_note` (D11) |
| `markDeliveredNoteLabel` | "Add a note (optional)" | "أضف ملاحظة (اختياري)" | `offerSubmissionNoteLabel` | `mark_delivered_note_field` label |
| `markDeliveredCta` | "Mark as delivered" | "تحديد كمسلّم" | `activeDeliveryMarkDone` ("Complete Delivery") | `mark_delivered_cta` |

> The proof-photo a11y label reuses `receiptProofPhotoLabel` ("Proof of delivery
> photo", D3) — semantically exact, no de-overload needed. When the dedicated keys
> land, swap the four reused getters in
> `active_delivery_jeeber/presentation/widgets/mark_delivered_panel.dart`.

### NO new DI / NO new mock endpoint
- `ActiveDeliveryRepository` → `DioActiveDeliveryRepository(sl<Dio>())` is **already
  registered** (`injection_container.dart` l.315). The Dio impl was repointed to the
  **real** mock gateway contract — `GET /v1/delivery/:id`,
  `POST /v1/delivery/status/transition` (`{deliveryId, to, evidenceUrl?}`, CapitalCase
  statuses per `delivery-service.ts` SM-1), and `POST /v1/delivery/proof-photo`
  (D1m sink, already landed W1). All three rewrite via the existing `/v1/delivery`
  key — **no mock-gateway map edit needed.** cites: 42_GUARDRAILS_MOCK D1m (DONE),
  backend W2 closeout (`AtDoor → proof-photo → Done(evidenceUrl)` chain tested).

---

## JM-046 — Insufficient Balance to Offer (sheet) (W2 engineer)

### CONVERGENCE NOTE — the sheet landed inside the JM-045 composer file (no duplicate)
JM-046's `insufficient_balance_sheet` is a **sheet, not a route** (40_GUARDRAILS_ARCH §5),
rendered ON the offer composer (`OfferSubmissionScreen`). The parallel JM-045 (offer
composer) engineer had already rewritten
`lib/features/offers/presentation/offer_submission_screen.dart` with a complete inline
`_InsufficientBalanceSheet` (all five JM-046 ids) + the `_showInsufficientSheet` /
`acknowledgeInsufficientBalance` wiring, keyed off the 402 cubit state. Per CTO-D R-F
(never duplicate a parallel agent's surface, never fight its state) the JM-046 engineer
adopted that sheet as canonical and **deleted an initially-drafted standalone
`insufficient_balance_sheet.dart`** to avoid two widgets owning the same Semantics ids.
JM-046's owned contribution is the **data layer that makes the sheet honest** (below) — the
402 detection + typed surfacing the composer's `_showInsufficientSheet` consumes.

### DATA WIRING OWNED BY JM-046 (O1 + W1m) — `lib/features/offers/{domain,data,application}`
Additive, in the offer feature only (no shared-file edit):
- `domain/offer_submission_repository.dart` — added `OfferSubmissionFailure.insufficientBalance`
  + a PURE-Dart `InsufficientBalanceInfo { needed, available, currency }` (Equatable) carried on
  `OfferSubmissionException.balance`. (`OfferSubmissionException`'s optional `message` moved from a
  positional to a named param — the only call site passing it, the Dio repo's `server` branch, was
  updated; all other call sites pass only the positional `failure`.)
- `data/dio_offer_submission_repository.dart` — `_mapDioError` now maps **402 → insufficientBalance**
  and defensively parses the O1 body `{needed, available, currency}` (camelCase + snake_case,
  tolerant of a missing/malformed body). 402 is NOT a generic error (42_GUARDRAILS_MOCK §5.1).
- `application/offer_submission_cubit.dart` — added `OfferFormMode.insufficientBalance` + a
  `state.insufficientBalance` payload + `acknowledgeInsufficientBalance()` (the "keep editing"
  dismiss → idle, draft untouched). The composer surfaces the sheet on this mode.

W1m: the composer resolves `sl<WalletRepository>()` for the available-balance fallback; the
402 body is the primary `{needed, available}` source, so AC1 (needed-vs-available visible)
is satisfiable from the 402 alone today and gets the live balance once DI swaps
`StubWalletRepository` → `DioWalletRepository` at the W1m hand-off (no screen change).

### l10n KEY REQUEST — dedicated `insufficientBalance*` copy (coded against the JM-045 resolver)
The sheet's visible copy lives in the JM-045 feature-local resolver
`lib/features/offers/presentation/offer_composer_l10n.dart` (the JM-008/JM-031 precedent —
EN/AR map until the integrator lands dedicated keys). Maestro keys on the
`insufficient_*` Semantics ids only, so this is copy-polish. Requesting (EN + AR, with
`@`-descriptions) so the resolver's insufficient-balance block can be deleted:

| intended key | proposed EN value | resolver getter |
|---|---|---|
| `insufficientBalanceTitle` | "Not enough balance" | `insufficientTitle` |
| `insufficientBalanceBody` | "Top up your wallet to reserve the 10% and send this offer." | `insufficientBody` |
| `insufficientBalanceNeeded` | "Needed: {amount} {currency}" | `insufficientNeeded` |
| `insufficientBalanceAvailable` | "Available: {amount} {currency}" | `insufficientAvailable` |
| `insufficientKeepEditingCta` | "Keep editing" | `insufficientKeepEditingCta` |

> The top-up CTA reuses the existing locale-safe `walletTopUpCta` ("Top up") — no new key.
> Cites: JM-046 AC1–AC3, 65_W2_TEST_PLAN §2 (JM-046 id registry), D43/D1/D92/D93, O1, W1m.

---

## JM-040 — KYC Identity (kyc-identity engineer)

### REWRITE-MAP KEY REQUEST — `/v1/kyc` → `/user-management/v1/kyc` (K1, load-bearing)
`lib/core/network/mock_gateway_client.dart` `_pathToServicePrefix` is core/shared
network wiring (analogous to `injection_container.dart` / `app_router.dart`) and is
therefore integrator-owned. The KYC data layer (`DioKycGateway`) already speaks the
intended `/v1/kyc/*` contract (form-schema · contract-template · sign · submit ·
status), and the W2 backender **landed K1 server-side** with the rewrite target
`/user-management/v1/kyc` (see `42_GUARDRAILS_MOCK.md §K1`). The ONE missing app-side
piece is the rewrite-map key, without which `/v1/kyc/*` calls hit `:4010/v1/kyc/*`
verbatim and 404. Requesting the integrator add (specific-before-general, no prefix
collision with the existing `/v1/*` keys):

```dart
'/v1/kyc': '/user-management/v1/kyc',
```

> Sibling of the backender's other follow-up `'/v1/jeeb/wallet' → '/wallet-service/v1/jeeb/wallet'`.
> Until it lands, JM-040's wizard runs against the seam (`jeeb.seam.kyc_status`)
> which bypasses the live KYC endpoint, so the Maestro flow can still go GREEN; the
> live getMe/kyc path only fully agrees once this key is added. **Owner: W2 integrator.**

### NOTE — no new route / l10n; the funding chain uses an already-registered route
- `kyc_submit_cta` chains to the **already-registered** `onboarding-funding` route
  (`context.goNamed('onboarding-funding')` in `kyc_wizard_screen.dart`). No router edit.
- The wizard is unchanged at `/profile/kyc` (name `kyc-status`); D20 removed the
  Vehicle step + `KycWizardStep.vehicle`/`VehicleType`/`vehicleRegistration` and
  collapsed id+selfie+ToS onto one `kyc-identity` screen. All copy reuses **existing**
  KYC getters (`kycIdStepTitle`, `kycSelfieStepTitle`, `kycTosStepTitle`,
  `kycTosDocumentBody`, `kycTosSignAndSubmit`, `kycWizardSubmit`, …) — no ARB change.
- Orphaned-but-harmless after D20 (flag for a later cleanup, NOT this feature's edit):
  l10n keys `kycVehicleStepTitle/Subtitle`, `kycVehicleType*`, `kycVehicleRegistration*`,
  `kycWizardStepVehicleLabel`, `kycRejectionReasonVehicleDocumentMissing`; and the
  now-unreferenced `IdSide` enum in `kyc_submission.dart`.

---

## JM-045 — Structured Offer Composer (economics layer, G3) (W2 engineer)

Feature: `lib/features/offers/` (offer-**submission** — distinct from
`client_offers/` per 40_GUARDRAILS §1). The composer is the **already-registered**
route `jeeber-offer-submission` (`/jeeber/requests/:id/offer` →
`OfferSubmissionScreen`). No `app_router.dart` / `injection_container.dart` /
`shell_screen.dart` / ARB edit. JM-046's insufficient-balance sheet + its O1/W1m
data layer landed in this same feature folder (see the JM-046 section above) —
this engineer owns the composer screen + economics layer + the inline
`_InsufficientBalanceSheet` widget; JM-046 owns the 402 data wiring. Converged,
no duplicate surfaces.

### NO ROUTE REQUEST — composer route + every target already registered
- Mounts on the existing `jeeber-offer-submission` builder. Constructor signature
  **unchanged** (`requestId`, `submissionService`, `onWithdrawn`, `onSubmitted`,
  `onRequestGone`, `repository`) + one **optional** `walletRepository` test seam
  (default -> `sl<WalletRepository>()`), so the integrator builder compiles untouched.
- AC4 send-success -> jeeber feed (`jeeber_feed_root`, the DELIVERY tab) via
  `context.go('/')` — **NOT** chat. Supersedes the builder's legacy
  `onSubmitted -> /chat/:conversationId` hand-off (`onSubmitted`/`onRequestGone`
  retained for back-compat; the screen owns its feed nav now).
  > Optional integrator cleanup: the builder's `onSubmitted: (cid) =>
  > context.go('/chat/$cid')` is now dead for this flow — droppable when convenient.
- `insufficient_topup_cta` -> already-registered `wallet-charge-info` (JM-046 AC2).

### DI — none requested
`OfferSubmissionRepository` (-> `DioOfferSubmissionRepository`) + `WalletRepository`
(-> `StubWalletRepository`; swap to `DioWalletRepository` at W1m) are already bound
by the W2 integrator. Screen resolves via `sl<T>()` with constructor test seams.

### l10n KEY REQUEST — composer economics copy (coded against a feature-local resolver)
The economics lines (fee/net/reserve/order-ref) + ETA-picker copy are not in the
ARB. Per the JM-008/JM-031 precedent the screen ships via a feature-local EN/AR
resolver (`lib/features/offers/presentation/offer_composer_l10n.dart`) reusing
existing locale-safe getters where one fits + a local map for the rest. Maestro
keys on Semantics ids only, so this is copy-polish. Requesting (EN + AR +
`@`-descriptions) so the resolver can be deleted:

| intended key | proposed EN value | resolver getter | element (id) |
|---|---|---|---|
| `offerComposerOrderRef` | "Your offer · {ref}" | `orderRef` | `offer_composer_order_ref` (AC3) |
| `offerComposerFeeLine` | "Platform fee (10%): {amount} {currency}" | `feeLine` | `offer_composer_fee_line` (D37/D44) |
| `offerComposerFeeLinePending` | "Platform fee: 10% of your offer" | `feeLinePending` | fee line, no price |
| `offerComposerNetLine` | "You earn (cash): {amount} {currency}" | `netLine` | `offer_composer_net_line` (D44) |
| `offerComposerNetLinePending` | "You earn (cash): your full offer, paid by the customer" | `netLinePending` | net line, no price |
| `offerComposerReserveNote` | "{amount} {currency} reserved now from your wallet · charged only if you win · released if you don't." | `reserveNote` | `offer_composer_reserve_note` (D1) |
| `offerComposerReserveNotePending` | "10% is reserved now from your wallet · charged only if you win · released if you don't." | `reserveNotePending` | reserve note, no price |
| `offerComposerEtaPlaceholder` | "Select pickup ETA" | `etaPlaceholder` | dropdown placeholder |
| `offerComposerEtaSheetTitle` | "Pickup ETA" | `etaSheetTitle` | ETA picker sheet title |
| `offerComposerEtaOption` | "{minutes} min" | `etaOption` | `offer_composer_eta_option_<i>` |
| `offerComposerErrorGeneric` | "Couldn't send your offer. Please try again." | `errorGeneric` | submit-failure snack |
| `offerComposerErrorNetwork` | "No connection. Check your network and try again." | `errorNetwork` | network snack |

> Reused as-is (no new key): `offerSubmissionTitle` (app-bar + economics card
> title), `offerSubmissionIntro` (header sub-line), `offerSubmissionFeeLabel`
> (`offer_composer_price_field` label), `offerSubmissionEtaLabel`
> (`offer_composer_eta_dropdown` label), `offerSubmissionSubmitButton`
> (`offer_composer_send_cta`), `offerSubmitWithdrawTooltip` (close),
> `offerSubmitRequestGone` (409 snack). Insufficient-sheet keys are in the JM-046
> table above. When the integrator lands the keys, swap the `_pick(...)` resolver
> calls and delete `offer_composer_l10n.dart`.

### NOTE (R-F / AP-9) — ETA bound by tier SLA uses the widest catalog band
JM-045 AC2 (D14): `offer_composer_eta_dropdown` is **bounded** (not free integer
minutes). The route carries only `requestId`, and the feed payload (`FeedRequest`)
does not carry the request's tier, so the composer can't read the *specific* tier
SLA today. Per R-F the picker is bounded by the **widest catalog band**
(`OfferEtaBand.defaultBand()`, 5..120 min / 5-min steps — pure Dart,
`lib/features/offers/domain/offer_eta_band.dart`): bounded + deterministic, not
free-form. AC (dropdown present + `offer_composer_eta_option_0` tappable) passes;
the exact per-tier band lights up once the request's tier reaches the composer.

> REQUEST (backend/integrator, P2 polish): carry the request's `tier` into the
> composer — widen `jeeber-offer-submission` to take the tier via `extra`/query,
> or have `FeedRequest` carry `tier` so the make-offer push forwards it. Then
> `OfferEtaBand.fromRange(minMinutes:, maxMinutes:)` is seeded from that tier's
> SLA (`GET /v1/tiers` exposes per-tier `ttlMinutes`). Until then the widest-band
> fallback is honest-but-not-tier-specific (AP-9). Cites: JM-045 AC2, D14,
> 42_GUARDRAILS_MOCK T1, 65_W2_TEST_PLAN section JM-045.

---

## JM-047 — Jeeber Pending Offers (submitted-offers list + withdraw, D15)

Feature: `lib/features/jeeber_pending_offers/`. The standalone
`/jeeber/pending-offers` route + `JeeberPendingOffersScreen` are already
registered by W2-INT (`builder: const JeeberPendingOffersScreen()`).

**Reuse decision (single source of truth, 40_GUARDRAILS_ARCH):** JM-048 had
ALREADY built and feed-wired the full submitted-offers stack in
`lib/features/jeeber_request_feed/` — `SubmittedOffer` domain,
`SubmittedOffersRepository` + `DioSubmittedOffersRepository`
(`GET /v1/offers?jeeberId=` filtered to `submitted` + `DELETE /v1/offers/:id`,
D1), `SubmittedOffersCubit` (lazy load + optimistic withdraw), and the shared
`PendingOfferRow` (which already carries the `pending_offer_<index>` /
`_price` / `_eta` / `pending_offer_awaiting_label` / `_withdraw_cta` ids). The
JM-047 Maestro flow reaches that list via the feed's `jeeber_feed_pending_tab`.
So the standalone screen REUSES that stack verbatim rather than duplicating a
parallel `pending_offers/*` domain (an initially-drafted duplicate was deleted).
The standalone screen owns ONLY the chrome: `jeeber_pending_offers_root` +
`OMDSAppBar` + the `pending_offers_back` edge → delivery-requests. No new
route/rewrite (the `/v1/offers` rewrite key already exists).

### l10n reused as-is (no new key; integrator owns l10n)
Standalone chrome reuses: `pendingOffersTitle` (app-bar), `pendingOffersEmptyTitle`
/ `pendingOffersEmptyBody` (empty-state), `offerSubmissionErrorGeneric` +
`offerSubmissionRetryButton` (cold-load error-state). The reused `PendingOfferRow`
already reuses `offerSubmissionEtaSuffix` ("min") for `_eta`,
`offerSubmissionWithdrawButton` for `_withdraw_cta`, and a `NumberFormat`-
formatted price for `_price`.

### NOTE (already filed by JM-048) — `pending_offer_awaiting_label` copy
The AC copy is literally "Awaiting customer decision". `PendingOfferRow` renders
the closest honest existing string (`jeeberFeedStatusPending` = "Pending", whose
ARB description is "awaiting the client's response") under the correct
`pending_offer_awaiting_label` id. The Maestro flow asserts the id's visibility
(not its text), so it is GREEN today. If the integrator lands a dedicated
`pendingOfferAwaitingLabel` ("Awaiting customer decision") key, the one swap is
in `jeeber_request_feed/presentation/pending_offer_row.dart` (`_AwaitingLabel`) —
that single change updates BOTH the feed sub-tab and this standalone screen.

### REQUEST (PO-jeeberid; integrator/session, P2) — real session-user-id provider
The standalone screen builds `DioSubmittedOffersRepository(dio: sl<Dio>(),
jeeberId: …)` and needs the current jeeber's id for `?jeeberId=`. There is no
app-side session-user-id provider yet (`SessionGate` exposes only a boolean), so
it defaults `jeeberId` to `SessionSeamBootstrap.jeeberUserId` (`user-jeeber-002`)
— exactly what the JM-047 seam pins and the Maestro flow queries. When a real
identity provider lands (e.g. a `SessionUserId` from the getMe/JWT path that
JM-036's KYC gate also uses), pass it into `JeeberPendingOffersScreen(jeeberId:)`
(constructor seam already present) — no body change. (The feed sub-tab's cubit
will need the same id wired at the dashboard call site.) Cites: 62_SEAM_HARNESS
W2 jeeber seam, 65_W2_TEST_PLAN JM-047.

---

## JM-053 — Wallet Hub (balance, affordability, reserved-now, states) (W2 engineer)

Feature: `lib/features/wallet/`. The hub is the **already-registered** route
`wallet` (`/wallet` → `WalletHubScreen`, the W2-INT REPLACE of the "coming soon"
stub). The engineer filled the screen body
(`presentation/wallet_hub_screen.dart`) + added a feature-local l10n resolver
(`presentation/wallet_hub_l10n.dart`). No `app_router.dart` /
`injection_container.dart` / `shell_screen.dart` / ARB edit. The screen
self-provides `WalletHubCubit` over `sl<WalletRepository>()` (the INTEGRATOR-STUB
until W1m) and reads `sl<JeeberKycStatusGate>()` for the KYC-pending banner.

### NO ROUTE REQUEST — hub route registered; owned + cross-wave edges honest
- Mounts on the existing `wallet` builder. Constructor signature gains two
  **optional** test seams (`repository` default → `sl<WalletRepository>()`,
  `kycStatusGate` default → `sl<JeeberKycStatusGate>()`), so the integrator
  builder (`const WalletHubScreen()`) compiles **untouched**.
- OWNED edge: `wallet_topup_cta` → already-registered `wallet-charge-info`
  (`goNamed('wallet-charge-info')`), guarded offline (D35); `wallet_how_fees_work`
  → in-screen `wallet_how_fees_explainer` bottom sheet (no route).
- CROSS-WAVE edges (AP-9 — tap accepted, hub root survives; NO `goNamed` to an
  unregistered name, CTO brief §6.7): `wallet_earnings_row` (target
  earnings-fees-dashboard / `earnings_total_cash`, JM-052, **W3**) and
  `wallet_see_all_activity` (target wallet-activity-list / `wallet_activity_root`,
  JM-055, **W3**) are GUARDED coming-soon SnackBars. The JM-052/055 engineers (or
  the W3 integrator) swap each `onTap` to the real `goNamed(...)` when those
  routes register — no other change. The JM-053 Maestro flow AP-9s the AC4/AC5
  landing assertions (`earnings_total_cash`, `wallet_activity_root`) until W3.

### DI — none requested
`WalletRepository` (→ `StubWalletRepository`) + `JeeberKycStatusGate` (→
`SeamJeeberKycStatusGate`) are already bound by the W2 integrator.

### W1m SWAP — gateway rewrite-map key + DI repoint (integrator, at W1m hand-off)
For the `jeeb.seam.wallet_state` Maestro states (AC6 insufficient/low) and the
real balance/affordability/reserved-now/gift to flow, the hub must read the live
endpoint. The integrator + backender both flagged this; restating the two-line
app-side swap so AC6 stops AP-9'ing:
- Add to `lib/core/network/mock_gateway_client.dart` rewrite map (sibling of the
  existing `/v1/jeeb/earnings` key): `'/v1/jeeb/wallet': '/wallet-service/v1/jeeb/wallet'`.
- Repoint `injection_container.dart`: `StubWalletRepository()` →
  `DioWalletRepository(sl<Dio>())` (impl already written, parser handles the W1m
  `affordabilityState` enum + snake/camel). No `WalletHubScreen` change.
> Until then the hub renders the deterministic `StubWalletRepository` snapshot
> (`enough`, gift > 0), so AC1/AC2/AC3 are GREEN on the stub; AC6 (insufficient
> copy) and the live AC7 (kyc banner via the getMe path) need the swap. AC7 is
> ALSO satisfiable on the seam alone today: `SeamJeeberKycStatusGate` reads
> `jeeb.seam.kyc_status=pending` synchronously, which the banner gates on — no
> swap needed for the banner's Maestro path.

### l10n KEY REQUEST — wallet-hub copy (coded against a feature-local resolver)
The integrator landed FIVE wallet-hub keys (`walletHubTitle`,
`walletAvailableBalanceLabel`, `walletTopUpCta`, `walletHubLoadError`,
`walletHubRetry`). The rest of the hub copy is not in the ARB. Per the
JM-008/JM-031/JM-045 precedent the screen ships via a feature-local EN/AR
resolver (`lib/features/wallet/presentation/wallet_hub_l10n.dart`) reusing the
five present getters + `shellComingSoon`, with a local map for the rest. Maestro
keys on Semantics ids only, so this is copy-polish. Requesting (EN + AR +
`@`-descriptions) so the resolver can be deleted:

| intended key | proposed EN value | resolver getter | element (id) |
|---|---|---|---|
| `walletGiftBadge` | "{amount} {currency} starter credit" | `giftBadge` | `wallet_gift_badge` (D42) |
| `walletReservedNowLabel` | "Reserved now" | `reservedNowLabel` | `wallet_reserved_now` (D1) |
| `walletReservedNowHint` | "Held against your live offers — released when each offer is decided." | `reservedNowHint` | `wallet_reserved_now` |
| `walletHowFeesWork` | "How fees work" | `howFeesWork` | `wallet_how_fees_work` |
| `walletFeesExplainerTitle` | "How fees work" | `feesExplainerTitle` | `wallet_how_fees_explainer` (D41/D44) |
| `walletFeesExplainerLine1` | "You only pay a flat 10% fee on offers you win." | `feesExplainerLine1` | explainer body |
| `walletFeesExplainerLine2` | "The fee is taken from your pre-charged wallet balance — never in-app." | `feesExplainerLine2` | explainer body |
| `walletFeesExplainerLine3` | "The customer pays you the delivery price in cash on delivery." | `feesExplainerLine3` | explainer body |
| `walletFeesExplainerGotIt` | "Got it" | `feesExplainerGotIt` | explainer dismiss |
| `walletEarningsRow` | "Earnings & fees" | `earningsRow` | `wallet_earnings_row` |
| `walletEarningsRowSubtitle` | "Your net cash and the fees you've paid." | `earningsRowSubtitle` | `wallet_earnings_row` |
| `walletSeeAllActivity` | "See all activity" | `seeAllActivity` | `wallet_see_all_activity` |
| `walletSeeAllActivitySubtitle` | "Reserves, fees, refunds and top-ups." | `seeAllActivitySubtitle` | `wallet_see_all_activity` |
| `walletKycPendingTitle` | "Verification in progress" | `kycPendingTitle` | `wallet_kyc_pending_banner` (D38/D39) |
| `walletKycPendingBody` | "You can top up now. You'll be able to make offers once your verification is approved." | `kycPendingBody` | banner body |
| `walletOfflineMoneyBlocked` | "You're offline — reconnect to add funds." | `offlineMoneyBlocked` | top-up offline guard (D35) |
| `walletAffordEnoughTitle` / `…Body` | "Ready to bid" / "You have enough to place offers." | `affordabilityTitle/Body(enough)` | `wallet_affordability_card` (D43) |
| `walletAffordLowTitle` / `…Body` | "Running low" / "Your balance is low — top up to keep bidding." | `affordabilityTitle/Body(low)` | `wallet_affordability_card` |
| `walletAffordEmptyTitle` / `…Body` | "Top up to bid" / "Add funds to start making offers." | `affordabilityTitle/Body(empty)` | `wallet_affordability_card` |
| `walletAffordAllReservedTitle` / `…Body` | "Everything is reserved" / "Your funds are all held against live offers. Top up to bid on more." | `affordabilityTitle/Body(allReserved)` | `wallet_affordability_card` |

> D43 is honored as required: the affordability card surfaces STATE copy
> (title + body keyed off `WalletAffordability`), NOT a derived capacity number —
> fixes the S-10 false-green. Reuses `shellComingSoon` for the AP-9 guarded-row
> notice (already present).

### OPTIONAL — app-wide OfflineCubit provider (D35 hardening; core/integrator, P2)
The top-up CTA's offline guard (D35) reads `context.read<OfflineCubit>()` inside
a try/catch and treats absence as online, because `OfflineCubit` is NOT in the
global provider tree today (`lib/app/app.dart` `MultiBlocProvider`). So the guard
is inert until either an ancestor provides it or it is added app-wide. Adding
`BlocProvider(create: (_) => OfflineCubit())` to the root MultiBlocProvider (wired
to real connectivity) would activate the guard with no screen change. Not blocking
any AC (the offline-block ACs are not in the JM-053 Maestro flow); flagged for the
D35 polish pass. **Owner: integrator / core.**

---

## JM-048 — Delivery Feed (W2 engineer)

### CROSS-WAVE DEPENDENCY on JM-036 gate — feed must be visible to a registered-but-unapproved jeeber
The JM-044 + JM-048 Maestro flows both drive `jeeb.seam.kyc_status=none` and then
expect `feed_make_offer_cta` to be **visible on the DELIVERY tab** so it can be
tapped to reach `offer_kyc_gate` (D38: gate at OFFER time, not at tab entry).

The JM-036 gate (`lib/features/shell/tabs/dashboard_tab.dart`, owned by the
JM-036 engineer) currently keys feed-vs-register-prompt off
`JeeberKycStatusGate.isApproved`, so `kyc_status ∈ {none,pending,rejected}` renders
`delivery_register_prompt` and **hides the feed** — meaning an unapproved jeeber
never sees `feed_make_offer_cta`, and jm-044 AC1-5 / jm-048 AC1 cannot go green.

**Resolution (JM-036 engineer):** the gate should distinguish *registration*
(has the jeeber started/submitted onboarding) from *KYC approval*. The
register-prompt is for the NOT-REGISTERED user; a registered-but-unapproved
jeeber (`pending`, or `none` once they've registered) should see the **feed** and
be gated at offer time by JM-044's `offer-kyc-gate`. Concretely: render
`delivery_register_prompt` only when the jeeber has no onboarding/KYC submission
at all, and render `jeeber_feed_root` (the feed) for `pending`/submitted states.
Today the gate falls to the prompt for every non-approved state.

JM-048's make-offer routing is already D38-correct and needs no change once the
gate shows the feed: it reads `JeeberKycStatusGate.isApproved` and routes
`offer-kyc-gate` (unapproved) vs `jeeber-offer-submission` (approved). No
route/key/ARB additions requested — all targets exist
(`offer-kyc-gate`, `jeeber-offer-submission`).

### l10n KEY REQUEST — Pending-Response sub-tab row copy (coded against existing keys)
The feed's Pending sub-tab (JM-048 AC3 / JM-047) renders submitted-offer rows
using the closest **existing** localized strings, since JM-047's dedicated copy
is not in the ARB yet and ARB is integrator-owned. Maestro asserts on
`Semantics(identifier:)` only, so this is cosmetic copy, not a behavioural gap.

| intended key | proposed EN value | currently reused | element |
|---|---|---|---|
| `pendingOfferAwaitingLabel` | "Awaiting customer decision" | `jeeberFeedStatusPending` ("Pending") | `pending_offer_awaiting_label` |
| `pendingOfferEtaSuffix` | "min ETA" | `offerSubmissionEtaSuffix` ("min") | `pending_offer_<i>_eta` |
| `pendingOfferWithdrawCta` | "Withdraw" | `offerSubmissionWithdrawButton` ("Withdraw offer") | `pending_offer_<i>_withdraw_cta` |

---

## JM-064 — Rate the App / native store-review sheet (W4 engineer)

JM-064 is a **thin handler**, not a route — the customer-profile `customer_profile_rate_app_row`
raises the OS store-review sheet and returns to Profile (blueprint `rate-the-app`; no network).
It is built behind the `AppReviewLauncher` **port** (`lib/features/rate_app/domain/app_review_launcher.dart`),
mirroring the `MapPickerLauncher` (location) / `VoiceRecorder` (voice_request) native-side-channel
idiom — the feature never imports the platform plugin directly. The customer-profile screen
self-provides the launcher (`CustomerProfileScreen._resolveReviewLauncher()`), so **no
`injection_container.dart` edit is required for the row to be honest today**: with no
`AppReviewLauncher` registered it falls back to `NoopAppReviewLauncher` (tap accepted, returns to
Profile — AP-9 honest; the OS sheet is itself rate-limited/no-op'able, so this is contract-faithful).
The `jm-064-rate-the-app.yaml` flow only asserts tap-accepted + profile survives, which this passes.

### PUBSPEC DEP REQUEST — `in_app_review` (currently absent from `pubspec.lock`)
The real sheet needs the `in_app_review` package, which is **not resolvable in this worktree**
(absent from `pubspec.lock`); importing it would red `flutter analyze` — exactly the
`ofl_geo_capture` / `MapPickerLauncher` situation (CTO-D R-F). Requesting the integrator add:

```yaml
# Native store-review sheet (JM-064 / rate-the-app). Wraps SKStoreReviewController
# (iOS) / Play In-App Review (Android) behind the AppReviewLauncher port.
in_app_review: ^2.0.10
```

> Version note: confirm `^2.0.10` resolves on Dart 3.10.8 / Flutter 3.38.9 (this app's pinned
> toolchain — same constraint that pinned `record`/`audioplayers` to their 6.x lines). If 2.x needs
> a newer SDK, pin the highest line that resolves; the port/adapter shape is version-independent.

### DI REQUEST — register the real adapter (after the dep lands)
```dart
// JM-064: native store-review sheet (in_app_review), behind AppReviewLauncher.
sl.registerLazySingleton<AppReviewLauncher>(() => const InAppReviewLauncher());
```

`InAppReviewLauncher` (`lib/features/rate_app/data/in_app_review_launcher.dart`) is the documented
swap-target: it carries an `INTEGRATOR-SWAP(JM-064)` marker with the exact `in_app_review` body to
drop in once the dep is present (today its body is a guarded debug no-op so analyze stays green).
With the registration above, `CustomerProfileScreen._resolveReviewLauncher()` resolves it from
GetIt automatically — **no edit to `customer_profile_screen.dart` is needed** (the self-provide
already prefers a registered `AppReviewLauncher` over the noop default). No route, no ARB, no edge.

---

## JM-057 — Notifications List l10n keys (W4 engineer)

The route (`/notifications` → `NotificationsListScreen`), the shell-bell edges
(`orders_home_bell` / `delivery_tab_bell` / `customer_profile_bell` → `goNamed('notifications')`),
the DI binding (`NotificationsRepository` → real `DioNotificationsRepository`), and three ARB keys
(`notificationsTitle` / `notificationsEmptyTitle` / `notificationsEmptyBody`) were all landed by the
W3+W4 integrator — **no route / DI / shell / ARB edit is required for the screen to be honest
today.** The screen reuses those three present getters and supplies the remaining cosmetic copy
(load-error + retry, the eight typed-row category labels, the relative timestamp) from a
feature-local EN/AR resolver — `lib/features/notifications/presentation/notifications_l10n.dart` —
following the JM-053 `wallet_hub_l10n.dart` / JM-045 `offer_composer_l10n.dart` precedent
(40_GUARDRAILS_ARCH §9). Maestro asserts on `Semantics(identifier:)` only, so the visible copy is
cosmetic and this swaps to real getters with no call-site change.

### ARB KEY REQUEST — fold these into BOTH `app_en.arb` + `app_ar.arb` (+ the hand-authored getters)
Once the integrator lands the keys below, delete `notifications_l10n.dart` and point the screen at
the getters directly (the `_pick` EN strings are the EN values):

```json
"notificationsLoadError": "Could not load notifications.",
"notificationsNetworkError": "No connection. Check your network and try again.",
"notificationsRetry": "Retry",
"notifCategoryOffer": "New offer",
"notifCategoryOfferAccepted": "Offer accepted",
"notifCategoryStatus": "Order update",
"notifCategoryLowBalance": "Low balance",
"notifCategoryFeeWon": "Fee captured",
"notifCategoryRefundPenalty": "Dispute outcome",
"notifCategoryTopup": "Top-up received",
"notifCategoryKycApproved": "KYC approved",
"notifCategoryKycRejected": "KYC rejected",
"notifCategoryRequestExpired": "Request expired",
"notifCategoryConfirmReceipt": "Confirm receipt",
"notifCategoryMarketing": "Jeeb",
"notifCategoryUnknown": "Notification",
"notifUnreadLabel": "Unread"
```

> The relative-time copy (`Xm/Xh/Xd ago` + `Just now`) stays in the resolver as a formatter (it is
> interpolated, not a fixed string) unless the integrator prefers ICU plural keys — either is fine;
> flows never assert on it.

No new route, no DI change, no shell/ARB edit needed for honesty NOW; this is a cosmetic-copy
follow-up only.

---

## JM-056 — Transaction Detail (W3 engineer)

The route `transaction-detail` (`/wallet/transactions/:id` → `TransactionDetailScreen`,
`transactionId` path param) is already registered by the W3+W4 integrator. The body is now built
(cubit + state + l10n resolver + per-type view + the two outbound edges). The following are
integrator/DI-owned and requested below; none block the screen (it renders + the data-bound ACs
go green the moment the DI swap lands).

### DI SWAP REQUEST — repoint `WalletTransactionRepository` to the real Dio impl
W3m `GET /v1/jeeb/wallet/ledger/:id` is now **LIVE on :4010** (BACKEND final-wave report +
`42_GUARDRAILS_MOCK` "FINAL WAVE (W3+W4) mock closeout"; verified shape
`{ id, type, category, title, amount, sign, ref, ts, currency, feeRate?, pinnedPrice?, offerId?, orderId?, disputeId? }`).
The integrator left the DI default as the `StubWalletTransactionRepository` INTEGRATOR-STUB
(`injection_container.dart`, "INTEGRATOR-STUB(JM-056)"). Repoint it — one line, no screen change:

```dart
// JM-056: wallet transaction-by-id (W3m LIVE on :4010 — swap off the stub).
sl.registerLazySingleton<WalletTransactionRepository>(
  () => DioWalletTransactionRepository(sl<Dio>()),
);
```

`DioWalletTransactionRepository` (`lib/features/wallet/data/dio_wallet_transaction_repository.dart`)
is the swap target and already parses the verified W3m wire (incl. `feeRate`→percent, `orderId`,
`disputeId`, `category`, `ts`). The gateway rewrite key (`/v1/jeeb/wallet` →
`/wallet-service/v1/jeeb/wallet`, covering the `/ledger/:id` depth) is already present in
`mock_gateway_client.dart` (W3-INT). The resolved jeeber comes from the bearer (no `?jeeberId=`).

> The DI test `test/core/di/injection_container_new_repos_test.dart` currently asserts the binding
> `isA<StubWalletTransactionRepository>()` — flip that assertion to
> `isA<DioWalletTransactionRepository>()` in the same batch as the swap.

### l10n KEY REQUEST — per-type copy + field labels (coded against a feature-local resolver)
The integrator landed FOUR keys (`txnDetailTitle` / `txnDetailBody` / `txnDetailOrderLink` /
`txnDetailDisputeLink`). The screen needs PER-TYPE copy (the seven ledger kinds), the fee_won
breakdown labels (D37), the amount sign affixes, and the field labels — supplied for now from a
feature-local EN/AR map in `lib/features/wallet/presentation/transaction_detail_l10n.dart`
(the `wallet_hub_l10n.dart` / `offer_composer_l10n.dart` precedent). Maestro asserts on
`Semantics(identifier:)` only, so this is cosmetic copy, not a behavioural gap. Requesting dedicated
keys (EN + AR, with `@`-descriptions) so a polish pass can fold the resolver away:

| intended key | proposed EN value | element |
|---|---|---|
| `txnDetailTypeReserveTitle` / `…Body` | "Offer reserve held" / reserve explainer (D1) | `txn_detail_type_summary` |
| `txnDetailTypeFeeWonTitle` / `…Body` | "Platform fee" / fee_won explainer (D37) | `txn_detail_type_summary` |
| `txnDetailTypeReleasedTitle` / `…Body` | "Reserve released" / released explainer | `txn_detail_type_summary` |
| `txnDetailTypeRefundTitle` / `…Body` | "Dispute refund" / refund explainer (D2) | `txn_detail_type_summary` |
| `txnDetailTypePenaltyTitle` / `…Body` | "Dispute penalty" / penalty explainer (D2) | `txn_detail_type_summary` |
| `txnDetailTypeTopupTitle` / `…Body` | "Wallet top-up" / topup explainer | `txn_detail_type_summary` |
| `txnDetailTypeGiftTitle` / `…Body` | "Starter credit" / gift explainer (D42) | `txn_detail_type_summary` |
| `txnDetailAmountLabel` | "Amount" | `txn_detail_amount` |
| `txnDetailDateLabel` | "Date" | date row |
| `txnDetailFeeRateLabel` | "Platform fee" | `txn_detail_fee_rate` |
| `txnDetailPinnedPriceLabel` | "Accepted price" | `txn_detail_pinned_price` |
| `txnDetailReferenceLabel` | "Reference" | reference row |
| `txnDetailDisputeRefLabel` | "Dispute" | dispute-ref row |
| `txnDetailLoadErrorNotFound` | "This transaction could not be found." | error state |
| `txnDetailLoadErrorGeneric` | "We couldn't load this transaction. Please try again." | error state |
| `txnDetailRetry` | "Retry" | error retry |

### EDGE NOTE (not a request) — `txn_detail_dispute_link` param-shape mismatch
The JM-056 AC sends `txn_detail_dispute_link → dispute-open-evidence` = the `escalate` route
(`/orders/:id/escalate`, JM-060), whose path param `id` is a **delivery/order id**. The W3m
refund/penalty row only carries a **`disputeId`** (D2) — there is no orderId on a dispute-adjustment
row. The link therefore routes `context.pushNamed('escalate', pathParameters: {'id': txn.disputeId})`,
passing the disputeId as the route handle (the integrator stub did the same with the txn id). This is
contract-faithful for navigation honesty (the route resolves + lands on the evidence screen), but the
escalate screen will treat the disputeId as its `deliveryId`. Two clean closes when ready (integrator
+ backend, neither in the wallet feature):
  (a) prefer routing the dispute link to `dispute-status` (`/disputes/:id`, JM-065) which takes a
      `disputeId` directly — change the AC's stated target, OR
  (b) have W3m additionally surface the dispute's `deliveryId`/`orderId` on the refund/penalty row so
      the `escalate` link gets its real path param.
The screen is structured so this is a one-line `onTap` change with no other edit.

---

## JM-058 — Notification Preferences (W4 engineer)

The `notification-prefs` screen (`notification_prefs_screen.dart`, blueprint
`notification-prefs`) was reworked to the D64 contract. **No route or DI request
needed** — the route `settings-notifications` (`/settings/notifications` →
`NotificationPreferencesScreen` wrapper → provides `NotificationPrefsCubit` via
`sl<NotificationPrefsRepository>()`) and the `DioNotificationPrefsRepository`
binding are already registered. The repository now speaks the AC path
`/v1/notifications/preferences` (gateway rewrites `/v1/notifications` →
`/notification-service/v1/notifications`; mock `GET/PUT` confirmed, 42 closeout).
Categories = offers / order-status / wallet / marketing; transactional is locked;
PUT carries `{ push:true, topics:{...} }` (the mock echoes `topics`).

### Exact Semantics identifiers exposed (JM-058 AC)
`notif_prefs_root`, `notif_prefs_offers_toggle`, `notif_prefs_order_status_toggle`,
`notif_prefs_wallet_toggle`, `notif_prefs_marketing_toggle`,
`notif_prefs_transactional_locked` (locked always-on row, D64),
`notif_prefs_push_only_note` (R2), `notif_prefs_retry_cta`, and `notif_prefs_back`
(app-bar leading → `customer-profile`; `pop()` when poppable, named fallback on a
cold deep-link).

### l10n KEY REQUEST — dedicated copy missing (coded against existing reused keys)
ARB is integrator-owned and has **no** dedicated copy for the wallet/marketing
categories, the transactional-locked row, or the push-only note. The screen ships
NOW reusing the closest EXISTING locale-safe getters (Maestro asserts on the
identifiers above, never visible text — copy-polish only, AC stays green).
Requesting the following dedicated keys (EN + AR, `@`-descriptions):

| intended key | proposed EN value | currently reused getter | element |
|---|---|---|---|
| `notifPrefsPushOnlyNote` | "These control your push notifications. Manage SMS/email in your device settings." | `notificationPreferencesRowSubtitle` | `notif_prefs_push_only_note` |
| `notifPrefsWalletTitle` | "Wallet" | `walletHubTitle` | `notif_prefs_wallet_toggle` row title |
| `notifPrefsWalletSubtitle` | "Low balance, fees, top-ups, and gifts" | `notificationPreferencesRowSubtitle` | wallet row subtitle |
| `notifPrefsMarketingTitle` | "Promotions" | `notificationCategoryRatingReminders` | `notif_prefs_marketing_toggle` row title |
| `notifPrefsMarketingSubtitle` | "Discounts and seasonal promotions" | `notificationCategoryOffersSubtitle` | marketing row subtitle |
| `notifPrefsTransactionalTitle` | "Transactional alerts" | `notificationCategoryOtp` | `notif_prefs_transactional_locked` title |
| `notifPrefsTransactionalLocked` | "Always on — order receipts and money movements" | `notificationCategoryOtpAlwaysOn` | locked-row subtitle |

> offers + order-status reuse the already-present, semantically-correct getters
> (`notificationCategoryOffers`/`…Subtitle`, `notificationCategoryStatus`/`…Subtitle`)
> — no new key needed for those two. The back tooltip reuses `kycWizardBack` ("Back").

---

## JM-061 — Password & Security (W4 engineer)

The change-password screen (`/settings/password`, `password-security`) ships now
fully wired against the **existing** integrator-landed getters
(`passwordSecurityTitle` / `passwordSecurityBody` / `passwordSetEntryCta`) plus
reuse of nearby auth getters. Two follow-up requests below; neither blocks the
screen (Maestro asserts on `Semantics(identifier:)`, not text — all JM-061 ids
are present and the W34 nav assertions pass against this build).

### l10n KEY REQUEST — dedicated copy (coded against reused getters)
The current-password field + the two distinct error nodes have no dedicated copy
yet (ARB is integrator-owned). Coded against the closest existing getters so the
screen renders correctly today; a polish pass can de-overload them.

| intended key | proposed EN value | currently reused getter | element |
|---|---|---|---|
| `passwordCurrentLabel` | "Current password" | `loginPasswordLabel` ("Password") | `password_current_field` label |
| `passwordCurrentHint` | "Enter your current password" | `loginPasswordHint` ("Your password") | `password_current_field` hint |
| `passwordMismatchError` | "Passwords don't match." | `setpwValidationError` | `password_mismatch_error` node |
| `passwordStrengthError` | "Use at least 8 characters with a letter and a number." | `setpwValidationError` | `password_strength_error` node |
| `passwordChangeSubmitCta` | "Save password" | `setpwSubmitCta` ("Save password") | `password_submit_cta` (already identical copy) |

> The new/confirm field labels + hints reuse `setpwNewLabel`/`setpwNewHint` /
> `setpwConfirmLabel`/`setpwConfirmHint` (already semantically correct — no new
> key needed). `password_submit_cta` already reuses `setpwSubmitCta` whose value
> is exactly "Save password", so `passwordChangeSubmitCta` is cosmetic-only.

### DEV-SEAM KEY REQUEST — `jeeb.seam.account_type` (NEW W4, still missing)
`67_W34_TEST_PLAN §JM-061` drives the AC4 social-only variant with
`jeeb.seam.account_type=social_only` (owner: Backend + seam), but the final-wave
SEAM agent added only the four `jeeb.seam.journey` values — **no `account_type`
field exists on `DevSeamConfig`**, and the mock has no
`POST /__mock/seed/account { "type": "social_only" }` seed. Until that lands:
> The screen exposes a `hasPassword` constructor flag (default `true`). It renders
> the change form AND the `password_set_entry` (D90) so EVERY asserted id is
> reachable in one render and the `password_set_entry → setpw_new_field` nav
> assertion holds against the standard `customer_logged_in` seam. When the
> `account_type` field lands, the integrator should pass
> `hasPassword: !(seam.accountType == 'social_only')` from the `/settings/password`
> route builder (and the seam agent maps the new field), flipping the AC4 path to
> render the social-only entry only. The router builder currently calls
> `const PasswordSecurityScreen()` — the only edit needed there is forwarding the
> resolved flag; no behavioural change to the screen itself.

---

## JM-060 — Dispute (open + evidence) [dispute-open-evidence]

**Author:** JM-060 engineer (Opus). **Date:** 2026-06-19. Extended the existing
`escalate` feature (`lib/features/escalate/`) into the blueprint
`dispute-open-evidence` flow and **retired the dead unrouted
`lib/features/dispute/presentation/dispute_screen.dart`** (deleted; the whole
`lib/features/dispute/` folder removed — it had no route and no caller; 20_GAP_MAP
reconciliation note 8). Touched ONLY `lib/features/escalate/**` + its two tests.

### NO route / DI / shell request needed — all already registered
- Route `escalate` (`/orders/:id/escalate` → `EscalateScreen`, cubit
  route-provided via `sl<EscalateRepository>()` + `deliveryId` path param) is
  **already in `app_router.dart`** (the W3+W4 integrator left it unchanged). The
  `EscalateCubit({repository, deliveryId})` constructor is **unchanged**, so the
  route builder compiles as-is.
- DI `EscalateRepository → DioEscalateRepository(sl<Dio>())` is **already
  registered** (`injection_container.dart`, T-MOB-022 tag). The `DioEscalateRepository`
  constructor signature is **unchanged** (`(Dio)`), so no DI edit is needed even
  though the impl was repointed from `/v1/deliveries/{id}/escalate` to
  `POST /v1/disputes`.
- Inbound edges already wired to `escalate` by their owners: `tracking_dispute_cta`
  (live_tracking), `receipt_not_yet_cta` (delivery_receipt), `order_chat_open_dispute`
  (chat). Outbound edges I wired in my own feature file: `dispute_submit_cta` →
  `goNamed('dispute-status', pathParameters:{id})` (JM-065, registered);
  `dispute_support_link` → `pushNamed('support-ticket')` (registered, D76);
  `dispute_back` → `pop()` (→ order-chat/tracking/receipt) with a `goNamed('shell')`
  cold-deep-link fallback (both registered).

### Endpoints wired (all LIVE on :4010, gateway-contract paths — interceptor rewrites)
- `POST /v1/disputes` → `compliment-service` (open dispute; idempotency-keyed
  `dispute-<deliveryId>`). Body: `{ deliveryId, requestId(=deliveryId, mock conv.),
  reason, comment?, photos[], voiceUrl?, evidence:{ chatSnapshotUrl?, chatMessageCount?,
  timeline[] } }`. Returns `{ id, status:"open", … }`; `id` routes to `/disputes/:id`.
- `GET /v1/chat/jeeb/conversations/by-request/:deliveryId` then
  `GET …/conversations/:conversationId/snapshot` → the auto-attached chat snapshot
  (D53). Best-effort: any failure degrades to empty (never blocks opening).
- `GET /v1/delivery/:deliveryId` → the GPS/status timeline (D53). Same best-effort.

### Exact Semantics identifiers exposed (JM-060 AC, blueprint dispute-open-evidence)
`dispute_reason` (reason picker; per-option `dispute_reason_<damaged|wrongItem|noShow|
fraud|abuse|other>`), `dispute_photos` (section; `dispute_photos_add_cta` +
`dispute_photos_chip_<i>` remove chips, ≤5 enforced in the cubit), `dispute_voice`
(D53 voice evidence toggle: record → stop → captured/re-record),
`dispute_comment_field`, `dispute_evidence_timeline` (auto-attached evidence card)
with `dispute_evidence_chat` (chat-snapshot row) inside it, `dispute_support_link`
(→ support-ticket), `dispute_back` (→ order-chat), `dispute_submit_cta`
(→ POST /v1/disputes → dispute-status), and `dispute_error` (error state).

### GAP — image_picker NOT a pubspec dependency (real picker deferred)
The AC asks for "real image_picker (≤5)". `image_picker` is **referenced only in
comments** across the codebase (chat, mark-delivered) and is **NOT a declared
dependency** in `pubspec.yaml`. To stay build-safe and not edit shared/pubspec
files outside my feature, photo capture is wired through the codebase's existing
`PhotoPickerService` port (`lib/features/photo_attachment/`), defaulting to
`StubPhotoPickerService` (the repo's MVP default — same posture as
`mark_delivered_panel`), injectable on `EscalateScreen({photoPicker})` for tests.
The ≤5 cap + the `dispute_photos`/`dispute_photos_add_cta`/`dispute_photos_chip_<i>`
identifiers are real; only the **device-native byte capture** is stubbed. **REQUEST:**
add `image_picker` to `pubspec.yaml` + bind a real `ImagePicker` impl of
`PhotoPickerService` in DI (cross-codebase D1m / T-mobile-040 follow-up) so the
real-camera AC closes. Voice (D53) uses the **already-real** `record`-backed
`VoiceRecorder` (`sl<VoiceRecorder>()`); `EscalateScreen({voiceRecorder})` defaults
to `FakeVoiceRecorder` for tests.

### l10n KEY REQUEST — dedicated dispute copy missing (coded against reused keys)
ARB is integrator-owned and carries the T-MOB-022 `escalate*` keys + the JM-065
`disputeStatus*` keys, but **no** dedicated `dispute-open-evidence` copy for the
voice control, the auto-attached evidence header, or the chat-snapshot row. The
screen ships NOW reusing the closest EXISTING locale-safe getters (Maestro asserts
on the identifiers above, never visible text — copy-polish only, AC stays green).
Requesting the following dedicated keys (EN + AR, `@`-descriptions):

| intended key | proposed EN value | currently reused getter | element |
|---|---|---|---|
| `disputeVoiceTitle` | "Voice note (optional)" | `voiceRecordingTitle` | `dispute_voice` section title |
| `disputeVoiceRecord` | "Record a voice note" | `voiceRecordingHoldToRecord` | record affordance |
| `disputeVoiceStop` | "Stop recording" | `voiceRecordingReleaseToStop` | stop affordance |
| `disputeVoiceRecorded` | "Voice note attached — tap to re-record" | `voiceRequestRecorded` / `voiceRecordingDiscard` | captured affordance |
| `disputeEvidenceHeader` | "Auto-attached evidence" | `escalateSubtitle` | `dispute_evidence_timeline` header |
| `disputeEvidenceChat` | "Conversation snapshot" | `chatTitle` | `dispute_evidence_chat` row |
| `disputeEvidenceTimeline` | "Delivery timeline" | `trackingTitle` | timeline fallback row |
| `disputeSupportLink` | "Contact support instead" | `disputeStatusSupportCta` | `dispute_support_link` |
| `disputeSubmitCta` | "Submit dispute" | `escalateSubmitButton` | `dispute_submit_cta` |
| `disputeBack` | "Back to chat" | `disputeStatusBackCta` | `dispute_back` |

> Reason options, photos label/count, comment label, submitting/error/confirmation
> copy reuse the already-present, semantically-correct `escalate*` getters — no new
> key needed for those. Timeline step labels reuse `trackingStep{Ordered,Picked,
> InTransit,Completed}`. The permission error reuses `voiceRecordingErrorPermission`.

---

## JM-062 — Logout / Delete Account (W4 engineer)

JM-062 builds the `logout-delete-account` confirm surface and hosts it in
`SettingsScreen._AccountSection` (the gap-map target). It is a **sheet, not a
route** (40_GUARDRAILS_ARCH §5 — `LogoutDeleteConfirmSheet.show(context, mode:)`,
mirrors `CancelRequestSheet`), so **no `GoRoute` request**. Files (all inside the
settings feature — no shared-file edit):
`lib/features/settings/presentation/widgets/logout_delete_confirm_sheet.dart`,
`lib/features/settings/data/dio_account_session_terminator.dart`,
`lib/features/settings/domain/account_session_terminator.dart`, and the
`_AccountSection` rewrite in `presentation/screens/settings_screen.dart`.

### Semantics identifiers exposed (EXACT — 30_BACKLOG JM-062 AC)
- `logout_confirm_cta` — confirm CTA in logout mode → session cleared → splash.
- `delete_confirm_cta` — confirm CTA in delete mode → session cleared → splash.
- `logout_delete_confirm_sheet` — sheet root (signature id).
- `logout_delete_cancel_cta` — dismiss / keep the session.
- `logout_delete_account_root` — the Account-section root (the host surface);
  plus `settings_sign_out_row` / `settings_delete_account_row` on the two rows.

> The blueprint confirm is a **sheet** with the two confirm CTAs carrying the
> exact ids. `OmdsConfirmationDialog` was retired for this surface because it
> renders its confirm `ElevatedButton` internally with no key/identifier hook —
> it cannot carry `logout_confirm_cta` / `delete_confirm_cta` (CTO brief §6.6
> requires the EXACT id on the asserted control). The dialog→sheet swap is
> confined to `_AccountSection`; the row keys QA/tests rely on are unchanged.

### DI — NONE (self-provided over `sl<Dio>()` + `sl<AuthTokenStore>()`)
Per 40_GUARDRAILS_ARCH §5.4 the sheet self-provides
`DioAccountSessionTerminator(sl<Dio>(), sl<AuthTokenStore>())` (both already
registered in `injection_container.dart`), with a fresh
`MockGatewayClient.createDio()` + `AuthTokenStore()` fallback when GetIt is not
configured (dev-seam / deep-link entry) and a constructor `terminator:` test
seam. **No `injection_container.dart` edit requested.**

### EDGE — already wired both ways (no router edit)
- **In (JM-066):** `account-status` `account_status_signout_cta` →
  `goNamed('settings')` (integrator-wired in `account_status_screen.dart`) →
  Account section → sheet. The leg is honest today; JM-062 is its terminal.
- **Out (JM-062 → splash, D5):** on confirm the terminator clears the local
  keystore session, then the sheet refreshes the app-root `SessionCubit?` and
  `context.go('/')` — the `_firstRunRedirect` gate sees
  `isUnauthenticated == true` and routes splash → `/login`. This is the verified
  login pattern run in reverse (registration/login screens, FR-P0-3).

### EDGE REQUEST (owner: JM-035 / customer-profile engineer, not router)
`customer_profile_logout_row` is currently a GUARDED coming-soon
(`_comingSoon`, `// TODO(JM-062)` in `customer_profile_screen.dart`). Now that
the JM-062 host exists, swap it to `context.goNamed('settings')` (the
`logout-delete-account` host) so the profile logout row reaches the confirm
sheet — same target the `account-status` sign-out uses. Touches the
customer_profile feature file (not `app_router.dart`); recorded here so the
W4 integrator / JM-035 owner can land it. Cites: JM-035 AC2 (50_ROUTE_REQUESTS
JM-035 row `customer_profile_logout_row`), JM-062, D5.

### MOCK NOTE (no app-side gap) — logout / delete endpoints are best-effort
`POST /v1/auth/logout` (→ 204, W-1 FLOOR, B1 rewrite) and
`POST /v1/devices/unregister` (push-notification) are fired best-effort by the
terminator and **never block** the local session clear (D5 fail-safe: a dead
token client-side is sufficient; a user trapped in a logged-in shell is not). The
app-client **account-deletion** route (`status → deleted`, D5) is backend-owned
(CTO-D2); the terminator PATCHes `/users/:id/status {status:'deleted'}`
best-effort and no-ops if the route is not served — the local clear + splash is
the load-bearing behaviour either way. No rewrite-map key needed (`/v1/devices`,
`/users`, `/v1/auth/logout` all already mapped).

---

## JM-052 — Earnings & Fees Dashboard (fee-only reframe) (W3 engineer)

Feature: `lib/features/earnings/`. The dashboard is the existing **Earnings-tab
body** — no route to register (`EarningsDashboardScreen`, mounted by
`shell/tabs/earnings_tab.dart`). The engineer REFRAMED the screen fee-only
(D41/D44): replaced the gross/commission/net-payout model (removed) with
`earnings_total_cash` (net off-wallet COD, D41) + `earnings_fees_paid` (captured
10%, D37) + `earnings_net_per_offer` (D44) + `earnings_member_since`, and wired
the two cross-feature links. Domain (`earnings_summary.dart`), repo path
(`dio_earnings_repository.dart`), screen, and a feature-local l10n resolver
(`earnings_dashboard_l10n.dart`) were touched. No `app_router.dart` /
`injection_container.dart` / `shell_screen.dart` / ARB edit.

### EARNINGS PATH REWRITE — CONFIRMED + FIXED (the JM-052 AC's open question)
The JM-052 AC asks to "confirm earnings path rewrite (`/v1/wallet/jeeb/earnings*`
vs `/wallet-service/v1/...`)". Resolved: `DioEarningsRepository` was posting
`/v1/wallet/jeeb/earnings`, which has **NO** rewrite key in
`mock_gateway_client.dart` and never reached the wallet-service (silently fell
through). The ONLY keyed path is `'/v1/jeeb/earnings' → '/wallet-service/v1/jeeb/earnings'`
(already present). Fixed the repo to post the keyed `/v1/jeeb/earnings`
(+ `/v1/jeeb/earnings/export`). Verified live on :4010: `GET
/wallet-service/v1/jeeb/earnings?jeeberId=user-jeeber-002` → `{totalEarnings:{value:10.5,
currency:USD}, items:[…]}`. **No router/gateway edit requested** — the key
already exists; only the app-side path was wrong.

### NO ROUTE REQUEST — both cross-feature links target REGISTERED routes
- `earnings_wallet_link` → `wallet` (wallet-hub, JM-053) via `pushNamed('wallet')`.
- `earnings_activity_link` → `wallet-activity` (wallet-activity-list, JM-055) via
  `pushNamed('wallet-activity')`.
Both names are registered (W2.5/W3-INT batch, `app_router.dart` l.1112/1134), so
these are **real edges, NOT guarded coming-soon** — they close the AP-9-deferred
JM-053 `wallet_earnings_row` landing (its `earnings_total_cash` assertion now has
a real target). Pushed (not `go`) so the back stack returns to the Earnings tab.

### REQUEST (PO-jeeberid; integrator/session, P2) — real session-user-id provider
`shell/tabs/earnings_tab.dart` builds the `EarningsCubit` with a `jeeberId` for
the `?jeeberId=` filter. There is no app-side session-user-id provider yet
(`SessionGate` exposes only a boolean), so it now defaults to the canonical
`SessionSeamBootstrap.jeeberUserId` (`user-jeeber-002`) — the SAME id the JM-047
standalone screen + the `wallet_with_ledger` seam use, and what the Maestro flow
queries. The previous hardcoded `'user-001'` has **no seeded earnings** (empty
dashboard against the live mock). When a real identity provider lands (the
`SessionUserId` JM-036's KYC gate will also need), pass it at the tab
construction site — no screen change. Cites: 50_ROUTE_REQUESTS "JM-047
PO-jeeberid", 62_SEAM_HARNESS W3 `wallet_with_ledger`, JM-052 AC.

### l10n KEY REQUEST — fee-only copy (coded against a feature-local resolver)
The previous gross/commission/net-payout getters (`earningsGross`,
`earningsCommission`, `earningsNet`) are the WRONG economic model (D41/D44) and
must NOT be reused. No dedicated fee-only keys exist. Per the JM-031/045/053
precedent the screen ships via a feature-local EN/AR resolver
(`earnings_dashboard_l10n.dart`) reusing the present `earnings*` getters
(title / period pills / load-error+retry / export button / empty) and supplying
the genuinely-missing strings from a local map. Maestro keys on Semantics ids
only, so this is copy-polish. Requesting (EN + AR + `@`-descriptions) so the
resolver can be deleted:

| intended key | proposed EN value | resolver getter | element (id) |
|---|---|---|---|
| `earningsTotalCashLabel` | "Total cash earned" | `totalCashLabel` | `earnings_total_cash` (D41) |
| `earningsTotalCashHint` | "Net cash you collected directly from customers, off-wallet." | `totalCashHint` | `earnings_total_cash` |
| `earningsFeesPaidLabel` | "Platform fees paid" | `feesPaidLabel` | `earnings_fees_paid` (D37) |
| `earningsFeesPaidHint` | "The flat 10% fee captured from your wallet on offers you won." | `feesPaidHint` | `earnings_fees_paid` |
| `earningsNetPerOfferLabel` | "Net per offer" | `netPerOfferLabel` | `earnings_net_per_offer` (D44) |
| `earningsNetPerOfferHint` | "Average cash you keep per delivery after the 10% fee." | `netPerOfferHint` | `earnings_net_per_offer` |
| `earningsDeliveriesLabel` | "Deliveries" | `deliveriesLabel` | `earnings_deliveries_count` |
| `earningsMemberSinceLabel` | "Member since" | `memberSinceLabel` | `earnings_member_since` |
| `earningsBreakdownTitle` | "Recent deliveries" | `breakdownTitle` | breakdown header |
| `earningsDeliveryRowTitle` | "Delivery {id}" | `deliveryRowTitle` | `earnings_delivery_row_<id>` title |
| `earningsDeliveryRowFee` | "{amount} {currency} fee" | `deliveryRowFee` | row subtitle |
| `earningsWalletLink` | "Open wallet" | `walletLink` | `earnings_wallet_link` |
| `earningsWalletLinkSubtitle` | "Balance, reserves and top-ups." | `walletLinkSubtitle` | `earnings_wallet_link` |
| `earningsActivityLink` | "See all activity" | `activityLink` | `earnings_activity_link` |
| `earningsActivityLinkSubtitle` | "Reserves, fees, refunds and top-ups." | `activityLinkSubtitle` | `earnings_activity_link` |

### MOCK NOTE (backenders, P2) — earnings endpoint is net-only; fee + member-since DERIVED/absent
`GET /wallet-service/v1/jeeb/earnings` returns net off-wallet COD entries only
(`items[].amount.value`, `totalEarnings.value`) — it carries **no** per-delivery
fee and **no** member-since. Per the fee-only reframe (D37) the screen DERIVES
`feesPaid = 10% × cashCollected` per delivery (the COD the Jeeber collects is the
full delivery price; the flat 10% is captured from the wallet). The domain parser
ALSO prefers explicit wire fields if the backend ever surfaces them (`feesPaid` /
`totalFees.value`, `memberSince` / `createdAt`); `earnings_member_since` is hidden
(never fabricated) until the wire carries it. OPTIONAL backend enrichment: add
`feesPaid` + `memberSince` to the earnings body so the display is authoritative
rather than derived. Not blocking — the derivation is exact per D37.

### KNOWN GAP (P2, pre-existing) — `/earnings/export` returns a URL, not PDF bytes
`exportEarningsPdf` uses `_dio.download(...)` (expects a byte stream) but the mock
`GET /v1/jeeb/earnings/export` returns JSON `{url, expiresAt}` (a signed download
link). The path is now correct + the export button compiles/tests green, but the
download saves the JSON envelope, not the PDF. Out of scope for the JM-052
fee-only AC (export is only listed as a touched endpoint). Proper fix: follow the
returned `url` (open externally) OR have the mock stream PDF bytes at this path.
**Owner: backenders / a later export polish pass.**

---

## JM-044r — ROUTE REQUEST: standalone `delivery-register-prompt` route (W2 RD-1 fix)

### Why (66_W2_QA RD-1 / jm-044 AC3 — `gate_register_link` mis-wired)
The offer-KYC gate's `gate_register_link` must land on **`delivery_register_prompt`**
(21_NAV §C JM-044, line 204: `offer-kyc-gate → delivery-register-prompt`). The old
wiring popped back to the DELIVERY tab, but that tab re-resolves its body from the
LIVE `JeeberKycStatusGate`. The gate is reached by a **`pending`** jeeber (the
reconciled JM-044 entry — `kyc_status=pending` → feed; `none` shows the prompt and
hides the feed, so a `none` jeeber can't reach `feed_make_offer_cta` at all), so the
pop rendered **`jeeber_feed_root`**, NOT `delivery_register_prompt` → AC3 FAIL
(RD-1). The `delivery_register_prompt` id is **only** produced by `DashboardTab`'s
`_GateScoped` for `JeeberDeliveryTabDestination.registerPrompt` (status `none`), so
no tab-pop can surface it for a `pending` jeeber.

### What I did in my feature file (coded against the intended name now)
`offer_kyc_gate_screen.dart`: `gate_register_link` → `context.goNamed('delivery-register-prompt')`.
`gate_back_cta` is unchanged (still pops to the DELIVERY tab → `jeeber_feed_root`,
which AC4 expects). The two exits previously SHARED `_popToDeliveryTab` — that was
the conflation that produced RD-1; they now have distinct targets.

### ROUTE REQUEST (integrator-owned `app_router.dart`)
Add the standalone register-prompt route the nav plan already sanctions as an
"optional ADD" (21_NAV line 50: ``| `delivery-register-prompt` | jeeber | (inline …) or `/jeeber/register-prompt` | `delivery-register-prompt` | tab-inline (+ optional **ADD**) |``):

| name | path | screen | renders root id |
|---|---|---|---|
| `delivery-register-prompt` | `/jeeber/register-prompt` | the register-prompt body, **unconditional** (NOT gated by `JeeberKycStatusGate`) | `delivery_register_prompt` |

Builder must render the SAME register-prompt body the DELIVERY tab shows for the
`registerPrompt` destination, wrapped in the `delivery_register_prompt` root
Semantics, with the "Register now" CTA chaining to `jeeber-onboarding` (JM-039) —
i.e. reuse `dashboard_tab.dart`'s `_JeeberHomeHost`/`_GateScoped` register-prompt
path but FORCE `JeeberDeliveryTabDestination.registerPrompt` (do not read the live
gate) so it always shows the prompt regardless of the session's real KYC status.
Sketch:

```dart
GoRoute(
  path: '/jeeber/register-prompt',
  name: 'delivery-register-prompt',
  builder: (context, state) => const JeeberRegisterPromptScreen(),
  // JeeberRegisterPromptScreen wraps JeeberHomeScreen(isRegistered: false,
  // registerCtaIdentifier: 'delivery_register_now_cta',
  // onRegister: () => context.pushNamed('jeeber-onboarding'))
  // in a `delivery_register_prompt` root Semantics — the unconditional twin of
  // the dashboard-tab register-prompt branch, with no JeeberKycStatusGate read.
),
```

If the integrator prefers not to add a new route, the alternative is to make
`gate_register_link` deep-link the DELIVERY tab into a forced-register-prompt state
(e.g. a `?registerPrompt=1` flag on the shell route the tab honours) — but a
standalone route is cleaner and matches the nav plan. **Owner: final-wave integrator.**

### Until the route lands
`goNamed('delivery-register-prompt')` will throw (unknown route) — same "code
against the intended name" contract as every other entry in this doc. No other
behaviour regresses; AC1/AC2/AC4/AC5/AC6 are unaffected (only AC3's target moved).

---

## JM-065 — Dispute Status (dispute-status engineer)

The dispute-status screen (`lib/features/dispute_status/`) was filled in this wave:
`DisputeStatusCubit` + `DisputeStatusState` over the LIVE compliment-service
(`GET /v1/disputes/:disputeId`, mock-ready on :4010 — 42 §4; DI already binds
`DioDisputeStatusRepository`). **No route or DI request needed** — the route
`dispute-status` (`/disputes/:id`) and the `DisputeStatusRepository` → real-Dio
binding are already registered by the integrator (W3+W4 batch). The back edge
routes to `chat-detail` (`/chat/:id`) using the dispute's conversation/order ref;
the support edge routes to `support-ticket` (`/support`) with the order ref as
`extra` (the support screen reads a String `extra`). All already registered.

### Exact Semantics identifiers exposed (JM-065 AC + D30)
`dispute_status_root`, `dispute_status_state` (Open/Resolved), `dispute_status_outcome`
(resolved outcome note — refund/penalty, D2), `dispute_status_evidence`
(auto-attached evidence summary, D53), `dispute_status_support` (→ support-ticket),
`dispute_status_back` (→ order-chat), plus the D30 state ids `dispute_status_loading`,
`dispute_status_error`, `dispute_status_retry_cta`.

### l10n KEY REQUEST — dedicated copy currently missing (coded against existing reused keys)
The integrator batched FIVE `disputeStatus*` keys
(`disputeStatusTitle` / `disputeStatusOpenLabel` / `disputeStatusBody` /
`disputeStatusSupportCta` / `disputeStatusBackCta`), all reused as-is. The Resolved
label, the typed outcome lines (D2), the evidence-summary heading + per-item labels
(D53), and the D30 error/retry copy are supplied by a feature-local resolver
(`dispute_status_l10n.dart`, the `notifications_l10n.dart` precedent). Maestro
asserts on the identifiers above, never visible text — copy is cosmetic; the AC
stays green. Requesting the following dedicated keys (EN + AR, `@`-descriptions),
after which `dispute_status_l10n.dart` folds away:

| intended key | proposed EN value | element |
|---|---|---|
| `disputeStatusResolvedLabel` | "Resolved" | `dispute_status_state` (resolved) |
| `disputeStatusOutcomeHeading` | "Outcome" | `dispute_status_outcome` heading |
| `disputeStatusOutcomeRefund` | "A refund of {amount} was issued to you." | refund outcome line (D2) |
| `disputeStatusOutcomeRefundNoAmount` | "A refund was issued to you." | refund line, no amount |
| `disputeStatusOutcomePenalty` | "A penalty of {amount} was applied." | penalty outcome line (D2) |
| `disputeStatusOutcomePenaltyNoAmount` | "A penalty was applied to the other party." | penalty line, no amount |
| `disputeStatusOutcomeDismissed` | "This dispute was reviewed and dismissed." | dismissed outcome line |
| `disputeStatusOutcomeGeneric` | "This dispute has been resolved." | resolved, untyped outcome |
| `disputeStatusEvidenceHeading` | "Evidence summary" | `dispute_status_evidence` heading (D53) |
| `disputeStatusEvidenceComment` | "Your note" | comment row label |
| `disputeStatusEvidencePhotos` | "{count} photos attached" | photos row (D53) |
| `disputeStatusEvidenceVoice` | "Voice note attached" | voice row (D53) |
| `disputeStatusEvidenceChat` | "Chat thread attached ({count} messages)" | chat-snapshot row (D53) |
| `disputeStatusEvidenceTimeline` | "Delivery timeline attached ({count} steps)" | timeline row (D53) |
| `disputeStatusLoadError` | "Could not load this dispute." | `dispute_status_error` (unknown) |
| `disputeStatusNotFound` | "This dispute could not be found." | `dispute_status_error` (404) |
| `disputeStatusNetworkError` | "No connection. Check your network and try again." | `dispute_status_error` (network) |
| `disputeStatusRetryCta` | "Retry" | `dispute_status_retry_cta` |

> Reason labels (damaged / wrong-item / no-show / fraud / abuse / other) reuse the
> `escalateReason*` getters where the wording matches; the feature-local resolver
> falls back to them so no new reason keys are strictly required.

### BACKEND/SEAM GAP (flagged, not mine to fix) — `dispute_open` journey seam not seeded
The app seam (`lib/core/dev_seam/dev_seam_config.dart`) declares a
`JourneySeed.disputeOpen('dispute_open', '/disputes/dispute-client-001-open')`
value (added in the final-wave SEAM pass) and `seam_landing_test`/`dev_seam_config_test`
pin it, BUT the mock's `JOURNEY_VALUES` in `jeeb-mock-backend/src/fixtures/journey-seed.ts`
does **not** include `dispute_open` and `seedJourney()` has no `dispute_open` case
(verified on HEAD: the list is pending_request…notifications_inbox, no dispute).
So a `jeeb.seam.journey=dispute_open` cold-start pins `/disputes/dispute-client-001-open`
but the dispute row was never seeded → the screen lands on its `dispute_status_error`
(notFound) state, not the intended Open dispute. The screen behaves correctly
(404 → error, by design); the **seam fixture is the gap**. Owner: backenders
(add the `dispute_open` branch seeding `store.disputes['dispute-client-001-open']`
on `req-client-001-accepted`/`conv-journey-accepted`) + the seam agent (add it to
`JOURNEY_VALUES`). Until then the dispute-status Maestro flow must seed the dispute
directly via `POST /__mock/seed/journey` once that branch exists, or deep-link to a
dispute created by the JM-060 escalate flow.

---

## JM-055 — Wallet Activity List (W3 engineer)

`WalletActivityListScreen` (`lib/features/wallet/presentation/wallet_activity_list_screen.dart`)
touches ONLY its own feature files — `lib/features/wallet/{application,data,
presentation}/...`. No `app_router.dart`, `injection_container.dart`,
`shell_screen.dart`, or ARB edit was made. The route (`wallet-activity` →
`/wallet/activity`), the DI binding (`WalletLedgerRepository` →
`DioWalletLedgerRepository`, the LIVE W2m repo), and the four `walletActivity*`
keys were all landed by the W3 integrator; this engineer filled the screen body
(cubit + 4-state machine + infinite scroll + skeletons + typed rows + tap →
transaction-detail).

### NO ROUTE / DI request
- `wallet-activity` (`/wallet/activity`) is REGISTERED (W3-INT) — the screen
  resolves `sl<WalletLedgerRepository>()` (the LIVE `DioWalletLedgerRepository`,
  W2m `GET /v1/jeeb/wallet/ledger`, mock-ready on :4010 per
  42_GUARDRAILS_MOCK "W2 mock closeout"); an unconfigured GetIt (router-resolution
  widget tests) falls back to a new feature-local `EmptyWalletLedgerRepository`
  (presentation FALLBACK only, NEVER DI — mirrors `EmptyNotificationsRepository`,
  JM-057). A constructor `repository:` override is the test seam (§5.4).
- The tap target `transaction-detail` (`/wallet/transactions/:id`, JM-056) is
  REGISTERED — the row pushes `goNamed('transaction-detail', pathParameters:
  {'id': <ledgerRowId>})`. No edge request.

### l10n KEY REQUEST — dedicated ledger copy currently missing (coded against a feature-local resolver)
The W3 integrator batched FOUR wallet-activity keys (`walletActivityTitle` /
`walletActivityEmptyTitle` / `walletActivityEmptyBody` / `walletActivityBackCta`).
The rest of the ledger copy — the seven typed-row labels (Reserve / Fee-won /
Released / Refund / Penalty / Top up / Gift, D41/D1/D37/D2), the load-error +
retry, the load-more-error footer, and the relative timestamp — is NOT yet
present. Per the JM-053 (`wallet_hub_l10n.dart`) / JM-057 (`notifications_l10n.dart`)
precedent, the screen ships now via a feature-local EN/AR resolver
(`lib/features/wallet/presentation/wallet_activity_l10n.dart`) that reuses the
EXISTING four getters and supplies the rest from a local map. Maestro asserts on
`Semantics(identifier:)` only (41_GUARDRAILS_TESTING §4), so this is cosmetic
copy, not a behavioural gap. Requesting these dedicated keys (EN + AR, with
`@`-descriptions) so the resolver can be deleted:

| intended key | proposed EN value | element |
|---|---|---|
| `walletActivityTypeReserve` | "Reserved" | row type label (reserve) |
| `walletActivityTypeFee` | "Fee" | row type label (fee_won) |
| `walletActivityTypeReleased` | "Released" | row type label (released) |
| `walletActivityTypeRefund` | "Refund" | row type label (refund) |
| `walletActivityTypePenalty` | "Penalty" | row type label (penalty) |
| `walletActivityTypeTopup` | "Top up" | row type label (topup) |
| `walletActivityTypeGift` | "Starter credit" | row type label (gift) |
| `walletActivityLoadError` | "Could not load your activity." | `wallet_activity_error` |
| `walletActivityNetworkError` | "No connection. Check your network and try again." | `wallet_activity_error` (network) |
| `walletActivityRetry` | "Retry" | `wallet_activity_retry_cta` / load-more retry |
| `walletActivityLoadMoreError` | "Could not load more." | load-more footer |

> Proposed AR: Reserve="محجوز", Fee="رسوم", Released="تم الإفراج",
> Refund="استرداد", Penalty="غرامة", Top up="شحن رصيد",
> Starter credit="رصيد بداية", LoadError="تعذّر تحميل نشاطك.",
> NetworkError="لا يوجد اتصال. تحقّق من الشبكة وحاول مجددًا.",
> Retry="إعادة المحاولة", LoadMoreError="تعذّر تحميل المزيد.". When landed, swap
> the `_pick` strings in `wallet_activity_l10n.dart` for the getters and delete
> the local map. Cites: JM-055 AC, D41/D1/D37/D2/D30/D73, 40_GUARDRAILS_ARCH §9.

### SEMANTICS IDS exposed (EXACT — 30_BACKLOG JM-055 + the D30 four-state contract)
- `wallet_activity_root` — screen host container (the `wallet_see_all_activity` /
  `earnings_activity_link` nav target).
- `wallet_activity_row_<id>` — per-ledger-row (dynamic id = the W2m row id, e.g.
  `wallet_activity_row_led-seed-fee_won`); typed icon + type label + ref + signed
  amount (`+`/`-`); tap → `transaction-detail`.
- `wallet_activity_loading` — first-load skeletons (D73; never a bare spinner on a
  list, 42 §5.1).
- `wallet_activity_error` + `wallet_activity_retry_cta` — cold-load failure (D30).
- `wallet_activity_empty` — `loaded` + no rows (D30; empty is a sub-state of
  loaded, not a fifth status).
- `wallet_activity_load_more` (in-list next-page skeleton) +
  `wallet_activity_load_more_retry` (soft next-page-failure retry) — the
  infinite-scroll footer (D73). These two are engineer additions beyond the
  backlog AC's named ids, consistent with the D30/D73 contract; presence-only,
  harmless to QA.

### SEAM NOTE (no JM-055 feature-file action) — `wallet_with_ledger`
62_SEAM_HARNESS lands `jeeb.seam.journey=wallet_with_ledger` (jeeber shell;
navigates wallet hub → `wallet_see_all_activity`) and the backend's
`jeeber_wallet_ledger` journey seeds one row of every type (`led-seed-<type>`) for
`user-jeeber-002`. The screen renders whatever the LIVE W2m endpoint returns; the
seam drives the rows once a flow deep-lands `/wallet/activity` (or navigates the
hub). No feature-file change needed.

---

## JM-063 — Support Ticket / Contact Us (W4 engineer)

The `/support` route + `support-ticket` name are already registered
(`app_router.dart`, integrator) and resolve to `SupportTicketScreen`. The screen
is now a full form (category + body + attach + order-link + submit/confirmation
+ dispute link) over a `SupportCubit`/`SupportRepository`. Only the items below
are integrator-owned (l10n + DI + gateway); none block the screen — it compiles,
analyzes clean, and its 14 tests are green.

### S1 DI SWAP + gateway rewrite key (integrator / when S1 is verified)
The backend landed **S1** (`support-service`, `POST/GET /v1/support/tickets`,
live on `:4010` per 42 §"FINAL WAVE … S1"). To wire the screen to the real mock:

1. **DI** (`lib/core/di/injection_container.dart`): swap the INTEGRATOR-STUB
   `SupportRepository` → `DioSupportRepository(sl<Dio>())` (the swap target the
   integrator already left a marker for). The screen needs no change — it
   resolves `GetIt.instance<SupportRepository>()` with a stub fallback.
2. **Gateway rewrite key** (`lib/core/network/mock_gateway_client.dart`
   `_pathToServicePrefix`): add `'/v1/support' → '/support-service/v1/support'`
   (no ordering hazard — `/v1/support` is a sibling of the other `/v1/*` keys).
   `DioSupportRepository` already posts the gateway path `/v1/support/tickets`.

Note: the Dio repo currently sends `{category, body, orderRef?, attachments?}`;
the S1 contract names the order field `orderId` (42 §S1 create body
`{category, body, attachments?, orderId?, subject?, userId?}`). When swapping DI,
either reconcile `orderRef`→`orderId` in `DioSupportRepository.submitTicket`
(one-line change in my feature's data layer — I can take it once DI is swapped)
or have S1 accept both. The screen/cubit are field-name agnostic.

### l10n KEY REQUEST — dedicated support form copy (coded against existing keys)
The form renders with the closest **existing** localized strings, since the
dedicated `support*` form copy is not in the ARB and ARB/`app_localizations.dart`
are integrator-owned. Maestro asserts on `Semantics(identifier:)` only, so this
is cosmetic copy, not a behavioural gap. The integrator already added
`supportTitle` / `supportBody` / `supportSubmitCta` / `supportDisputeLink`.

| intended key | proposed EN value | currently reused | element |
|---|---|---|---|
| `supportCategoryLabel` | "What's this about?" | `customerProfileSectionSupport` ("Support") | `support_category` label |
| `supportCategoryAccount` | "Account" | `customerProfileSectionSupport` | `support_category_account` |
| `supportCategoryPayment` | "Payment" | `navEarnings` ("Earnings") | `support_category_payment` |
| `supportCategoryDelivery` | "Delivery / order" | `navDelivery` ("Delivery") | `support_category_delivery` |
| `supportCategoryKyc` | "KYC / verification" | `kycRejectedAppealCta` | `support_category_kycAppeal` |
| `supportCategoryDispute` | "Dispute" | `disputeStatusSupportCta` | `support_category_dispute` |
| `supportCategoryOther` | "Something else" | `escalateReasonOther` ("Other") | `support_category_other` |
| `supportBodyLabel` | "Describe the issue" | `escalateCommentLabel` | `support_body` |
| `supportOrderLinkLabel` | "Link an order (optional)" | `ordersTitle` | `support_order_link` |
| `supportAttachLabel` | "Attachments (optional)" | `escalatePhotoLabel` | `support_attach` section |
| `supportAttachCta` | "Add attachment" | `photoAttachmentAddLabel` | `support_attach` |
| `supportAttachItem(n)` | "Attachment {n}" | `escalatePhotoAttached(n)` | attachment chip |
| `supportSubmitting` | "Submitting…" | `escalateSubmitting` | `support_submitting` |
| `supportConfirmationTitle` | "Ticket submitted" | `escalateConfirmationTitle` | `support_success` |
| `supportConfirmationBody` | "We'll get back to you within 24h." | `escalateConfirmationBody` | `support_success` |
| `supportConfirmationDone` | "Done" | `escalateConfirmationDone` | `support_success_done_cta` |
| `supportRetryCta` | "Try again" | `supportSubmitCta` ("Submit") | `support_retry_cta` |
| `supportErrorNetwork` / `supportErrorServer` | network / server error copy | `escalateErrorNetwork` / `escalateErrorServer` | `support_error` |

The `support_attach` picker is device-native (image_picker); like
`EscalateScreen._fakePickPhoto` it records a placeholder path so the attach cap
(≤5) + flow are testable now. Wire to `image_picker` in the same follow-up that
covers EscalateScreen.

---

## JM-066 — Account Status (suspended/locked) body fill (W4 engineer)

`lib/features/account_status/` got its full clean-arch body fill
(`domain/account_status.dart` + `account_status_repository.dart`,
`data/dio_account_status_repository.dart` + `stub_account_status_repository.dart`,
`application/account_status_cubit.dart` + `account_status_state.dart`,
`presentation/account_status_screen.dart` + `account_status_l10n.dart`). The
route (`/account-status`, name `account-status` → `const AccountStatusScreen()`)
and the redirect-gate predicate ([AccountStatusGate]) were landed in W0 — **no
`app_router.dart` edit needed** (the screen's new constructor is still `const`
with an optional `repository` test seam, so `const AccountStatusScreen()` still
compiles). The screen reads the blocked status from `GET /users/me` (U1 — the
JM-066 AC's named endpoint; surfaces D5 `status`), renders the D30 four-state
machine, and distinguishes the suspended vs locked banner/reason.

### DI REGISTRATION REQUEST — `AccountStatusRepository` (owner: W4 integrator)
`injection_container.dart`, in the W4 batch (alongside the other W4 Dio repos):
```dart
// JM-066 (D5): blocked-account status read for /account-status.
// GET /users/me (U1 — surfaces status; MockGatewayClient rewrites /users →
// /user-management/users → :4010). LIVE — the status field is already served.
sl.registerLazySingleton<AccountStatusRepository>(
  () => DioAccountStatusRepository(sl<Dio>()),
);
```
- imports: `package:jeeb_mobile/features/account_status/domain/account_status_repository.dart`
  + `.../data/dio_account_status_repository.dart`.
- **Coded against it in the meantime (no DI edit by me):** the screen's
  `_resolveRepository()` mirrors `NotificationsListScreen` — explicit override
  (tests) → `sl<AccountStatusRepository>()` when registered → a LIVE
  `DioAccountStatusRepository(sl<Dio>())` when `Dio` is registered → the inert
  `StubAccountStatusRepository` for bare router-resolution widget tests. So the
  screen is **already data-bound to `:4010` today** even before the registration
  lands; this request only makes the binding canonical (no behaviour change).
- NOTE (authStub caveat, W-1 FLOOR): the mock's `authStub` resolves any bearer to
  `user-client-001` for `/users/me`. The suspended seam seeds the blocked flag the
  GATE reads (`SeededAccountStatusGate`), so reachability is deterministic; the
  per-state reason is best-effort against the stock mock. A future precise read
  would `GET /users/:id` by the persisted userId (the gate's documented path) —
  out of scope for this body fill.

### l10n KEY REQUEST — per-blocked-state banner + reason copy (coded feature-local)
The screen reuses the EXISTING integrator-batched `accountStatus*` getters
(`accountStatusTitle`/`Body`/`SupportCta`/`SignoutCta`) and supplies the
per-state banner + reason + error/retry strings from a feature-local resolver
(`account_status_l10n.dart`), following the JM-008 / JM-031 precedent (ARB is
integrator-owned). Maestro asserts on `Semantics(identifier:)` only (R-B), so
this is cosmetic copy. Requesting dedicated keys (EN + AR, `@`-described) so a
polish pass can delete the resolver:

| intended key | proposed EN value | element / id |
|---|---|---|
| `accountStatusBannerSuspended` | "Your account is suspended" | `account_status_banner` (suspended) |
| `accountStatusBannerLocked` | "Your account is locked" | `account_status_banner` (locked) |
| `accountStatusReasonSuspended` | "Your account is under review. Contact support to resolve it, or sign out." | `account_status_reason` (suspended default) |
| `accountStatusReasonLocked` | "Your account has been locked for security. Contact support to restore access, or sign out." | `account_status_reason` (locked default) |
| `accountStatusLoadError` | "Couldn't load your account status. Check your connection and try again." | `account_status` D30 error |
| `accountStatusRetry` | "Retry" | retry CTA |

Proposed AR: banner suspended="تم تعليق حسابك", locked="تم قفل حسابك"; reasons +
error mirror the EN (the resolver already carries the AR strings). A
server-supplied `statusReason` (if the backend ever sends one) is shown verbatim
in `account_status_reason` and wins over these defaults.

### NEW Semantics ids exposed (engineer additions, D30/D5-consistent)
`account_status_root` (existing), `account_status_support_cta` (AC),
`account_status_signout_cta` (AC) — PLUS `account_status_banner` +
`account_status_reason` (the AC's "status banner + reason", D5). The two new ids
are presence-only display nodes (not in a prior test plan), harmless to QA, added
per the D30 contract / 40_GUARDRAILS_ARCH §3.

### EDGES — both wired in the feature file (no router edit; both targets REGISTERED)
```
EDGE — JM-066 → support-ticket
  control: account_status_support_cta
  call:    context.goNamed('support-ticket')   # /support (JM-063, REGISTERED)
  cites:   JM-066 AC, D76
EDGE — JM-066 → logout-delete-account (host)
  control: account_status_signout_cta
  call:    context.goNamed('settings')          # logout/delete confirm host
                                                 # (JM-062, REGISTERED). On confirm
                                                 # the session clears → gate → splash (D5).
  cites:   JM-066 AC, JM-062, D5
```

### ⚠️ PRE-EXISTING BUILD BREAKS in sibling W4 features (NOT JM-066; block the test binary)
Verifying JM-066 against the FULL test suite is blocked by three **pre-existing,
non-account-status** compile errors in sibling W4 screens (the integrator's
"1350/1350 green" claim does not hold on the current tree). They block any test
that transitively imports the app router. JM-066 was verified instead via an
isolated feature-local widget test (`test/features/account_status/
account_status_screen_test.dart`, **7/7 green** when the siblings are made to
compile) that does NOT import `app_router`. The breaks (owner = each feature's
engineer / W4 integrator):
  1. `lib/features/dispute_status/presentation/dispute_status_screen.dart:137` —
     `return const Semantics(... child: Center(child: OmdsLoadingState()))` —
     `OmdsLoadingState()` is not a const ctor → `const_with_non_const`. Drop the
     `const`. (JM-065)
  2. `lib/features/reviews/data/{stub,dio}_reviews_repository.dart` — call
     `ReviewItem(rating:, comment:, isNew:)` + `ReviewsPage(hideScore:)`, but the
     domain ctor is `ReviewItem(score:, body:)` (no `isNew`) + `ReviewsPage(coldStart:)`.
     Rename `rating→score`, `comment→body`, drop `isNew`, `hideScore→coldStart`. (JM-068)
  3. `lib/features/delivery_man_profile/presentation/widgets/delivery_review_card.dart:13`
     — `DeliveryReviewCard` ctor args don't match its call site. (JM-067)
     ✅ **RESOLVED by the JM-067 build** — the card + list no longer take
     `onHelpful`/`onReply` (D57 removed them), so the ctor and call site now match.
     `flutter analyze lib/features/delivery_man_profile/` → "No issues found".

---

## JM-067 — Jeeber Profile Reviews (delivery-man-profile engineer)

JM-067 is implemented entirely inside `lib/features/delivery_man_profile/`
(no shared-file edits made). Two non-blocking follow-ups for the integrator /
JM-028 owner — neither blocks the JM-067 ACs, all of which are met today:

### EDGE REQUEST — thread the jeeber id from the offer card into the profile extra
  from:    offer-review-list (`lib/features/client_offers/.../client_offers_screen.dart`
           `_openJeeberProfile`, owned by JM-028 — NOT a JM-067 file)
  to:      delivery-man-profile (REGISTERED)
  change:  add `jeeberId: offer.jeeberId` to the `DeliveryManProfileViewData(...)`
           it builds for `extra` (the `Offer` entity already carries `jeeberId`,
           and `DeliveryManProfileViewData` now accepts an optional `jeeberId`).
  why:     so `profile_view_all_reviews` forwards `?jeeberId=` to `reviews-list`
           (JM-068) instead of relying on the seeded-jeeber fallback. WITHOUT
           this the View-all edge still works — `reviews-list` resolves the
           seeded jeeber when no `?jeeberId=` is present — so this is a fidelity
           nicety, not a blocker.
  cites:   JM-067 AC, JM-068, 21_NAV_PLAN §C

### l10n KEY REQUEST — dedicated D59 cold-start "New" copy (polish; coded against existing keys)
The cold-start branch (jeeber with < 5 reviews) currently HIDES the aggregate
score and falls back to the existing `deliveryManProfileReviewsCount` ("{count}
Reviews") for the header meta-row, because no dedicated "New jeeber" / "Not
enough ratings yet" key exists and the ARB + hand-authored `app_localizations.dart`
are integrator-owned. The D59 score-hide AC is fully met with the existing key;
this is cosmetic copy only (Maestro asserts ids, not text).

| intended key | proposed EN value | proposed AR value | currently reused |
|---|---|---|---|
| `deliveryManProfileNewBadge` | "New Jeeber" | "جيبر جديد" | (none — falls back to review-count) |
| `deliveryManProfileScoreHidden` | "Not enough ratings yet" | "لا توجد تقييمات كافية بعد" | `deliveryManProfileReviewsCount` |

> When these land, swap the cold-start `DeliveryManMetaRow.text` in
> `delivery_man_profile_header.dart` (`_RatingRow`, `isColdStart` branch) to
> `l10n.deliveryManProfileScoreHidden` + a `deliveryManProfileNewBadge` chip.

---

## JM-068 — All Reviews List (reviews-list engineer)

JM-068 is implemented entirely inside `lib/features/reviews/` (no shared-file
edits). The route + DI binding the W3+W4 integrator landed are correct and
unchanged; this section records two integrator follow-ups (neither blocks the
JM-068 ACs against the INTEGRATOR-STUB) plus the LIVE-swap contract.

### Already in place (no request — for the record)
- ROUTE `reviews-list` → `/profile/delivery-man/reviews` → `ReviewsListScreen`
  (`app_router.dart`), passing `jeeberId: state.uri.queryParameters['jeeberId']`.
  My screen constructor matches (`ReviewsListScreen({jeeberId, repository})`); a
  missing `?jeeberId=` falls back to the seeded jeeber (`user-jeeber-002`) so a
  cold deep-link / no-extra entry still renders content (R-F).
- DI `sl.registerLazySingleton<ReviewsRepository>(() => const StubReviewsRepository())`
  (`injection_container.dart`, JM-068) — kept as the DI default per CTO-D2 (R1m
  gated). `injection_container_new_repos_test.dart` asserts the stub binding;
  unchanged.

### l10n KEY REQUEST — promote the feature-local `ReviewsL10n` strings to ARB getters
The integrator batched THREE reviews keys (`reviewsTitle` / `reviewsEmptyTitle`
/ `reviewsEmptyBody`), which I reuse. The rest of the list copy lives in a
feature-local resolver `lib/features/reviews/presentation/reviews_l10n.dart`
(the `wallet_activity_l10n` / `notifications_l10n` precedent) until dedicated
keys land. Maestro asserts on `Semantics(identifier:)` only, so this is cosmetic
— swapping to the real getters is a no-call-site-change edit. Proposed keys
(EN / AR already in the resolver):

| intended key | EN | AR |
|---|---|---|
| `reviewsNewBadge` | "New" | "جديد" |
| `reviewsHiddenScoreNote` | "New Jeeber — overall score appears after a few completed deliveries." | "جيبر جديد — تظهر النتيجة الإجمالية بعد إتمام عدد من عمليات التوصيل." |
| `reviewsReportAction` | "Report" | "إبلاغ" |
| `reviewsReportConfirmTitle` | "Report this review?" | "الإبلاغ عن هذا التقييم؟" |
| `reviewsReportConfirmBody` | "We'll send this review to our team to check it against our guidelines." | "سنرسل هذا التقييم إلى فريقنا لمراجعته وفق إرشاداتنا." |
| `reviewsReportSuccess` | "Thanks — this review was reported." | "شكرًا — تم الإبلاغ عن التقييم." |
| `reviewsReportFailure` | "Couldn't report this review. Try again." | "تعذّر الإبلاغ عن التقييم. حاول مجددًا." |
| `reviewsLoadError` / `reviewsLoadMoreError` / `commonRetry` | "Could not load reviews." / "Could not load more." / "Retry" | … |

> When these land, fold the `_pick(...)` strings in `reviews_l10n.dart` into the
> matching `AppLocalizations` getters and delete the resolver (keep `ReviewsL10n`
> as a thin pass-through, or inline the getters).

### DI SWAP (when R1m is verified end-to-end on :4010)
`DioReviewsRepository` is now wired to the REAL R1m contract (corrected this
wave — the integrator stub had the wrong path/fields):
  GET  `/v1/ratings/jeeb/reviews?jeeberId=&page=&pageSize=`  (envelope:
       `items[{id, reviewerFirstName, score, body, reportable, createdAt}]`,
       `coldStart`, `reviewCount`, `averageScore` — D58/D59/D27)
  POST `/v1/ratings/jeeb/reviews/:reviewId/report`            → 202 (D27)
Both rewrite via the EXISTING `/v1/ratings/jeeb` key (no map edit). To go LIVE,
swap the DI registration's `const StubReviewsRepository()` →
`DioReviewsRepository(sl<Dio>())` — no screen/cubit/domain change.

### NOTE — stale `67_W34_TEST_PLAN` path/endpoint coinages superseded
The W34 test plan coined `/profile/delivery-man/:jeeberId/reviews` +
`/v1/ratings/jeeb/jeeber/:jeeberId/reviews`. The SHIPPED contract is the
integrator route `/profile/delivery-man/reviews?jeeberId=` and the backend's
actual R1m `/v1/ratings/jeeb/reviews?jeeberId=` (42_GUARDRAILS_MOCK "FINAL WAVE
… R1m"). The screen + Dio repo code to the shipped contract; QA should key the
jm-068 flow to `?jeeberId=` and the `reviews_*` ids below.
