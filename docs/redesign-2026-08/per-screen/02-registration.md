# 02 · Registration — change proposal

**Target file:** `lib/features/registration/presentation/registration_screen.dart` (603 LOC)
**Confirmed against `screen-repo-map.md:51`** — this is the live `/register` route
(`app_router.dart:744`), and it is the *only* consumer of `SocialSignInSection`.
**Verdict: rebuild.** The app bar is deleted, the hero is rebuilt, the field is rebuilt from an
`InputDecoration` into a composed row, the section order inverts (phone-first), and a docked trust
footer is added. Nothing in `application/`, `domain/` or `data/` changes.

Wave: **5 (Entry + integration)**. Depends on kit widgets #4 `JeebNavySurfaceCard` (top-band mode),
#22 `JeebInfoNote`, #2 `JeebCtaFooter`. None exist yet (`lib/core/widgets/jeeb/` is empty today) —
build order below tolerates that.

---

## 0. Semantics inventory (frozen — grepped `lib/features/registration/`)

Rendered by this screen and **must still be emitted after the rebuild**:

| Identifier | Today at | After |
|---|---|---|
| `registration_root` | `registration_screen.dart:278` | unchanged, still wraps the `Scaffold` |
| `_register_hero` | `:417` | moves onto the **navy top band** (Maestro `jm-018:73`, `jm-009:107,207` assert it visible) |
| `_register_hero_logo` | `:428` | unchanged, on the wordmark `SvgPicture` (keeps `label: l10n.splashLogoSemantic` — `registration_screen_test.dart:340` matches `RegExp('Jeeb')` against it) |
| `register_phone_field` | `:537` | stays on the **`TextField` itself**, not on the new outer container |
| `register_phone_submit_cta` | `:380` | unchanged, wraps the CTA |
| `login_social_google` | `social_sign_in_section.dart:85` | unchanged |
| `login_social_apple` | `social_sign_in_section.dart:72` | unchanged (iOS/macOS only) |

Widget **keys** that tests pin and that must also survive: `registration.phonePrefix`,
`registration.phoneField`, `registration.sendCode`, `registration.welcome`,
`registration.orDivider`, `registration.googleSignIn`, `registration.appleSignIn`.

**New identifiers proposed** (`<screen>_<element>` per §7.5):

| New identifier | On |
|---|---|
| `register_phone_valid_check` | the live-valid orange tick inside the field |
| `register_phone_helper` | the helper/error line under the field (lets Maestro assert the invalid-number path, which has no selector today) |
| `register_trust_note` | the docked trust footer |

Nothing is renamed. Nothing is removed.

---

## 1. Layout & structure

### 1.1 What the board actually is

`02-registration.html` is a 6-block column with a real `flex:1` spacer (line 42) — R1:

```
navy top band  (r 0 0 36 36, pad 18/28/34, 2 off-canvas rings, wordmark, headline, tagline)
↓ 28
label "Phone number" → field (h60) → helper → CTA "Send code" (h58, pill, ctaNavy shadow)
↓ 26
"—— or ——"
↓ 18
[ Google ] [ Apple ]        ← two flex:1 outline pills, h52
↓ flex:1                    ← REAL EMPTINESS (the bottom ~35% of the render is white)
trust note (r16, surfaceContainerHigh, shield + 2 lines), margin 0/24/32
```

### 1.2 Delete

- **`OMDSAppBar`** (`:281-284`). The board has no app bar; the navy band *is* the header. This
  orphans `l10n.registrationPhoneTitle` ("Enter your phone") — an orphan getter is a
  **non-blocking warning** in `l10n_parity_check.sh` (`orphan_getters.txt`, S2 \ S1). Leave the key.
- **`_WelcomeHeading`** as a standalone block (`:446-471`). Headline + tagline fold **into** the navy
  band (note: "brand hero folds the welcome + bilingual tagline into one navy band"). `:465`'s
  `registrationPhoneSubtitle` line disappears — second orphan getter, also non-blocking.
- **`SingleChildScrollView(padding: EdgeInsets.all(Spacing.medium))`** (`:287`) — the band must bleed
  to all three top edges; the gutter becomes 24 and applies to the body only.
- The `SizedBox(height: Spacing.large/twoXLarge)` rhythm at `:336-353` — measured gaps are 9–22px
  (R12), never 20/32.

### 1.3 Reorder (this is the note's whole point)

Today: `hero → welcome → SOCIAL → or → field → CTA`.
Board: `hero(+welcome) → label → field → helper → CTA → or → social → spacer → trust`.
"phone-first — the field and Send code lead (the app's only working auth), social demoted to
compact secondary pills".

### 1.4 The new `build()` skeleton

