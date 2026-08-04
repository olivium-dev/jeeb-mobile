# Wiring requests — 03 · OTP verify

Source of truth: `docs/redesign-2026-08/per-screen-revised/03-otp-verify.md`.
Screen code (`lib/features/registration/presentation/otp_verification_screen.dart`) is written
**as if every request below has been granted**. Until the l10n block lands, `dart analyze` reports
exactly six `undefined_getter` errors in that file and nothing else — see the apply report.

### l10n
file: lib/l10n/app_en.arb, lib/l10n/app_ar.arb, lib/l10n/app_localizations.dart
need: six new keys for the rebuilt OTP verify screen (headline, split subtitle, inline Edit link, auto-verify hint, resend-in label, backspace a11y label), plus their getters.
exact change:
app_en.arb — add:
```json
"registrationOtpHeadline": "Check your messages",
"@registrationOtpHeadline": {"description": "OTP verify headline; replaces the app-bar title, board copy."},
"registrationOtpSentToLabel": "Code sent to",
"@registrationOtpSentToLabel": {"description": "Subtitle label preceding the phone number on OTP verify."},
"registrationOtpEditPhone": "Edit",
"@registrationOtpEditPhone": {"description": "Inline change-phone link in the OTP subtitle row."},
"registrationOtpAutoVerifyHint": "Verifies automatically",
"@registrationOtpAutoVerifyHint": {"description": "Meta-row hint on OTP verify. Means auto-submit on the 4th typed digit ONLY — the app cannot read SMS; translations must not imply it does."},
"registrationOtpResendInLabel": "Resend in",
"@registrationOtpResendInLabel": {"description": "Label before the m:ss resend countdown on OTP verify; the value is rendered separately in a second ink."},
"registrationOtpKeypadBackspaceA11y": "Delete last digit",
"@registrationOtpKeypadBackspaceA11y": {"description": "Screen-reader label for the in-screen keypad backspace key."}
```
app_ar.arb — add (integrator owns the final AR register):
```json
"registrationOtpHeadline": "تفقّد رسائلك",
"registrationOtpSentToLabel": "أُرسل الرمز إلى",
"registrationOtpEditPhone": "تعديل",
"registrationOtpAutoVerifyHint": "يتم التحقّق تلقائيًا",
"registrationOtpResendInLabel": "إعادة الإرسال خلال",
"registrationOtpKeypadBackspaceA11y": "حذف آخر رقم"
```
app_localizations.dart — add next to the existing `registrationOtp*` getters (immediately after `registrationChangePhone`, ~:569):
```dart
  String get registrationOtpHeadline => _get('registrationOtpHeadline');
  String get registrationOtpSentToLabel => _get('registrationOtpSentToLabel');
  String get registrationOtpEditPhone => _get('registrationOtpEditPhone');
  String get registrationOtpAutoVerifyHint => _get('registrationOtpAutoVerifyHint');
  String get registrationOtpResendInLabel => _get('registrationOtpResendInLabel');
  String get registrationOtpKeypadBackspaceA11y => _get('registrationOtpKeypadBackspaceA11y');
```
why: the rebuilt screen renders all six strings. AR for `registrationOtpAutoVerifyHint` must stay "verifies automatically" — never wording that implies SMS reading (no-fabrication rule applied to copy). `registrationOtpTitle`, `registrationOtpSubtitle`, `registrationOtpResendIn` and `registrationChangePhone` become orphan getters — leave them (arbs are append-only; orphans are warn-only per `qa/t-mob-fix-002/l10n_parity_check.sh:29`).

**Verified locally:** this exact patch was applied to a scratch copy of the three files, after which
`dart analyze lib/features/registration/presentation` reported **No issues found** and
`flutter test test/otp_verification_screen_test.dart` was **10/10 green**. The three files were then
restored byte-identical (they are NOT part of this lane's diff).

### cross-feature
file: .maestro/flows/jm-009-phone-otp.yaml
need: the OTP digit-entry block must drive the new in-screen keypad — the code cells are no longer TextFields, so `tapOn` + `inputText` per cell can no longer deposit digits (and the block is already stale: it addresses 6 cells, only 4 exist since kCustomerOtpLength = 4).
exact change: replace lines 126-146 (the RC-7 comment block plus the six `tapOn: phone_otp_input_N` / `inputText` pairs) with:
```yaml
# Enter the 4-digit OTP on the in-screen keypad (redesign 03: the code cells
# are display-only; kCustomerOtpLength = 4). Auto-verifies on the 4th digit.
- tapOn:
    id: "phone_otp_keypad_1"
- tapOn:
    id: "phone_otp_keypad_2"
- tapOn:
    id: "phone_otp_keypad_3"
- tapOn:
    id: "phone_otp_keypad_4"
```
Keep the conditional `phone_otp_verify_cta` runFlow block (149-155) unchanged as a harmless fallback. All `phone_otp_input` visibility asserts (jm-009:121/219/239/257, jm-018:92) and jm-051:81 survive untouched.
why: without this, jm-009's OTP entry silently types nothing and AC1 fails at the verify step.
