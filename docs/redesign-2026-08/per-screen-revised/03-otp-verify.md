# 03 · OTP verify — REVISED instruction set (authoritative)

**Target file:** `lib/features/registration/presentation/otp_verification_screen.dart` (409 LOC).
**Verdict: rebuild** — confirmed. The Opus proposal was verified against the render, the HTML
(tpl 107–147), the note, the current source, the OMDS clone, the tests, the Maestro flows and the
migration plan. It is largely sound; the corrections below are **binding** where they differ.

Wave 5. `lib/core/widgets/jeeb/` is **empty today** — this lane may not create files there. Kit
consumption (`JeebTopBar` / `JeebCodeCells` / `JeebNumericKeypad` / `JeebCtaButton`) is built
**feature-local to the kit spec** and swapped in the Wave-5 sweep, exactly as the revised 02 doc
established. Do not wait on Wave 1, and do not file kit wiring requests — they are not in the
`route|di|l10n|theme|cross-feature` taxonomy.

---

## A. Deltas from the Opus proposal (audit trail — implementer follows THIS doc)

**Cut (scope creep / rule violations):**
1. **Every periwinkle-on-white ink — OVERRULED, not flagged.** The proposal maps the subtitle
   label, the `·`, "Verifies automatically", the "Resend in" label and the attempts label to
   `colorScheme.onSecondaryContainer` (periwinkle `#777FC0`) on the white surface.
   `test/core/theme/color_role_contrast_test.dart:129-139` exists specifically to guard against
   "anyone reverting the label roles back to onSecondaryContainer on a light surface" (an
   owner-reported AA defect, ~2.2–3.8:1), and plan §4.1 says periwinkle is "NEVER body text on
   white". All of these use `colorScheme.onSurfaceVariant` (the AA-safe muted ink — same call the
   02 reviewer made). The proposal's ":313/:352 brown → periwinkle" row is CUT: those stay
   `onSurfaceVariant`.
2. Kit wiring requests W1–W4/W6 (`JeebTopBar` nullable title, `JeebCodeCells` flex/identifier/
   hasError, `JeebNumericKeypad` LTR grid) — **CUT as requests.** The kit does not exist; the specs
   fold into the feature-local widgets below and travel to the kit owner via the Wave-5 sweep.
3. W5 `JeebInfoNote` error tone — **CUT.** The proposal itself marked it optional; keep
   `_LockoutBanner` restyled in place. It already benefits from the Wave-0 error quartet
   (`app_theme.dart:121-123`, verified: `errorContainer #FFDAD6` / `onErrorContainer #410002`).
4. `resizeToAvoidBottomInset: false` — **CUT.** After the rebuild no `TextField` exists on the
   screen, so the OS keyboard can never open; the property is dead code.
5. `_enteredCode` → `_code` rename — **CUT.** Pure churn; the seam and all tests are name-agnostic.
   Keep `_enteredCode`.
6. `textField: true` on the per-cell Semantics — **CUT** (the OMDS contract sets it because its
   cells ARE TextFields, `omds_otp_input.dart:289-297`; the new cells are not editable, claiming
   `textField` would lie to TalkBack). Per-cell ids survive as plain identifier leaves.

**Corrected (factually off):**
1. **"All eight `Key`s are test-pinned" — false.** Verified by grep across `test/`: only FIVE are
   (`registration.otpField`, `.verify`, `.resend`, `.resendCountdown`, `.lockoutBanner`).
   `registration.otpBack`, `.changePhone`, `.attemptsLeft` have **zero** test references. All
   eight still survive (continuity is cheap), but do not treat the last three as load-bearing.
2. **The CTA-retention justification was overstated.** jm-009's tap is a *conditional* `runFlow`
   (`when: visible:` — it silently skips if the CTA is gone) and `jm-051:81`'s `assertNotVisible`
   is on the rating screen (passes either way). The REAL pins: `registration_screen_test.dart:308`
   asserts `Key('registration.verify')` findsOneWidget on arrival — and that file is **owned by
   lane 02** (its revised doc §C-6 claims it), so this lane cannot edit it even if the owner chose
   deletion. Retention is therefore AFFIRMED, now for the right reasons: one hard test pin outside
   our ownership + WCAG 3.2.2. The deviation stays declared (§C task 8).
