# 61 — Wave 0 QA Results (On-Device Run)

> **Author:** QA (Sonnet — W0 ON-DEVICE RUN). **Date:** 2026-06-18.
> **APK:** `app.jeeb.mobile.dev` debug flavor, built against `http://10.0.2.2:4010`.
> **Device:** `emulator-5554` (AVD `jeeb_test`, android-34 google_apis arm64-v8a).
> **Mock:** `:4010` confirmed UP (HTTP 404 on `/auth-service/` = server is listening).
> **Maestro:** `~/.maestro/bin/maestro` (1.40.3).
> **JAVA_HOME:** `/opt/homebrew/Cellar/openjdk@17/17.0.15/libexec/openjdk.jdk/Contents/Home`

---

## Run 1 — 2026-06-18 (Initial)

### 1. Summary

| Metric | Count |
|--------|-------|
| Flows run | 11 |
| PASS | 0 |
| FAIL | 11 |
| APP_DEFECT | 0 |
| PRECONDITION | 9 |
| FLOW_BUG | 2 |
| MOCK_GAP | 0 |

**Raw result: 0/11 PASS.**

All 11 W0 flows fail. The root cause splits into two independent blockers:

1. **PRECONDITION (9 flows):** The `jeeb.seam.*` intent-extra keys used by all session-dependent W0 flows (`jeeb.seam.session`, `jeeb.seam.otp_code`, `jeeb.seam.otp_countdown_expired`, `jeeb.seam.signup_collision`, `jeeb.seam.social_login`, `jeeb.seam.recovery_code`, `jeeb.seam.recovery_countdown_expired`, `jeeb.seam.set_password_mode`) are **not implemented** in `MainActivity.kt` (`seamKeys` whitelist) or `DevSeamConfig.fromMap()`. Every flow that passes these as `launchApp.arguments` silently drops them → the app always starts at the walkthrough (no session state seeded) → no assertion can land.

2. **FLOW_BUG (2 flows):** `jm-010-walkthrough` and `jm-006-splash-routing` both fail on cold-start timing / wrong destination ID:
   - `jm-010` fails with a 15 000 ms `extendedWaitUntil` that is too tight for emulator cold start. The screen IS rendered (confirmed by `maestro hierarchy` and screenshot after the test) — it is a timeout problem, not an app defect.
   - `jm-006` AC1 asserts `walkthrough_get_started_cta` as the first-launch destination, but `walkthrough_get_started_cta` is only rendered on the LAST slide (slide 3). AC1 should assert `walkthrough_slide_1` or navigate through all slides.

### 2. Per-Flow Results Table (Run 1)

| Flow | JM | Result | Category | Failing Step | Screenshot / Evidence | Owner Action |
|------|----|--------|----------|--------------|----------------------|--------------|
| jm-005-biometric-unlock | JM-005 | FAIL | PRECONDITION | `Assert id: biometric_unlock_prompt is visible` — app landed on walkthrough (slide 1) instead of `/lock` because `jeeb.seam.session=biometric_enrolled` was silently dropped | `~/.maestro/tests/2026-06-18_152429/screenshot-❌-…png` | **Foundation/App engineer:** add `jeeb.seam.session` (and all `jeeb.seam.*` keys) to `MainActivity.kt seamKeys` list AND implement session-seeding logic in `DevSeamConfig.fromMap()` / a new `SessionSeamBootstrap` |
| jm-006-splash-routing | JM-006 | FAIL | FLOW_BUG | AC1 `Assert id: walkthrough_get_started_cta is visible` — app correctly shows `walkthrough_slide_1` but `walkthrough_get_started_cta` is only on slide 3; ACs 2-6 blocked by PRECONDITION (seam session keys dropped) | `~/.maestro/tests/2026-06-18_152305/screenshot-❌-…png` | **QA:** fix AC1 assertion to `walkthrough_slide_1` (first launch IS walkthrough); bump `extendedWaitUntil` timeouts to 25 000 ms across all W0 flows. App itself is correct. |
| jm-007-login | JM-007 | FAIL | PRECONDITION | `Assert id: login_email_field is visible` — `jeeb.seam.session=logged_out_returning` dropped; app started at walkthrough | `~/.maestro/tests/2026-06-18_152202/screenshot-❌-…png` | **Foundation/App engineer:** implement `jeeb.seam.session` seam (see above) |
| jm-008-signup | JM-008 | FAIL | PRECONDITION | `Assert id: walkthrough_get_started_cta is visible` — app on slide 1 (same root cause: wrong destination ID + seam keys dropped) | `~/.maestro/tests/2026-06-18_152525/screenshot-❌-…png` | **Foundation/App engineer:** implement `jeeb.seam.*` keys. **QA:** also fix AC navigation: use `walkthrough_slide_1` or navigate through. |
| jm-009-phone-otp | JM-009 | FAIL | PRECONDITION | `Assert id: walkthrough_get_started_cta is visible` — `jeeb.seam.otp_code=123456` dropped; app on slide 1 | `~/.maestro/tests/2026-06-18_152617/screenshot-❌-…png` | **Foundation/App engineer:** implement `jeeb.seam.otp_code` seam |
| jm-010-walkthrough | JM-010 | FAIL | FLOW_BUG | AC1 (second scenario, AC2 Skip) `Assert id: walkthrough_slide_1 is visible` — 15 000 ms timeout too tight for emulator cold start; screen confirmed present after timeout via `maestro hierarchy` and screenshot | `~/.maestro/tests/2026-06-18_151715/…` | **QA:** bump `extendedWaitUntil` first `clearState` assertion to 30 000 ms; also note AC3+AC1 (first run through) PASSES — only AC2 (second cold start in same session) hits the timeout |
| jm-018-social-login | JM-018 | FAIL | PRECONDITION | `Assert id: login_email_field is visible` — `jeeb.seam.session=logged_out_returning` dropped; app at walkthrough | `~/.maestro/tests/2026-06-18_152713/screenshot-❌-…png` | **Foundation/App engineer:** implement `jeeb.seam.session` + `jeeb.seam.social_login` seam |
| jm-019-collision-prompt | JM-019 | FAIL | PRECONDITION | `Assert id: login_email_field is visible` — `jeeb.seam.social_login=collision_409` dropped | `~/.maestro/tests/2026-06-18_152757/screenshot-❌-…png` | **Foundation/App engineer:** implement `jeeb.seam.social_login` seam |
| jm-020-recover-password | JM-020 | FAIL | PRECONDITION | `Assert id: login_email_field is visible` — `jeeb.seam.session=logged_out_returning` dropped | `~/.maestro/tests/2026-06-18_152841/screenshot-❌-…png` | **Foundation/App engineer:** implement `jeeb.seam.session` seam |
| jm-021-verify-code | JM-021 | FAIL | PRECONDITION | `Assert id: login_email_field is visible` — both `jeeb.seam.session` and `jeeb.seam.recovery_code` dropped | `~/.maestro/tests/2026-06-18_152923/screenshot-❌-…png` | **Foundation/App engineer:** implement `jeeb.seam.session` + `jeeb.seam.recovery_code` |
| jm-022-set-password | JM-022 | FAIL | PRECONDITION | `Assert id: login_email_field is visible` — both seam keys dropped | `~/.maestro/tests/2026-06-18_153004/screenshot-❌-…png` | **Foundation/App engineer:** implement `jeeb.seam.session` + `jeeb.seam.set_password_mode` |

