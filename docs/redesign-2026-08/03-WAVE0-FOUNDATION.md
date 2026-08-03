# Wave 0 — Foundation (delivered)

Branch `feat/redesign-24-migration`. Implements §6 Wave 0 of `00-MIGRATION-PLAN.md`, values per §4.
No git operations performed. Every file below is Wave-0-owned and is **frozen from here on** —
screen lanes consume these tokens, they do not edit them.

**Exit numbers (measured, end state):**

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | **5 issues, 0 errors** — identical to the pre-Wave-0 baseline (5 `containsSemantics` deprecation infos in test files, local-Flutter-3.44-only). Zero new issues of any severity. |
| `flutter test test/core/theme/` | **84/84 pass** (was 60; +24 from the new pairs and the new suite) |
| Adjacent suites re-run | `app_shell_test`, `inter_font_weight_test`, `availability_card_test`, both golden suites → **24/24 pass**, all 6 goldens within tolerance. No regeneration needed. |

The full suite was deliberately **not** run — 24 lanes are editing the tree concurrently, so the
result would be noise. The three CI-red-on-`main` suites (`client_offers_screen_test`,
`mutual_rating_tag_chips_l10n_test`, `jeeber_feed_card_test`) were not touched.

---

## 1. `lib/core/theme/app_theme.dart`

**Error quartet** — added to the light `ColorScheme.light(...)` via three new private seeds
(`_jeebError`, `_jeebErrorContainer`, `_jeebOnErrorContainer`; `onError` is `Colors.white`):

| Role | Value | Effect |
|---|---|---|
| `error` | `#B00020` | **no-op** — this is already the `ColorScheme.light` default; now explicit. 47 `.error` sites unchanged. |
| `onError` | `#FFFFFF` | **no-op**, same reason. |
| `errorContainer` | `#FFDAD6` | **real change.** `ColorScheme` implements `errorContainer => _errorContainer ?? error`, so leaving it unset rendered recoverable-attention states as a solid `#B00020` slab. |
| `onErrorContainer` | `#410002` | **real change**, pairs with the above at 13.26:1. |

Re-tinted call sites (§9.9, by design, red slab → soft tint): `order_status_chip.dart:51-53`
(cancelled pill), `otp_verification_screen.dart:375,384,391`. **No test pinned the old slab** — a
full sweep of `test/` for `errorContainer` / `0xFFB00020` / `FFDAD6` found only the contrast test,
which has no error-container pair. Nothing needed fixing forward.

**`chipTheme.shape`** → `const StadiumBorder()` (was `RoundedRectangleBorder(OmdsBorderRadius.xSmall)`).
Blast radius is smaller than §9.8 feared: the OMDS chip family draws its own containers and never
reads `ChipThemeData`, and the only Material chip in the app is an `ActionChip` in
`lib/devtool/dev_settings_page.dart:113`. Still worth the Wave-5 visual sweep, but nothing rendered
in a test or golden changes.

**`switchTheme`** (new) — `thumbColor` white in every state; `trackColor` = `primary` selected /
`surfaceContainerHighest` unselected. `trackOutlineColor` deliberately **left to M3 defaults** so the
off state keeps its outline (outline-over-shadow); the plan named three values and inventing a
fourth would be fabrication. The selected values equal the M3 defaults — the real change is the
unselected knob, which M3 paints `outline` brown (reads as "disabled").

> Verified non-regression: widget-level `activeColor` / `activeTrackColor` resolve **before**
> `switchTheme` in Flutter's `Switch`. `OmdsSwitchTile` passes `activeTrackColor` and
> `OmdsSettingsSwitchRow` passes `activeColor`, so screen 16's green availability toggle and the
> settings rows keep their explicit colors. `availability_card_test.dart` passes.

**`JeebTextStyles` registered** in `_build`'s extension list, per brightness. The M3 `TextTheme` is
untouched — that is what keeps all 6 goldens and ~770 existing files pixel-neutral.

## 2. `lib/core/theme/jeeb_color_roles.dart`

Accent quartet added to `JeebColorRoles` (ctor, both factories, fields, `copyWith`, `lerp`) and to
the `JeebRoles` read facade:

| Symbol | Light | Dark | Contrast |
|---|---|---|---|
| `accent` | `#D73B00` | `#D73B00` | — |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | 4.65:1 (AA by 0.15 — **never fade `onAccent`**) |
| `accentContainer` | `#FFDBD1` | `#FFDBD1` | — |
| `onAccentContainer` | `#3A0B01` | `#3A0B01` | 13.26:1 |

Dark reuses the light quartet verbatim per §6 item 2 — the redesign is light-only (§9.4) and
inventing a dark brand orange would be design fabrication. Both pairs clear AA on dark surfaces.

`test/core/theme/color_role_contrast_test.dart` gained three pairs (gate **strengthened**, never
weakened): `onAccent / accent`, `onAccentContainer / accentContainer`, and
`onErrorContainer / errorContainer` (now that it is explicit). All pass in light and dark. The
periwinkle-fails-on-white guard is untouched.

## 3. `lib/core/theme/jeeb_semantic_colors.dart`

The dead extension is revived — four decorative tokens added (ctor, both factories, fields,
`copyWith`, `lerp`). **Not contrast-gated, never body-text ink**, as the class doc now states.