`registration_screen.dart:276-299` becomes:

```dart
return Semantics(
  identifier: 'registration_root',
  container: true,
  child: AnnotatedRegion<SystemUiOverlayStyle>(
    // The navy band bleeds under the status bar now that OMDSAppBar is gone.
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
                  const _RegisterHero(),          // navy top band, full-bleed
                  Padding(                        // 24px gutter body
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      Spacing.xLarge, Spacing.xLarge, Spacing.xLarge, 0),
                    child: _PhoneEntryBody(...),
                  ),
                  const Spacer(),                 // R1: real emptiness
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

- **No `SafeArea`** at the top (the band paints under the status bar and pads itself with
  `MediaQuery.paddingOf(context).top`); keep `SafeArea(top: false)` semantics by letting `_TrustNote`
  add `MediaQuery.viewPaddingOf(context).bottom` to its bottom margin.
- `LayoutBuilder + ConstrainedBox(minHeight) + IntrinsicHeight` is what makes `Spacer()` legal inside
  a scroll view **and** stops the 800×600 widget-test surface from throwing a RenderFlex overflow —
  measured natural height ≈ 590dp, so it fits, but the scroll fallback removes the cliff.
- `resizeToAvoidBottomInset` stays default `true`: when the keypad opens the whole column scrolls and
  the trust note rides up rather than being clipped.

---

## 2. Block-by-block spec

### 2.1 `_RegisterHero` → the navy top band (`:407-442`)

Today: a 96dp `Container(color: colorScheme.secondaryContainer, radius: large)` with a centred
56dp logo. Becomes the board's band.

Consume kit **#4 `JeebNavySurfaceCard` in `topBand` mode** (§5 #4 explicitly names
"optional top-band mode (`0 0 36 36`, screen 02)" — screen 02 is its only consumer, so this lane
should specify it, not invent a local variant). If the kit lands after this screen, build it inline
and swap in the Wave-5 sweep.

| Property | Value | Token |
|---|---|---|
| fill | `#0B1351` | `colorScheme.primary` (**not** `secondaryContainer` — same hex today, but `primary` is the role the plan names) |
| radius | bottom 36 | `OmdsBorderRadius.only(bottomLeft: Spacing.twoXLarge, bottomRight: Spacing.twoXLarge)` → **32, a −4 divergence**; there is no 36 token and `BorderRadius.circular(36)` is banned in `lib/features` |
| padding | `18 / 28 / 34` | `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, MediaQuery.paddingOf(context).top + Spacing.medium, Spacing.xLarge, Spacing.twoXLarge)` — horizontal normalised 28→24 per §4.3 ("no 28 token, and the 28px rhythm claim is wrong") |
| shadow | none | R6(b)/R7 — the band relies on `overflow: hidden` + the rings |
| décor ring A | Ø200 @ `right:-60 top:-60`, `1.5px rgba(255,255,255,.08)` | `PositionedDirectional(top: -60, end: -60)`, `Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.08), width: 1.5)` |
| décor ring B | Ø120 @ `right:-24 top:-24`, `1.5px rgba(215,59,0,.25)` | same, colour = `JeebSemanticColors.accentRing` (token is `.30` vs the board's `.25` — accept the token, §4.1) |
| clip | `ClipRRect` with the same radius | rings are off-canvas |

Content column inside:

| Element | Board | Flutter |
|---|---|---|
| status row `9:41` | — | **DO NOT BUILD** (§3 "mock chrome") |
| wordmark | `assets/jeeb-wordmark.svg` h30, margin-top 26 | existing `assets/brand/jeeb_logo.svg`, `height: Sizes.twoXLarge` (32), keep `Semantics(identifier: '_register_hero_logo', label: l10n.splashLogoSemantic, image: true)` |
| headline | 26 / w700 / ls −0.6 / white, margin-top 16 | `Text(l10n.registrationWelcome, key: const Key('registration.welcome'), style: context.jeebText.h1.copyWith(color: colorScheme.onPrimary))` — `h1` is 24/w700, a **−2px divergence**; R3 says do not scale up, and Wave 0 is frozen |
| tagline | 15 / w500 / periwinkle, margin-top 6, with the AR half at w700 | `Text(l10n.registrationTagline, style: context.jeebText.body.copyWith(color: colorScheme.onSecondaryContainer))` (13.5/w500, −1.5px) |

`Semantics(identifier: '_register_hero', container: true, explicitChildNodes: true)` wraps the whole
band (per §7.5, `explicitChildNodes` is required or it swallows `_register_hero_logo`) — this is what
`.maestro/flows/jm-018-social-login.yaml:73` and `jm-009-phone-otp.yaml:107,207` wait on.

### 2.2 Field label + field + helper (`_PhoneField`, `:517-589`)

The board (HTML lines 23–30) is **one 60dp decorated row**, not a Material `InputDecoration`:

```
Text "Phone number"            14 / w700 / navy
  ↓ 10
Container h60 r16 fill #EAE7EB border 2px navy pad 0/18 gap 12
   [🇱🇧] [+961]  │  [ digits …………… ]  [✓ orange 20px]
  ↓ 8
Text "8-digit Lebanese number — we text you a code."   12.5 / w500 / periwinkle
```

Concretely:

- **Keep the raw `TextField`.** The `EXEMPT(flutter-omds-design-system-usage)` block at `:507-516`
  and `tool/check_design_tokens.sh:124` (`registration_screen.dart` is excluded from the raw-TextField
  check by filename) both stay valid. §Wave-5 of the plan says "keep the raw-TextField +961 exemption".
- Move fill/border **out of `InputDecoration`** into an outer `Container`:
  `color: colorScheme.surfaceContainerHigh` (**changed from `surfaceContainerHighest`** — §4.1 maps
  `--jeeb-surface-high #EAE7EB` → `surfaceContainerHigh` and names "fields" as its use),
  `borderRadius: OmdsBorderRadius.medium` (16 — unchanged), `border: Border.all(color:
  colorScheme.primary, width: Sizes.threeXSmall)` (2px navy, board-literal),
  `height: Sizes.sixXLarge - Sizes.twoXSmall` → prefer plain `Sizes.sixXLarge` (64) or
  `constraints: BoxConstraints(minHeight: Sizes.fiveXLarge + Sizes.twoXSmall)`; **simplest honest
  choice: `Sizes.sixXLarge` (64) — a +4 divergence, and there is no 60 token.**
  Add `boxShadow: JeebShadows.focusRing` when a `FocusNode` reports focus (§4.5 names `focusRing`
  for "focused inputs"; the board draws only the resting state).
- `InputDecoration` collapses to `border: InputBorder.none, filled: false, isDense: true,
  contentPadding: EdgeInsets.zero, hintText: l10n.registrationPhoneExample` and **no `errorText`** —
  the helper/error line is now our own `Text` below the container (see below).
- Row children, in order (auto-mirrors under RTL, all directional):
  1. `const Text('🇱🇧')` — **separate `Text` from the dial code**. If the flag and `+961` are merged
     into one string, `registration_screen_test.dart:41` (`find.text(LebanonPhone.dialCode)`) fails.
  2. `Text(LebanonPhone.dialCode, key: const Key('registration.phonePrefix'),
     style: context.jeebText.titleProminent, textDirection: TextDirection.ltr)` — 17/w700 exactly
     matches the board.
  3. 1×24 divider: `Container(width: 1, height: Sizes.xLarge, color: colorScheme.outlineVariant)`
     (`--jeeb-surface-highest` → `outlineVariant` for 1px dividers, §4.1).
  4. `Expanded(child: Semantics(identifier: 'register_phone_field', textField: true, container: true,
     child: TextField(key: const Key('registration.phoneField'), …)))` with
     `style: context.jeebText.titleProminent.copyWith(fontWeight: FontWeight.w600)` (17/w600) and
     `textDirection: TextDirection.ltr`.
  5. the live-valid tick (§2.3).
  Gaps of 12 via `Spacing.small`.
- **Do not add a digit-grouping `TextInputFormatter`.** The board renders `3 123 456`, but the
  controller is the source of truth at submit (`:377`, `:396`) and three regression tests
  (`registration_screen_test.dart:60`, `:131`, `:159`) exist *because* a formatter-like rewrite of the
  controller once made on-device login impossible. Render the grouping as the **hint**
  (`registrationPhoneExample`) only. The `FilteringTextInputFormatter.allow` at `:552-554` stays.
- Helper / error line, keyed for Maestro:
  ```dart
  Semantics(
    identifier: 'register_phone_helper',
    child: Text(
      errorText ?? l10n.registrationPhoneHelper,
      style: context.jeebText.bodySmall.copyWith(
        fontWeight: FontWeight.w500,
        color: errorText == null
            ? colorScheme.onSecondaryContainer   // periwinkle qualifier (R4)
            : colorScheme.error,
      ),
    ),
  )
  ```
  On error the container border also flips to `colorScheme.error`. `_phoneErrorCopy` (`:591-602`)
  is unchanged.

**Field label** above: `Text(l10n.registrationPhoneHint, style: context.jeebText.cardTitle)` —
board is 14/w700, `cardTitle` is 15.5/w700 (**+1.5 divergence**; `bodySmall` at 12 is further off).
Reuses the existing key ("Phone number" / "رقم الهاتف") rather than minting one.

### 2.3 The live-valid check — the note's one new behaviour

> "live-valid check on the field"

HTML line 28: a 20px checkmark filled `var(--jeeb-orange)`.

**No cubit or backend change is needed.** `LebanonPhone.tryParse` (`domain/lebanon_phone.dart:50`)
already answers this and `RegistrationState.isPhoneReady` (`registration_state.dart:67`) already
exposes it. But drive the tick from the **controller**, not from state:

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
        child: Icon(Icons.check, size: Sizes.large, color: context.jeebRoles.accent),
      ),
    );
  },
)
```

Rationale (matters): the field owns its text while the user types (`:158-178`, PR #45) and two tests
(`:214`, `:159`) deliberately set `controller.text` **without** firing `onChanged`. A tick bound to
`state.phoneInput` would be wrong in exactly those paths. `ValueListenableBuilder` also keeps the
tick out of the `BlocConsumer` rebuild, so no extra rebuilds of the CTA.

Colour: `context.jeebRoles.accent` (§4.6 — the only sanctioned orange). `registration_screen.dart`
is **not** in `no_raw_semantic_colors_test.dart`'s 18-file list, but the rule is global.
Reserve `AnimatedOpacity` (not conditional insertion) so the row does not reflow per keystroke.

### 2.4 `_SendCodeButton` (`:362-402`) — restyle in place, **keep `OmdsLoadingButton`**

Board: h58, `r999`, navy, white 17/w600, `box-shadow: rgba(11,19,81,.28) 0 10 24` = exactly
`JeebShadows.ctaNavy`.

**Do not swap in kit #2 `JeebCtaButton` yet.** `registration_screen_test.dart:363-377` asserts the CTA
`isA<OmdsLoadingButton>()`, and that is not a cosmetic assertion — it pins the in-button spinner
(`state.isSendingCode`), a real capability the kit spec does not mention. Instead:

```dart
Semantics(
  identifier: 'register_phone_submit_cta',
  button: true,
  container: true,
  child: DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: OmdsBorderRadius.pill,
      boxShadow: JeebShadows.ctaNavy,
    ),
    child: OmdsLoadingButton(
      key: const Key('registration.sendCode'),
      height: Sizes.fiveXLarge,                    // 56 vs the board's 58
      borderRadius: OmdsBorderRadius.pill,
      textStyle: context.jeebText.button,          // 17/w600 exactly
      // …text / isLoading / isEnabled / onTap unchanged, byte-for-byte
    ),
  ),
)
```

`OmdsLoadingButton` already accepts `height`, `borderRadius`, `textStyle`, `backgroundColor`
(verified in `omds_library/lib/src/buttons/omds_loading_button.dart:19-36`), so no OMDS edit is
needed. **Wiring request:** if Wave 1 gives `JeebCtaButton` an `isLoading` passthrough that renders
`OmdsLoadingButton` internally, swap during the Wave-5 sweep and update the type assertion then.

The three enablement/submit behaviours at `:377-398` (`renderedReady`, `sendCode(renderedPhone:)`)
are **untouched** — four P0 regression tests sit on them.

### 2.5 `_OrDivider` (`:475-501`) — keep, retune

- Keep `key: const Key('registration.orDivider')` and the single label — `registration_screen_test.dart:347`
  (D4) asserts `find.text('or')` findsOneWidget.
- Rules: `Divider(color: colorScheme.outlineVariant)` already correct (`--jeeb-surface-highest`).
- Label: `context.jeebText.bodySmall.copyWith(color: colorScheme.onSecondaryContainer)` (12/w600 vs
  the board's 13/w600) — **changed from `onSurfaceVariant`**; the board's "or" is periwinkle.
- Horizontal padding 14 → `Spacing.small` (12), replacing `Spacing.medium`.
- Block gap above = 26 → `Spacing.xLarge` (24); below = 18 → `Spacing.medium` (16).

### 2.6 Social row — demoted, two-up, brand chrome **unchanged**

Position moves below the CTA (§1.3). Shape changes from a stacked full-width column to a
`Row` of two `Expanded` pills, 12px gap.

This requires editing `lib/features/auth/social/social_sign_in_section.dart:64-91` — **another
feature dir**, so §7.4 makes it a **wiring request**, not a unilateral edit. Proposed API:
`SocialSignInSection({this.onAuthenticated, this.axis = Axis.vertical})`; screen 02 passes
`Axis.horizontal`. Implementation detail that matters: on Android
`SocialSignInButton.isAppleAvailable()` is false, so the row must degrade to **one full-width
Google button**, not a half-width one. (Under `flutter test` on the Mac host, `Platform.isMacOS` is
true, so both buttons render — `test/social_collision_sheet_test.dart:55` mounts the section
standalone and taps `registration.googleSignIn`; a `Row` inside a `Scaffold` body keeps working.)

**REFUSED — the board's button chrome and labels.** The board draws brown-outlined pills labelled
bare `Google` / `Apple` with a monochrome `G`. Do not build that:

1. Google's Identity Branding Guidelines mandate one of the approved strings ("Sign in with
   Google" / "Continue with Google") and a compliant `G` mark; `Apple` HIG likewise constrains the
   "Sign in with Apple" label. Bare `Google`/`Apple` is out of spec for both. Keep
   `l10n.registrationContinueWithGoogle` / `…WithApple`.
2. `social_sign_in_button.dart` carries a documented `EXEMPT` brand-color block and is the one
   filename excluded from the `Color(0xFF…)` gate (`tool/check_design_tokens.sh:78`). The plan's
   Wave-5 line for this screen says explicitly: "keep `social_sign_in_button.dart` hex exemption".
3. The local OMDS has *already* moved to a neutral skin — `OmdsSocialButtons._branded`
   (`omds_social_button.dart:160-181`) is a white pill, navy label `#0B1351`, 1px `#CBD0E0` border.
   That is within ~1 token of the board's intent; the remaining delta (brown outline vs `#CBD0E0`)
   is an **OMDS** value and OMDS is off-limits (§7.4).

