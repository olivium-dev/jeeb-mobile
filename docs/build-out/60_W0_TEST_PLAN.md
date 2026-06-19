# 60 — Wave 0 Test Plan (Auth + Gates)

> **Author:** QA (Sonnet, test-first). **Date:** 2026-06-18.
> **Status:** ALL flows are RED (test-first). They become GREEN when each JM item ships
> and mock blockers B1–B4 land.
>
> **Run recipe (copy-paste):**
> ```bash
> export JAVA_HOME="$(/usr/libexec/java_home)"
> ~/.maestro/bin/maestro --device emulator-5554 test \
>   -e APP_ID=app.jeeb.mobile.dev \
>   .maestro/flows/<flow>.yaml
> ```
> The `--device emulator-5554` flag is **REQUIRED** — an iPhone sim is also attached
> and Maestro will hang on a device picker if the flag is omitted.

---

## 1. Flow → JM Item Mapping

| JM Item | Flow File | Brief |
|---------|-----------|-------|
| JM-005 | `jm-005-biometric-unlock.yaml` | Biometric lock screen: cold-start routing, authenticate success, password fallback |
| JM-006 | `jm-006-splash-routing.yaml` | Splash router: all 6 session branches (first-launch, customer, jeeber, biometric, logged-out, suspended) |
| JM-007 | `jm-007-login.yaml` | Email+password login, password toggle, forgot/signup/social links, biometric affordance |
| JM-008 | `jm-008-signup.yaml` | Email-first sign-up → phone OTP, password strength, visibility toggle, login link, social CTAs, collision |
| JM-009 | `jm-009-phone-otp.yaml` | 6-digit OTP entry → shell, resend, biometric bypass |
| JM-010 | `jm-010-walkthrough.yaml` | Walkthrough 3 slides, Get Started → sign-up, Skip → sign-up |
| JM-018 | `jm-018-social-login.yaml` | Social CTAs present, social success (no phone) → OTP, 409 → collision sheet |
| JM-019 | `jm-019-collision-prompt.yaml` | Collision sheet: Continue → login, Other email → sign-up |
| JM-020 | `jm-020-recover-password.yaml` | Recover screen: submit → verify-code, sign-up link, back-to-signin link |
| JM-021 | `jm-021-verify-code.yaml` | Verify code: correct → set-password, wrong → error, resend |
| JM-022 | `jm-022-set-password.yaml` | Set password: mode=recovery → login, mode=in-app-social → profile, mismatch error, eye toggles |

---

## 2. Full Semantics Identifier Contract (grouped by screen)

Engineers must implement `Semantics(identifier: '<id>')` on every widget listed below.
All identifiers follow the convention `<screen-id>_<element>` per the backlog identifier
convention (30_BACKLOG.md §Identifier convention).

### 2.1 Splash / Routing (JM-006)
> No new interactive identifiers required. Routing is asserted via destination screen IDs.
> Existing: `_splash_screen`, `_splash_logo`, `_splash_tagline` (already shipped in Phase 2).

### 2.2 Walkthrough Screen (JM-010)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `walkthrough_slide_1` | Slide 1 container | Root of first slide |
| `walkthrough_slide_2` | Slide 2 container | Root of second slide |
| `walkthrough_slide_3` | Slide 3 container | Root of third slide (last) |
| `walkthrough_next_cta` | Next/advance button | Present on slides 1–2; becomes Get Started on slide 3 |
| `walkthrough_get_started_cta` | Get Started button | Visible on last slide only |
| `walkthrough_skip_cta` | Skip button | Present from slide 1; **coined — see §4** |

### 2.3 Login Screen `/login` (JM-007)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `login_email_field` | Email text field | Signature id for login screen |
| `login_password_field` | Password text field | |
| `login_password_visibility_toggle` | Eye icon button | Flips masking |
| `login_continue_cta` | Primary submit button | |
| `login_forgot_password_link` | Forgot password tap target | Routes to `/recover` |
| `login_signup_link` | Sign-up tap target | Routes to sign-up screen |
| `login_social_google` | Google social button | |
| `login_social_facebook` | Facebook social button | |
| `login_social_apple` | Apple social button | |
| `login_biometric_affordance` | Biometric shortcut widget | Only shown if biometric enrolled [D23] |

### 2.4 Sign-Up Screen `/sign-up` (JM-008)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `signup_name_field` | Name text field | Signature id for sign-up screen |
| `signup_email_field` | Email text field | |
| `signup_password_field` | Password text field | |
| `signup_password_visibility_toggle` | Eye icon button | Flips masking |
| `signup_password_strength_hint` | Strength indicator widget | Reflects entered password strength |
| `signup_submit_cta` | Primary submit button | |
| `signup_login_link` | Already have account tap target | Routes to `/login` |
| `signup_social_google` | Google social button | |
| `signup_social_facebook` | Facebook social button | |
| `signup_social_apple` | Apple social button | |

### 2.5 Phone OTP Verification Screen (JM-009)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `phone_otp_input` | OTP input widget (OmdsOtpInput) | 6-digit; auto-submits on completion |
| `phone_otp_verify_cta` | Verify button | Fallback for manual submit |
| `phone_otp_resend_cta` | Resend button | Active only after countdown expires |

