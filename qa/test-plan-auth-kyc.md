# Test Plan — Authentication and KYC Verification

Maps to: **FR-1.x** (authentication), **FR-2.x** (KYC), **US-1.x**, **US-2.x**
Backend: `auth-service` (phone+OTP, social, JWT) + back-office KYC triage
Owner: Mobile QA + Security + Backend QA
Status: Draft v1 — JEEB-108

## 1. Scope

End-to-end coverage of every identity-related flow from first launch to
role-switching as an approved Jeeber.

In scope:
- Phone number validation (Lebanese +961, 8-digit mobile format)
- OTP send → countdown → verify → lockout lifecycle
- Social sign-in (Apple, Google): returning vs first-time user
- JWT access/refresh token management (planned — `DioClient` wiring)
- Dual-role registration and role switching (Client ↔ Jeeber)
- KYC document capture (national ID front/back, selfie)
- KYC wizard step gating and vehicle registration
- KYC status transitions (notSubmitted → pending → approved / rejected)
- KYC rejection → resubmission flow
- Photo compression and size-limit enforcement
- Role eligibility gate: KYC approval required for Jeeber role

Out of scope:
- Handover OTP (delivery verification) — covered in `test-plan-otp.md`
- Biometric app lock — separate test plan
- Payment / wallet flows — covered in `test-plan-settlement.md`
- Push notification delivery — covered in `test-plan-chat.md`

## 2. Architecture under test

```
[Mobile app]                              [auth-service]                    [back-office]
    │                                          │                                │
    │── POST /api/jeeb/auth/otp/send ─────────►│                                │
    │◄─ 200 (OTP dispatched via SMS) ──────────│                                │
    │                                          │                                │
    │── POST /api/jeeb/auth/otp/verify ───────►│                                │
    │◄─ 200 { access_token, refresh_token } ───│                                │
    │                                          │                                │
    │── POST /api/jeeb/auth/social ───────────►│                                │
    │◄─ 200 (returning) / 202 (link phone) ────│                                │
    │                                          │                                │
    │── POST /api/jeeb/auth/token/refresh ────►│                                │
    │◄─ 200 { access_token } ──────────────────│                                │
    │                                          │                                │
    │── POST /v1/kyc/submit (multipart) ──────►│───── triage queue ────────────►│
    │◄─ 200 { status: pending } ───────────────│                                │
    │                                          │                                │
    │── GET  /v1/kyc/status ──────────────────►│◄── decision (approve/reject) ──│
    │◄─ 200 { status, rejection_reason? } ─────│                                │
```

Current MVP state:
- `RegistrationCubit` drives the phone+OTP flow via `OtpGateway` (ships with `FakeOtpGateway`, dev code `123456`)
- `NativeSocialAuthGateway` hits `POST /api/jeeb/auth/social` for Apple/Google
- `KycWizardCubit` drives the 3-step wizard via `KycGateway` (ships with `FakeKycGateway`)
- `DioClient` has **no** auth interceptor / token persistence yet — JWT wiring is planned
- `RoleCubit` persists last role in `SharedPreferences`; `RoleEligibilityCubit` gates Jeeber switch on KYC

## 3. Phone number validation

### 3.1 Input rules

| Constant | Value | Source |
|----------|-------|--------|
| Country code | `+961` (fixed, non-editable) | `LebanesePhoneField` |
| Digit count | 8 | `RegistrationState.phoneDigitCount` |
| Input filter | digits only | `FilteringTextInputFormatter.digitsOnly` |
| Hint | `70 123 456` | `LebanesePhoneField` |

### 3.2 Happy path

| # | Input | Expected |
|---|-------|----------|
| 1 | `70123456` (8 digits) | `isPhoneValid == true`; "Request OTP" enabled |
| 2 | `03123456` (landline prefix) | Accepted — length-only validation; backend may reject |
| 3 | `76987654` | Valid; canonical form `+96176987654` |

### 3.3 Rejection / edge cases

| # | Input | Expected |
|---|-------|----------|
| 1 | `7012345` (7 digits) | `isPhoneValid == false`; button disabled |
| 2 | `701234567` (9 digits — paste) | Clamped to first 8 digits `70123456` |
| 3 | `` (empty) | Button disabled |
| 4 | `7012345a` (non-digit) | Non-digit stripped; treated as 7 digits → disabled |
| 5 | `+96170123456` (pasted with country code) | Non-digits stripped → `96170123456` → clamped to `96170123` (wrong); verify UI prevents prefix entry |
| 6 | Whitespace `  70123456  ` | Stripped by digits-only filter → valid |
| 7 | Arabic-Indic numerals `٧٠١٢٣٤٥٦` | Rejected by `\D` regex — digits-only filter; field stays empty |

