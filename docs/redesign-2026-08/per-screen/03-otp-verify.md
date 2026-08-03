# Screen 03 — OTP verify (`03-otp-verify`)

**File:** `lib/features/registration/presentation/otp_verification_screen.dart` (409 LOC, 5 widgets)
**Route:** none. Pushed by `registration_screen.dart:185-197` (`_openOtpRoute` → `OmdsSlideRoute`) inside
the host's `RegistrationCubit` scope. Confirmed against `screen-repo-map.md:52` ("*not routed; mounted by 02*").
**Verdict: REBUILD.** Not a restyle — the input mechanism, the chrome and the footer all change.
The OS keyboard is removed, `OmdsOtpInput` is dropped, the app bar is deleted, and the two docked
text buttons are re-homed into the header. Wave 5 per `00-MIGRATION-PLAN.md:491`.

---

## 0. Semantics inventory (done FIRST, per §7.5)

`grep -n "identifier:" lib/features/registration/presentation/otp_verification_screen.dart`

| # | Identifier | Today at | Must be re-homed to |
|---|---|---|---|
| 1 | `phone_otp_root` | :132 | the `Scaffold` wrapper — unchanged |
| 2 | `phone_otp_back_cta` | :140 | `JeebTopBar` back circle (§1.1) |
| 3 | `phone_otp_input` | :278 | `Semantics` container around `JeebCodeCells` (§1.3) |
| 4 | `phone_otp_input` (per-cell base → `_0.._3`) | :286 | `JeebCodeCells.identifier` (§1.3) |
| 5 | `phone_otp_verify_cta` | :206 | retained CTA pill, docked above the keypad (§1.6) |
| 6 | `phone_otp_change_phone_cta` | :227 | the inline orange **Edit** link in the subtitle (§1.2) |
| 7 | `phone_otp_resend_cta` | :337 | the end slot of the meta row (§1.4) |

**Widget `Key`s that are also test-pinned** (not `Semantics`, but breaking them breaks CI):
`registration.otpBack` (:144), `registration.otpField` (:283), `registration.verify` (:210),
`registration.changePhone` (:231), `registration.resend` (:341), `registration.resendCountdown` (:350),
`registration.attemptsLeft` (:311), `registration.lockoutBanner` (:372). **All eight survive.**

**New identifiers proposed** (convention `<screen>_<element>`):
`phone_otp_keypad_0` … `phone_otp_keypad_9`, `phone_otp_keypad_backspace`, `phone_otp_resend_timer`.

---

## 1. Layout & structure

The designed column, top to bottom (HTML `03-otp-verify.html`, tpl 112 → 145). **Mock chrome —
the 440×956 frame, the 40px frame radius, `scale(0.55)` and the `9:41` status row (tpl 108-111) —
is NOT built** (§3 of the plan).

```
Scaffold(backgroundColor: colorScheme.surface = white)   ← already white (app_theme.dart:154)
└ SafeArea
  └ SingleChildScrollView + ConstrainedBox(minHeight: viewportHeight) + IntrinsicHeight
    └ Column(crossAxisAlignment: start)
       ├ JeebTopBar(leading: back, title: null)          ← tpl 112-115: Ø40 circle ONLY, no title
       ├ headline  "Check your messages"                 ← tpl 117
       ├ subtitle  "Code sent to <phone> · Edit"         ← tpl 118-120
       ├ JeebCodeCells.input74 (4 cells, flex:1, gap 12) ← tpl 121-126
       ├ meta row  "Verifies automatically" ⟷ "Resend in 0:42"  ← tpl 127-130
       ├ (conditional) attempts-remaining label
       ├ Spacer()                                        ← tpl 131 `flex: 1 1 0%`
       ├ JeebCtaFooter.single → Verify pill              ← RETAINED, see §1.6 (deviation, declared)
       └ JeebNumericKeypad                               ← tpl 132-147
```

### 1.1 DELETE the app bar; add an in-body back circle
**Where:** `otp_verification_screen.dart:136-150`.
**Now:** `OMDSAppBar(title: l10n.registrationOtpTitle, centerTitle: false, leading: IconButton(...))`.
**Becomes:** `Scaffold` with **no `appBar:`**; the first child of the body column is
`JeebTopBar(leading: JeebTopBarLeading.back, title: null, identifier: 'phone_otp_back_cta',
onLeadingTap: () => context.read<RegistrationCubit>().changePhone())`, keeping
`key: const Key('registration.otpBack')` on the button.
**Evidence:** the render shows one Ø40 `surfaceContainerHigh` circle at the top-start with a 20px
navy back arrow and **no title text next to it**; HTML tpl 113 is a bare `<span>` circle inside a
row whose only content is that circle. The title has moved into the body as the h1 (tpl 117).
Keeping `OMDSAppBar` would render "Enter the code" twice (bar + body), which is what happens today.