3. Test-fix type: `tester.widget<JeebCodeCells>` → **`tester.widget<OtpCodeCells>`** — a private
   or non-existent kit type cannot be named from a test; the cells widget must be a *public
   feature-local* class (below).
4. Orphaned l10n keys are **four**, not three: `registrationOtpTitle`, `registrationOtpSubtitle`,
   `registrationOtpResendIn` **and `registrationChangePhone`** (`:232` is its only consumer).
   All four stay in the arbs (append-only; orphan getters are warn-only per
   `qa/t-mob-fix-002/l10n_parity_check.sh:29`).
5. Path/line nits: `Key('registration.otpField')` is at `:282` (not :283); the contrast-gate file
   is `test/core/theme/no_raw_semantic_colors_test.dart` (this screen confirmed NOT in its list);
   the digit-policy precedent is `lib/core/formatting/money_format.dart` (not `core/utils/`).
6. Keypad container bottom pad: board 30 has no token → `Spacing.twoXLarge` (32), inside the
   existing `SafeArea` (which already absorbs the home-indicator inset — no `viewPaddingOf` math).
7. Top-bar row top pad: board 14 has no token → `Spacing.medium` (16), accepted divergence.

**Verified true (kept, load-bearing):** the 7-identifier Semantics inventory and per-cell
`phone_otp_input_0..3` contract (`omds_otp_input.dart:285-297` emits `${identifier}_$index`);
HTML tpl claims byte-for-byte (26/w700/−0.6 headline; cells flex-1 h74 r16 `surface-high` digit
29/w800, active 2px orange + 2×30 caret, empty cell truly empty; meta row 12.5px space-between at
+12; keypad 3-col gap 10 h62 r16 digit 23/w700, blank bottom-start, bare 24px backspace bottom-end,
pad 0/20/30); the render shows NO verify CTA and a ~355px empty band; the note's five claims;
`kCustomerOtpLength = 4` (`otp_service.dart:6`); `resendSecondsRemaining`
(`registration_state.dart:60`) and `displayPhone` (`:70`); `changePhone()`
(`registration_cubit.dart:184-193`); the static-caret requirement
(`registration_screen_test.dart:303` calls `pumpAndSettle` — an infinite blink controller hangs
it); the single-render error constraint (`batch_b_additional_ac_tests.dart:151` findsOneWidget);
`decision_violations_test.dart` has no OTP/registration rule; jm-009's digit block (`:129-146`)
is already stale (taps 6 cells, 4 exist; RC-7 in `61_W0_QA_RESULTS.md` documents `inputText`
non-distribution); Wave-0 tokens all exist (`context.jeebText.h1/body/bodySmall/button/
titleProminent/keypadDigit/codeInput`, `context.jeebRoles.accent #D73B00`, `JeebShadows.ctaNavy`);
`OmdsPrimaryButton` exposes `height/borderRadius/textStyle/backgroundColor` and defaults to
`OmdsBorderRadius.pill`; the grouped-phone divergence (C4), the seam survival, the paste/autofill
loss log, and the auto-verify-copy honesty rule (C3).

---

## B. Frozen inventory — every one must survive byte-identical

Semantics identifiers:

| Identifier | Today at | After |
|---|---|---|
| `phone_otp_root` | `:132` (`container: true, explicitChildNodes: true`) | outermost wrapper, unchanged |
| `phone_otp_back_cta` | `:140` (`button: true, container: true`) | in-body back circle (task 4). Keep the existing value — do NOT rename to the plan's `phone_otp_back` (§7.5: reuse wins) |
| `phone_otp_input` | `:278` | container around `OtpCodeCells` (task 5) |
| `phone_otp_input_0..3` | emitted by `OmdsOtpInput` via `identifier:` `:286` | emitted by `OtpCodeCells` per-cell wrappers |
| `phone_otp_verify_cta` | `:206` (`button: true, container: true`) | retained CTA pill (task 8) |
| `phone_otp_change_phone_cta` | `:227` (`button: true, container: true`) | inline **Edit** link (task 5) |
| `phone_otp_resend_cta` | `:337` (`button: true, container: true`) | meta-row end slot when cooldown == 0 (task 6) |