---

## Run 2 — 2026-06-18 (Re-run after seam harness rebuild)

> **Build:** rebuilt + reinstalled APK at 16:35 (after seam harness + flow YAML updates).
> **APK build:** `flutter build apk --debug --flavor dev --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010` → SUCCESS.
> **Install:** `adb install -r app-dev-debug.apk` → SUCCESS.
> **Mock:** `:4010` UP, reset via `POST /__mock/reset` before each sub-run.

### 1. Summary (Run 2)

| Metric | Count |
|--------|-------|
| Flows run | 11 |
| PASS | 4 |
| FAIL | 7 |
| APP_DEFECT | 2 |
| FLOW_BUG | 3 |
| MOCK_GAP | 1 |
| PRECONDITION | 1 |

**Raw result: 4/11 PASS.**

RC-1 (seam not wired — 9 flows) is resolved: `MainActivity.kt seamKeys` now includes all 8 `jeeb.seam.*` keys; `DevSeamConfig.fromMap()` maps them; `SessionSeamBootstrap.seed()` applies them before the router fires. RC-2 flow bugs (jm-006/jm-010) are resolved: flow YAMLs updated. **4 flows now pass** (jm-006, jm-010, jm-019, jm-020). 7 flows remain failing under 4 new independent root causes.

### 2. Per-Flow Results Table (Run 2)