`DirectionalIcons.back(context)` (:145) is preserved verbatim — it is what makes the arrow point
right under `ar`.

### 1.2 Rewrite the subtitle into the "Code sent to … · Edit" row and DELETE the docked change-phone button
**Where:** `otp_verification_screen.dart:162-165` (subtitle) and `:226-237` (change-phone button).
**Now:** a `bodyMedium` sentence "We sent a 4-digit code to +961 71123456." plus a separate
full-width `OmdsPrimaryButton(variant: text)` "Change phone number" pinned at the very bottom.
**Becomes:** one wrapping row directly under the headline:

```dart
Wrap(
  crossAxisAlignment: WrapCrossAlignment.center,
  spacing: Spacing.twoXSmall,
  children: [
    Text.rich(TextSpan(children: [
      TextSpan(text: '${l10n.registrationOtpSentToLabel} ',
        style: context.jeebText.body.copyWith(color: cs.onSecondaryContainer)),
      TextSpan(text: MoneyFormat-style LTR isolate of state.displayPhone,
        style: context.jeebText.body.copyWith(
          color: cs.primary, fontWeight: FontWeight.w700)),
    ])),
    Text('·', style: … onSecondaryContainer),
    Semantics(identifier: 'phone_otp_change_phone_cta', button: true, container: true,
      child: JeebCtaButton.accentText(
        key: const Key('registration.changePhone'),
        label: l10n.registrationOtpEditPhone,          // "Edit"
        onTap: () => context.read<RegistrationCubit>().changePhone())),
  ],
)
```

**Evidence:** tpl 118-120 — `Code sent to` in `--jeeb-periwinkle` 15/w500, the number in
`--jeeb-navy` **w700**, then `· ` and `Edit` in `--jeeb-orange` **w700**. The designer note is
explicit: *"inline Edit-number instead of a buried text button"*. Three inks in one row is R4.
`Wrap` (not `Row`) so the row degrades instead of overflowing at 200% text scale, and because
`Wrap` is direction-aware and mirrors for free.

**Copy divergence, declared:** the board prints `+961 3 123 456` (grouped). `LebanonPhone.displayWithPrefix`
(`lebanon_phone.dart:60`) yields `+961 71123456`. **Do not add a grouping formatter** — it is shared
with the phone-entry screen (02) and no test covers the format; a purely cosmetic regrouping is not
worth touching a domain value object in this lane. Accepted divergence.

### 1.3 Replace `OmdsOtpInput` with `JeebCodeCells.input74`
**Where:** `otp_verification_screen.dart:250-293` (`_OtpEntry`) — **delete the whole private widget**.
**Now:** `OmdsOtpInput(length: 4, boxWidth: 48, boxHeight: 56, spacing: 8)` = four focusable
`TextField`s that force the OS keyboard open. Resting border `tokens.inputBorderColor`, radius
`OmdsBorderRadius.small` (8).
**Becomes:**

```dart
Semantics(
  identifier: 'phone_otp_input',
  container: true,
  explicitChildNodes: true,          // §7.5 — without it the per-cell ids are swallowed
  value: _code.split('').join(' '),  // a11y: precedent handover_code_display.dart:47
  child: JeebCodeCells.input74(
    key: const Key('registration.otpField'),
    length: kCustomerOtpLength,      // 4 — otp_service.dart:6, unchanged
    value: _code,
    activeIndex: _code.length,
    hasError: state.otpError != null,
    identifier: 'phone_otp_input',   // emits phone_otp_input_0 .. _3
  ),
)
```

**Exact visual (tpl 122-126):** each cell `flex: 1 1 0%` (NOT a fixed 48px), height **74**,
radius **16**, fill `--jeeb-surface-high` → `colorScheme.surfaceContainerHigh`, gap **12**, digit
**29/w800** navy → `context.jeebText.codeInput` + `colorScheme.primary`. Active cell: **2px**
`jeebRoles.accent` border with `box-sizing: border-box`, containing a **2×30** accent caret at
radius 2. Empty cells render nothing at all (tpl 126 is an empty span) — **no placeholder dot, no
underscore**.