So: adopt the board's **placement and two-up compactness**, keep the brand-compliant buttons.

**Live defect found while reading this (worth its own fix):**
`social_sign_in_button.dart:126,138` computes `isDark = brightness == Brightness.dark` and passes
`_AppleGlyph(color: isDark ? _appleBrandBlack : _appleBrandWhite)`. Since OMDS now always renders a
**white** pill, light mode paints a **white Apple glyph on a white button — invisible**. The ternary
is inverted for the current OMDS skin. Wiring request to the `auth/social` owner; it is on-screen on
screen 02 on every iOS device.

### 2.7 Trust footer (new) — kit #22 `JeebInfoNote`

HTML lines 43–46: `margin 0/24/32`, `pad 15/17`, `r16`, `surfaceContainerHigh`, gap 12, a 20px
periwinkle shield, text 13/lh19/w500 periwinkle.

That is exactly `JeebInfoNote(tone: JeebInfoNoteTone.muted)` (§5 #22: "`muted`
(`surfaceContainerHigh` + 12.5/w500 lh18 `mutedText`)"). Build:

```dart
Padding(
  padding: EdgeInsetsDirectional.fromSTEB(
    Spacing.xLarge, 0, Spacing.xLarge,
    Spacing.twoXLarge + MediaQuery.viewPaddingOf(context).bottom),
  child: Semantics(
    identifier: 'register_trust_note',
    child: JeebInfoNote(
      icon: Icons.shield_outlined,
      text: l10n.registrationTrustNote,
    ),
  ),
)
```

If `JeebInfoNote` has not landed, inline the same decoration and swap it in the Wave-5 sweep — do
**not** hand-roll a second grey-panel style (§5.1 step 2 exists precisely to stop that).

"trust footer replaces fine print" (note) — there is no fine print on this screen today, so this is
additive; nothing is deleted for it.

---

## 3. Token table — every hardcoded/mis-roled value in the current file

| Current | Line | Becomes |
|---|---|---|
| `colorScheme.secondaryContainer` (hero fill) | `:422` | `colorScheme.primary` |
| `Sizes.tenXLarge` (96 hero height) | `:421` | height is intrinsic (pad + content), no fixed height |
| `OmdsBorderRadius.large` (hero r20, all corners) | `:423` | `OmdsBorderRadius.only(bottomLeft: Spacing.twoXLarge, bottomRight: Spacing.twoXLarge)` |
| `Sizes.fiveXLarge` (56 logo) | `:435` | `Sizes.twoXLarge` (32) |
| `theme.textTheme.headlineSmall.copyWith(w700)` | `:459` | `context.jeebText.h1` + `colorScheme.onPrimary` |
| `theme.textTheme.bodyMedium` + `onSurfaceVariant` | `:465` | tagline: `context.jeebText.body` + `colorScheme.onSecondaryContainer` |
| `textTheme.bodyMedium` + `onSurfaceVariant` ("or") | `:491-494` | `context.jeebText.bodySmall` + `colorScheme.onSecondaryContainer` |
| `EdgeInsets.symmetric(horizontal: Spacing.medium)` (divider) | `:488` | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.small)` |
| `colorScheme.surfaceContainerHighest` (field fill) | `:560` | `colorScheme.surfaceContainerHigh` |
| `textTheme.bodyLarge` (field text) | `:555` | `context.jeebText.titleProminent.copyWith(fontWeight: FontWeight.w600)` |
| `textTheme.bodyLarge.copyWith(w500, onSurface)` (prefix) | `:569-572` | `context.jeebText.titleProminent` (17/w700, ink inherits navy) |
| `EdgeInsets.symmetric(h: medium, v: small)` prefix pad | `:562-565` | gone — the prefix is a Row child with `Spacing.small` gaps |
| `border: OutlineInputBorder(BorderSide.none)` | `:576-579` | `InputBorder.none`; border moves to the outer `Container` (`2px colorScheme.primary`) |
| `EdgeInsets.all(Spacing.medium)` (body pad) | `:287` | `EdgeInsetsDirectional` gutters of `Spacing.xLarge` on the body only |
| `SizedBox(height: Spacing.large / twoXLarge)` ×5 | `:336-353` | `Spacing.small`–`Spacing.large` per §2 above (R12: 9–22, never 28/32) |
| — (no shadow today) | `:383` | `JeebShadows.ctaNavy` behind the CTA |
| — | new | `JeebSemanticColors.accentRing` for the hero ring |
| — | new | `context.jeebRoles.accent` for the valid tick |

**Read `JeebSemanticColors` null-safely.** §4.6 tells lanes to write
`Theme.of(context).extension<JeebSemanticColors>()!` — under `test/support/sync_app_localizations.dart`'s
`wrapForTest`, the harness builds `ThemeData.light()`, **not** `AppTheme.light()`, so the extension
is absent and the `!` would throw in all 13 registration widget tests. `context.jeebText` and
`context.jeebRoles` both have `?? …light()` fallbacks (`jeeb_text_styles.dart:211`,
`jeeb_color_roles.dart:264`); `JeebSemanticColors` has none and has **zero consumers app-wide today**,
so this lane would be the first to hit it. Use
`Theme.of(context).extension<JeebSemanticColors>() ?? JeebSemanticColors.light()` and raise the
wiring request below.

---

## 4. Shared components consumed

| Kit widget | Replaces | Note |
|---|---|---|
| #4 `JeebNavySurfaceCard` (`topBand` mode + décor ring, `shadow: none`) | `_RegisterHero`'s `Container` | screen 02 is the *only* consumer of `topBand`; the mode must accept a **bottom-only radius** and a **status-bar-inset top pad** |
| #22 `JeebInfoNote` (`muted`) | net-new trust footer | 5-of-10-spine pattern; do not hand-roll |
| #2 `JeebCtaFooter`/`JeebCtaButton` | `_SendCodeButton` | **deferred** — see §2.4; take the `ctaNavy` shadow + pill + `jeebText.button` now, swap the widget when `isLoading` exists |
| #23 `JeebProfileHeader` | — | **not applicable**, pre-auth screen |
| #1 `JeebTopBar` | `OMDSAppBar` | **not applicable** — the board gives 02 no top bar at all (like 04/16) |

Not consumed and deliberately so: `JeebSelectChip`, `JeebSectionLabel` (the "Phone number" label is a
navy w700 field label, not an uppercase ls-1.2 periwinkle section label — do not force it).

---

## 5. New functionality & data

| Board feature | Buildable today? | Needs |
|---|---|---|
| live-valid tick | **yes** | `LebanonPhone.tryParse` + `ValueListenableBuilder` on the existing controller. **No cubit/state change, no endpoint.** |
| helper "8-digit Lebanese number — we text you a code." | yes | l10n only. Honest: `LebanonPhone` accepts **7 or 8** digits (`minNationalDigitCount = 7`, documented for the `+9613000002` seed). The board's copy says 8. Ship the board's copy — it is guidance for the common case and the field still accepts 7 — but do **not** tighten the parser to match the string. |
| trust note | yes | l10n only. Factual: cash-on-delivery, no in-app payment; the phone is shared with the accepted Jeeber. Consistent with the DS voice section and with D41/D44 framing. |
| bilingual tagline | yes | l10n only. |
| digit grouping `3 123 456` | rendered as **hint text only** | a live formatter is refused (§2.2) |
| country picker | not drawn, not built | JEEB-55 fixes +961; no change |

**Nothing here invents a field or an endpoint.** No `TODO(redesign-24)` data gaps on this screen.

### l10n batch (integrator-serialized, §7.4 — 4-edit recipe each)

| Key | EN | AR | Status |
|---|---|---|---|
| `registrationWelcome` | `Welcome, neighbour` | `أهلاً بك يا جار` | **value change** (was "Welcome to Jeeb" / "مرحباً بك في جيب"). Board copy + the DS content rule "prefer *neighbour* over *client*". |
| `registrationTagline` | `Your errand, made easier · جيب، مشوارك أسهل` | `جيب، مشوارك أسهل · Your errand, made easier` | NEW. Bilingual pairing is a DS signature; each locale leads with its own script so the bidi run order is authored, not accidental. |
| `registrationPhoneHelper` | `8-digit Lebanese number — we text you a code.` | `رقم لبناني من ٨ أرقام — منبعتلك رمز برسالة نصية.` | NEW |
| `registrationPhoneExample` | `3 123 456` | `3 123 456` | NEW (in-field hint; identical values are fine — the gate only forbids `value == key`) |
| `registrationTrustNote` | `No card needed. Your number is only shared with the Jeeber you accept.` | `ما في حاجة لبطاقة. رقمك بينشارك بس مع الجيبر يلي بتقبل عرضه.` | NEW |

Orphaned (leave in place, non-blocking warning): `registrationPhoneTitle`, `registrationPhoneSubtitle`.

---

## 6. New routes

**None.** `/register` already exists (`app_router.dart:744-745`, name `register`) and is the sole
pre-auth destination (`:271-277`, `:384`). This screen adds no surface. Do **not** touch
`backFallbacks` — `register` is a first-run root (`:446`).

---

## 7. RTL

| Risk | Handling |
|---|---|
| hero décor circles at `right:-60/-24` | `PositionedDirectional(top:, end:)` — they belong at the top-**END**, mirroring with the locale (R6/§5 #4) |
| body gutters | `EdgeInsetsDirectional` everywhere; never `EdgeInsets.only(left:)` |
| field row order (flag → +961 → divider → digits → tick) | plain `Row` — mirrors automatically; in AR the dial code sits at the right and the tick at the left, which is correct |
| the phone digits themselves | `TextField(textDirection: TextDirection.ltr)` **and** `Text(dialCode, textDirection: TextDirection.ltr)`. Without this the `+` migrates and the caret jumps under `ar` |
| bilingual tagline (mixed AR+EN in one string) | authored per locale so the leading script matches the paragraph direction; no forced `Directionality`, no `textAlign` override. **Verify visually under `ar`** — the `·` separator is the one glyph that can land on the wrong side |
| social `Row` | two `Expanded` in a `Row`; mirrors automatically |
| bottom-only radius 36/36 | symmetric — no directional variant needed |
| trust note icon + text | `Row` with `Spacing.small` gap; `JeebInfoNote` owns the direction |
| 200% text scale | the `SingleChildScrollView + ConstrainedBox(minHeight) + IntrinsicHeight` shell means the `Spacer` collapses and the column scrolls instead of overflowing |

Existing RTL coverage (`registration_screen_test.dart:379`) stays and should gain an assertion that
the tagline renders.

---

## 8. Test impact

| Test | Effect | Legitimate? |
|---|---|---|
| `registration_screen_test.dart:379-393` "lays out RTL under Locale(ar)" — asserts `find.text('مرحباً بك في جيب')` | **BREAKS** | **Yes** — the welcome copy genuinely changes to the board's "Welcome, neighbour". Update the expected string to `أهلاً بك يا جار`. The `Directionality` assertion on `Key('registration.welcome')` still passes because the key moves with the headline into the hero. |
| `:36-42` "renders the fixed +961 prefix" | passes **only if** the flag emoji is a separate `Text` | design pressure; handled in §2.2 |
| `:331-345` "branded hero + welcome heading + or divider" | passes — `_register_hero_logo`'s `label: splashLogoSemantic` ("Jeeb") and both keys survive | — |
| `:347-361` D4 "exactly ONE or divider" / `find.text('or')` | passes — one `_OrDivider`, and `SocialSignInSection` still renders none | — |
| `:363-377` "CTA is an OmdsLoadingButton" | passes — deliberately kept (§2.4) | — |
| `:44-58`, `:60-129`, `:131-157`, `:159-212`, `:214-267`, `:269-288`, `:290-310` (7 phone/controller/submit tests) | pass — controller ownership, `onChanged`, key, `isEnabled`, `sendCode(renderedPhone:)` untouched | — |
| `:312-329` super-login relocation | passes — nothing re-added | — |
| `test/social_collision_sheet_test.dart:55` | passes if the section's horizontal mode is opt-in (`axis` defaults to vertical) | — |
| `test/core/router/fr_gating_first_run_test.dart:285,367`, `w1_routes_resolve_test` | pass — `find.byType(RegistrationScreen)` only | — |
| new | **add**: tick visible at 8 digits / absent at 6; trust note present; `register_phone_helper` shows `registrationPhoneInvalid` on the error path | additive only |

No goldens exist for this screen. **Net expected delta: one string updated in one existing test,
plus three added tests.** If any *other* assertion in `registration_screen_test.dart` breaks, the
proposal is wrong — every one of those tests encodes an on-device P0.

---

## 9. Conflicts

| # | Board asks | Verdict |
|---|---|---|
| **R1** | bare `Google` / `Apple` labels in brown-outlined pills with a monochrome `G` | **REFUSED (partial).** Google Identity + Apple HIG constrain both the label string and the mark; `social_sign_in_button.dart` carries a documented brand `EXEMPT` block and is the one file excluded from the hex gate, and the plan's own Wave-5 line says keep it. Adopt the **placement and two-up compactness**; keep the compliant buttons and `registrationContinueWith*` labels. |
| **R2** | a mic / voice affordance | not drawn on 02 — no B04 exposure. Noted only so a lane does not add one. |
| **R3** | `--jeeb-cyan-check #20F0FF` | not used here, and `readTick` has **zero** board occurrences (§4.1) — the tick is `jeebRoles.accent`. |
| **R4** | periwinkle helper text on white, periwinkle body in the trust note | **Ship, with a flag.** `color_role_contrast_test` pins that periwinkle-on-white *fails* AA and that guard stays; `JeebSemanticColors` is explicitly "decorative, NOT contrast-gated". The board does exactly this on 5 screens and `JeebInfoNote.muted` bakes it in, so refusing it here alone would create drift. If a11y review objects, the AA-safe swap is `colorScheme.onSurfaceVariant` (`#5C4038`) for the two lines — a one-token change, not a redesign. |
| **R5** | 🇱🇧 flag emoji in the prefix | **Ship, verify on the S22.** The DS says emoji are reserved for the tier lexicon, and Android flag rendering is inconsistent (some builds show `LB`). Same class of gamble as the plan's risk #7 (🟦). If it renders badly, drop the glyph — `+961` alone is unambiguous. |
| **R6** | exact 36px band radius / 60px field / 58px CTA | **Divergences accepted** (32 / 64 / 56) — no tokens exist at those values and §4.4 forbids raw `BorderRadius.circular(N)` in `lib/features`. Listed here so the Wave-5 pixel sweep does not report them as misses. |
| **R7** | the board's status row `9:41` and 440×956 frame | **Never built** (§3 mock chrome). |