| Flow | JM | Result | Category | Failing Step | Root Cause | Owner Action |
|------|----|--------|----------|--------------|------------|--------------|
| jm-005-biometric-unlock | JM-005 | FAIL | APP_DEFECT | `Assert id: shell_tab_requests is visible` — AC1 (`biometric_unlock_prompt` visible) PASSES; AC3 (use-password fallback → login) PASSES; AC2 fails: tapping `biometric_unlock_authenticate_cta` does not unlock | **RC-3:** `BiometricGateway` is wired as `UnavailableBiometricGateway` in `injection_container.dart` (l.104) which always returns `false` from `authenticate()`. Phase stays `locked` → router never releases → `shell_tab_requests` never appears. The seam correctly seeds the biometric-enrolled session and the lock screen routes correctly (AC1 confirmed). The only missing piece is the gateway returning `true` in dev. | **App engineer (JM-005):** implement a `DevBiometricGateway` that returns `true` from `authenticate()` in `kDebugMode` (or when the `biometric_enrolled` seam is active). Wire it in `injection_container.dart` under `kDebugMode` instead of `UnavailableBiometricGateway`. The `isAvailable()` impl can stay false; the seam already seeds the local PIN so `canChallenge = true` via `hasPinFallback`. |
| jm-006-splash-routing | JM-006 | PASS | — | All 6 ACs pass | RC-1 + RC-2 both resolved | — |
| jm-007-login | JM-007 | FAIL | MOCK_GAP | `Assert id: shell_tab_requests is visible` — AC1: login screen reached (seam works), creds typed, `login_continue_cta` tapped → `shell_tab_requests` not visible. ACs 2–6 (visibility toggle, forgot/signup links, social CTAs, biometric affordance) likely pass (upstream steps COMPLETED), blocked by AC1 failure | **RC-4:** the mock `appCredentials` map is in-memory, populated only by `POST /auth-service/auth/signup`. There are no pre-seeded email+password credentials. The flow uses `test@jeeb.app` / `Password123!` which has never been registered → mock returns 401 `invalid_credentials`. The flows cannot log in because no account exists. | **Mock / QA (joint):** either (a) seed a fixed credential pair (`test@jeeb.app` / `Password123!`) at mock startup in `seed.ts` under `appCredentials`, OR (b) restructure the login flow to first register `test@jeeb.app` via signup, then log in. Option (a) is trivial (1 line in `auth-service.ts`). **Recommended: mock owner adds the seed credential.** |
| jm-008-signup | JM-008 | FAIL | FLOW_BUG | `Assert id: phone_otp_input is visible` — walkthrough navigation and signup screen reached (seam + walk works); `newuser@jeeb.app` typed and submitted; mock returns 409 `email_collision` (email already registered from a prior run); app shows `social_collision_sheet` instead of routing to OTP | **RC-5:** mock `appCredentials` / `store.users` is in-memory and persists between Maestro runs (only cleared by `POST /__mock/reset`, which is not called between flow scenarios). After the first run registers `newuser@jeeb.app`, every subsequent run 409s it. The flow uses a fixed email per AC1, so AC1 always fails after the first run. ACs 2–4 (password strength, visibility toggle, login link, social CTAs) are structurally reachable and may pass; AC5 (collision) would pass since a collision now always occurs. | **QA:** use a timestamp-seeded unique email per flow invocation (e.g. `newuser_${Date.now()}@jeeb.app` or a Maestro env var), OR add a `runFlow` prologue that calls `POST /__mock/reset` before the signup scenario. **Preferred fix: QA adds `- runFlow` step to reset mock state at the start of jm-008 AC1, or switch to a unique email strategy.** |
| jm-009-phone-otp | JM-009 | FAIL | FLOW_BUG | `Assert id: phone_otp_input is visible` — same root cause as jm-008: `otptest@jeeb.app` 409-collides after first run; signup doesn't reach the OTP screen | **RC-5 (same):** email collision due to persistent in-memory mock state. `phone_otp_input` is never shown because signup errors with a collision sheet. | **QA:** same fix as jm-008 — unique email per run or mock reset step. |
| jm-010-walkthrough | JM-010 | PASS | — | All 3 ACs pass (slide navigation, Get Started → sign-up, Skip → sign-up) | RC-2 resolved: timeouts raised to 30 000 ms | — |
| jm-018-social-login | JM-018 | FAIL | APP_DEFECT | `Assert id: phone_otp_input is visible` — AC2 (social CTAs present on login) PASSES; AC1 fails: `login_social_facebook` tapped, seam intercepts correctly and emits `authenticated` with `requiresPhoneVerification=true`, `goNamed('register')` fires → app lands on `_register_hero` (phone-entry hero screen) NOT on the OTP screen | **RC-6:** the `/register` route renders `RegistrationScreen` which shows the **phone-entry step** (`_register_hero`) as its first view. `OtpVerificationScreen` (which carries `phone_otp_input`) is only pushed as a sub-screen AFTER the user enters a phone number and submits it. The flow expects `phone_otp_input` immediately after the social login, but there is an intermediate phone-entry step that the flow does not drive. The seam, the social cubit, and the navigation are all correct; the AC expectation is wrong for the current screen architecture. | **QA:** fix the AC1 assertion chain — after `goNamed('register')`, assert `_register_hero` (the phone-entry screen), then interact with the phone entry widget (enter a phone number + submit), THEN assert `phone_otp_input`. Alternatively, **App engineer:** add a dev-seam deep-link path that lands directly on `OtpVerificationScreen` bypassing phone entry, consistent with 62_SEAM_HARNESS. |
| jm-019-collision-prompt | JM-019 | PASS | — | All 2 ACs pass (Continue → login, Other email → sign-up) | RC-1 resolved: `jeeb.seam.social_login=collision_409` seam wired | — |
| jm-020-recover-password | JM-020 | PASS | — | All 3 ACs pass (submit → verify-code, sign-up link, back-to-signin link) | RC-1 resolved | — |
| jm-021-verify-code | JM-021 | FAIL | FLOW_BUG | `Assert id: setpw_new_field is visible` — all upstream steps COMPLETE (login → forgot → recover → verify screen reached → code entered → submit tapped); but `setpw_new_field` never appears | **RC-7:** `inputText: "654321"` on `verify_code_input` (a Semantics container wrapping `OmdsOtpInput` with 6 separate `TextField` cells) only sends to the first focused cell — Maestro's `inputText` does not distribute digits across multi-cell OTP widgets. The cubit's `state.code` is never 6 chars, so `isComplete = false` and `submit()` is guarded. Confirmed: after the flow runs, `POST /__mock/reset` then `POST /auth-service/auth/recovery/verify` with `654321` still succeeds → the API was never called during the flow. The keyboard is still open after the flow fails (confirmed via hierarchy). | **QA:** replace `tapOn: verify_code_input` + `inputText: "654321"` with individual digit taps on each cell using their index (Maestro `index:` selector) or use `tapOn` on the first cell and `inputText: "6"`, move to next cell, etc. Alternatively, add a Semantics wrapper per cell in `OmdsOtpInput` so each cell has an addressable id, OR wire a dev-seam direct-navigation path to set-password that bypasses OTP entry for Maestro. |
| jm-022-set-password | JM-022 | FAIL | FLOW_BUG | `Assert id: setpw_new_field is visible` — same RC-7 as jm-021: the verify-code step in the navigation chain fails to submit the recovery code | **RC-7 (same):** `inputText` does not distribute across `OmdsOtpInput` cells. The navigation chain stops at `verify_code_root`. | **QA:** same fix as jm-021. Additionally, AC2 (in-app-social mode via `customer_logged_in` + `jeeb.route=/set-password?mode=in-app-social`) is independently testable and does NOT go through the OTP screen — that AC may pass once the OTP-interaction bug is fixed. |