**The caret must NOT blink.** An infinitely repeating `AnimationController` makes
`tester.pumpAndSettle()` never settle, and `registration_screen_test.dart:303` calls it. Ship a
static caret; the plan specs no motion.

### 1.4 Rebuild the resend row as the design's meta row
**Where:** `otp_verification_screen.dart:319-358` (`_ResendRow`) — restructure; **do not delete the keys**.
**Now:** a `MainAxisAlignment.center` row holding either a text button or a centred countdown.
**Becomes:** a `Row(mainAxisAlignment: spaceBetween)` **12px** below the cells:

| Slot | Content | Style (tpl 128-130) |
|---|---|---|
| start | `l10n.registrationOtpAutoVerifyHint` — "Verifies automatically" | 12.5/w500 periwinkle → `context.jeebText.bodySmall` + `cs.onSecondaryContainer` |
| start (error) | `_otpErrorCopy(state.otpError!, l10n)` **replaces** the hint | same size, `cs.error` |
| end (cooldown > 0) | `"Resend in " + m:ss` | label 12.5/w600 periwinkle; value **navy w700** — two inks, R4 |
| end (cooldown == 0) | `l10n.registrationOtpResend` tappable | `jeebRoles.accent` w700 (R5: orange text marks what decays) |

The end slot keeps `Key('registration.resendCountdown')` on the timer `Text` and
`Semantics(identifier: 'phone_otp_resend_cta') + Key('registration.resend')` on the tappable form —
exactly the swap `otp_verification_screen_test.dart:93-105` asserts.

**Evidence:** tpl 127 `display:flex; justify-content:space-between; margin-top:12px`; the note says
*"resend timer kept in view"*. The design's `0:42` is **m:ss**, not `{seconds}s`.

### 1.5 DELETE the standalone error paragraph
**Where:** `otp_verification_screen.dart:183-191`.
The error copy moves into the meta row's start slot (§1.4). **It must render exactly once** —
`batch_b_additional_ac_tests.dart:151` asserts `find.textContaining('Wrong code')` is
`findsOneWidget`. Rendering it in both places turns that green test red.

### 1.6 The Verify CTA — RETAINED, as a declared deviation
**Where:** `otp_verification_screen.dart:205-220`.
The board has **no CTA at all**: the note says *"auto-verify on the 4th digit"*, and the space
between the meta row and the keypad is plain white. Deleting the button is what the design asks for.
**I am not deleting it**, for three verifiable reasons:

1. `registration_screen_test.dart:308` asserts `find.byKey(const Key('registration.verify'))` is
   `findsOneWidget` on arrival at the OTP screen, with zero digits entered.
2. `.maestro/flows/jm-009-phone-otp.yaml:149-155` taps `phone_otp_verify_cta` as a conditional
   fallback, and `jm-051-mark-delivered.yaml:81` asserts it is *not* visible on another surface —
   i.e. its presence/absence is a load-bearing signal in two flows.
3. Auto-submit-on-last-digit with no explicit submit control is a WCAG 3.2.2 (On Input) hazard;
   the current code already treats the button as "manual verify fallback" (comment at :202-204).

**Becomes:** `JeebCtaFooter.single` holding a `JeebCtaButton.primary` — h56 navy pill, white
`context.jeebText.button`, `JeebShadows.ctaNavy`, `isEnabled: !state.isVerifying && _code.length == kCustomerOtpLength`
— docked between the `Spacer()` and the keypad, keeping both the `Semantics` id and
`Key('registration.verify')`.

**Cost of the deviation:** ~88 logical px (56 pill + 32 footer padding) out of the ~355 px empty
band the render shows, so the screen still reads as low-density (R1/risk 13). **Owner decision:**
if the board's literal "no CTA" is wanted, the price is one assertion removed from
`registration_screen_test.dart:308`, one `runFlow` block removed from jm-009, and re-checking
jm-051's `assertNotVisible`. Cheap either way; I default to the safe side.

### 1.7 ADD the in-screen keypad
**Where:** new, at the bottom of the column.
```dart
JeebNumericKeypad(
  identifierPrefix: 'phone_otp_keypad',
  onDigit: _appendDigit,
  onBackspace: _deleteDigit,
)
```
**Exact visual (tpl 132-147):** container padding `0 / 20 / 30`; 3-column grid, gap **10**; cells
height **62**, radius **16**, fill `surfaceContainerHigh`, digit **23/w700** navy →
`context.jeebText.keypadDigit`. Bottom-start cell is **empty and unfilled** (tpl 143 has no
background). Bottom-end is the backspace: **no fill**, a **24px navy** backspace glyph (tpl 145-147).
**Evidence:** the whole point of the note — *"in-screen keypad (no OS keyboard covering the code)"*.