### 2.6 Biometric Lock Screen `/lock` (JM-005)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `biometric_unlock_prompt` | Lock screen root / prompt widget | Signature id for `/lock`; no OTP |
| `biometric_unlock_authenticate_cta` | Authenticate button | Triggers platform biometric dialog |
| `biometric_unlock_use_password_link` | Use password tap target | Falls back to `/login` |

### 2.7 Social Login (JM-018)
> Social CTAs on the login screen are covered by `login_social_*` identifiers above.
> The social flow itself is OS-mediated; no additional screen-level Semantics ids are
> required beyond what the login/sign-up screens already expose.

### 2.8 Social Collision Prompt Sheet (JM-019)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `social_collision_sheet` | Bottom sheet root | Signature id for collision prompt |
| `social_collision_continue_cta` | Continue (use password) button | Routes to `/login` |
| `social_collision_other_email_cta` | Use other email button | Routes to sign-up |

### 2.9 Recover Password Screen `/recover` (JM-020)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `recover_email_field` | Email input field | Signature id for `/recover` |
| `recover_submit_cta` | Send code button | Routes to `/recover/verify` |
| `recover_signup_link` | Sign-up tap target | Routes to sign-up |
| `recover_back_to_signin_link` | Back to sign-in tap target | Routes to `/login` |

### 2.10 Verify Recovery Code Screen `/recover/verify` (JM-021)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `verify_code_input` | Code input widget | Email-based recovery; must NOT anchor phone |
| `verify_code_submit_cta` | Submit button | Routes to `/set-password?mode=recovery` |
| `verify_code_resend_cta` | Resend button | Active after countdown expires |
| `verify_code_error` | Inline error widget | Shown on wrong/expired code; **coined — see §4** |

### 2.11 Set Password Screen `/set-password` (JM-022)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `setpw_new_field` | New password field | Signature id; screen used for both modes |
| `setpw_confirm_field` | Confirm password field | |
| `setpw_new_visibility_toggle` | Eye icon for new field | **coined — see §4** |
| `setpw_confirm_visibility_toggle` | Eye icon for confirm field | **coined — see §4** |
| `setpw_submit_cta` | Primary submit button | |
| `setpw_validation_error` | Validation error widget | Mismatch / weak password; **coined — see §4** |

### 2.12 Shell Navigation Tabs (destination assertions used across W0 flows)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `shell_tab_requests` | Requests tab in bottom nav | Customer home destination |
| `shell_tab_delivery` | Delivery tab in bottom nav | Jeeber home destination |

### 2.13 Account Status Screen `/account-status` (JM-066, used as splash branch in JM-006)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `account_status_support_cta` | Contact support CTA | Signature id for `/account-status` |
| `account_status_signout_cta` | Sign out CTA | |

### 2.14 Customer Profile Screen (destination for JM-022 in-app-social mode)
| Identifier | Widget | Notes |
|------------|--------|-------|
| `customer_profile_wallet_chip` | Wallet chip in profile header | Signature id; used as destination assertion for set-password → profile nav |

---

## 3. Navigation Assertion Matrix

| Flow | Tapped / Triggered | Expected Destination ID | JM Dep |
|------|--------------------|------------------------|--------|
| jm-005 | `biometric_unlock_authenticate_cta` success | `shell_tab_requests` | JM-006 |
| jm-005 | `biometric_unlock_use_password_link` | `login_email_field` | JM-007 |
| jm-006 | First launch (no session) | `walkthrough_get_started_cta` | JM-010 |
| jm-006 | Session = customer_logged_in | `shell_tab_requests` | JM-023 |
| jm-006 | Session = jeeber_logged_in | `shell_tab_delivery` | JM-036 |
| jm-006 | Session = biometric_enrolled | `biometric_unlock_prompt` | JM-005 |
| jm-006 | Session = logged_out_returning | `login_email_field` | JM-007 |
| jm-006 | Session = suspended | `account_status_support_cta` | JM-066 |
| jm-007 | `login_continue_cta` (valid creds) | `shell_tab_requests` | JM-023 |
| jm-007 | `login_forgot_password_link` | `recover_email_field` | JM-020 |
| jm-007 | `login_signup_link` | `signup_name_field` | JM-008 |
| jm-008 | `signup_submit_cta` (valid, no collision) | `phone_otp_input` | JM-009 |
| jm-008 | `signup_login_link` | `login_email_field` | JM-007 |
| jm-008 | `signup_submit_cta` (409 collision) | `social_collision_sheet` | JM-019 |
| jm-009 | `phone_otp_input` 6-digit + verify | `shell_tab_requests` | JM-023 |
| jm-010 | `walkthrough_get_started_cta` | `signup_name_field` | JM-008 |
| jm-010 | `walkthrough_skip_cta` | `signup_name_field` | JM-008 |
| jm-018 | `login_social_facebook` (no phone) | `phone_otp_input` | JM-009 |
| jm-018 | `login_social_facebook` (409) | `social_collision_sheet` | JM-019 |
| jm-019 | `social_collision_continue_cta` | `login_email_field` | JM-007 |
| jm-019 | `social_collision_other_email_cta` | `signup_name_field` | JM-008 |
| jm-020 | `recover_submit_cta` | `verify_code_input` | JM-021 |
| jm-020 | `recover_signup_link` | `signup_name_field` | JM-008 |
| jm-020 | `recover_back_to_signin_link` | `login_email_field` | JM-007 |
| jm-021 | `verify_code_submit_cta` (correct) | `setpw_new_field` | JM-022 |
| jm-022 | `setpw_submit_cta` (mode=recovery) | `login_email_field` | JM-007 |
| jm-022 | `setpw_submit_cta` (mode=in-app-social) | `customer_profile_wallet_chip` | JM-035 |