Widget keys — all eight kept: `registration.otpBack` (:144), `registration.otpField` (:282),
`registration.verify` (:210), `registration.changePhone` (:231), `registration.resend` (:341),
`registration.resendCountdown` (:350), `registration.attemptsLeft` (:311),
`registration.lockoutBanner` (:372). Test-pinned: only the five in §A-corrected-1.

New identifiers (convention `<screen>_<element>`): `phone_otp_keypad_0`…`phone_otp_keypad_9`,
`phone_otp_keypad_backspace`, `phone_otp_resend_timer`.

Untouchable behaviour: the `BlocConsumer` step listener (:110-129), `_maybeAutoSubmitSeamCode`
(:77-105, both seam tests sit on it), `_otpErrorCopy` (:400-409), the
`POST /v1/auth/otp/request|verify` contract, D23 (lives in the router redirect, not here).

---

## C. Tasks — execute in order, no backtracking

### 1. Create `lib/features/registration/presentation/widgets/otp_code_cells.dart` (public)

Inline form of kit #12 `JeebCodeCells.input74`; swapped in the Wave-5 sweep. Public class
`OtpCodeCells` — public because the updated length test must name the type (§A-corrected-3).

```dart
/// Kit #12 `JeebCodeCells.input74` built feature-local (kit dir is Wave-5).
class OtpCodeCells extends StatelessWidget {
  const OtpCodeCells({
    required this.length,
    required this.value,
    super.key,
    this.hasError = false,
    this.identifier,
  });

  /// h74 / caret 2×30 per kit #12 input74 — no Sizes token exists for these.
  static const double _cellHeight = 74;
  static const double _caretHeight = 30;

  final int length;
  final String value;
  final bool hasError;
  final String? identifier;
  ...
}
```

- Build: `Directionality(textDirection: TextDirection.ltr)` around the `Row` — bidi guard, an
  all-numeric code must never reorder (precedent `handover_code_display.dart:58-61`).
- Cells are `Expanded` (tpl 122 `flex: 1 1 0%`), gap `Spacing.small` (12), height `_cellHeight`,
  radius `OmdsBorderRadius.medium` (16), fill `colorScheme.surfaceContainerHigh`.
- Filled cell: digit in `context.jeebText.codeInput.copyWith(color: colorScheme.primary)` (29/w800).
- Active cell (`index == value.length && index < length`): `Border.all(color:
  context.jeebRoles.accent, width: Sizes.threeXSmall)` + a **static** centred caret
  `Container(width: Sizes.threeXSmall, height: _caretHeight, decoration: BoxDecoration(color:
  context.jeebRoles.accent, borderRadius: BorderRadius.circular(Sizes.threeXSmall)))`.
  **No AnimationController — the caret must not blink** (pumpAndSettle hang, §A).