| Symbol | Light | Dark | Notes |
|---|---|---|---|
| `mutedSurface` | `#F4F4F6` | `#29292F` | Dark value is the dark scheme's own `surfaceContainerHigh`, probed from `ColorScheme.fromSeed(navy, dark)` and pinned by a test (a const factory cannot call `fromSeed`). |
| `readTick` | `#20F0FF` | `#20F0FF` | Decorative icon ink, navy outgoing bubbles only. |
| `accentTint` | `rgba(215,59,0,.12)` | same | `Color.fromRGBO(215, 59, 0, 0.12)`. Alpha-based, composites over any surface. |
| `accentRing` | `rgba(215,59,0,.30)` | same | `Color.fromRGBO(215, 59, 0, 0.30)`. Stroke only. |

## 4. NEW `lib/core/theme/jeeb_text_styles.dart`

`JeebTextStyles extends ThemeExtension<JeebTextStyles>` + `context.jeebText` accessor
(`JeebTextStylesX on BuildContext`), 16 fields exactly per §4.2. Every field names
`fontFamily: 'Inter'` explicitly — a `ThemeExtension` `TextStyle` does not inherit the family from
the theme, and a test asserts it on all 16.

Only `sectionLabel` carries ink (`mutedText`, per §4.2); every other field is color-free so ambient
`ColorScheme` ink still applies. The M3 `TextTheme` is **not** reshaped (§4 explicitly: "zero drift
for existing consumers").

## 5. NEW `lib/core/theme/jeeb_shadows.dart`

`JeebShadows` — 11 `static const List<BoxShadow>` per §4.5, private ctor, no extension (values are
brightness-independent in a light-only spec). Each maps 1:1 onto its CSS source; `stepGlow` and
`focusRing` are spread-only rings (`spreadRadius`, zero blur/offset). Outlined cards carry **no**
shadow, ever.

## 6. `lib/app/app.dart`

`OmdsColorTokensProvider` at line ~616 now passes
`const OmdsColorTokens(starRatingColor: Color(0xFFFFC107))`. This is a real change, not a
formality: OMDS defaults `starRatingColor` to `#D73B00`, the brand orange, and the redesign rations
orange to state/emphasis — a rating star is neither. The stale "we use the default token set"
comment was corrected. Hand-rolled stars must read `context.omdsColorTokens.starRatingColor`.

## 7. `test/core/theme/jeeb_text_styles_test.dart` (NEW)

Registration in both brightnesses, `context.jeebText` resolution, the accessor's null-safe fallback,
all 16 fields' size/weight/family, `body`'s 19px line box, both tracking values, and three
cross-token invariants: `sectionLabel` ink == `JeebSemanticColors.mutedText` (light **and** dark —
these are what keep the one duplicated hex honest) and dark `mutedSurface` ==
`AppTheme.dark().colorScheme.surfaceContainerHigh`.

---

## DEFERRED — `Inter-ExtraBold.ttf` (w800). `pubspec.yaml` is UNCHANGED.

`assets/fonts/` contains exactly four faces — Regular (400), Medium (500), SemiBold (600), Bold
(700). There is **no ExtraBold anywhere in the repo** (`find . -iname "*extrabold*"` → nothing), and
Wave 0's remit is explicitly not to download one. Adding a `pubspec.yaml` entry pointing at a
missing asset would fail the build for all 24 lanes, so the entry was **not** added.

**Consequence — and why it is safe:** the six w800 fields (`statHero`, `statDisplay`, `badge`,
`price`, `codeInput`, plus w800 usages at call sites) currently render at the bundled w700. Flutter
weight-matching picks the nearest available face; nothing crashes, nothing fails. §9.2 already
accepts this outcome ("acceptable but flatter").

**Nothing written in Wave 0 depends on the asset existing.** Specifically:
- No test asserts a w800 face renders. `test/inter_font_weight_test.dart` is a *closed* enumeration
  of its own hardcoded four-file map — it never reads `pubspec.yaml` or lists `assets/fonts/`.
- `test/support/load_test_fonts.dart` (the golden font loader) hardcodes the same four faces, so
  goldens render w800 text at w700 consistently — no spurious golden diffs either way.
- The w800 values stay in `jeeb_text_styles.dart` because they are the design truth; when the owner
  green-lights the asset, dropping the TTF into `assets/fonts/` plus one `pubspec.yaml` line under
  the existing `Inter` family is the entire change. No Dart edit, no screen edit.

**To un-defer:** owner approves → add `Inter-ExtraBold.ttf` (OFL-1.1) to `assets/fonts/` and
`- asset: assets/fonts/Inter-ExtraBold.ttf` / `weight: 800` under `flutter > fonts > family: Inter`.

Also still deferred by the plan itself, not by Wave 0: the Arabic display face (Baloo Bhaijaan 2)
is unlicensed per the DS readme (§4.2/§9.3). AR headlines render in Inter / system Arabic fallback.

---

## Notes for the 24 screen lanes

- Orange in the 18 contrast-gated files comes **only** from `context.jeebRoles.accent`.
  `.tertiary*` and `Color(0x` remain banned there — `no_raw_semantic_colors_test.dart` is unamended.
- `context.jeebText` and `context.jeebRoles` both fall back to their light variant if the extension
  is absent, so a bare-`ThemeData` widget test cannot null-crash a redesigned screen.
- `JeebShadows` is read directly (`boxShadow: JeebShadows.ctaNavy`) — it is not a `ThemeExtension`.
- Nothing here assumes LTR: no token carries a direction, and `sectionLabel` applies no case
  transform (uppercasing happens at the call site, so AR passes through — see `JeebSectionLabel`).
- `tool/check_design_tokens.sh` and `no_raw_semantic_colors_test.dart` scan `lib/features` only;
  design-exact px and hexes are legal inside `lib/core/theme/` and `lib/core/widgets/jeeb/`.
