# 02 · Registration — REVISED instruction set (authoritative)

**Target file:** `lib/features/registration/presentation/registration_screen.dart` (603 LOC).
**Verdict: rebuild** — confirmed. The Opus proposal was verified against the render, the HTML, the
current source, the tests, the OMDS clone and the migration plan. Most of it checked out; the
corrections below are binding where they differ from it.

Wave 5 (Entry + integration). `lib/core/widgets/jeeb/` is **empty today** — every kit consumption
below is built **inline in this file** to the kit spec, and swapped in the Wave-5 sweep. Do not
wait on Wave 1.

Everything stays in this one file as private widgets — that is the file's existing structure.
No `presentation/widgets/` extraction is required; do not create one.

---

## A. Deltas from the Opus proposal (audit trail — implementer follows THIS doc)

**Cut (scope creep / rule violations):**
1. `_OrDivider` label ink change `onSurfaceVariant → onSecondaryContainer` — **CUT.**
   `test/core/theme/color_role_contrast_test.dart:129-137` exists specifically to guard against
   "anyone reverting the label roles back to onSecondaryContainer on a light surface" (an
   owner-reported AA defect), and plan §4.1 says periwinkle is "NEVER body text on white". The
   label keeps `colorScheme.onSurfaceVariant`.
2. `_OrDivider` padding change `Spacing.medium → Spacing.small` — **CUT.** Board gap is 14px,
   exactly between the 12 and 16 tokens; churn for zero fidelity gain.
3. Wiring request "add `context.jeebSemantics` accessor to `lib/core/theme/`" — **CUT.** The
   null-safe read below makes it unnecessary for this screen; theme files are not this lane's
   problem to improve.
4. Wiring request "kit #4 topBand spec / kit #2 `isLoading`" — **CUT.** The plan's §5 #4 row
   already specs the topBand mode for screen 02 verbatim, and keeping `OmdsLoadingButton` (below)
   makes the `isLoading` request moot.
5. Helper line / trust-copy periwinkle-on-light "ship with a flag" (proposal R4) — **overruled,
   not flagged.** Plan §4.1 is a locked rule, not a preference. See tasks 3 and 5 for the inks.

**Corrected (would not compile / factually off):**
1. `OmdsBorderRadius.only(...)` **does not exist** (OMDS `border_radius.dart` is static consts
   only). Use `const BorderRadius.only(bottomLeft: Radius.circular(Spacing.twoXLarge),
   bottomRight: Radius.circular(Spacing.twoXLarge))`. The token gate
   (`tool/check_design_tokens.sh:98-99`) only bans `BorderRadius.circular(<digit…` — a token
   argument passes it.