- `hasError`: every cell's border becomes `Border.all(color: colorScheme.error, width:
  Sizes.threeXSmall)` (carries today's `OmdsOtpInput.hasError` signal forward).
- Empty cells render nothing inside (tpl 126) — no placeholder, no underscore.
- Per-cell `Semantics(identifier: '${identifier}_$i')` when `identifier != null` — plain leaf,
  no `textField:` flag (§A-cut-6).
- Lints: `sort_constructors_first` (constructor above statics is fine — constructor first, then
  consts, then fields), `prefer_const_constructors` where possible.

### 2. Create `lib/features/registration/presentation/widgets/otp_numeric_keypad.dart` (public)

Inline form of kit #13 `JeebNumericKeypad`; swapped in Wave-5. Class `OtpNumericKeypad`.

```dart
class OtpNumericKeypad extends StatelessWidget {
  const OtpNumericKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.backspaceLabel,
    super.key,
    this.identifierPrefix,
  });

  /// Key height 62 / grid gap 10 per kit #13 — no token exists for either.
  static const double _keyHeight = 62;
  static const double _keyGap = 10;

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final String backspaceLabel; // l10n passed in — keeps the widget kit-swappable
  final String? identifierPrefix;
  ...
}
```

- Whole grid wrapped in `Directionality(textDirection: TextDirection.ltr)` — Arabic dialers do
  not mirror 1-2-3; mirroring would swap the 1/3 columns and move backspace bottom-start.
- Container padding `EdgeInsetsDirectional.fromSTEB(Spacing.large, 0, Spacing.large,
  Spacing.twoXLarge)` (board 0/20/30; 32 accepted, SafeArea handles the inset below it).
- `Column` of four `Row`s (no GridView), gaps `_keyGap` via `SizedBox`.
- Digit key: `Expanded` → `Semantics(identifier: '${identifierPrefix}_$d', button: true)` →
  `Material(color: colorScheme.surfaceContainerHigh, borderRadius: OmdsBorderRadius.medium)` +
  `InkWell(borderRadius: ..., onTap: () => onDigit('$d'))` → `SizedBox(height: _keyHeight)` →
  centred `Text('$d', style: context.jeebText.keypadDigit.copyWith(color: colorScheme.primary))`.
  Labels are ASCII `'0'`–`'9'`, NOT l10n'd, NOT Arabic-Indic — the code must reach
  `/v1/auth/otp/verify` as ASCII (`money_format.dart` recorded digit policy).
- Bottom row: blank `Expanded(child: SizedBox(height: _keyHeight))` at grid-start (tpl 143 — no
  fill), `0` centre, backspace at grid-end: **no fill**, `Icon(Icons.backspace, size:
  Sizes.xLarge, color: colorScheme.primary)` inside `Semantics(identifier:
  '${identifierPrefix}_backspace', button: true, label: backspaceLabel)`. Plain `Icons.backspace`
  — inside the forced-LTR frame it already points the right way; do NOT use `DirectionalIcons`.

### 3. Rebuild the screen shell (`otp_verification_screen.dart` `:135-153`)

Delete `appBar: OMDSAppBar(...)` (`:136-150`) and the flat
`SingleChildScrollView(padding: EdgeInsets.all(Spacing.medium))` (`:152-153`). New shape (02
precedent — makes `Spacer()` legal in a scroll view and degrades to scrolling at 200% text scale):

```dart
child: Scaffold(
  body: SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [ /* tasks 4–9 */ ],
            ),
          ),
        ),
      ),
    ),
  ),
),
```

The outer `Semantics(identifier: 'phone_otp_root', container: true, explicitChildNodes: true)`
(`:131-134`) is untouched. Keep the `BlocConsumer` builder/listener shells; task 7 extends
`listenWhen` only. Body content (tasks 4–7 + CTA) sits in a
`Padding(padding: EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge))` (§4.3 gutter =
24; board's 28 is normalized by plan rule). The keypad (task 9) sits OUTSIDE that padding —
it carries its own 20px gutter.

### 4. In-body back circle (replaces the app bar's leading)

First child of the column, row padding `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge,
Spacing.medium, Spacing.xLarge, 0)` (kit #1 pad 14/24/0; 16 top accepted):

```dart
Semantics(
  identifier: 'phone_otp_back_cta',
  button: true,
  container: true,
  child: Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const CircleBorder(),
    child: InkWell(
      key: const Key('registration.otpBack'),
      customBorder: const CircleBorder(),
      onTap: () => context.read<RegistrationCubit>().changePhone(),
      child: SizedBox(
        width: Sizes.threeXLarge,  // Ø40 (tpl 113)
        height: Sizes.threeXLarge,
        child: Icon(DirectionalIcons.back(context),
            size: Sizes.large, color: Theme.of(context).colorScheme.primary),
      ),
    ),
  ),
)
```

No title beside it (tpl 112's row contains ONLY the circle — keeping `OMDSAppBar` would render
the title twice). `DirectionalIcons.back(context)` preserved verbatim — it mirrors under `ar`.

### 5. Headline + subtitle row; DELETE the docked change-phone button (`:157-165`, `:226-237`)

- Headline (board gap 18 above → `Spacing.medium`):
  `Text(l10n.registrationOtpHeadline, style: context.jeebText.h1.copyWith(color:
  colorScheme.primary))`. Board is 26/w700/−0.6; `h1` is 24/w700 — plan R3 ("heavier, not
  bigger") wins. Do NOT add a 26px constant.
- Gap `Spacing.xSmall` (board 7), then the three-ink row (tpl 118-120):

```dart
Wrap(
  crossAxisAlignment: WrapCrossAlignment.center,
  spacing: Spacing.twoXSmall,
  children: [
    Text.rich(TextSpan(children: [
      TextSpan(
        text: '${l10n.registrationOtpSentToLabel} ',
        style: context.jeebText.body
            .copyWith(color: colorScheme.onSurfaceVariant), // AA — NOT periwinkle (§A-cut-1)
      ),
      TextSpan(
        // U+2066/U+2069 LTR isolate — "+961 …" must not reorder beside Arabic
        // (money_format.dart precedent).
        text: '⁦${state.displayPhone}⁩',
        style: context.jeebText.body.copyWith(
            color: colorScheme.primary, fontWeight: FontWeight.w700),
      ),
    ])),
    Text('·',
        style: context.jeebText.body
            .copyWith(color: colorScheme.onSurfaceVariant)),
    Semantics(
      identifier: 'phone_otp_change_phone_cta',
      button: true,
      container: true,
      child: InkWell(
        key: const Key('registration.changePhone'),
        onTap: () => context.read<RegistrationCubit>().changePhone(),
        child: Text(l10n.registrationOtpEditPhone,
            style: context.jeebText.body.copyWith(
                color: context.jeebRoles.accent,
                fontWeight: FontWeight.w700)),
      ),
    ),
  ],
)
```

- `Wrap` (not `Row`): degrades at 200% text scale, mirrors for free.
- DELETE the whole docked change-phone block (`:225-237`) — the note's "inline Edit-number
  instead of a buried text button". Identifier + key re-homed above.
- The literal `·` is punctuation, l10n-exempt.
- Accepted divergence C4: `displayPhone` renders `+961 71123456`, not the board's grouped
  `+961 3 123 456`. Do NOT touch `LebanonPhone` (shared with screen 02, no format test).

### 6. Replace `_OtpEntry` with `OtpCodeCells`; rebuild the meta row; delete the standalone error

- DELETE `_OtpEntry` entirely (`:250-293`) and the `OmdsOtpInput` usage. Its `_kOtpLength`
  references at `:215` switch to `kCustomerOtpLength` (already imported via `domain/otp_service.dart`).
- Gap above cells `Spacing.xLarge` (board 24, tpl 121). Mount (non-lockout branch, replacing
  `:172-182`):

```dart
Semantics(
  identifier: 'phone_otp_input',
  container: true,
  explicitChildNodes: true, // without it the per-cell ids are swallowed (§7.5)
  value: _enteredCode.split('').join(' '), // a11y: cells are not TextFields any more
  child: OtpCodeCells(
    key: const Key('registration.otpField'),
    length: kCustomerOtpLength,
    value: _enteredCode,
    hasError: state.otpError != null,
    identifier: 'phone_otp_input', // emits phone_otp_input_0..3 verbatim
  ),
)
```

- DELETE the standalone error paragraph (`:183-191`). The error renders **exactly once**, in the
  meta row's start slot (batch_b:151 findsOneWidget).
- Meta row, gap `Spacing.small` (12, tpl 127) under the cells, replaces `_ResendRow`
  (delete `:319-358`):

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Flexible(
      child: state.otpError != null
          ? Text(_otpErrorCopy(state.otpError!, l10n),
              style: context.jeebText.bodySmall
                  .copyWith(color: colorScheme.error))
          : Text(l10n.registrationOtpAutoVerifyHint,
              style: context.jeebText.bodySmall
                  .copyWith(color: colorScheme.onSurfaceVariant)),
    ),
    if (state.resendSecondsRemaining > 0)
      Semantics(
        identifier: 'phone_otp_resend_timer',
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '${l10n.registrationOtpResendInLabel} ',
              style: context.jeebText.bodySmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: '⁦$countdownText⁩', // m:ss, LTR-isolated
              style: context.jeebText.bodySmall.copyWith(
                  color: colorScheme.primary, fontWeight: FontWeight.w700),
            ),
          ]),
          key: const Key('registration.resendCountdown'),
        ),
      )
    else
      Semantics(
        identifier: 'phone_otp_resend_cta',
        button: true,
        container: true,
        child: InkWell(
          key: const Key('registration.resend'),
          onTap: () {
            // Stale full code must not sit under a fresh SMS.
            setState(() => _enteredCode = '');
            context.read<RegistrationCubit>().resendCode();
          },
          child: Text(l10n.registrationOtpResend,
              style: context.jeebText.bodySmall.copyWith(
                  color: context.jeebRoles.accent,
                  fontWeight: FontWeight.w700)),
        ),
      ),
  ],
)
```