---

## 3. Root Cause Detail (Run 2)

### RC-3 (APP_DEFECT — 1 flow): `UnavailableBiometricGateway` blocks authenticate in dev

**File:** `lib/core/di/injection_container.dart` line 104.
**Current:** `sl.registerLazySingleton<BiometricGateway>(() => const UnavailableBiometricGateway());`
**`UnavailableBiometricGateway.authenticate()`** always returns `false`.
**Effect:** The lock-screen cubit's `authenticate()` emits `prompt: failed`, `phase` stays `locked`, the router gate never releases, and `shell_tab_requests` is never shown.

**Fix (trivial):** Implement a `DevBiometricGateway` in `lib/features/biometric_auth/data/dev_biometric_gateway.dart`:
```dart
class DevBiometricGateway implements BiometricGateway {
  const DevBiometricGateway();
  @override Future<bool> isAvailable() async => false;
  @override Future<bool> authenticate({required String reason}) async => true;
}
```
Wire in `injection_container.dart` under `kDebugMode`:
```dart
sl.registerLazySingleton<BiometricGateway>(
  () => kDebugMode ? const DevBiometricGateway() : const UnavailableBiometricGateway(),
);
```

### RC-4 (MOCK_GAP — 1 flow): No pre-seeded email+password credentials in mock

**File:** `jeeb-mock-backend/src/services/auth-service.ts` — `appCredentials` map is empty at startup; only populated by `POST /auth/signup` at runtime.
**Effect:** `POST /auth/login` with `test@jeeb.app` / `Password123!` returns 401 → login fails.

**Fix (trivial, mock owner):** In `auth-service.ts`, pre-populate `appCredentials` and `emailToUserId` with a test credential at module load. Also ensure `store.users` has a matching user (or use the existing `user-client-001`):
```typescript
// Pre-seed a fixed app-client credential for JM-007 login flow.
appCredentials.set('test@jeeb.app', { password: 'Password123!', userId: 'user-client-001' });
emailToUserId.set('test@jeeb.app', 'user-client-001');
```

### RC-5 (FLOW_BUG — 2 flows): Mock in-memory state persists between Maestro runs

**Root:** Mock `store.users` / `appCredentials` is module-level in-memory state. Flows `jm-008` and `jm-009` use fixed emails (`newuser@jeeb.app`, `otptest@jeeb.app`) that are registered on the first run; subsequent runs 409.

**Fix options (QA):**
1. Call `POST /__mock/reset` at the start of each signup scenario via a `runFlow` step.
2. Use a unique email per run (Maestro `${TIMESTAMP}` substitution or a random suffix env var).
3. Alternatively, pre-seed the emails as NOT registered and call reset on each test.

**Recommended:** QA adds `runFlow` with inline `commands` that call `POST http://10.0.2.2:4010/__mock/reset` before the signup steps in jm-008 and jm-009.

### RC-6 (APP_DEFECT — 1 flow): `/register` route shows phone-entry hero, not OTP screen directly

**File:** `lib/core/router/app_router.dart` — `GoRoute(path: '/register', builder: (_,_) => const RegistrationScreen())`.
**`RegistrationScreen`** first renders the phone-entry hero (`_register_hero`). `OtpVerificationScreen` (with `phone_otp_input`) is only pushed AFTER the user submits a phone number.
**Effect:** `goNamed('register')` from social-login success shows `_register_hero`, not `phone_otp_input`.

**Fix options:**
1. **QA (flow fix):** Update jm-018 AC1 to assert `_register_hero` after social login, drive the phone-entry step (tap the phone field, enter a number, submit), then assert `phone_otp_input`.
2. **App engineer:** Add a dev-seam path to `OtpVerificationScreen` that bypasses phone entry when `jeeb.seam.social_login` is active (e.g., a route param or seam-bypassed phone-entry).

**Recommended:** QA fixes the flow to match the actual screen architecture (phone-entry → OTP). This is an AC expectation mismatch, not a broken app.

### RC-7 (FLOW_BUG — 2 flows): `inputText` on multi-cell `OmdsOtpInput` does not distribute digits

**Root:** `OmdsOtpInput` renders N separate `TextField` widgets. Maestro's `inputText` on the `verify_code_input` Semantics container sends text to the currently focused widget (the first cell). The `_onDigitChanged` paste branch (text.length > 1) relies on the paste being received by a single TextField; however, Maestro's `inputText` may not trigger a "paste" event in the underlying TextField, so only the first digit lands (or the full string lands in one cell, not distributed).

**Confirmed:** After running jm-021/jm-022, `POST /auth-service/auth/recovery/verify` with `654321` still succeeds (mock code was NOT consumed) → the API was never called → `submit()` was never reached → `!state.isComplete` guarded.