### 3.4 Accessibility & RTL

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Arabic locale | `+961` prefix remains LTR; digit field LTR; label/hint Arabic RTL |
| 2 | VoiceOver / TalkBack | Field announced as "Phone number, text field, +961" with digit content |
| 3 | Large font / Dynamic Type | Field does not truncate or overlap prefix |

## 4. OTP send / verify flow

### 4.1 Constants

| Parameter | Value | Source |
|-----------|-------|--------|
| OTP length | 6 digits | `RegistrationState.otpLength` |
| Countdown | 60 s | `RegistrationState.otpValiditySeconds` |
| Max failed attempts | 3 | `RegistrationState.maxFailedAttempts` |
| Lockout duration | 300 s (5 min) | `RegistrationState.lockoutDurationSeconds` |
| Dev code (fake) | `123456` | `FakeOtpGateway.acceptedCode` |

### 4.2 Happy path — OTP send + verify

| # | Step | Expected |
|---|------|----------|
| 1 | Enter valid 8-digit phone, tap "Request OTP" | `isSendingOtp` briefly true → step transitions to `otpEntry`; countdown starts at 60 |
| 2 | Countdown ticks every 1 s | UI shows "Resend in 0:59", "0:58", … |
| 3 | Enter correct 6-digit OTP | `canVerify == true`; verify button enabled |
| 4 | Tap Verify | `isVerifyingOtp` briefly true → step transitions to `verified` |
| 5 | Post-verify | `OnboardingCubit.complete()` called; `context.go('/')` navigates to shell |
| 6 | Countdown cancelled on success | Timer stopped; no lingering ticks |

### 4.3 Wrong code

| # | Scenario | Expected |
|---|----------|----------|
| 1 | First wrong code | `failedAttempts = 1`; OTP cleared; `otpNotice = invalidCode`; "Wrong code" displayed |
| 2 | Notice clears on edit | Typing a new digit sets `otpNotice = none` |
| 3 | Second wrong code | `failedAttempts = 2`; same behaviour |
| 4 | Third wrong code (= `maxFailedAttempts`) | `lockoutRemainingSeconds = 300`; OTP cleared; countdown switches to lockout mode |
| 5 | During lockout | `setOtp` is no-op (`isLocked == true`); verify button disabled; `changePhone` blocked |
| 6 | Lockout countdown | Ticks from 300 → 299 → … → 1 → 0 |
| 7 | Lockout expires | `failedAttempts` reset to 0; step returns to `phoneEntry`; user can request fresh OTP |

### 4.4 OTP expiry

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Countdown reaches 0 without verification | `otpNotice = expired`; `canVerify == false` (countdown 0 blocks it) |
| 2 | Resend available after expiry | `canResendOtp == true` (not locked, not sending, countdown 0) |
| 3 | Resend resets countdown to 60 | OTP cleared; new 60 s timer starts |

### 4.5 Change phone

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Tap "Change number" from OTP step | Timer cancelled; step → `phoneEntry`; OTP cleared |
| 2 | Change phone during lockout | No-op — user must wait for lockout to expire |

### 4.6 Network / transport errors

| # | Scenario | Expected |
|---|----------|----------|
| 1 | `sendOtp` throws | `isSendingOtp` reset to false; exception rethrown for UI error handler |
| 2 | `verifyOtp` throws | `isVerifyingOtp` reset to false; exception rethrown; attempt NOT incremented |
| 3 | Timeout on OTP request (>15 s) | Dio timeout → same as transport error |

## 5. Social sign-in (Apple / Google)

### 5.1 Happy path — returning user

| # | Step | Expected |
|---|------|----------|
| 1 | Tap Apple/Google button | `socialPending = provider`; native sheet appears; other social button disabled |
| 2 | Complete native sheet (returning user) | Backend returns 200; `isReturningUser = true` |
| 3 | Cubit transitions | Step → `verified`; `socialPending` cleared; OTP countdown cancelled; navigate to shell |

### 5.2 Happy path — first-time user