with `final countdownText = '${state.resendSecondsRemaining ~/ 60}:'
'${(state.resendSecondsRemaining % 60).toString().padLeft(2, '0')}';` (`prefer_final_locals`) —
the board format is **m:ss** (`0:42`), not `{seconds}s`. The countdown/resend key swap is exactly
what `otp_verification_screen_test.dart:93-105` asserts. Orange resend text = plan R5 (orange
marks what decays); orange `#D73B00` on white passes AA and is the sanctioned accent role.
- `_AttemptsRemainingLabel` (`:295-317`) stays as-is (key, `onSurfaceVariant` ink — do NOT flip
  it to periwinkle), mounted directly under the meta row with gap `Spacing.small`. It renders
  `SizedBox.shrink` until the first failure.

### 7. Keypad-driven input: local handlers + clear-on-error

Add to `_OtpVerificationScreenState`:

```dart
void _appendDigit(String digit) {
  final cubit = context.read<RegistrationCubit>();
  if (cubit.state.isVerifying) return; // no racing input mid-verify
  if (_enteredCode.length >= kCustomerOtpLength) return;
  setState(() => _enteredCode += digit);
  if (_enteredCode.length == kCustomerOtpLength) {
    cubit.verifyCode(_enteredCode); // the note's auto-verify on the 4th digit
  }
}

void _deleteDigit() {
  if (_enteredCode.isEmpty) return;
  setState(
      () => _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1));
}
```