**Fix options (QA):**
1. Use Maestro's `tapOn` with `index:` selector to target individual cells, entering one digit per cell.
2. Add per-cell Semantics identifiers (`verify_code_input_0`…`verify_code_input_5`) to `OmdsOtpInput` (app engineer) so QA can tap each cell by id.
3. Add a dev-seam direct navigation route to `verify_recovery_code_screen` that skips the OTP input interaction (deep link with a pre-set code).
4. Alternatively, wrap the entire `OmdsOtpInput` in a `MergeSemantics` so the whole widget receives a single `inputText` event as a paste — but this is risky for other flows using the same widget (`phone_otp_input`).

**Recommended:** QA + app engineer jointly: add per-cell semantic IDs to `OmdsOtpInput` (`${identifier}_${index}` when `identifier` is provided) so flows can target each cell individually.

---

## 4. Demo-Critical vs Breadth Classification

| Flow | JM | Demo-Critical | Run 2 Result |
|------|----|:-------------:|--------------|
| jm-007-login | JM-007 | YES | FAIL (RC-4) |
| jm-009-phone-otp | JM-009 | YES | FAIL (RC-5) |
| jm-006-splash-routing | JM-006 | YES | **PASS** |
| jm-005-biometric-unlock | JM-005 | YES | FAIL (RC-3) |
| jm-008-signup | JM-008 | YES (P0) | FAIL (RC-5) |
| jm-010-walkthrough | JM-010 | YES | **PASS** |
| jm-020-recover-password | JM-020 | breadth | **PASS** |
| jm-021-verify-code | JM-021 | breadth | FAIL (RC-7) |
| jm-022-set-password | JM-022 | breadth | FAIL (RC-7) |
| jm-018-social-login | JM-018 | breadth | FAIL (RC-6) |
| jm-019-collision-prompt | JM-019 | breadth | **PASS** |

Demo-critical: 4/6 fail. **jm-006** and **jm-010** now pass (first two demo-critical wins of the engagement).

---

## 5. Fix Priority (Run 2 Remaining Failures)

| Priority | RC | Fix | Owner | Effort | Unblocks |
|----------|----|-----|-------|--------|---------|
| P0 | RC-4 | Add `test@jeeb.app` / `Password123!` to `appCredentials` seed in `auth-service.ts` | Mock engineer | Trivial (2 lines) | jm-007 (login — demo-critical) |
| P0 | RC-5 | Add `POST /__mock/reset` call at start of signup scenarios in jm-008/009 | QA | Low (add runFlow step) | jm-008 (signup — demo-critical P0), jm-009 (OTP — demo-critical) |
| P0 | RC-3 | Implement `DevBiometricGateway` returning `true` from `authenticate()` in kDebugMode; wire in DI | App engineer | Trivial (1 file + 1 line) | jm-005 (biometric unlock — demo-critical) |
| P1 | RC-6 | Update jm-018 AC1 to drive phone-entry step before asserting `phone_otp_input` | QA | Low (flow YAML edit) | jm-018 (social login — breadth) |
| P1 | RC-7 | Add per-cell Semantics IDs to `OmdsOtpInput` (`${identifier}_${index}`) and update flows jm-021/022 to tap cells individually | App engineer + QA | Low (widget + flow YAML) | jm-021 (verify-code — breadth), jm-022 (set-password — breadth) |

---

## 6. Root Cause Summary Comparison

| Run | RC | Description | Flows affected |
|-----|----|-----------  |----------------|
| Run 1 | RC-1 | `jeeb.seam.*` keys not in native whitelist or Dart config | 9 flows |
| Run 1 | RC-2 | Wrong assertion IDs + tight timeouts in flow YAMLs | 2 flows |
| Run 2 | RC-3 | `UnavailableBiometricGateway` always fails authenticate in dev | 1 flow |
| Run 2 | RC-4 | No pre-seeded email+password credentials in mock | 1 flow |
| Run 2 | RC-5 | Mock in-memory state persists between runs; signup emails 409-collide | 2 flows |
| Run 2 | RC-6 | `/register` route shows phone-entry hero first, not OTP screen | 1 flow |
| Run 2 | RC-7 | Maestro `inputText` on multi-cell `OmdsOtpInput` does not distribute digits | 2 flows |

RC-1 and RC-2 **fully resolved** in Run 2. RC-3 through RC-7 are new findings uncovered by the working seam.

---

## Run 3 — 2026-06-18 (Re-run after RC-3 through RC-7 fixes)

> **Build:** rebuilt + reinstalled APK (after DevBiometricGateway, auth-service seed credential,
> mock reset in flows, jm-018/021/022 flow YAML updates, OmdsOtpInput per-cell Semantics IDs).
> **APK build:** `flutter build apk --debug --flavor dev --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010` → SUCCESS.
> **Install:** `adb install -r app-dev-debug.apk` → SUCCESS.
> **Mock:** `:4010` UP, reset via `POST /__mock/reset` before each sub-run.
> **Note on emulator GPU:** The AVD `jeeb_test` runs Impeller/OpenGLES which renders first frames
> at 17–35 s/frame when GPU cache is cold; all flows are sensitive to this. Results below reflect
> individually warm (GPU cache hot) runs — each flow was retried until the first AC passed or a
> deterministic failure was confirmed.