### 1.8 Lockout and attempts
- `_LockoutBanner` (:360-398) **stays** — `otp_verification_screen_test.dart:124` and
  `batch_b_additional_ac_tests.dart:207` pin `Key('registration.lockoutBanner')`. Restyle only:
  radius `OmdsBorderRadius.medium` (16), title → `context.jeebText.titleProminent`, body →
  `context.jeebText.body`. It already improves for free from Wave 0's error quartet
  (`app_theme.dart:121-123`: `errorContainer #FFDAD6` / `onErrorContainer #410002` instead of the
  old `#B00020` slab).
  *Preferred:* consume `JeebInfoNote` with a new `error` tone — see §10 wiring request W5.
- **The keypad and the Verify pill must both be hidden while `step == lockedOut`.** Today the
  guard at `:192` already hides the CTA/resend/change-phone block; extend it to the keypad. There is
  nothing to type into during a lockout, and `batch_b:209` asserts the CTA is gone.
- `_AttemptsRemainingLabel` (:295-317) **stays** (`Key('registration.attemptsLeft')`), moved
  directly under the meta row, styled `context.jeebText.bodySmall` + `cs.onSecondaryContainer`. It
  only mounts after the first failure, so it eats the spacer only in the error case.

### 1.9 Scroll/overflow structure
Replace `SingleChildScrollView(padding: EdgeInsets.all(Spacing.medium))` (:152-153) with
`SingleChildScrollView` → `ConstrainedBox(minHeight: constraints.maxHeight)` → `IntrinsicHeight` →
`Column` + `Spacer()`. This is what makes tpl 131's `flex: 1` real emptiness on a tall screen while
still scrolling at 200% text scale (DoD: "text scale 200% does not overflow-crash"). Also set
`resizeToAvoidBottomInset: false` — no OS keyboard can open on this screen any more.

---

## 2. Tokens — every hardcoded value that changes

There are zero `Color(0x…)` literals in this file today; the issue is **stock M3 roles where the
redesign ramp belongs**. `otp_verification_screen.dart` is **not** in the
`no_raw_semantic_colors_test.dart` 18-file list, but use `context.jeebRoles.accent` anyway (§4.6) —
never `colorScheme.tertiary` — so the file does not need re-auditing if it is ever added.