Extend the existing `BlocConsumer` (do NOT add a second listener):

```dart
listenWhen: (prev, curr) =>
    prev.step != curr.step || prev.otpError != curr.otpError,
listener: (context, state) {
  // A rejected code would strand activeIndex at 4 with a keypad-driven input.
  if (state.otpError != null && _enteredCode.isNotEmpty) {
    setState(() => _enteredCode = '');
  }
  switch (state.step) { /* existing cases, unchanged */ }
},
```

`_maybeAutoSubmitSeamCode` (`:92-105`) is untouched — it assigns `_enteredCode` and calls
`verifyCode`; both seam tests stay green, and the seam code is now visible in the cells.

### 8. Restyle the retained Verify CTA (`:205-220`) — declared deviation

The board draws NO CTA (auto-verify + empty band). Retained per §A-corrected-2: the
`registration_screen_test.dart:308` pin is outside this lane's ownership, and removing the only
explicit submit control is a WCAG 3.2.2 hazard. Placement: after the attempts label comes
`const Spacer()` (tpl 131 — the empty band stays EMPTY, R1), then the pill, then gap
`Spacing.medium`, then the keypad.

```dart
Semantics(
  identifier: 'phone_otp_verify_cta',
  button: true,
  container: true,
  child: DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: OmdsBorderRadius.pill,
      boxShadow: JeebShadows.ctaNavy, // the screen's ONLY shadow (R7)
    ),
    child: OmdsPrimaryButton(
      key: const Key('registration.verify'),
      height: Sizes.fiveXLarge,              // h56, kit #2 primary
      textStyle: context.jeebText.button,    // 17/w600
      text: state.isVerifying
          ? l10n.registrationOtpVerifying
          : l10n.registrationOtpVerify,
      isEnabled: !state.isVerifying &&
          _enteredCode.length == kCustomerOtpLength,
      onTap: () =>
          context.read<RegistrationCubit>().verifyCode(_enteredCode),
    ),
  ),
)
```