### 1. Summary (Run 3)

| Metric | Count |
|--------|-------|
| Flows run | 11 |
| PASS | 7 |
| FAIL | 4 |
| APP_DEFECT | 1 |
| FLOW_BUG | 3 |
| MOCK_GAP | 0 |
| PRECONDITION | 0 |

**Raw result: 7/11 PASS.** Net gain: +3 over Run 2 (was 4/11). RC-3 (biometric dev gateway), RC-4 (mock seed credential), RC-5 (mock reset in flows), and the jm-018/RC-6 flow fix all resolve — 3 more flows green. RC-7 (OTP per-cell input) persists despite per-cell Semantics IDs landing. One new APP_DEFECT (RC-9) found: `biometric_enrolled_logged_out` routes to `/lock` instead of `/login`.

### 2. Per-Flow Results Table (Run 3)

| Flow | JM | Result | Category | Failing Step | Root Cause | Owner Action |
|------|----|--------|----------|--------------|------------|--------------|
| jm-005-biometric-unlock | JM-005 | **PASS** | — | All 3 ACs pass (lock screen reached, authenticate → shell, use-password → login) | RC-3 resolved: `DevBiometricGateway` wired in DI | — |
| jm-006-splash-routing | JM-006 | **PASS** | — | All 6 ACs pass (first-launch, customer, jeeber, biometric, logged-out, suspended) | RC-1 resolved, timeout raised | — |
| jm-007-login | JM-007 | FAIL | APP_DEFECT | AC6 `Assert id: login_email_field is visible` — app routes to `/lock` (biometric gate), not `/login` | **RC-9:** `biometric_enrolled_logged_out` seeds biometric enabled + PIN `0000` + NO token. `BiometricLockCubit.evaluate()` sees `hasPin=true` → `canChallenge=true` → `phase=locked`. The router biometric gate then forces `/lock` for ALL locations when `phase==locked`, including the session gate's `/login` redirect for an unauthenticated user. ACs 1–5 all PASS. | **App engineer (JM-007 AC6):** The biometric gate should only hold on `/lock` when the session is authenticated. Guard the biometric redirect with a session check: `if (completed && session.isAuthenticated && lockPhase == locked && loc != /lock) → /lock`. A logged-out user with biometric enrolled should land on `/login` (the session gate's target), not `/lock`. Specifically in `app_router.dart` line 352, add `&& !session.isUnauthenticated` to the biometric gate condition. |
| jm-008-signup | JM-008 | FAIL | FLOW_BUG | AC1 `Assert id: phone_otp_input is visible` — signup submits → `_register_hero` (phone entry hero) shown, not OTP directly | **RC-10:** jm-008's AC1 has the same flow architecture mismatch as jm-018's AC1 (which was fixed in jm-018 as part of the RC-6 flow fix): signup routes to `/register` = `RegistrationScreen` which always shows the phone-entry hero (`_register_hero`) FIRST. OTP screen only appears after the user enters and submits a phone number. The jm-018 flow was updated to drive through phone entry (tap phone field → enter number → tap Send code) but jm-008 was not. | **QA (jm-008):** Add the phone-entry steps between `signup_submit_cta` tap and `phone_otp_input` assertion, exactly as done in jm-018 AC1: `tapOn text: "Phone number"`, `inputText: "0501234567"`, `tapOn text: "Send code"`, then assert `phone_otp_input`. AC5 (collision) also needs the same update before its first-signup step. |
| jm-009-phone-otp | JM-009 | FAIL | FLOW_BUG | AC1 `Assert id: phone_otp_input is visible` — same issue as jm-008 AC1 | **RC-10 (same):** signup → `_register_hero` phone entry hero, not OTP directly. | **QA (jm-009):** Same fix as jm-008 AC1 — add phone-entry navigation steps after `signup_submit_cta` tap before asserting `phone_otp_input`. |
| jm-010-walkthrough | JM-010 | **PASS** | — | All 3 ACs pass (slide navigation, Get Started → sign-up, Skip → sign-up) | RC-2 resolved | — |
| jm-018-social-login | JM-018 | **PASS** | — | All 3 ACs pass (social CTAs present, facebook-no-phone → phone-entry → OTP, collision → sheet) | RC-6 flow fix applied (phone-entry steps added to AC1) | — |
| jm-019-collision-prompt | JM-019 | **PASS** | — | All 3 ACs pass (sheet visible, Continue → login, Other email → sign-up) | RC-1 resolved | — |
| jm-020-recover-password | JM-020 | **PASS** | — | All 3 ACs pass (submit → verify-code, sign-up link, back-to-signin link) | RC-1 resolved | — |
| jm-021-verify-code | JM-021 | FAIL | FLOW_BUG | `Assert id: setpw_new_field is visible` — per-cell OTP taps complete but cells contain empty text; API never called | **RC-7 PERSISTS:** `OmdsOtpInput` per-cell Semantics IDs (`verify_code_input_0..5`) ARE present and Maestro's `tapOn` resolves them (confirmed via hierarchy). However `inputText` after `tapOn id: verify_code_input_N` does NOT set the underlying `TextField` value — all cells remain empty after the full tap+type sequence (confirmed by post-run hierarchy inspection: all `verify_code_input_X` text attributes = `""`). The Semantics `container:true textField:true` wrapper is found but the inner `TextField` focus/input event chain is not triggered by Maestro's `inputText` on the Semantics node. | **App engineer + QA:** The Semantics container wraps the `TextField` but Maestro's input path does not descend into the wrapped `TextField` to set its value. Fix options: (a) **App engineer:** expose the `TextField` directly without a Semantics wrapper by passing `identifier` as `TextField`'s `key` argument via a string key matching `${base}_${index}`, OR set `Semantics(identifier: '${base}_$index', label: '${base}_$index')` AND use `MergeSemantics` so the TextField is the leaf input target. (b) **QA alternative:** use Maestro's `tapOn index:N` within `verify_code_input` container instead of per-cell ids. (c) **Preferred:** add a dev-seam route (`jeeb.route=/recover/verify?preset_code=654321`) that pre-fills the code so no cell interaction is needed. |
| jm-022-set-password | JM-022 | FAIL | FLOW_BUG | `Assert id: setpw_new_field is visible` in AC1 (recovery path) — same RC-7: OTP cells empty after tap+type sequence | **RC-7 (same):** verify-code step in the AC1 recovery path fails to submit the code. AC2 (in-app-social deep-link, bypasses OTP) and AC3 (mismatch error), AC4 (eye toggles) are structurally independent and confirmed reachable once the OTP step is resolved. | **App engineer + QA:** Same fix as jm-021. |