2. Off-by-one line refs: hero fill is `:423`, hero radius `:424`, subtitle `:464`.
3. Trust-note ink is `JeebSemanticColors.mutedText` (the kit #22 `muted`-tone spec), not a bare
   periwinkle role.
4. Social horizontal order per the render: **Google start, Apple end** (current vertical stack is
   Apple-first).
5. Field height: plain `Sizes.sixXLarge` (64; +4 vs board 60). Drop the `- twoXSmall` idea.
6. Build order: write the screen **as if all wiring requests are already granted** (l10n getters,
   `axis:` param) — that is the workflow contract. Do not sequence work on wiring landing.

**Verified true (kept, load-bearing):** the Semantics/key inventory; Maestro `_register_hero` at
`jm-018:73`, `jm-009:107,207`; `wrapForTest` themes with `ThemeData.light()` (so any
`extension<JeebSemanticColors>()!` would crash all registration widget tests — null-safe read is
mandatory); `OmdsLoadingButton` exposes `height/borderRadius/textStyle/backgroundColor`; the
`registration_screen.dart` raw-TextField exemption and `social_sign_in_button.dart` hex exemption
in `tool/check_design_tokens.sh`; `LebanonPhone.tryParse` (`domain/lebanon_phone.dart:50`,
`minNationalDigitCount = 7`); orphan l10n getters are warn-only in
`qa/t-mob-fix-002/l10n_parity_check.sh:29`; the parity test forbids only `value == key`
(identical EN/AR values are fine); and the Apple-glyph inversion defect in
`social_sign_in_button.dart:126,137-138` is REAL (OMDS's `_branded` pill is always white —
`omds_social_button.dart:177` — so light mode paints a white glyph on a white button).

---

## B. Frozen inventory — every one must survive byte-identical

Semantics identifiers (Maestro + widget tests assert these):

| Identifier | Today | After |
|---|---|---|
| `registration_root` | `:278` | outermost wrapper, unchanged |
| `_register_hero` | `:417` (already `container: true, explicitChildNodes: true` — preserve both) | wraps the navy band |
| `_register_hero_logo` | `:428` (keeps `label: l10n.splashLogoSemantic, image: true`) | on the wordmark SvgPicture |
| `register_phone_field` | `:537` (`textField: true, container: true`) | stays on the `TextField` itself, NOT the new outer container |
| `register_phone_submit_cta` | `:380` (`button: true, container: true`) | wraps the CTA |
| `login_social_google` / `login_social_apple` | `social_sign_in_section.dart` (not ours) | untouched |

Widget keys: `registration.phonePrefix`, `registration.phoneField`, `registration.sendCode`,
`registration.welcome`, `registration.orDivider`, `registration.googleSignIn`,
`registration.appleSignIn`.

New identifiers (convention `register_<element>`, matching the screen's existing prefix):
`register_phone_valid_check` (tick), `register_phone_helper` (helper/error line),
`register_trust_note` (trust footer).

---

## C. Tasks — execute in order, no backtracking

### 1. Restructure the shell (`_RegistrationViewState.build`, `:276-299`)

Delete the `OMDSAppBar` (`:281-284`) and the top `SafeArea` + `SingleChildScrollView(padding:
EdgeInsets.all(Spacing.medium))` (`:285-294`). New shape:

```dart
return Semantics(
  identifier: 'registration_root',
  container: true,
  child: AnnotatedRegion<SystemUiOverlayStyle>(
    // Navy band bleeds under the status bar now the app bar is gone.
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _RegisterHero(),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        Spacing.xLarge, Spacing.xLarge, Spacing.xLarge, 0),
                    child: _PhoneEntryBody(/* unchanged params */),
                  ),
                  const Spacer(), // HTML line 42 is a literal flex:1
                  const _TrustNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
```

- The `LayoutBuilder + ConstrainedBox(minHeight) + IntrinsicHeight` trio makes `Spacer()` legal
  inside a scroll view and degrades to scrolling on the 800×600 test surface, at 200% text scale,
  and when the keyboard opens (`resizeToAvoidBottomInset` stays default).
- Needs `import 'package:flutter/services.dart'` — already imported (`:3`).
- Do this step with all child widgets untouched; run `flutter test test/registration_screen_test.dart`
  before moving on. Only styling-neutral structure changes here.
- `l10n.registrationPhoneTitle` loses its call site — leave the key and getter in place (orphan
  getters are warn-only).

### 2. Rebuild `_RegisterHero` (`:407-442`) into the navy band; delete `_WelcomeHeading` (`:446-471`)

This is the inline form of kit #4 `JeebNavySurfaceCard` topBand mode (screen 02 is its only
topBand consumer; swap in Wave-5 sweep). Spec (HTML lines 11-20):

- Outer: `Semantics(identifier: '_register_hero', container: true, explicitChildNodes: true)` —
  all three properties exist today; preserve them or the logo id gets swallowed.
- `ClipRRect` + `Container`:
  - fill `colorScheme.primary` (board `--jeeb-navy`; kit #4 names `primary` fill — today's
    `secondaryContainer` at `:423` goes away),
  - radius `const BorderRadius.only(bottomLeft: Radius.circular(Spacing.twoXLarge), bottomRight:
    Radius.circular(Spacing.twoXLarge))` (32 vs board 36 — accepted divergence, no 36 token),
  - padding `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, MediaQuery.paddingOf(context).top +
    Spacing.medium, Spacing.xLarge, Spacing.twoXLarge)` (board `18/28/34` normalised to tokens;
    the top pad replaces the deleted status-bar chrome),
  - **no shadow** (kit #4: the 04-style hero "relies on overflow:hidden + the rings").
- Décor rings in a `Stack`, both `PositionedDirectional` so they mirror under RTL:
  - Ø200 at `top: -60, end: -60`, `Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.08), width: 1.5)`,
  - Ø120 at `top: -24, end: -24`, stroke = `accentRing` read null-safely:
    ```dart
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();
    ```
    (`wrapForTest` themes with `ThemeData.light()` — a `!` read crashes all 13 widget tests.)
    Token is α.30 vs board α.25 — accept the token.
- Content column (start-aligned):
  1. **No `9:41` status row. Never build device chrome.**
  2. Wordmark: existing `assets/brand/jeeb_logo.svg`, `height: Sizes.twoXLarge` (32; board h30),
     inside the existing `Semantics(identifier: '_register_hero_logo', label:
     l10n.splashLogoSemantic, image: true)` — `registration_screen_test.dart:340` matches
     `RegExp('Jeeb')` against that label.
  3. gap `Spacing.medium`, then headline:
     `Text(l10n.registrationWelcome, key: const Key('registration.welcome'), style:
     context.jeebText.h1.copyWith(color: colorScheme.onPrimary))` (24/w700 vs board 26 — R3: do
     not scale up).
  4. gap `Spacing.xSmall`, then tagline:
     `Text(l10n.registrationTagline, style: context.jeebText.body.copyWith(color:
     colorScheme.onSecondaryContainer))` — periwinkle on navy is the board's pairing and legal
     (the AA guard bans it on light surfaces only). The bilingual string is authored per locale
     (wiring request 1); no `Directionality` override, no `textAlign`.
- Delete `_WelcomeHeading` entirely; `registrationPhoneSubtitle` becomes the second warn-only
  orphan. The `Key('registration.welcome')` MUST move onto the headline (the RTL test reads
  `Directionality.of` at that key).

### 3. Rebuild the phone block (`_PhoneField`, `:517-589`) — label → field row → helper

Board (HTML 23-30): label 14/w700 navy · h60 row, r16, fill `--jeeb-surface-high`, 2px navy
border, pad 0/18, gap 12 · helper 12.5/w500.

- **Label** above the field: `Text(l10n.registrationPhoneHint, style: context.jeebText.cardTitle)`
  (15.5/w700; nearest to board 14/w700). Reuses the existing key ("Phone number"/"رقم الهاتف").
  Gap to field: `Spacing.small`.
- **Keep the raw `TextField` and its EXEMPT comment block (`:507-516`) verbatim** — the
  `tool/check_design_tokens.sh` filename exclusion depends on this file keeping that shape.
- Outer `Container` (fill/border move OUT of `InputDecoration`):
  `height: Sizes.sixXLarge` (64), `color: colorScheme.surfaceContainerHigh` (board
  `--jeeb-surface-high` per §4.1; today's `surfaceContainerHighest` at `:560` is the wrong role),
  `borderRadius: OmdsBorderRadius.medium`, `border: Border.all(color: errorText == null ?
  colorScheme.primary : colorScheme.error, width: Sizes.threeXSmall)`,
  `padding: EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium)`.
- **Focus ring** (plan §4.5 assigns `JeebShadows.focusRing` to focused inputs; once the
  InputDecoration border is gone the field would otherwise have zero focus feedback): give
  `_PhoneField` a `StatefulWidget` shell or a local `FocusNode` + `ListenableBuilder`; when
  focused add `boxShadow: JeebShadows.focusRing` to the container decoration.
- Row children in order, gaps `Spacing.small` (12):
  1. `const Text('🇱🇧')` — **its own `Text` widget.** Merging it into the dial-code string breaks
     `registration_screen_test.dart:41` (`find.text(LebanonPhone.dialCode)` findsOneWidget).
     Verify rendering on the S22; if Android draws "LB", delete this one `Text` only.
  2. `Text(LebanonPhone.dialCode, key: const Key('registration.phonePrefix'),
     style: context.jeebText.titleProminent, textDirection: TextDirection.ltr)` (17/w700 =
     board-exact; LTR pin keeps `+` on the correct side under `ar`).
  3. Divider `Container(width: 1, height: Sizes.xLarge, color: colorScheme.outlineVariant)`.
  4. `Expanded(` existing `Semantics(identifier: 'register_phone_field', textField: true,
     container: true, child: TextField(...)))` — keep `key`, `controller`, `enabled`,
     `keyboardType`, `onChanged` and the `FilteringTextInputFormatter.allow` (`:552-554`)
     byte-identical. Style `context.jeebText.titleProminent.copyWith(fontWeight: FontWeight.w600)`
     (17/w600 board-exact), `textDirection: TextDirection.ltr`. `InputDecoration` collapses to
     `border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintText:
     l10n.registrationPhoneExample` and **no `errorText`/`filled`/`fillColor`/`prefixIcon`**.
  5. The tick (below).
- **NO digit-grouping `TextInputFormatter`.** Board's `3 123 456` is rendered as the hint only.
  Three regression tests (`:60`, `:131`, `:159`) exist because a controller rewrite once made
  on-device login impossible. Do not touch the controller-ownership machinery (`:158-178`).
- **Tick** — the note's "live-valid check". Controller-driven, NOT state-driven (tests at `:159`,
  `:214` set controller text without firing `onChanged`; a state-bound tick would be wrong there):
  ```dart
  ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final isValid = LebanonPhone.tryParse(value.text) != null;
      return Semantics(
        identifier: 'register_phone_valid_check',
        child: AnimatedOpacity(
          opacity: isValid ? 1 : 0,
          duration: Durations.short3,
          child: Icon(Icons.check,
              size: Sizes.large, color: context.jeebRoles.accent),
        ),
      );
    },
  )
  ```
  `context.jeebRoles.accent` is the only sanctioned orange. `AnimatedOpacity` (not conditional
  insertion) so the row never reflows per keystroke.
- **Helper/error line** under the container, gap `Spacing.xSmall`:
  ```dart
  Semantics(
    identifier: 'register_phone_helper',
    child: Text(
      errorText ?? l10n.registrationPhoneHelper,
      style: context.jeebText.bodySmall.copyWith(
        fontWeight: FontWeight.w500,
        color: errorText == null
            ? colorScheme.onSurfaceVariant // AA-safe; NOT periwinkle (plan §4.1)
            : colorScheme.error,
      ),
    ),
  )
  ```
  `_phoneErrorCopy` (`:591-602`) is unchanged. The helper copy says "8-digit" while
  `LebanonPhone` accepts 7 — ship the copy, do **not** tighten the parser.

### 4. Restyle `_SendCodeButton` (`:362-402`) and `_OrDivider` (`:475-501`)

CTA — **keep `OmdsLoadingButton`** (`registration_screen_test.dart:363-377` pins the type, and it
pins the in-button spinner, a real capability). Do not swap to a kit CTA:

```dart
Semantics(
  identifier: 'register_phone_submit_cta',
  button: true,
  container: true,
  child: DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: OmdsBorderRadius.pill,
      boxShadow: JeebShadows.ctaNavy, // board-exact: 0 10 24 rgba(11,19,81,.28)
    ),
    child: OmdsLoadingButton(
      key: const Key('registration.sendCode'),
      height: Sizes.fiveXLarge,          // 56 vs board 58 — accepted
      borderRadius: OmdsBorderRadius.pill,
      textStyle: context.jeebText.button, // 17/w600 board-exact
      // text / isLoading / isEnabled / onTap byte-identical to today
    ),
  ),
)
```
The `renderedReady` / `sendCode(renderedPhone:)` logic (`:377-398`) is untouched — four P0
regression tests sit on it.

`_OrDivider`: keep the key, the single label, `Divider(color: colorScheme.outlineVariant)`, the
`onSurfaceVariant` ink and the `Spacing.medium` padding. Only change: label style becomes
`context.jeebText.bodySmall.copyWith(color: colorScheme.onSurfaceVariant)`. (`find.text('or')`
must stay findsOneWidget — D4.)

### 5. Reorder `_PhoneEntryBody` (`:332-356`) and add `_TrustNote`

New child order (the designer note's whole point — "phone-first"):
label → field row → helper → gap `Spacing.medium` → `_SendCodeButton` → gap `Spacing.xLarge` →
`_OrDivider` → gap `Spacing.medium` → `SocialSignInSection(axis: Axis.horizontal, onAuthenticated:
(_) => onSocialAuthenticated())`. Nothing at `Spacing.large`/`twoXLarge` between blocks any more
(board gaps are 10/8/18/26/18).

`_TrustNote` (new, docked after the `Spacer` in the shell) — inline form of kit #22
`JeebInfoNote(tone: muted)`; swap in the Wave-5 sweep, do not hand-roll a divergent style:

```dart
Padding(
  padding: EdgeInsetsDirectional.fromSTEB(
      Spacing.xLarge, 0, Spacing.xLarge,
      Spacing.twoXLarge + MediaQuery.viewPaddingOf(context).bottom),
  child: Semantics(
    identifier: 'register_trust_note',
    child: Container(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium, vertical: Spacing.small),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: Row(children: [
        Icon(Icons.shield, size: Sizes.large, color: semantics.mutedText),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(l10n.registrationTrustNote,
              style: context.jeebText.bodySmall
                  .copyWith(fontWeight: FontWeight.w500, color: semantics.mutedText)),
        ),
      ]),
    ),
  ),
)
```
`semantics` = the null-safe `JeebSemanticColors` read from task 2. `mutedText` here is the kit
#22 muted-tone spec, so the Wave-5 swap is a no-op.

### 6. Update the screen's own tests (`test/registration_screen_test.dart` — this lane owns it)

- `:392` — the one legitimate break: `find.text('مرحباً بك في جيب')` → `find.text('أهلاً بك يا جار')`.
- Add to the RTL test: assert the tagline renders.
- Add three tests: tick opacity 1 at 8 valid digits / 0 at 6; trust note present
  (`register_trust_note`); helper shows `registrationPhoneInvalid` on the error path
  (`register_phone_helper`).
- **If any other assertion in this file breaks, the implementation is wrong** — every remaining
  test encodes an on-device P0. Expected net delta: 1 string updated, 3 tests added.

### 7. Append the wiring requests (section E, verbatim) to
`docs/redesign-2026-08/wiring/02-registration.md`, then gate

- `flutter analyze` — bar: no issues beyond the pre-existing baseline (11 issues / 6 errors:
  2× `Semantics identifier` + 4× `DioExceptionType.transformTimeout`). Do not fix those.
- `flutter test test/registration_screen_test.dart` will only be green after the l10n wiring is
  applied by the integrator (the code references four new getters). That is expected under the
  as-if-granted contract; note it in your hand-off.

---

## D. Stop conditions

**Done means:** the seven identifiers and seven keys in §B all emitted, spelled identically; the
new screen renders band → phone-first form → CTA → or → two-up social → real emptiness → docked
trust note; no formatter on the controller; CTA still `isA<OmdsLoadingButton>`; flag emoji and
dial code are separate `Text`s; exactly one "or" text; analyze delta zero; test delta exactly as
§C-6; wiring file appended.

**Do NOT touch:** `application/`, `domain/`, `data/` of this feature;
`otp_verification_screen.dart`, `super_login/` (other lanes); `lib/features/auth/social/*`
(wiring requests only — including the Apple-glyph fix, which is NOT yours to apply);
`lib/core/router/*`, `lib/core/di/*`, `lib/core/theme/*`, `lib/l10n/*` (arb AND
`app_localizations.dart`), `pubspec.yaml`, OMDS, `.maestro/`, `tool/`. Do not build the `9:41`
status row, a country picker, a mic affordance, an email/password variant (deleted-funnel rule
JEBV4-199/Q-044), or the board's bare `Google`/`Apple` brand chrome (Google/Apple brand
guidelines + the documented hex-exemption block win; adopt placement + compactness only).

---

## E. Wiring requests — final text, ready to paste

### l10n
file: lib/l10n/app_en.arb, lib/l10n/app_ar.arb, lib/l10n/app_localizations.dart
need: one value change + four new keys for the rebuilt registration screen, plus their getters.
exact change:
app_en.arb — change:
```json
"registrationWelcome": "Welcome, neighbour",
```
app_en.arb — add:
```json
"registrationTagline": "Your errand, made easier · جيب، مشوارك أسهل",
"@registrationTagline": {"description": "Bilingual brand tagline in the registration hero band; each locale leads with its own script."},
"registrationPhoneHelper": "8-digit Lebanese number — we text you a code.",
"@registrationPhoneHelper": {"description": "Resting helper line under the phone field on registration."},
"registrationPhoneExample": "3 123 456",
"@registrationPhoneExample": {"description": "In-field example hint for the phone number; digit grouping is display-only."},
"registrationTrustNote": "No card needed. Your number is only shared with the Jeeber you accept.",
"@registrationTrustNote": {"description": "Docked trust footer on registration; cash-on-delivery, no in-app payment."}
```
app_ar.arb — change:
```json
"registrationWelcome": "أهلاً بك يا جار",
```
app_ar.arb — add (integrator owns final AR register; these follow the board's warm tone):
```json
"registrationTagline": "جيب، مشوارك أسهل · Your errand, made easier",
"registrationPhoneHelper": "رقم لبناني من ٨ أرقام — منبعتلك رمز برسالة نصية.",
"registrationPhoneExample": "3 123 456",
"registrationTrustNote": "ما في حاجة لبطاقة. رقمك بينشارك بس مع الجيبر يلي بتقبل عرضه."
```
app_localizations.dart — add next to `registrationWelcome` (`:572`):
```dart
String get registrationTagline => _get('registrationTagline');
String get registrationPhoneHelper => _get('registrationPhoneHelper');
String get registrationPhoneExample => _get('registrationPhoneExample');
String get registrationTrustNote => _get('registrationTrustNote');
```
why: the hero tagline, field hint, helper line and trust footer are all new board copy; the
welcome headline changes to the board's "Welcome, neighbour". `registrationPhoneTitle` and
`registrationPhoneSubtitle` become orphan getters — leave them (warn-only).

### cross-feature
file: lib/features/auth/social/social_sign_in_section.dart
need: an opt-in horizontal layout so screen 02 can demote social to a compact two-up row.
exact change: add `this.axis = Axis.vertical` to the constructor (`final Axis axis;`). In
`build`, when `axis == Axis.horizontal`, render `Row(children: [Expanded(google), SizedBox(width:
Spacing.small), Expanded(apple-if-available)])` with Google at the start (board order); when
`SocialSignInButton.isAppleAvailable()` is false, the Row degrades to one full-width Google
button. Keys (`registration.googleSignIn`/`appleSignIn`) and identifiers
(`login_social_google`/`login_social_apple`) unchanged. Default stays vertical so
`test/social_collision_sheet_test.dart` is untouched.
why: screen 02 passes `axis: Axis.horizontal` (already written as-if-granted); without this the
screen does not compile.

### cross-feature
file: lib/features/auth/social/social_sign_in_button.dart
need: fix the inverted Apple-glyph ternary — a live visibility defect on every light-mode iOS build.
exact change: at `:137-138`, `_AppleGlyph(color: isDark ? _appleBrandBlack : _appleBrandWhite)`
→ `_AppleGlyph(color: isDark ? _appleBrandWhite : _appleBrandBlack)` (OMDS's neutral skin renders
an always-white pill — `omds_social_button.dart:177` — so light mode currently paints a white
glyph on a white button). Re-check the `isDark:` passthrough at `:142` for the same inversion.
why: the glyph is invisible on screen 02 (and login) in light mode on iOS; found while verifying
this screen, independent of the redesign.