Keep `OmdsPrimaryButton` (it exposes `height/textStyle`, defaults to the pill radius, and handles
the disabled state) — do not hand-roll a button. Update the stale ":202-204 / 6th digit" comment
to one short line ("manual fallback; keypad auto-submits on the 4th digit").

### 9. Mount the keypad; extend the lockout guard

Last child of the column, outside the 24px body padding:

```dart
if (state.step != RegistrationStep.lockedOut)
  OtpNumericKeypad(
    identifierPrefix: 'phone_otp_keypad',
    onDigit: _appendDigit,
    onBackspace: _deleteDigit,
    backspaceLabel: l10n.registrationOtpKeypadBackspaceA11y,
  ),
```

The existing `:192` guard already hides CTA/resend/attempts during lockout — the keypad joins it
(nothing to type into; batch_b:209 asserts the CTA is gone). `_LockoutBanner` (`:360-398`) stays,
restyle only: title → `context.jeebText.titleProminent`, body → `context.jeebText.body`, both
keeping `onErrorContainer`; radius stays `OmdsBorderRadius.medium`.

### 10. Sweep the file

- Remove the now-unused `OmdsOtpInput` pathway: `_OtpEntry`, `_ResendRow` deleted; imports
  pruned (keep `omds.dart` — Spacing/Sizes/OmdsBorderRadius/OmdsPrimaryButton still used).
- Import the two new widget files.
- Fix the two stale doc-comment facts the rebuild makes wrong ("6-digit" at `:19`/`:30` → 4-digit
  per `kCustomerOtpLength`) — keep the edits to those lines only, comments stay short.
- Lint pass: `prefer_const_constructors` (back-circle `CircleBorder`, gaps), `prefer_final_locals`
  (`countdownText`), `sort_constructors_first` in both new widgets, no `print`, no async context
  use (all handlers are sync).

### 11. Update this screen's tests (`test/otp_verification_screen_test.dart` — this lane owns it)

Exactly two legitimate breaks, both because the design genuinely changed:
- `:70-73`: `tester.widget<OmdsOtpInput>(...)` → `tester.widget<OtpCodeCells>(find.byKey(const
  Key('registration.otpField'))).length` still `== 4` (intent preserved: input length locked to
  `kCustomerOtpLength`). Import the new widget file; drop the `OmdsOtpInput` import if unused.
- `:79`: `find.textContaining('60')` → `find.textContaining('1:00')` (m:ss format).

Add four tests:
1. tapping `phone_otp_keypad_1..4` (find by Semantics identifier or by `find.text` within the
   keypad) fills the cells and auto-fires `verifyCode('1234')` on the 4th tap;
2. `phone_otp_keypad_backspace` removes the last digit (3 taps + backspace + 2 taps → verify
   fires with the corrected code);
3. a rejected code clears the cells: after `verifyCode` returns invalid, four fresh keypad taps
   fire `verifyCode` with ONLY the four new digits;