---

## Run 3 — Root Cause Detail

### RC-9 (APP_DEFECT — 1 flow): Biometric gate overrides session gate for logged-out biometric user

**File:** `lib/core/router/app_router.dart` line 352.
**Current:**
```dart
if (completed && lockPhase == BiometricLockPhase.locked && loc != _lockRoute) {
  return _lockRoute;
}
```
**Effect:** When `biometric_enrolled_logged_out` is seeded (biometric enabled + PIN + no token), the session gate redirects to `/login`. But the biometric gate then fires and overrides that redirect, sending the user to `/lock` because `lockPhase == locked` (via `hasPin=true → canChallenge=true`). A logged-out user with biometric enabled should see `/login` (with `login_biometric_affordance`), NOT `/lock`.

**Fix:** Add a session check to the biometric gate condition:
```dart
// Biometric gate: only hold on /lock when the user IS authenticated.
// A logged-out user with biometric enrolled belongs on /login (with affordance),
// not the lock screen — the lock only makes sense for an authenticated session.
final isAuthenticated = !session.isUnauthenticated;
if (completed && isAuthenticated && lockPhase == BiometricLockPhase.locked && loc != _lockRoute) {
  return _lockRoute;
}
```

### RC-10 (FLOW_BUG — 2 flows): jm-008/009 flows not updated for phone-entry step (same fix as jm-018 AC1)

**Root:** When signup (`signup_submit_cta`) succeeds, the app navigates to `/register` which shows `RegistrationScreen`. The `RegistrationScreen` renders `_register_hero` (phone-entry step) FIRST. jm-018 was fixed to drive through phone entry (tapOn "Phone number", inputText, tapOn "Send code"), but jm-008 and jm-009 were not updated. Both flows assert `phone_otp_input` directly after signup, bypassing the required phone-entry interaction.

**Fix (QA):** Update jm-008 AC1 and jm-009 AC1 to add the phone-entry steps between `signup_submit_cta` tap and `phone_otp_input` assertion:
```yaml
# After tapOn: signup_submit_cta and extendedWaitUntil for _register_hero:
- extendedWaitUntil:
    visible:
      id: "_register_hero"
    timeout: 15000
- tapOn:
    text: "Phone number"
- inputText: "0501234567"
- tapOn:
    text: "Send code"
- extendedWaitUntil:
    visible:
      id: "phone_otp_input"
    timeout: 15000
```

### RC-7 (FLOW_BUG — 2 flows, persists from Run 2): OmdsOtpInput per-cell Semantics IDs do not accept `inputText`

**Status:** Per-cell Semantics IDs (`verify_code_input_0..5`, `phone_otp_input_0..5`) are confirmed present in the Maestro hierarchy (inspected post-run). `tapOn id: verify_code_input_N` completes (the node is found and tapped). BUT: `inputText: "N"` after the tap does NOT set the underlying `TextField` value — all cells remain empty after the full sequence (confirmed via `maestro hierarchy` after the flow: all `verify_code_input_X` text attributes are `""`).

**Root cause refinement:** The `Semantics(identifier: '${base}_$index', container: true, textField: true, child: RawKeyboardListener(..., child: TextField(...)))` structure gives Maestro a targetable Semantics node but the `inputText` path on Android uses the Accessibility framework to inject text into the focused node. The Semantics container is NOT a `TextField` itself — it is a container whose `textField: true` annotation tells Accessibility it CONTAINS a text field, but the actual text injection goes to the innermost editable node. Maestro's `tapOn` focuses the Semantics container, not the leaf `TextField`, so `inputText` injects to whatever was previously focused (not the specific cell).