| Where (current) | Now | Becomes |
|---|---|---|
| `:159` title | `textTheme.headlineSmall` | `context.jeebText.h1` + `cs.primary`. Board is 26/w700/ls −0.6; `h1` is 24/w700 — **do not add a 26px kit const** (R3: don't make it bigger, make it heavier) |
| `:164` subtitle | `textTheme.bodyMedium` | label + `·`: `jeebText.body` + `cs.onSecondaryContainer` (periwinkle); phone: `jeebText.body.copyWith(fontWeight: w700)` + `cs.primary`; `Edit`: `jeebText.body.copyWith(fontWeight: w700)` + `jeebRoles.accent` |
| `:153` body padding | `EdgeInsets.all(Spacing.medium)` (16) | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` (24). Board uses 28 for the body block and 24 for the bar; §4.3 normalizes every redesigned body to **24** and `check_design_tokens.sh` bans literal `EdgeInsets` numbers |
| `:161` `Spacing.xSmall` | 8 | keep (board margin-top 7) |
| `:166` `Spacing.large` | 20 | `Spacing.xLarge` (24) — board margin-top 24 (tpl 121) |
| cells → meta gap | n/a | `Spacing.small` (12) — tpl 127 |
| `_OtpEntry` box | 48×56, `OmdsBorderRadius.small` (8), `tokens.inputBorderColor` | `Expanded` × h74, `OmdsBorderRadius.medium` (16) **inside the kit**, fill `cs.surfaceContainerHigh`, digit `jeebText.codeInput` + `cs.primary` |
| active cell | `focusedBorder` 2px `colorScheme.primary` | 2px `jeebRoles.accent` + a 2×30 `jeebRoles.accent` caret (tpl 124-125) |
| error cell | `tokens.semanticErrorColor` | 2px `cs.error` |
| `:188` error ink | `colorScheme.error` | keep `cs.error`, size → `jeebText.bodySmall` |
| `:313`, `:352` muted ink | `colorScheme.onSurfaceVariant` (brown `#5C4038`) | `colorScheme.onSecondaryContainer` (periwinkle `#777FC0`). The board's muted meta ink is periwinkle, not brown (R4) |
| `:212-213` CTA text | default `OmdsPrimaryButton` type | `context.jeebText.button` (17/w600) via `JeebCtaButton` |
| `:376` banner radius | `OmdsBorderRadius.medium` | keep (16) |
| keypad digits | n/a | `context.jeebText.keypadDigit` (23/w700) + `cs.primary`, fill `cs.surfaceContainerHigh` |
| back circle | `IconButton` in an `OMDSAppBar` | Ø40 `cs.surfaceContainerHigh` circle, 20px `cs.primary` glyph — inside `JeebTopBar` |

No shadow anywhere on this screen except `JeebShadows.ctaNavy` on the retained Verify pill —
R7: a white card with a shadow does not exist on this board, and every surface here is flat.

---

## 3. Shared components consumed

| Plan § | Component | Used for | Notes |
|---|---|---|---|
| §5 #1 | `JeebTopBar` | the bare back circle | needs `title: null` support — **W1** |
| §5 #12 | `JeebCodeCells.input74` | the 4 code cells | needs `identifier` → per-cell ids, `hasError`, `Expanded` cells — **W2/W3/W4** |
| §5 #13 | `JeebNumericKeypad` | the keypad | needs a forced-LTR grid — **W6** |
| §5 #2 | `JeebCtaButton` + `JeebCtaFooter.single` | the retained Verify pill | `primary` variant |
| §5 #2 | `JeebCtaButton.accentText` | the inline **Edit** link | `accentText` variant, `jeebRoles.accent` |
| §5 #22 | `JeebInfoNote` (`error` tone) | the lockout banner | **W5**, optional — fallback is an in-file restyle |

**Deleted bespoke widgets:** `_OtpEntry` (:250-293) entirely; `_ResendRow` (:319-358) collapses into
the meta row. `_AttemptsRemainingLabel` and `_LockoutBanner` stay as private widgets.

`JeebCodeCells` is shared with **13** (OTP handover) and **18**; `JeebNumericKeypad` with **18**.
Screen 13 already has its own display-only `HandoverCodeDisplay`
(`lib/features/otp_handover/presentation/widgets/handover_code_display.dart`) — do not conflate:
that is the `display` variant, this is `input74`.

---

## 4. New functionality and what it needs from the cubit/state

**Nothing new is needed from `RegistrationCubit` or `RegistrationState`, and no endpoint is
invented.** Everything the board draws is derivable from state that exists today. Detail:

| Board behaviour | Source | Verdict |
|---|---|---|
| In-screen keypad | new local `String _code` in `_OtpVerificationScreenState` (replaces `_enteredCode`, :69); `_appendDigit` / `_deleteDigit` | **screen-local** |
| Active cell + caret | `activeIndex = _code.length` | **screen-local** |
| Auto-verify on the 4th digit | already exists — `OmdsOtpInput.onCompleted` → `verifyCode` (:176-181). Becomes: `if (_code.length == kCustomerOtpLength) cubit.verifyCode(_code)` inside `_appendDigit` | **already shipped** |
| "Verifies automatically" copy | describes exactly the above | **honest** — it must NOT be read as SMS auto-read (see §9-C3) |
| `Resend in 0:42` | `state.resendSecondsRemaining` (`registration_state.dart:60`) → `'${s ~/ 60}:${(s % 60).toString().padLeft(2, "0")}'` | **existing field, client-side format** |
| Inline `Edit` | `RegistrationCubit.changePhone()` (`registration_cubit.dart:184-193`) — same call the deleted button made | **existing** |
| Error frame on the cells | `state.otpError != null` | **existing** |

**Two genuinely new screen-local behaviours, both required by the redesign:**

1. **Clear the cells after a wrong code.** With `OmdsOtpInput` the user could overtype a cell.
   With a keypad-driven `_code`, a rejected 4-digit code leaves `activeIndex == 4` and the user is
   stuck. Add a `BlocListener` on `otpError` (`null → non-null`) that does
   `setState(() => _code = '')`. This is a defect the redesign *exposes*, not one it creates.
2. **Clear the cells on resend.** In `onTap` of the resend affordance: `setState(() => _code = '')`
   before `cubit.resendCode()`. Otherwise a stale full code sits under a fresh SMS.

**The dev seam survives unchanged.** `_maybeAutoSubmitSeamCode` (:92-105) only assigns the local
field and calls `verifyCode`; rename `_enteredCode` → `_code` and both seam tests
(`otp_verification_screen_test.dart:151-191`) stay green. Bonus: the seam code is now *visible* in
the cells, which it never was.

**Capabilities genuinely lost — flagged, not worked around:**
- **Paste.** `OmdsOtpInput._onControllerChanged` (omds:134-150) distributes a pasted string across
  cells. A keypad has no paste affordance and the board draws none. Do not invent a long-press
  paste; record the loss.
- **SMS one-time-code autofill.** `AutofillHints.oneTimeCode` needs a focusable text field. It is
  **not wired today** either (`OmdsOtpInput` sets no `autofillHints`), so this is a foreclosed
  future, not a regression. Worth an owner note: if iOS/Android OTP autofill is ever wanted, the
  keypad design blocks the standard implementation.

---

## 5. New routes

**None.** This screen is not a `GoRoute` today and must not become one. It is pushed by the host
(`registration_screen.dart:185`) with `BlocProvider.value` so the countdown and the attempt budget
survive the navigation (:52-54 doc comment). `app_router.dart` is untouched by this lane, and
nothing goes into `backFallbacks`.

---

## 6. Semantics identifiers

**Preserved, value-identical (7):** `phone_otp_root`, `phone_otp_back_cta`, `phone_otp_input`,
`phone_otp_input_0..3`, `phone_otp_verify_cta`, `phone_otp_change_phone_cta`, `phone_otp_resend_cta`.
Mapping in §0. Note `phone_otp_back_cta` is kept **as-is** even though the plan's new convention
would spell it `phone_otp_back` — §7.5 says reuse the existing value, never rename.

**New (12):**

| Identifier | Widget |
|---|---|
| `phone_otp_keypad_0` … `phone_otp_keypad_9` | the ten digit cells |
| `phone_otp_keypad_backspace` | the backspace cell (icon-only → also needs a `Semantics(label:)`, new l10n key L6) |
| `phone_otp_resend_timer` | the countdown `Text` — non-interactive, but the resend state is what jm-009 AC2 exercises |

**Container discipline:** the `phone_otp_input` wrapper takes `container: true` **and**
`explicitChildNodes: true` (today only `container: true`, :279-280). Without the second flag the
per-cell `phone_otp_input_N` nodes get swallowed — §7.5, canonical idiom in `active_request_card.dart`.

**Always an explicit `Semantics` wrapper.** Do not pass `identifier:` to an OMDS widget (§7.5) —
`JeebCodeCells` and `JeebNumericKeypad` take an `identifier`/`identifierPrefix` and apply it via
their own explicit wrappers, per the kit rule.

---

## 7. RTL

The screen is nearly all digits, which is the highest-risk category for bidi.

1. **The code-cell row must be pinned LTR.** A 4-digit code is a number: under `ar` a plain `Row`
   would put cell 0 on the right and the code would read backwards. Wrap the cells row in
   `Directionality(textDirection: TextDirection.ltr)` **inside `JeebCodeCells`** — precedent
   `handover_code_display.dart:58-61` ("Bidi guard: an all-numeric code must never reorder").
2. **The keypad grid must be pinned LTR.** iOS and Android Arabic dialers do not mirror 1-2-3;
   mirroring would put `3` where users expect `1`, and would move backspace to the bottom-left.
   Force LTR inside `JeebNumericKeypad` and **do not** use `DirectionalIcons` for the backspace
   glyph — inside a forced-LTR numeric context `Icons.backspace` already points the correct way.
3. **Keypad labels are ASCII `'0'`–`'9'`, not l10n'd and not localized numerals.** The verified
   code must reach `/v1/auth/otp/verify` as ASCII. Precedent: `MoneyFormat`'s recorded digit policy
   (`money_format.dart:20-23`) — "the numerals stay Western/ASCII in both locales".
4. **The phone number in the subtitle needs an LTR isolate** — `+961 71123456` next to Arabic text
   reorders otherwise. Use the `⁦ … ⁩` pair (`money_format.dart:26-29`) or a nested
   `Directionality`.
5. **The `m:ss` countdown value** likewise goes in an LTR isolate.
6. `Wrap` (subtitle) and `Row(spaceBetween)` (meta) mirror automatically — no `EdgeInsets.only`
   anywhere; body padding is `EdgeInsetsDirectional`.
7. `JeebTopBar`'s back circle sits at the **start** edge, so it lands on the right under `ar`.
   `DirectionalIcons.back(context)` (:145) is preserved.

---

## 8. Test impact

Existing suites: `test/otp_verification_screen_test.dart` (6 tests),
`test/features/batch_b_additional_ac_tests.dart` (2 relevant), `test/registration_screen_test.dart` (1 relevant).

| Test | file:line | Outcome |
|---|---|---|
| `renders the 4-digit OTP input …` — `find.byKey('registration.otpField')` | otp_verification:66 | **PASSES** — the key moves to `JeebCodeCells` |
| same test — `tester.widget<OmdsOtpInput>(…).length == 4` | otp_verification:70-73 | **BREAKS — legitimate.** `OmdsOtpInput` is gone because it force-opens the OS keyboard the design removes. Fix: `expect(tester.widget<JeebCodeCells>(find.byKey(const Key('registration.otpField'))).length, 4)`. The *intent* (input length is locked to `kCustomerOtpLength`) is preserved |
| same test — `find.textContaining('60')` | otp_verification:79 | **BREAKS — legitimate.** The board's format is m:ss, so 60s renders `1:00`. Fix: `find.textContaining('1:00')` |
| countdown → resend swap | otp_verification:93-105 | **PASSES** — both keys re-homed onto the meta row |
| lockout banner + CTA/resend hidden | otp_verification:124-127 | **PASSES** |
| `onVerified` on verify | otp_verification:144-147 | **PASSES** |
| both seam tests | otp_verification:151-191 | **PASSES** (local field rename only) |
| `find.textContaining('Wrong code')` findsOneWidget | batch_b:151 | **PASSES only if §1.5 is honored** — render the error once |
| lockout at maxAttempts:5 | batch_b:202-210 | **PASSES** |
| `registration.otpField` + `registration.verify` after Send code | registration_screen:307-308 | **PASSES** — this is precisely why §1.6 keeps the CTA |

**Two edits total, both in `test/otp_verification_screen_test.dart`, both because the design
genuinely changed.** No identifier renamed, no gate weakened, no assertion deleted.

**New tests to add** (`test/otp_verification_screen_test.dart`):
- tapping `phone_otp_keypad_1..4` fills the cells and auto-fires `verifyCode('1234')` on the 4th;
- `phone_otp_keypad_backspace` removes the last digit;
- a wrong code clears the cells (`_code` back to `''`);
- an `ar` RTL smoke test asserting the cells and the keypad still lay out LTR.

**Maestro — a required flow edit outside this lane's ownership.**
`.maestro/flows/jm-009-phone-otp.yaml:130-147` taps `phone_otp_input_0..5` and `inputText`s one
digit into each. Two problems, one of them **pre-existing**: (a) it addresses six cells when only
four exist since the `kCustomerOtpLength = 4` switch, so the flow is *already* stale; (b) after this
change the cells are not `TextField`s, so `inputText` cannot reach them (`61_W0_QA_RESULTS.md:310`
records that `inputText` into these cells already fails in practice). **Fix:** replace those 18 lines
with four `tapOn: {id: phone_otp_keypad_1|2|3|4}` steps. Flows are integrator-owned → wiring request
W7. `jm-009:121/219/239/257` and `jm-018:92` only assert `phone_otp_input` *visibility* and survive
untouched; `jm-051:81` (`assertNotVisible phone_otp_verify_cta`) survives.

**Goldens:** none exist for this screen (the 6 committed PNGs are 18 and the 24-sheet). Nothing to regenerate.

---

## 9. Conflicts and refusals

**C1 — The board deletes the Verify CTA. PARTIALLY REFUSED.** See §1.6: refused on the strength of
`registration_screen_test.dart:308`, jm-009's fallback branch, jm-051's `assertNotVisible`, and WCAG
3.2.2. The CTA is retained but demoted to a docked pill that is disabled until the code is complete.
Escalated as an owner decision with its exact price named.

**C2 — `test/decision_violations_test.dart` has no rule touching this screen.** Verified by grep:
zero matches for `otp` / `registration` / `Otp` in that file. There is no D-decision conflict here.
D23 (no per-login OTP for returning users) lives in the router redirect, not this widget (:39-44) —
untouched.

**C3 — "Verifies automatically" must not be allowed to mean "we read your SMS".** The app cannot
read SMS (no autofill hints, no SMS Retriever). The copy is honest **only** as a description of
auto-submit-on-4th-digit, which is what it does. Keep the EN wording; the AR value must be
`"يتم التحقّق تلقائيًا"` ("verifies automatically"), **not** anything implying the app reads the message.
This is the §7.6 no-fabrication rule applied to copy rather than to data.

**C4 — The board's grouped `+961 3 123 456` is not what the domain produces.** Declared divergence
in §1.2; refusing to touch `LebanonPhone` for cosmetics.

**No backend contract is touched.** `POST /v1/auth/otp/request` / `/verify` (:26-28), the 4-digit
`kCustomerOtpLength` and the `OtpVerifyOutcome` enum are all consumed exactly as today.

---

## 10. Wiring requests (kit + integrator)

**To the Wave-1 kit owners:**
- **W1** `JeebTopBar` — `title` must be nullable/optional; screen 03 renders the back circle alone
  (HTML tpl 112-115). Also expose `onLeadingTap` and a `leadingKey` so `Key('registration.otpBack')`
  can ride along.
- **W2** `JeebCodeCells.input74` — cells are `Expanded` (`flex: 1 1 0%`, tpl 122), **not** a fixed
  width; gap 12; the row itself is pinned LTR internally.
- **W3** `JeebCodeCells` — `identifier` emits per-cell `${identifier}_$i`, matching
  `OmdsOtpInput.identifier`'s contract (omds `omds_otp_input.dart:289-297`) so `phone_otp_input_0..3`
  survive verbatim.
- **W4** `JeebCodeCells` — needs a `hasError` state (2px `colorScheme.error` frame). Not in the §5
  spec; required because this screen has a real invalid-code path.
- **W5** `JeebInfoNote` — an `error` tone (`errorContainer` fill + `onErrorContainer` ink) for the
  lockout banner. **Optional**: if declined, screen 03 keeps its private `_LockoutBanner` restyled
  in place, and this proposal is unaffected.
- **W6** `JeebNumericKeypad` — the 3×4 grid is pinned LTR; the blank cell is bottom-**start** and
  backspace bottom-**end** *within that forced LTR frame*, i.e. they do not mirror under `ar`.
  Identifier prefix produces `<prefix>_0..9` and `<prefix>_backspace`; the backspace takes a
  `backspaceSemanticsLabel`.

**To the integrator (l10n batch, 4-edit recipe each — EN + `@desc` → real AR → getter → call site):**

| # | Key | EN | AR |
|---|---|---|---|
| L1 | `registrationOtpHeadline` | `Check your messages` | `تفقّد رسائلك` |
| L2 | `registrationOtpSentToLabel` | `Code sent to` | `أُرسل الرمز إلى` |
| L3 | `registrationOtpEditPhone` | `Edit` | `تعديل` |
| L4 | `registrationOtpAutoVerifyHint` | `Verifies automatically` | `يتم التحقّق تلقائيًا` |
| L5 | `registrationOtpResendInLabel` | `Resend in` | `إعادة الإرسال خلال` |
| L6 | `registrationOtpKeypadBackspaceA11y` | `Delete last digit` | `حذف آخر رقم` |

`registrationOtpTitle`, `registrationOtpSubtitle` and `registrationOtpResendIn` lose their only
consumer. **Do not delete them** — `lib/l10n/*.arb` is integrator-owned and append-only, the parity
gate checks EN↔AR↔getter parity rather than usage, and deletions ripple into
`app_localizations.dart`.

**To the integrator (Maestro):** W7 — rewrite `jm-009-phone-otp.yaml:130-147` as four
`tapOn: {id: phone_otp_keypad_N}` steps (the existing block is already stale against the 4-digit code).

---

## 11. Definition-of-done deltas for this screen

- [ ] No `appBar:` on the `Scaffold`; the back circle is in-body.
- [ ] `OmdsOtpInput` no longer imported; the OS keyboard never opens on this screen.
- [ ] All 7 `Semantics` identifiers + all 8 test-pinned `Key`s still emitted.
- [ ] `tool/check_design_tokens.sh` clean — no `fontSize:`, no `Color(0x`, no
      `BorderRadius.circular(N)`, no literal `EdgeInsets.all(16)` in the feature file.
- [ ] Cells and keypad render LTR under `ar`; back arrow mirrors; subtitle wraps.
- [ ] 200% text scale scrolls instead of overflowing.
- [ ] Exactly two test lines changed (`otp_verification_screen_test.dart:70-73` and `:79`), plus
      four added tests.
- [ ] The empty band between the meta row and the CTA is left empty (R1 / risk 13).