| # | Step | Expected |
|---|------|----------|
| 1 | Complete native sheet (new user) | Backend returns 202; `isReturningUser = false` |
| 2 | Cubit transitions | Step stays `phoneEntry`; `linkedSocialIdentity` set with provider data |
| 3 | User enters phone + OTP | Standard phone+OTP flow proceeds with social identity attached |
| 4 | On verify success | Both phone and social identity linked on backend |

### 5.3 Cancellation and errors

| # | Scenario | Expected |
|---|----------|----------|
| 1 | User dismisses native sheet | `SocialAuthCancelledException` caught; `socialPending` cleared; no error shown |
| 2 | Network error during social auth | `socialPending` cleared; exception rethrown for UI handler |
| 3 | Tap social while OTP sending | No-op (guard: `isSendingOtp`) |
| 4 | Tap social while verifying OTP | No-op (guard: `isVerifyingOtp`) |
| 5 | Tap social while locked out | No-op (guard: `isLocked`) |
| 6 | Tap Apple while Google pending | No-op (guard: `isSigningInWithSocial`) |

### 5.4 Platform-specific

| # | Platform | Scenario | Expected |
|---|----------|----------|----------|
| 1 | iOS | Apple Sign In | ASAuthorizationController presented; SIWA privacy relay email possible |
| 2 | Android | Google Sign In | One Tap UI or legacy Google Sign-In sheet |
| 3 | iOS | Google Sign In | GIDSignIn presented |
| 4 | Android | Apple Sign In | Web-based Apple auth (if supported) or hidden button |

## 6. JWT token management (planned — integration readiness)

`DioClient` currently has no auth interceptor. These tests apply when
the `auth-service` integration ticket lands. Test readiness documented
now to avoid gaps.

### 6.1 Token lifecycle

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Successful OTP verify returns tokens | `access_token` + `refresh_token` persisted to `flutter_secure_storage` |
| 2 | Social returning-user returns tokens | Same persistence path |
| 3 | Authenticated request | `Authorization: Bearer {access_token}` injected by Dio interceptor |
| 4 | Access token expired (401 response) | Interceptor calls `/auth/token/refresh` with refresh token |
| 5 | Refresh succeeds | New access token persisted; original request retried transparently |
| 6 | Refresh fails (refresh token expired) | User logged out; navigate to `/register` |
| 7 | Concurrent 401s | Only one refresh in flight; queued requests wait for the single refresh |
| 8 | Token cleared on logout | Both tokens removed from secure storage |

### 6.2 Security

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Tokens stored in `flutter_secure_storage` | Keychain (iOS) / EncryptedSharedPreferences (Android); never in plain prefs |
| 2 | Tokens not in logs | Dio `LogInterceptor` must redact `Authorization` header |
| 3 | Tokens not in Sentry breadcrumbs | Verified by inspecting captured events |
| 4 | JWT `alg:none` from server | Client rejects; does not trust unverified tokens |
| 5 | Clock skew > 5 min | Token expiry check uses server-provided `exp`, not local clock math |

### 6.3 Performance

| Metric | Target | Measurement |
|--------|--------|-------------|
| Auth API response (login) | < 200 ms p99 | curl timing from staging |
| Token refresh | < 100 ms p99 | curl timing from staging |
| OTP SMS delivery | < 5 s from request to device | Measured via Twilio webhook timestamp delta |

## 7. Role switching (Client ↔ Jeeber)

### 7.1 Architecture

- `UserRole` enum: `client`, `jeeber`
- `RoleCubit`: persists `app.role` in `SharedPreferences`
- `RoleEligibilityCubit`: emits `RoleEligibility(isJeeberKycApproved, hasActiveDelivery)`
- `RoleToggle` widget: guards switch on eligibility

### 7.2 Happy path

| # | Step | Expected |
|---|------|----------|
| 1 | Fresh install, post-registration | Role defaults to `client` |
| 2 | Tap Jeeber on `RoleToggle` (KYC approved, no active delivery) | `RoleCubit` emits `jeeber`; shell switches to Jeeber tabs (Dashboard/Earnings/Chat/Profile) |
| 3 | Tap Client on `RoleToggle` | `RoleCubit` emits `client`; shell switches to Client tabs (Home/Orders/Chat/Profile) |
| 4 | Kill app, relaunch | Last role restored from `SharedPreferences` |