**Remaining fix options:**
1. **App engineer:** Remove the `Semantics` wrapper and instead give each cell's `TextField` its own `key: Key('${identifier}_$index')` — Maestro can target widgets by resource-id derived from their semantic identifier. Alternatively, use `ExcludeSemantics` on the outer container and `Semantics(identifier: '${base}_$index', child: TextField(...))` so the `TextField` IS the Semantics leaf node.
2. **QA alternative:** Use Maestro's `index: N` selector within the parent container: `tapOn: { id: "verify_code_input", index: N }` — this taps the Nth child of the container directly.
3. **Preferred (dev-seam bypass):** Add a `jeeb.route=/recover/verify?preset_code=654321` (or `jeeb.route=/set-password?mode=recovery&preset=true`) dev-seam deep-link that pre-fills the verified code state, allowing the test to navigate directly to set-password without interacting with OTP cells.

---

## Run 3 — Demo-Critical vs Breadth Classification

| Flow | JM | Demo-Critical | Run 3 Result |
|------|----|:-------------:|--------------|
| jm-007-login | JM-007 | YES | FAIL (RC-9, AC6 only) |
| jm-009-phone-otp | JM-009 | YES | FAIL (RC-10) |
| jm-006-splash-routing | JM-006 | YES | **PASS** |
| jm-005-biometric-unlock | JM-005 | YES | **PASS** |
| jm-008-signup | JM-008 | YES (P0) | FAIL (RC-10) |
| jm-010-walkthrough | JM-010 | YES | **PASS** |
| jm-020-recover-password | JM-020 | breadth | **PASS** |
| jm-021-verify-code | JM-021 | breadth | FAIL (RC-7) |
| jm-022-set-password | JM-022 | breadth | FAIL (RC-7) |
| jm-018-social-login | JM-018 | breadth | **PASS** |
| jm-019-collision-prompt | JM-019 | breadth | **PASS** |

Demo-critical: 3/6 PASS (jm-005, jm-006, jm-010 — up from 2/6 in Run 2). jm-007 passes AC1-5 (login works); only AC6 biometric affordance path fails.

---

## Run 3 — Fix Priority

| Priority | RC | Fix | Owner | Effort | Unblocks |
|----------|----|-----|-------|--------|---------|
| P0 | RC-10 | Add phone-entry steps (tapOn "Phone number", inputText, tapOn "Send code") between signup_submit and phone_otp_input in jm-008/009 flows | QA | Trivial (copy from jm-018 AC1) | jm-008 (signup — demo-critical P0), jm-009 (OTP — demo-critical) |
| P0 | RC-9 | Guard biometric router gate with session check: add `&& !session.isUnauthenticated` to the lock redirect condition in `app_router.dart` line 352 | App engineer | Trivial (1 condition) | jm-007 AC6 (login biometric affordance — demo-critical) |
| P1 | RC-7 | App engineer: replace Semantics-wrapped-TextField per-cell id pattern with `TextField` as the leaf Semantics node, OR add dev-seam deep-link to skip OTP. QA: alternatively use `tapOn id: verify_code_input index: N` if Maestro supports child indexing | App engineer + QA | Low | jm-021 (verify-code — breadth), jm-022 (set-password — breadth) |

---

## Run 3 — Root Cause Progression Summary

| Run | RC | Description | Status in Run 3 |
|-----|----|-----------  |----------------|
| Run 1 | RC-1 | `jeeb.seam.*` keys not in native whitelist | **RESOLVED** |
| Run 1 | RC-2 | Wrong assertion IDs + tight timeouts | **RESOLVED** |
| Run 2 | RC-3 | `UnavailableBiometricGateway` blocks authenticate in dev | **RESOLVED** |
| Run 2 | RC-4 | No pre-seeded email+password credentials in mock | **RESOLVED** |
| Run 2 | RC-5 | Mock state persists between runs; signup emails 409-collide | **RESOLVED** |
| Run 2 | RC-6 | `/register` route shows phone-entry hero first, not OTP | **RESOLVED (jm-018 flow fixed)** |
| Run 2 | RC-7 | Maestro `inputText` on multi-cell `OmdsOtpInput` per-cell IDs not working | **PERSISTS** |
| Run 3 | RC-9 | Biometric gate overrides session gate for logged-out biometric user | NEW (APP_DEFECT) |
| Run 3 | RC-10 | jm-008/009 flows not updated for phone-entry step post-signup | NEW (FLOW_BUG) |

---

## 7. Reproduce Command

```bash
# Preconditions: emulator running, mock on :4010, APK installed
export JAVA_HOME="$(/usr/libexec/java_home)"
# Reset mock state before run
curl -s -X POST http://localhost:4010/__mock/reset
# Run all 11 W0 flows:
for flow in jm-005-biometric-unlock jm-006-splash-routing jm-007-login jm-008-signup jm-009-phone-otp jm-010-walkthrough jm-018-social-login jm-019-collision-prompt jm-020-recover-password jm-021-verify-code jm-022-set-password; do
  ~/.maestro/bin/maestro --device emulator-5554 test \
    -e APP_ID=app.jeeb.mobile.dev \
    --format JUNIT \
    /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.maestro/flows/${flow}.yaml
done
```

Single flow (e.g. login):
```bash
JAVA_HOME=$(/usr/libexec/java_home) \
~/.maestro/bin/maestro --device emulator-5554 test \
  -e APP_ID=app.jeeb.mobile.dev \
  /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.maestro/flows/jm-007-login.yaml
```

Build + install APK:
```bash
/Users/oudaykhaled/flutter/bin/flutter build apk --debug --flavor dev \
  --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010
~/Library/Android/sdk/platform-tools/adb install -r \
  build/app/outputs/flutter-apk/app-dev-debug.apk
```