---

## 4. Coined Identifiers (AC ambiguity resolutions)

The following identifiers were coined by QA because the JM item's AC implies the element
but does not name it. Engineers must implement `Semantics(identifier: '<id>')` exactly as
written. These should be reviewed by the PO/tech lead before implementation.

| Coined Identifier | Screen | Reason Coined |
|-------------------|--------|---------------|
| `walkthrough_skip_cta` | Walkthrough | JM-010 AC says "or Skip" without naming the id. Convention: `walkthrough_skip_cta`. |
| `walkthrough_next_cta` | Walkthrough | JM-010 describes slide advancement; no id named. Convention: `walkthrough_next_cta`. |
| `walkthrough_slide_1` / `_slide_2` / `_slide_3` | Walkthrough | JM-010 AC3 implies 3 assertable slides. Convention: `walkthrough_slide_<n>`. |
| `login_social_google` | Login | JM-007 says `login_social_<provider>`; coins the three concrete values. |
| `login_social_facebook` | Login | Same as above. |
| `login_social_apple` | Login | Same as above. |
| `signup_social_google` | Sign-Up | JM-008 says "social row" without naming; coins per `signup_social_<provider>`. |
| `signup_social_facebook` | Sign-Up | Same as above. |
| `signup_social_apple` | Sign-Up | Same as above. |
| `verify_code_error` | Verify Recovery Code | JM-021 AC says "wrong/expired shows error" without naming the error widget. |
| `setpw_new_visibility_toggle` | Set Password | JM-022 AC says "both eye toggles work" without naming them individually. |
| `setpw_confirm_visibility_toggle` | Set Password | Same as above. |
| `setpw_validation_error` | Set Password | JM-022 AC says "Mismatch/strength validation enforced" without naming the error widget. |
| `account_status_signout_cta` | Account Status | JM-066 names `account_status_support_cta`; the sign-out CTA is implied by the AC but not named. |

---

## 5. Mock Blockers (flows remain RED until these land)

| Blocker | Affects | Description |
|---------|---------|-------------|
| B1 | JM-007/008/009 | `/v1/auth/...` rewrite map keys missing from mock gateway (CTO brief §4) |
| B3 | JM-007/008/020/021/022 | App-client login/signup/recover/set-password routes not defined on mock |
| B4 | JM-009 | OTP length contract — mock must return/accept exactly 6 digits |
| B2 | JM-018/019 | `POST /auth-service/auth/social` not yet defined on mock |

---

## 6. Dev Seam Contracts

The flows use `launchApp.arguments` to inject session state via a MethodChannel seam
already established in the Phase 2 guardrails (`lib/core/seams/`). The following seam
keys must be recognized by the dev-flavor seam infrastructure:

| Seam Key | Value(s) | Purpose |
|----------|----------|---------|
| `jeeb.seam.session` | `biometric_enrolled` | Pre-seeds a logged-in user with biometric enrolled |
| `jeeb.seam.session` | `customer_logged_in` | Pre-seeds a logged-in customer |
| `jeeb.seam.session` | `jeeber_logged_in` | Pre-seeds a logged-in jeeber |
| `jeeb.seam.session` | `logged_out_returning` | Pre-seeds a logged-out returning user (session token expired/absent, hasOnboarded=true) |
| `jeeb.seam.session` | `biometric_enrolled_logged_out` | Pre-seeds biometric enrolled but session token absent (shows biometric affordance on login) |
| `jeeb.seam.session` | `suspended` | Pre-seeds `getMe.status = suspended` |
| `jeeb.seam.otp_code` | `"123456"` | Mock OTP fixed response code for auto-approval |
| `jeeb.seam.otp_countdown_expired` | `"true"` | Forces OTP countdown to zero so resend CTA is immediately tappable |
| `jeeb.seam.signup_collision` | `"true"` | Forces 409 response on the signup endpoint |
| `jeeb.seam.social_login` | `facebook_no_phone` | Auto-approves Facebook OAuth, returns user with no phone |
| `jeeb.seam.social_login` | `collision_409` | Auto-approves Facebook OAuth then returns 409 |
| `jeeb.seam.recovery_code` | `"654321"` | Sets the mock recovery code to accept |
| `jeeb.seam.recovery_countdown_expired` | `"true"` | Forces recovery countdown to zero |
| `jeeb.seam.set_password_mode` | `in-app-social` | Launches set-password screen directly with mode=in-app-social |