4. `ar` RTL smoke: under `Directionality.rtl` + ar locale, cell 0's dx < cell 1's dx and keypad
   `1` dx < `3` dx (both grids pinned LTR), while the back icon mirrors.

**If any other assertion in this file breaks, the implementation is wrong.** Do NOT touch
`test/registration_screen_test.dart` (lane 02) or `test/features/batch_b_additional_ac_tests.dart`
(both its OTP tests must pass unmodified — they will if the error renders once and the lockout
guard holds).

### 12. Append the wiring requests (section E, verbatim) to
`docs/redesign-2026-08/wiring/03-otp-verify.md`, then gate

- `flutter analyze` — bar: nothing beyond the pre-existing baseline (11 issues / 6 errors:
  2× `Semantics identifier` + 4× `DioExceptionType.transformTimeout`). Do not fix those.
- `flutter test test/otp_verification_screen_test.dart test/features/batch_b_additional_ac_tests.dart`
  — green only after the l10n wiring lands (the code references six new getters). Expected under
  the as-if-granted contract; note it in the hand-off.
- `tool/check_design_tokens.sh` — the gate bans `EdgeInsets.<ctor>(<digit`,
  `BorderRadius.circular(<digit`, `fontSize: <digit`, `Color(0xFF`. The named height consts
  (74/62/30/10) are legal; every padding above is token-fed.

---

## D. Stop conditions

**Done means:** all 7 identifiers + `phone_otp_input_0..3` + all 8 keys emitted, spelled
identically; no `appBar:`; `OmdsOtpInput` gone and the OS keyboard can never open here; headline/
subtitle/cells/meta-row/keypad match §C; the error renders exactly once; countdown reads m:ss;
the empty band is real emptiness (Spacer — no filler content, R1); cells and keypad lay out LTR
under `ar`, back arrow mirrors, phone + countdown LTR-isolated; only `JeebShadows.ctaNavy` casts
a shadow; 200% text scale scrolls instead of overflowing; analyze delta zero; test delta = 2
edits + 4 additions in this lane's file only; wiring file appended.

**Do NOT touch:** `registration_screen.dart` / `test/registration_screen_test.dart` (lane 02);
`application/`, `domain/`, `data/` of this feature (no cubit/state/API change is needed —
verified); `lib/core/router/*`, `lib/core/di/*`, `lib/core/theme/*`, `lib/core/widgets/jeeb/`
(does not exist — do not create it), `lib/l10n/*`, `pubspec.yaml`, OMDS, `.maestro/`, `tool/`.
Do not build the `9:41` status row or frame chrome; no paste affordance, no
`AutofillHints.oneTimeCode` (foreclosed-future note stands — flag to owner, do not wire); no
blinking caret; no phone-number grouping formatter; no new route (stays pushed by the host via
`OmdsSlideRoute`, `registration_screen.dart:180-197`); do not delete the four orphaned l10n keys.

---

## E. Wiring requests — final text, ready to paste into `docs/redesign-2026-08/wiring/03-otp-verify.md`

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
app_localizations.dart — add next to the existing `registrationOtp*` getters:
```dart
String get registrationOtpHeadline => _get('registrationOtpHeadline');
String get registrationOtpSentToLabel => _get('registrationOtpSentToLabel');
String get registrationOtpEditPhone => _get('registrationOtpEditPhone');
String get registrationOtpAutoVerifyHint => _get('registrationOtpAutoVerifyHint');
String get registrationOtpResendInLabel => _get('registrationOtpResendInLabel');
String get registrationOtpKeypadBackspaceA11y => _get('registrationOtpKeypadBackspaceA11y');
```
why: the rebuilt screen renders all six strings (screen code already written as-if-granted). AR for `registrationOtpAutoVerifyHint` must stay "verifies automatically" — never wording that implies SMS reading (no-fabrication rule applied to copy). `registrationOtpTitle`, `registrationOtpSubtitle`, `registrationOtpResendIn` and `registrationChangePhone` become orphan getters — leave them (arbs are append-only; orphans are warn-only).

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