No `decision_violations_test.dart` decision touches this screen: D56 (no-skip) is the mutual-rating
screen; D41/D44 wording is not on 02; B04 is the chat composer; the "deleted funnel" rule (JEBV4-199 /
Q-044) means **do not** build an L1/L2 email-password variant — this proposal does not.

---

## 10. Wiring requests (files this lane does not own)

1. **l10n integrator** — the 5-key batch in §5 (EN + `@` description, real AR, `_get` getter, call
   site), including the `registrationWelcome` **value change**.
2. **`lib/features/auth/social/social_sign_in_section.dart`** — add `axis` (default `Axis.vertical`,
   so `social_collision_sheet_test` is untouched); horizontal mode = `Row` of `Expanded` with a
   `Spacing.small` gap, degrading to one full-width button when Apple is unavailable.
3. **`lib/features/auth/social/social_sign_in_button.dart`** — fix the inverted Apple glyph ternary
   (`:138`): OMDS's neutral skin is always white, so light mode currently paints a white glyph on a
   white button. Independent of this redesign; visible on every iOS build.
4. **Wave-0 owner / `lib/core/theme/jeeb_semantic_colors.dart`** — add a `context.jeebSemantics`
   accessor with a `?? JeebSemanticColors.light()` fallback, mirroring `jeebText`/`jeebRoles`.
   Today the documented `!` read crashes under any harness that themes with `ThemeData.light()` —
   which is what `test/support/sync_app_localizations.dart`'s `wrapForTest` does.
5. **Wave-1 kit** — `JeebNavySurfaceCard.topBand` must accept a bottom-only radius, `shadow: none`,
   and a top pad that folds in `MediaQuery.paddingOf(context).top`; `JeebCtaButton` should expose
   `isLoading`.

## 11. Build order for this lane

1. Restructure `build()` (shell + `Spacer` + gutters), keep every child widget as-is — verify all 13
   tests still green. *(Structure-only commit; easiest to review.)*
2. Rebuild `_RegisterHero` into the navy band, fold `_WelcomeHeading` in, delete `OMDSAppBar`.
3. Rebuild `_PhoneField` (container + row + prefix + tick + helper line).
4. Restyle `_SendCodeButton` and `_OrDivider`.
5. Add `_TrustNote`.
6. Social demotion — **after** wiring request #2 lands.
7. Add the three new tests; update the one AR string.
