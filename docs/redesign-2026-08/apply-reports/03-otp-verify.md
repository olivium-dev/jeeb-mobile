# Apply report — 03 · OTP verify

Instruction set: `docs/redesign-2026-08/per-screen-revised/03-otp-verify.md`
Status: **applied** (with the two declared deviations below and the l10n hand-off).

## Files touched (this lane only)

| File | Change |
|---|---|
| `lib/features/registration/presentation/otp_verification_screen.dart` | rebuilt (409 → 476 LOC) |
| `test/otp_verification_screen_test.dart` | 2 edits + 4 new tests |
| `docs/redesign-2026-08/wiring/03-otp-verify.md` | created (l10n + Maestro) |

**No new widget files were created.** The instruction set (§C tasks 1–2) predates Wave 1 and told
this lane to build `OtpCodeCells` / `OtpNumericKeypad` feature-local. The 🛑 STOP block in
`00-MIGRATION-PLAN.md` §4 overrides that: the kit exists, so the screen imports
`JeebCodeCells.input74` and `JeebNumericKeypad` from `lib/core/widgets/jeeb/` instead. Same for the
top bar (`JeebTopBar.back`) and the CTA (`JeebCtaButton.primary`) — the instruction's
`OMDSAppBar`-deletion / `OmdsPrimaryButton`-retention text was likewise written kit-less.

## Kit widgets consumed

`JeebTopBar.back` · `JeebCodeCells.input74` · `JeebNumericKeypad` · `JeebCtaButton.primary` ·
`JeebCtaButton.accentText`.

## Frozen inventory — all preserved byte-identical

Identifiers: `phone_otp_root`, `phone_otp_back_cta` (→ `JeebTopBar.identifier`),
`phone_otp_input` (screen-owned wrapper), `phone_otp_input_0..3` (→ `JeebCodeCells.cellIdentifier`),
`phone_otp_verify_cta`, `phone_otp_change_phone_cta`, `phone_otp_resend_cta`.
New: `phone_otp_resend_timer`, `phone_otp_keypad_0..9`, `phone_otp_keypad_backspace`.

Keys: all eight — `registration.otpBack` (now on `JeebTopBar`), `.otpField` (on `JeebCodeCells`),
`.verify` (on `JeebCtaButton`), `.changePhone`, `.resend`, `.resendCountdown`, `.attemptsLeft`,
`.lockoutBanner`.

Untouched behaviour: `_maybeAutoSubmitSeamCode`, `_otpErrorCopy`, the `BlocConsumer` step switch,
the `/v1/auth/otp/*` contract. No cubit / state / domain / data / router / DI / theme / kit / arb
file was edited.

## What changed visually

- `appBar: OMDSAppBar` deleted → in-body bare `JeebTopBar.back` circle (no title; the board's
  tpl-112 row holds only the circle).
- New `h1` headline + the three-ink `Code sent to <phone> · Edit` run; the docked
  "Change phone number" text button is gone, its id/key re-homed onto the inline **Edit** link.
- `OmdsOtpInput` deleted — **no `TextField` remains on this screen, so the OS keyboard can never
  open here.** `JeebCodeCells.input74` (h74 / r16 / `surfaceContainerHigh`, 29-w800 digits, 2px
  accent frame + static 2×30 caret on the active cell) is fed by a screen-owned `String`.
- New meta row under the cells: auto-verify hint (or the error, rendered **exactly once**) at the
  start; `Resend in 0:42` in **m:ss** at the end, swapping to the orange resend CTA at zero.
- `Spacer()` → the empty band is real emptiness; `JeebNumericKeypad` docked at the bottom with its
  own 0/20/30 gutter, hidden during lockout alongside the CTA/resend/attempts.
- Keypad drives entry: auto-verify fires on the 4th digit; a rejected code clears the buffer.
- `_LockoutBanner` restyled to `titleProminent` / `body` (error quartet colours unchanged).
- `SafeArea → LayoutBuilder → SingleChildScrollView → ConstrainedBox(minHeight) → IntrinsicHeight`
  so the `Spacer` is legal and the layout degrades to scrolling at 200 % text scale.

## Declared deviations

1. **The Verify CTA is retained; the board draws none.** `registration_screen_test.dart:308`
   asserts `Key('registration.verify')` findsOneWidget and that file belongs to lane 02, so this
   lane cannot remove it; removing the only explicit submit control is also a WCAG 3.2.2 hazard.
   It is the screen's only navy fill and its only shadow (`JeebShadows.ctaNavy`, via the kit).
2. **Periwinkle → `onSurfaceVariant` on every muted label** (subtitle, `·`, auto-verify hint,
   "Resend in", attempts). `test/core/theme/color_role_contrast_test.dart:129-139` exists to stop
   periwinkle-on-white body text (≈2.2–3.8:1). Instruction §A-cut-1, binding.
3. `h1` is 24/w700 vs the board's 26/w700/−0.6 (plan R3: heavier, not bigger).
4. `displayPhone` renders `+961 71123456`, not the board's grouped `+961 3 123 456`
   (`LebanonPhone` is shared with screen 02 — instruction C4).
5. The inline **Edit** link is an `InkWell + Text` with 4pt vertical padding rather than
   `JeebCtaButton.accentText`: the kit CTA's 48pt a11y height would inflate the board's 22px
   subtitle run by ~26px. The **Resend** CTA, which sits alone at the meta-row end, *does* use
   `JeebCtaButton.accentText`.

## Gates

| Gate | Result |
|---|---|
| `dart analyze lib/features/registration/presentation` | 6 errors, all `undefined_getter` on the six as-if-granted l10n keys, all in this file. Nothing else. (The 5 further errors in that directory are lane 02's `registration_screen.dart`, same as-if-granted pattern.) |
| `flutter test test/otp_verification_screen_test.dart` | **10/10 green** — verified by applying the l10n wiring patch to a scratch copy of the three l10n files, running, then restoring them byte-identical (`diff -q` clean; they are NOT in this lane's diff). |
| `bash tool/check_design_tokens.sh` | 0 violations under `lib/features/registration/`. The 8 pre-existing failures are in settlement / wallet / location / reviews. |
| `flutter test test/features/batch_b_additional_ac_tests.dart test/registration_screen_test.dart` | Cannot compile **today** — blocked by other lanes' in-flight as-if-granted edits (`registration_screen.dart`, `social_sign_in_section.dart`, `dio_client_home_repository.dart`), not by this file. The two OTP assertions they own are satisfied by construction: the error renders exactly once (meta row) and the lockout branch drops the CTA. |

## Test delta (this lane's file only)

- `:70-73` `tester.widget<OmdsOtpInput>` → `tester.widget<JeebCodeCells>` (`.length` still `== 4`).
  The instruction named `OtpCodeCells`; the kit type supersedes it.
- `:79` `find.textContaining('60')` → `find.textContaining('1:00')` (m:ss).
- Added: keypad fills + auto-verifies on the 4th digit · backspace corrects before submit ·
  a rejected code clears the cells · `ar`/RTL smoke (cells and keypad pinned LTR, back arrow
  mirrors to `Icons.arrow_forward`).
- Added a `JeebNumericKeypad` findsNothing assertion to the existing lockout test.
- Nothing was deleted or weakened.

## Hand-off

Apply `docs/redesign-2026-08/wiring/03-otp-verify.md` (six l10n keys + getters, and the jm-009
Maestro keypad block). `AppLocalizations` here is hand-authored, so the ARB entries alone are not
enough — the six getters must land in the same commit.