### 7.3 KYC gate

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Tap Jeeber toggle, KYC NOT approved | Dialog: "Complete your Jeeber verification"; CTA navigates to `/profile/kyc` |
| 2 | Tap Jeeber toggle, KYC pending | Same dialog — pending is not approved |
| 3 | Tap Jeeber toggle, KYC rejected | Same dialog — rejected is not approved |
| 4 | Complete KYC → approved → tap Jeeber | Role switches to Jeeber without dialog |

### 7.4 Active delivery block

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Jeeber has active delivery, taps Client toggle | Blocked; explanation shown: "Complete your current delivery first" |
| 2 | Client has active order, taps Jeeber toggle | Allowed (Client orders don't block switching) — OR blocked if product decides otherwise |
| 3 | Active delivery completes | Toggle unblocks on next eligibility check |

### 7.5 Profile tab role rows

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Profile → tap "Switch to Jeeber" | Calls `setRole(jeeber)` directly; same KYC eligibility gate applies |
| 2 | Profile → tap "Switch to Client" | Calls `setRole(client)` directly; always allowed |

## 8. KYC document capture and upload

### 8.1 Wizard steps

```
Step 1: ID Card (front + back)  →  Step 2: Selfie  →  Step 3: Vehicle  →  Submit  →  Status
```

### 8.2 Step 1 — ID card

| # | Step | Expected |
|---|------|----------|
| 1 | Tap "Capture front" | Camera opens via `PhotoPickerService` |
| 2 | Take photo | Photo compressed via `HalvingPhotoCompressor`; tile shows thumbnail |
| 3 | Tap "Capture back" | Second camera capture |
| 4 | Both captured | `canAdvanceFromId == true`; "Next" enabled |
| 5 | Only front captured | `canAdvanceFromId == false`; "Next" disabled |
| 6 | Re-capture front | New photo replaces old; attachment ID increments |

### 8.3 Step 2 — Selfie

| # | Step | Expected |
|---|------|----------|
| 1 | Arrive at selfie step | Liveness prompt card displayed |
| 2 | Tap "Capture selfie" | Front camera opens |
| 3 | Selfie captured | `canAdvanceFromSelfie == true`; "Next" enabled |
| 4 | Tap "Next" without selfie | No-op (guard in `goToVehicle`) |

### 8.4 Step 3 — Vehicle

| # | Step | Expected |
|---|------|----------|
| 1 | Select vehicle type | `VehicleType` set (scooter / car / bicycle / onFoot) |
| 2 | Enter registration/plate | Free-text field; required for submit |
| 3 | Submit with empty registration | `KycWizardError.vehicleRegistrationRequired` emitted; inline error shown |
| 4 | Typing after error | Error clears on input (`setVehicleRegistration` clears the specific error) |
| 5 | Registration with only whitespace | Treated as empty (`trim().isEmpty`); submit blocked |

### 8.5 Photo capture errors

| # | Scenario | Expected |
|---|----------|----------|
| 1 | User cancels camera | `KycWizardError.pickCancelled` → toast; no photo set |
| 2 | Camera permission denied | `KycWizardError.permissionDenied` → settings prompt |
| 3 | Camera unavailable (simulator) | `KycWizardError.unavailable` → generic error |
| 4 | Compressed photo > `maxSizeBytes` | `KycWizardError.compressionFailed` → "Photo too large" |
| 5 | Capture while already capturing | No-op (guard: `state.isCapturing`) |

### 8.6 Wizard navigation

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Back from selfie step | Returns to ID step |
| 2 | Back from vehicle step | Returns to selfie step |
| 3 | Back from ID step | No-op (first step) |
| 4 | Back from submitting | No-op (blocked during submission) |
| 5 | Back from status | No-op (status is terminal view) |

## 9. KYC submission and status transitions

### 9.1 State machine

```
notSubmitted ──submit()──► pending ──back-office──► approved
                                │                         │
                                └──back-office──► rejected │
                                                     │     │
                                          resubmit() │     │
                                                     ▼     │
                                              notSubmitted  │
                                                     │     │
                                                   submit() │
                                                     ▼     │
                                                  pending   │
```

### 9.2 Submit flow

| # | Step | Expected |
|---|------|----------|
| 1 | All fields valid, tap Submit | Step → `submitting`; `KycGateway.submit()` called |
| 2 | Gateway returns success | Step → `status`; submission updated with `pending` status + `submittedAt` |
| 3 | Gateway throws | Step → `vehicle` (rollback); `KycWizardError.submitFailed` emitted |
| 4 | Double-tap submit | Second tap is no-op (guard: `step == submitting`) |
| 5 | Submit with missing ID | No-op (guard: `canAdvanceFromId` check) |
| 6 | Submit with missing selfie | No-op (guard: `canAdvanceFromSelfie` check) |
| 7 | Submit with missing vehicle type | No-op (guard: `vehicleType == null`) |

### 9.3 Status screen (cold start)

| # | Scenario | Expected |
|---|----------|----------|
| 1 | `loadStatus()` → `notSubmitted` | Wizard opens at step 1 (ID) |
| 2 | `loadStatus()` → `pending` | Status view: "Under review" with submission timestamp |
| 3 | `loadStatus()` → `approved` | Status view: "Approved ✓"; `RoleEligibilityCubit.setKycApproved(true)` |
| 4 | `loadStatus()` → `rejected` | Status view: rejection reason displayed; "Resubmit" CTA |

### 9.4 Rejection reasons

| Reason | UI copy | Recovery |
|--------|---------|----------|
| `idUnreadable` | "ID photos were not clear enough" | Re-capture both sides |
| `selfieMismatch` | "Selfie does not match ID photo" | Re-capture selfie |
| `vehicleDocumentMissing` | "Vehicle registration is incomplete" | Re-enter vehicle details |
| `expired` | "ID document has expired" | Use a valid, non-expired ID |
| `other` | "Verification could not be completed" | Contact support or retry |

### 9.5 Resubmission

| # | Step | Expected |
|---|------|----------|
| 1 | Tap "Resubmit" after rejection | Wizard resets to step 1; submission reset to `notSubmitted`; all captures cleared |
| 2 | Complete wizard again | New submission goes through standard submit path |
| 3 | Resubmit after approval | Not available — approval is terminal (no resubmit CTA shown) |

## 10. Security tests

Per `auth-jwt-pitfalls`, `owasp-api-top-10-2023`.

| # | Attack surface | Test | Expected |
|---|---------------|------|----------|
| 1 | OTP brute-force | Script 10000 codes against verify endpoint | Rate limit + lockout; at most 3 attempts succeed before lock |
| 2 | OTP enumeration | `sendOtp` with non-existent phone | Same 200 response (no user-existence leak) |
| 3 | OTP replay | Capture a valid verify; replay after success | Rejected — OTP is single-use |
| 4 | Social token reuse | Replay a captured Apple/Google Id token | Rejected by auth-service (nonce / token binding) |
| 5 | KYC photo exfiltration | Verify KYC photos are not stored in app sandbox unencrypted | Photos live only in cubit state (`Uint8List` in memory); no file-system persistence |
| 6 | KYC multipart injection | Malformed multipart body to KYC submit | Server rejects with 400; no crash |
| 7 | Phone in logs | Check `flutter logs` during registration | Phone number redacted in production builds |
| 8 | OTP in logs | Check Sentry breadcrumbs and `LogInterceptor` | OTP never logged; Dio interceptor excludes OTP fields |
| 9 | JWT in app-switcher | iOS/Android task-switcher screenshot | Sensitive screens blurred / `FLAG_SECURE` |
| 10 | Role elevation | Modify `SharedPreferences` `app.role` to `jeeber` manually | App checks `isJeeberKycApproved` at runtime; Jeeber features fail gracefully |

## 11. Backend smoke tests (curl) — pre-mobile gate

```bash
# 1) OTP send
curl -sf -X POST "$API/api/jeeb/auth/otp/send" \
  -H "Content-Type: application/json" \
  -d '{"phone":"+96170123456"}' \
  -w 'http=%{http_code} time=%{time_total}\n' | tee otp-send.log
# Expect: http=200 time < 0.200

# 2) OTP verify (wrong code)
curl -sf -X POST "$API/api/jeeb/auth/otp/verify" \
  -H "Content-Type: application/json" \
  -d '{"phone":"+96170123456","code":"000000"}' \
  -w 'http=%{http_code}\n' | grep -q 401

# 3) OTP verify (correct code)
curl -sf -X POST "$API/api/jeeb/auth/otp/verify" \
  -H "Content-Type: application/json" \
  -d '{"phone":"+96170123456","code":"$OTP_CODE"}' \
  | jq -e '.access_token and .refresh_token'

# 4) Social auth (Google returning user)
curl -sf -X POST "$API/api/jeeb/auth/social" \
  -H "Content-Type: application/json" \
  -d '{"provider":"google","token":"$GOOGLE_ID_TOKEN"}' \
  -w 'http=%{http_code}\n' | grep -q 200

# 5) Token refresh
curl -sf -X POST "$API/api/jeeb/auth/token/refresh" \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"$REFRESH_TOKEN"}' \
  | jq -e '.access_token'

# 6) KYC submit status
curl -sf -H "Authorization: Bearer $JWT" \
  "$API/v1/kyc/status" \
  | jq -e '.status | IN("notSubmitted","pending","approved","rejected")'
```

Assert all timing values with `curl-w-format-timing-assertions`:
- OTP send: `time_total < 0.200`
- OTP verify: `time_total < 0.200`
- Token refresh: `time_total < 0.100`
- KYC status: `time_total < 0.200`

## 12. Performance criteria

| Metric | Target | Method |
|--------|--------|--------|
| OTP SMS delivery | < 5 s from API call to SMS arrival | Twilio delivery webhook timestamp delta |
| Auth API (login via OTP) | < 200 ms p99 | `oha -n 1000 -c 10` against staging |
| Auth API (social) | < 300 ms p99 | curl timing (native sheet latency is platform-dependent) |
| Token refresh | < 100 ms p99 | `oha -n 1000 -c 10` against staging |
| KYC submit (with photos) | < 2 s p99 | curl multipart upload with 3 × 500 KB images |
| KYC status fetch | < 200 ms p99 | curl timing |
| Photo compression (per image) | < 500 ms on Tier 1 device | `Stopwatch` in debug build; Macrobenchmark for CI |
| Registration screen cold start | < 300 ms to first interactive frame | Flutter `Timeline` trace |

## 13. Test inventory

### 13.1 Unit (`test/`)

**Existing:**
- `registration_cubit_test.dart` — phone validation, OTP send/verify, countdown, lockout, social
- `native_social_auth_gateway_test.dart` — Apple/Google HTTP calls
- `onboarding_cubit_test.dart` — complete/reset lifecycle
- `role_cubit_test.dart` — persist/restore role
- `role_eligibility_cubit_test.dart` — KYC gate, active delivery
- `kyc_wizard_cubit_test.dart` — capture, steps, submit, resubmit, errors

**Needed (auth-service integration):**
- `auth_interceptor_test.dart` — token injection, 401 → refresh → retry, concurrent refresh
- `token_storage_test.dart` — secure storage read/write/delete
- `phone_validator_test.dart` — Lebanese format edge cases (Arabic-Indic, paste, prefix)

### 13.2 Widget (`test/`)

**Existing:**
- `registration_screen_test.dart` — phone entry, OTP entry, lockout banner rendering
- `role_toggle_test.dart` — KYC dialog, role switch, active delivery block
- `kyc_wizard_screen_test.dart` — step transitions, capture tiles, status views
- `kyc_submitting_view_test.dart` — spinner state
- `kyc_liveness_prompt_card_test.dart` — copy rendering
- `kyc_id_alignment_guide_test.dart` — overlay rendering

**Needed:**
- `lebanese_phone_field_test.dart` — prefix lock, digit filter, max length, RTL
- `social_sign_in_section_test.dart` — button states, spinner, disabled during pending
- `kyc_status_view_test.dart` — all 4 status states + rejection reasons
- `kyc_vehicle_step_test.dart` — vehicle type selection, registration validation

### 13.3 Integration (`integration_test/`)

**Needed:**
- `auth_flow_happy_test.dart` — phone → OTP → verified → shell (Patrol with mocked gateway)
- `auth_flow_social_test.dart` — social sign-in → verified → shell
- `auth_flow_lockout_test.dart` — 3 wrong OTPs → lockout → wait → unlock → retry
- `kyc_flow_happy_test.dart` — ID → selfie → vehicle → submit → pending status
- `kyc_flow_rejection_test.dart` — submit → rejected → resubmit → pending
- `role_switch_flow_test.dart` — register → KYC approved → toggle Jeeber → toggle Client

### 13.4 E2E — Maestro (`qa/maestro/`)

**Existing:**
- `auth/register_phone_happy.yaml` — full phone+OTP flow
- `auth/otp_lockout.yaml` — lockout cycle
- `auth/role_toggle_kyc_gate.yaml` — toggle blocked without KYC
- `kyc/submit_happy.yaml` — full wizard flow

**Needed:**
- `auth/social_apple_happy.yaml` — Apple sign-in (requires real device, Maestro Cloud)
- `auth/social_google_happy.yaml` — Google sign-in
- `auth/register_phone_change.yaml` — change phone mid-OTP
- `kyc/rejection_resubmit.yaml` — rejected → resubmit flow
- `kyc/camera_permission_denied.yaml` — permission denial handling
- `role/switch_client_jeeber.yaml` — full role switch cycle

### 13.5 Security harness (`qa/security/scripts/`)

**Existing:**
- `03-jwt-tamper.sh` — JWT manipulation tests

**Needed:**
- `01-otp-brute-force.sh` — rate-limit and lockout verification
- `02-otp-enumeration.sh` — no phone existence leak
- `04-social-token-replay.sh` — stale token rejection
- `05-kyc-photo-exfil.sh` — verify no photos on disk post-flow

## 14. Test data

Seeded in `jeeb-infrastructure/seeds/qa-auth-kyc.sql`:

| Fixture | State |
|---------|-------|
| `qa-user-new` | No account; phone `+96170000001` available for registration |
| `qa-user-registered` | Completed phone+OTP; role `client`; KYC `notSubmitted` |
| `qa-user-kyc-pending` | KYC submitted; status `pending`; role `client` |
| `qa-user-kyc-approved` | KYC `approved`; role `jeeber`; eligible for deliveries |
| `qa-user-kyc-rejected` | KYC `rejected`; reason `idUnreadable`; role `client` |
| `qa-user-social-google` | Google-linked returning user; role `client` |
| `qa-user-social-apple` | Apple-linked returning user; role `client` |
| `qa-user-locked-out` | 3 failed OTP attempts; lockout expires in 5 min |
| `qa-user-active-delivery` | Jeeber with active delivery; role switch blocked |

## 15. Acceptance gate

A build ships to staging only when **all** of the following are true:

- All §3–§5 functional cases pass on Tier 1 devices (iPhone 15, Pixel 8).
- All §8–§9 KYC cases pass including every rejection reason.
- All §10 security cases pass; no credentials in any log surface.
- Backend smoke pack §11 green for ≥ 5 consecutive runs.
- Performance targets in §12 met on staging environment.
- Unit + widget test coverage for `registration/` and `kyc/` features ≥ 80% line.
- Zero P0/P1 bugs open against auth or KYC.
- Crash-free rate for registration + KYC screens ≥ 99.9% over prior 24 h.

## 16. Risks and assumptions

- **Assumption**: JWT token management will use `flutter_secure_storage` with Keychain/EncryptedSharedPreferences. If the team picks a different storage mechanism, §6.2 tests must be updated.
- **Assumption**: `auth-service` returns standard JWT with `exp` claim. If it returns opaque tokens, the refresh logic changes (no client-side expiry check).
- **Risk**: `FakeOtpGateway` accepts `123456` in dev builds. If a production build accidentally ships with the fake gateway registered, anyone can authenticate. Verify DI registration is build-flavour gated.
- **Risk**: Phone validation is length-only (8 digits). Lebanese mobile prefixes (03, 70, 71, 76, 78, 79, 81) are not validated. Backend must reject landline numbers (01, 04, 05, 06, 07, 08, 09) or the app will show OTP step for numbers that cannot receive SMS.
- **Risk**: KYC photos are held in cubit state as `Uint8List`. Three high-res photos (~2–5 MB each pre-compression) may cause memory pressure on low-end devices. Monitor OOM crashes on Tier 2 devices.
- **Risk**: `RoleEligibilityCubit.setKycApproved(true)` is never called from production code paths yet — only from tests. The wiring from backend KYC status → eligibility cubit is a gap that must be closed before the role-switch gate works in production.
- **Risk**: Social auth uses native platform plugins (`sign_in_with_apple`, `google_sign_in`). Plugin updates may break the authentication flow silently. Pin plugin versions and test on each OS upgrade.
- **Assumption**: OTP SMS delivery < 5 s target assumes Twilio as the SMS provider in the Lebanon region. If a different provider or route is used, latency may vary.
