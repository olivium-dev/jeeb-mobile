# 03 — Wave 1 Component Kit: Final Reference

**Status: SHIPPED and audited.** This document is the authoritative API reference for the 24
screen-implementation lanes. Where a per-screen instruction file and this document disagree, **this
document wins** — the deltas are listed in §4 and are deliberate.

- Location: `lib/core/widgets/jeeb/` (one file per widget; `JeebChipRow` co-located with
  `JeebSelectChip` per plan §5 #6's own file column).
- Tests: `test/core/widgets/jeeb/` — **476 tests, all passing** (`flutter test
  test/core/widgets/jeeb/ --no-pub`).
- `flutter analyze --no-pub`: **5 issues** — the 5 baseline `containsSemantics` deprecation infos in
  legacy test files, zero errors, zero new warnings/infos. `dart analyze lib/core/widgets/jeeb
  test/core/widgets/jeeb`: **No issues found.**
- Inventory vs plan §5: **all 28 rows built.** No row is missing. One extra file beyond the table:
  `jeeb_surface_tone.dart` (§2.9) — kit infrastructure the table's "on navy" columns imply.

---

## 1. Kit-wide conventions (the reconciled contract)

Thirteen agents built this in parallel; the following conventions were verified/enforced across
every file. Build your screens against these and nothing will surprise you.

### 1.1 Identifiers & semantics
- Every interactive widget takes `String? identifier` and applies it via an **explicit
  `Semantics(identifier: …)` wrapper**. OMDS's own `identifier:` parameter is never used, with
  **one sanctioned, documented exception**: `JeebCodeCells.input52` passes `cellIdentifier` through
  `OmdsOtpInput.identifier` because the per-cell id must merge onto the editable `TextField` leaf —
  an outer wrapper would not be a tappable/typable target for Maestro (RC-7). The row-level
  `identifier` on that same widget still uses the explicit wrapper.
- Non-interactive widgets emit **no Semantics node at all** unless `identifier` or `semanticLabel`
  is passed (JeebMeter, JeebWaveform, JeebPriceMeter, JeebTierChip, JeebPageDots, JeebSectionLabel,
  JeebStepper root). Exception: `JeebStepperPill` always emits a node — a button must announce as a
  button even without an id.
- When a kit widget does add a wrapper node it is `container: true, explicitChildNodes: true` so
  nested ids survive — except `JeebAvatarStack` (plain `Semantics(identifier:, label:)`, byte-
  matching the shipped wrapper that `semantics_identifier_surfacing_test.dart` reads) and
  `JeebStepper`'s per-step nodes (no `explicitChildNodes`, so the label merges into the node —
  the shipped `_StepNode` shape).
- Frozen contracts verified intact: `tracking_step_*` (JeebStepper `stepIdentifiers`),
  `<screen>_back` (JeebTopBar `identifier` lands on the leading circle),
  `<prefix>_0…_9` + `<prefix>_backspace` (JeebNumericKeypad `identifierPrefix`),
  `ChatComposer.textFieldKey/attachButtonKey/sendButtonKey` (JeebChatComposer
  `fieldKey`/`attachKey`/`sendKey` pass-throughs).

### 1.2 Naming
- **Primary tap is always `onTap`.** Named sub-element callbacks are `on<Element>Pressed`
  (`onLeadingPressed`, `onAvatarPressed`, `JeebTopBarAction.onPressed`) or intent verbs
  (`onSend`, `onAttach`, `onLink`, `onSeek`, `onDigit`, `onBackspace`, `onChanged`, `onCompleted`,
  `onPressStart/End`, `onSlideCancel`).
- **State booleans are `is`-prefixed:** `isEnabled`, `isLoading`, `isRecording`, `isAttaching`.
  (`JeebListRow.enabled` was renamed to `isEnabled` in this audit — §4.)
- **Selection is `selected`** (bare, matching Flutter's `Semantics(selected:)`): JeebNavySurfaceCard,
  JeebSelectChip, JeebTierRow, JeebSegment (via `selectedIndex`). Cards use the richer
  `JeebCardState { normal, selected, dormant }` enum.
- **Outer padding is `padding`** on every widget (`JeebListRow.contentPadding` was renamed —
  §4). `contentPadding` survives only on `JeebCtaButton`, where it genuinely means the pill's
  *internal* content inset, distinct from any outer padding.
- **Corner radius is `radius`** (a `double`) everywhere it is parameterized.
- **`gap`** = space between two named slots inside one widget; **`spacing`** = repeated inter-item
  space in a row/column of peers (JeebChipRow, JeebCtaFooter, iconSpacing, rowSpacing).
- Text params: buttons and chips take `label`; rows/cards/notes take `title` (+ `subtitle`/`text`).
  `JeebTierRow.compact(mark:, title:)` vs `.catalog(emoji:, name:)` is a deliberate alias pair —
  both spellings are pinned verbatim by 07's and 08's per-screen contracts.
- Every public widget takes a named `key` (`super.key`); lint-enforced.

### 1.3 Geometry & RTL
- All insets are `EdgeInsetsDirectional`, all corner sets `BorderRadiusDirectional`, all alignments
  `AlignmentDirectional`/`PositionedDirectional`; icons that flip use the repo's `DirectionalIcons`.
  Audit greps for `EdgeInsets.only/fromLTRB`, `Alignment.centerLeft/right`, `left:`/`right:` found
  only two hits, both correct: `JeebTopBar._compensatedPadding` operates on an
  **already-resolved** `EdgeInsets` (both sides get the same −4 tap-overhang compensation) and
  `JeebNavySurfaceCard.topBand` adds a top-only inset (non-directional by definition).
- Deliberate LTR isolates (the only three): `JeebCodeCells` (all four forms — a code never reorders
  in Arabic), `JeebNumericKeypad` with `forceLtr: true` (default; `false` gives a genuinely
  mirrored pad), `JeebTierRow.catalog`'s latin-numeric SLA label (`slaForceLtr`, opt-out for pure-
  Arabic labels). `JeebChatBubble` renders `time` in an LTR isolate; `JeebQuickReplyRow`
  deliberately introduces **no** Directionality so AR pills in an EN thread shape themselves.
- `JeebMicHero`'s progress arc stays **clockwise** under RTL (a time budget reads as a clock);
  its slide-to-cancel threshold sign flips under RTL.
- Every widget has RTL coverage in its test file (directly or via its shared harness).

### 1.4 Tokens
- **Zero `Color(0x…)` literals** in the kit (grep-verified).
- Raw `TextStyle(` appears only where no token exists: emoji sizing in `JeebTierRow` and the
  weight/letter-spacing-only hint span in `JeebSectionLabel` (inherits size+ink from the token).
- Raw `BoxShadow(` appears only for values `JeebShadows` genuinely lacks, each documented at the
  definition: `JeebNavySurfaceCard.selectedShadow` (`0 10 22 @.28` — measured distinct from
  `ctaNavy`'s `0 10 24`, pinned by 08 §3), `.stripShadow` (`0 8 20 @.25`, 21), `JeebStepper.barGlow`
  (spread 3 for 18's h5 bars, built from `stepGlow`'s ink token), `JeebMicGlow` (shape consts
  resolved against `jeebRoles.accent` at paint time), `JeebMeter`'s scrubber knob shadow (derived
  from the fill colour so it inverts on navy).
- The one warm-ink rationing rule (§4.1) is enforced in code: `JeebProfileHeader`'s rating star is
  **navy** (test-pinned), `readTick` has zero consumers (`JeebChatBubble` renders the literal
  `· Read` text), `accentTint` is used exactly once (07's "Most picked" badge in `JeebTierRow`).

### 1.5 Surface re-toning (`JeebSurfaceTone`)
One mechanism, no `onNavy` parameters anywhere. **Publishers:** `JeebNavySurfaceCard` (navy),
`JeebOutlinedCard` in `state: selected` (delegates to the navy card), `JeebAccentFrameCard.filled`
(light-ink tone built from `onAccent`), `JeebChatBubble` (navy for outgoing, light for incoming).
**Readers:** `JeebTierChip`, `JeebInfoNote` (`muted`/`accent`/`outlined` only — status tones keep
their role colours), `JeebListRow`, `JeebMeter`, `JeebPriceMeter`, `JeebAvatar` (`primary`/`dormant`
fills), `JeebWaveform.inBubble`. **Deliberate non-readers:** `JeebSectionLabel` (stays periwinkle on
navy — 19/23 measured), `JeebSelectChip` (the board has no on-navy unselected chip).

### 1.6 Structural rules that hold kit-wide
- Selection is a **fill swap, never a thicker border**: strokes are painted by decorations that do
  not inset the child, so selected/unselected peers are pixel-identical in size (no row jitter).
- 1.5px strokes are folded into padding (border-box correction) on JeebOutlinedCard, JeebInfoNote
  `outlined`, JeebSegmentedToggle, JeebStepperPill, JeebChatComposer's pill, JeebQuickReplyRow.
- Outline-over-shadow: outlined things never cast shadows; disabled CTAs drop their shadow.
- Disabled paint: `.45` fill / `.9` label on CTAs (matches OmdsPrimaryButton P0-X01), `.5` on
  JeebListRow, `.4` on JeebStepperPill, `.38` send circle on the composer — each measured from its
  screen, all reporting `Semantics(enabled: false)` when tappable-but-disabled.
- Loading states never settle: test with `pump()`, not `pumpAndSettle()` (JeebCtaButton.isLoading,
  JeebChatComposer.isAttaching). JeebStepper's pulse is **bounded** (3 × 900ms, lands byte-exact on
  the token) and skipped under `MediaQuery.disableAnimationsOf`, so `pumpAndSettle` is safe there.

---

## 2. Component inventory & exact APIs

Import: `package:jeeb_mobile/core/widgets/jeeb/<file>.dart`.

### 2.1 Cards & surfaces

#### `JeebOutlinedCard` — `jeeb_outlined_card.dart` (plan #3)

```dart
enum JeebCardState { normal, selected, dormant }

class JeebOutlinedCard extends StatelessWidget {
  const JeebOutlinedCard({
    super.key,
    required Widget child,
    Widget? actions,
    JeebCardState state = JeebCardState.normal,
    double radius = 16,
    EdgeInsetsGeometry padding = JeebOutlinedCard.defaultPadding, // 13/16
    Color? borderColor,                 // null -> colorScheme.outline
    double borderWidth = 1.5,
    double actionsSpacing = 12,
    List<BoxShadow>? selectedShadow,    // null -> JeebNavySurfaceCard.selectedShadow
    List<JeebNavyRing> selectedRings = const <JeebNavyRing>[],
    VoidCallback? onTap,
    String? identifier,
    String? semanticLabel,
    String? semanticHint,
  });

  const JeebOutlinedCard.grouped({
    super.key,
    required List<Widget> children,
    bool dividers = true,               // n-1 × 1px outlineVariant, inset 16 directional
    // …same remaining params; padding defaults to zero (rows own their padding)
  });

  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 13);
  static const double dormantOpacity = 0.75;
}
```

States: `normal` = surface fill + 1.5px outline, **no shadow ever**; `selected` = returns a
`JeebNavySurfaceCard` (same radius/padding, `selectedShadow`, no border) — one state machine;
`dormant` = `Opacity(.75)` **and `actions` not built at all** (§7.2-C4's structural half).
`borderColor`/`borderWidth` overrides serve 11's recommended offer (`primary`, 2, r18).

#### `JeebNavySurfaceCard` — `jeeb_navy_surface_card.dart` (plan #4)

```dart
enum JeebNavyRingInk { accent, onPrimaryFaint }

class JeebNavyRing {
  const JeebNavyRing({
    required double diameter,
    double? top, double? bottom, double? start, double? end,
    JeebNavyRingInk ink = JeebNavyRingInk.accent,
    double strokeWidth = 1.5,
  });
  static const JeebNavyRing heroTopEnd;    // 04: Ø140, top −40, end −40
  static const JeebNavyRing statTopEnd;    // 19: Ø160, top −50, end −50
  static const JeebNavyRing statBottomEnd; // 23: Ø170, bottom −50, end −50
  static const JeebNavyRing bandOuter;     // 02: Ø200, onPrimaryFaint
  static const JeebNavyRing bandInner;     // 02: Ø120
}

class JeebNavySurfaceCard extends StatelessWidget {
  const JeebNavySurfaceCard({
    super.key,
    required Widget child,
    double radius = 16,
    EdgeInsetsGeometry padding = JeebNavySurfaceCard.defaultPadding, // 14/16
    List<BoxShadow> shadow = JeebNavySurfaceCard.noShadow, // pass JeebShadows.ctaNavy/heroNavy/…
    List<JeebNavyRing> rings = const <JeebNavyRing>[],     // ClipRRect'd, PositionedDirectional
    VoidCallback? onTap,
    String? identifier, String? semanticLabel, String? semanticHint,
    bool selected = false,              // reports Semantics(selected: true)
  });

  const JeebNavySurfaceCard.topBand({ /* 02 only: bottom-only r36, status-bar inset folded in */ });

  static const List<BoxShadow> noShadow;
  static const List<BoxShadow> selectedShadow; // 0 10 22 rgba(11,19,81,.28) — NOT ctaNavy
  static const List<BoxShadow> stripShadow;    // 0 8 20 rgba(11,19,81,.25) — 21
}
```

Publishes the navy `JeebSurfaceTone`; every kit child re-inks itself with no parameters.

#### `JeebAccentFrameCard` — `jeeb_accent_frame_card.dart` (plan #5)

```dart
class JeebAccentFrameCard extends StatelessWidget {
  const JeebAccentFrameCard({
    super.key, required Widget child,
    double radius = 16,                 // 18 for screens 18 and 24
    EdgeInsetsGeometry padding = defaultPadding, // 13/16
    double borderWidth = 2,
    VoidCallback? onTap, String? identifier, String? semanticLabel, String? semanticHint,
  });
  const JeebAccentFrameCard.filled({ /* 13's arrival banner only: accent fill +
      JeebShadows.accentBanner, r16, pad 14/16, publishes a light-ink tone */ });
}
```

The unnamed form **delegates to `JeebOutlinedCard`** (accent 2px frame). Screen 12 is NOT a
consumer (12 §A-1 cut the OtpAtDoorCard restyle — do not reintroduce).

#### `JeebSurfaceTone` — `jeeb_surface_tone.dart` (infrastructure)

```dart
enum JeebSurfaceKind { light, navy }

class JeebSurfaceToneData {
  const JeebSurfaceToneData({
    required JeebSurfaceKind kind,
    required Color titleInk, required Color mutedInk,
    required Color chipFill, required Color chipInk,
    required Color meterFill, required Color meterEmpty, required Color dividerInk,
  });
  factory JeebSurfaceToneData.light(BuildContext context);
  factory JeebSurfaceToneData.navy(BuildContext context);
  bool get onNavy;
}

class JeebSurfaceTone extends InheritedWidget {
  const JeebSurfaceTone({super.key, required JeebSurfaceToneData tone, required super.child});
  static JeebSurfaceToneData of(BuildContext context);   // falls back to .light
  static JeebSurfaceToneData? maybeOf(BuildContext context);
}
```

Screens rarely touch this directly — the cards publish it. Publish it yourself only when building
a screen-local navy surface that hosts kit children.

### 2.2 Buttons & footers

#### `JeebCtaButton` — `jeeb_cta_button.dart` (plan #2)

```dart
enum JeebCtaVariant { primary, outline, text, accentText }

class JeebCtaButton extends StatelessWidget {
  const JeebCtaButton({
    super.key,
    required String label,
    VoidCallback? onTap,
    JeebCtaVariant variant = JeebCtaVariant.primary,
    bool isEnabled = true,
    bool isLoading = false,
    double? height,                     // null -> per-variant default
    bool? expand,                       // null -> true on pill variants, false on text ones
    TextStyle? labelStyle,              // null -> per-variant default
    IconData? leadingIcon, IconData? trailingIcon,
    double? iconSize,                   // null -> 16 outline, 19 elsewhere
    double iconSpacing = 10,            // 01 uses 9, 18 uses 8
    bool mirrorIcons = false,           // Transform.flip for directional glyphs (01's →)
    EdgeInsetsGeometry? contentPadding, // null -> 0/20 pill, 0/22 text
    String? identifier, String? semanticLabel, String? semanticHint,
  });
  // Named forms: .primary / .outline / .text / .accentText — identical params minus `variant`.

  static const double primaryHeight = 56;      // 01 08 15 23
  static const double primaryHeightTall = 58;  // 10 14 17
  static const double outlineHeight = 50;      // 12 18
  static const double outlineHeightTall = 54;  // 14
  static const double textHeight = 48;         // a11y floor
  static const double pillRadius = 999;
  static const double disabledFillOpacity = 0.45;
  static const double disabledLabelOpacity = 0.9;

  bool get isInteractive; // isEnabled && !isLoading && onTap != null — one source of truth
}
```

Variant paints: `primary` navy pill / `jeebText.button` / `JeebShadows.ctaNavy`; `outline`
transparent, 1.5px outline stroke, 13.5/w600 primary ink, no shadow ever; `text`
`onSurfaceVariant` 15.5/w600, no pill; `accentText` `jeebRoles.accent` 13.5/w700 — **the only
sanctioned orange text affordance**. Disabled drops the shadow. `isLoading` replaces the whole
label row with a 22px spinner in the variant ink — **test with `pump()`, never `pumpAndSettle()`**.

#### `JeebCtaFooter` — `jeeb_cta_footer.dart` (plan #2)

```dart
enum JeebCtaFooterForm { single, split, textStack }

class JeebCtaFooter extends StatelessWidget {
  const JeebCtaFooter.single({
    super.key,
    Widget? below,                 // e.g. a cancel note or an accentText CTA
    double spacing = 10,
    EdgeInsetsGeometry padding = JeebCtaFooter.docked,
    required Widget child,         // declared LAST (sort_child_properties_last)
  });
  const JeebCtaFooter.split({
    super.key,
    required Widget leading,       // arbitrary widget — 01 passes OmdsSkipButton (type-pinned)
    required Widget trailing,      // always Expanded
    bool expandLeading = false,    // 12: true (both flex:1)
    double spacing = 12,
    EdgeInsetsGeometry padding = JeebCtaFooter.docked,
  });
  const JeebCtaFooter.textStack({
    super.key,
    required String note,          // kit styles it: bodySmall w700 accent, centred
    required Widget action,
    double spacing = 10,
    EdgeInsetsGeometry padding = JeebCtaFooter.docked,
  });

  static const EdgeInsetsGeometry docked = EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32);
  static const EdgeInsetsGeometry inline = EdgeInsetsDirectional.fromSTEB(24, 16, 24, 0); // 23
}
```

Applies **no SafeArea** (08 wraps it itself; 23's inline form must not gain a bottom inset) and
adds **no Semantics node** (children carry ids). No identifier param — by design.

### 2.3 Chips & pills

#### `JeebSelectChip` + `JeebChipRow` — `jeeb_select_chip.dart` (plan #6)

```dart
enum JeebChipRole { filter, sort, choice, quickReply, inlineAction }

class JeebSelectChip extends StatelessWidget {
  const JeebSelectChip({
    super.key,
    required JeebChipRole role,   // role fixes pad + font: filter 11/20 · 14.5/w600;
    required String label,        //   sort 8/15 · 12.5/w600(→700 selected); choice 11/0 · 13.5/w600;
    bool selected = false,        //   quickReply 8/13 · 12/w600; inlineAction 9/18 · 13/w600
    VoidCallback? onTap,
    int? count,                   // selected -> inline text; unselected -> Ø18 accent badge
    Widget? leading,              // free slot, 6px gap
    String? identifier, String? semanticLabel,
  });
  static const double contentSpacing = 6;
  static const double borderWidth = 1.5;
}

const BorderRadius jeebPillRadius = BorderRadius.all(Radius.circular(999)); // shared, same file

class JeebChipRow extends StatelessWidget {
  const JeebChipRow({
    super.key,
    required List<Widget> children,
    double spacing = 8,
    EdgeInsetsGeometry padding = EdgeInsetsDirectional.zero,
    String? identifier,
  });
  const JeebChipRow.expanded({ ...same });   // each child in Expanded — 17's ETA row
  const JeebChipRow.scrollable({ ...same }); // horizontal SingleChildScrollView over a NON-LAZY Row
}
```

Chip semantics: node added **only** when `identifier`/`semanticLabel` given (`onTap` alone adds
nothing — the dominant call-site idiom is the consumer's own frozen wrapper). **No minimum tap
target on purpose** (11's test asserts sub-48dp) — wrap at the call site. Light surfaces only
(deliberately tone-blind). On `.scrollable`, `padding` becomes the scroll view's padding so the
trailing gutter scrolls with the last pill; never wrap it in a second scroll view; a `ListView`
would hide off-screen pills from `find.bySemanticsIdentifier` (09's regression note).

#### `JeebTierChip` — `jeeb_tier_chip.dart` (plan #7)

```dart
enum JeebTier {
  flash('⚡'), express('🚀'), standard('🟦'), onTheWay('🤝'), eco('🌿'), unknown('');
  final String emoji;
  static JeebTier fromId(String? tierId); // case/separator-insensitive; never throws
}

class JeebTierChip extends StatelessWidget {
  const JeebTierChip({ super.key, required JeebTier tier, required String label /* LOCALIZED */,
      String? identifier, String? semanticLabel });
  const JeebTierChip.custom({ super.key, required String emoji, required String label, ... }); // 24
  const JeebTierChip.meta({ super.key, required String label, ... }); // emoji-less: SLA/meta chips
  static String emojiFor(String? tierId);   // 12 consumes ONLY this
}
```

One treatment for all tiers (surfaceContainerHigh pill, 11.5/w700). Emoji and label are **two
separate `Text` children** (`find.text('Flash')` pinned; `find.text('⚡ سريع')` must find nothing).
`unknown` renders no emoji widget at all. Re-tones structurally via `JeebSurfaceTone`.
Non-interactive — no `onTap` exists. No shadow, no border, ever.

#### `JeebSystemChip` — `jeeb_system_chip.dart` (plan #17)

```dart
enum JeebSystemChipTone { filled, outlined, accent }

class JeebSystemChip extends StatelessWidget {
  const JeebSystemChip({ super.key, required String label, required JeebSystemChipTone tone,
      String? identifier, String? semanticLabel, bool center = true });
  // .filled / .outlined / .accent named forms, same params minus tone.
}
```

`filled` = settled facts (`Offer accepted · 9:12`, date separators); `outlined` = live/progress
events; `accent` = the broadcast-TTL countdown (21 §2 R5 — a deliberate third tone beyond §5).
`center: false` adds no `Align` at all.

#### `JeebStepperPill` — `jeeb_stepper_pill.dart` (plan #27)

```dart
class JeebStepperPill extends StatelessWidget {
  const JeebStepperPill({
    super.key, required String label, required VoidCallback onTap,
    String? identifier, String? semanticLabel,
    bool isEnabled = true,
    EdgeInsetsGeometry padding = defaultPadding, // 6/12 (border-box corrected)
    double borderWidth = 1.5,
  });
  static const double spacing = 6;          // the pair gap — no JeebStepperPillRow exists
  static const double disabledOpacity = 0.4;
}
```

Always emits a full button Semantics node (see §1.1 exception).

#### `JeebPageDots` — `jeeb_page_dots.dart` (plan #28)

```dart
class JeebPageDots extends StatelessWidget {
  const JeebPageDots({
    super.key, required int count, required int activeIndex, // logical; clamped, never RTL-flipped
    double dotSize = 8, double activeWidth = 22, double gap = 7,
    Duration duration = const Duration(milliseconds: 200),
    String? identifier, String? semanticLabel,
  });
  static const double planActiveWidth = 28; // plan §5 #28's reading, if a lane wants it
}
```

**Deliberate deviation:** defaults are the re-verified render measurements (22×8, gap 7), not the
plan's 28×8/6. 01 is the only consumer and already declared 22×8.

### 2.4 Headers & rows

#### `JeebTopBar` — `jeeb_top_bar.dart` (plan #1)

```dart
enum JeebTopBarLeading { back, close, identity }
enum JeebTopBarLeadingTreatment { tonal, floating }  // floating = surface + floatPill (09's map)
enum JeebTopBarTitleScale { standard, compact }      // h2 20/w700 vs titleProminent 17/w700 (12)

class JeebTopBarAction {
  const JeebTopBarAction({ required IconData icon, required VoidCallback onPressed,
      String? identifier, String? semanticLabel, double iconSize = 19 });
}

class JeebTopBar extends StatelessWidget {
  const JeebTopBar({
    super.key,
    JeebTopBarLeading leading = JeebTopBarLeading.back,
    JeebTopBarLeadingTreatment leadingTreatment = JeebTopBarLeadingTreatment.tonal,
    String? title,                  // null -> bare circle (03)
    Widget? titleSlot,              // xor title
    JeebTopBarTitleScale titleScale = JeebTopBarTitleScale.standard,
    String? subtitle, Widget? subtitleSlot, String? subtitleIdentifier,
    Widget? avatar, String? avatarIdentifier, VoidCallback? onAvatarPressed, // identity only
    JeebTopBarAction? trailing,     // real Ø40 circle action with its own id (12, 21)
    String? identifier,             // THE LEADING CIRCLE -> '<screen>_back'
    String? leadingTooltip,         // doubles as the a11y label
    VoidCallback? onLeadingPressed, // null -> Navigator.maybeOf(ctx)?.maybePop()
    EdgeInsetsGeometry padding = defaultPadding, // 14/24/0, tap-overhang compensated
    double? gap,                    // null -> 12 (identity/trailing) else 14
  });
  // .back / .close / .identity named forms.
  static const double circleDiameter = 40;
  static const double identityAvatarDiameter = 42;
}
```

Screens 04/16/19 do **not** use this — they use `JeebProfileHeader`.

#### `JeebProfileHeader` — `jeeb_profile_header.dart` (plan #23)

```dart
class JeebProfileHeader extends StatelessWidget {
  const JeebProfileHeader({
    super.key,
    required String name,           // 19/w700 primary, 1 line ellipsis
    String? eyebrow,                // 13/w600 mutedText
    Widget? avatar,                 // Ø46 slot — pass a JeebAvatar
    String? avatarIdentifier, VoidCallback? onAvatarPressed,
    Widget? trailing,               // auto-inked primary @24 via IconTheme.merge (04's bell)
    double? trailingReserve,        // end-side width reserved when trailing == null (04)
    String? ratingLabel,            // '4.8' -> ★ pill; xor trailing (asserted)
    String? ratingIdentifier, String? ratingSemanticLabel, // SET IT — bare ★ must not reach TalkBack
    String? identifier,
    EdgeInsetsGeometry padding = EdgeInsetsDirectional.zero, // consumers wrap their own Padding
    double gap = 14,
  });
  static const EdgeInsetsGeometry defaultPadding; // 16/24/0 for bare mounting — NOT the default
}
```

**The rating star is NAVY** — never `starRatingColor`, never `accent` (§4.1; test-pinned).

#### `JeebListRow` — `jeeb_list_row.dart` (plan #25)

```dart
class JeebListRow extends StatelessWidget {
  const JeebListRow({
    super.key,                       // 20 passes Key('settings-row-addresses') etc.
    required String title,
    String? subtitle,
    IconData? icon,                  // FILLED glyphs (R10)
    double iconSize = 19,            // 18 on 20's sign-out
    Color? iconColor,
    Widget? trailing,                // replaces the chevron entirely
    bool showChevron = true,         // false = 20's sign-out (K2)
    double chevronSize = 16,
    TextStyle? titleStyle,           // MERGED over the default, not replacing it
    TextStyle? subtitleStyle,
    EdgeInsetsGeometry padding = JeebListRow.defaultPadding,  // 14/16  ⟵ RENAMED (was contentPadding)
    double gap = 12,
    bool isEnabled = true,           //                              ⟵ RENAMED (was enabled)
    VoidCallback? onTap,
    String? identifier, String? semanticLabel, String? semanticHint,
  });
  static const double disabledOpacity = 0.5;
}
```

Rows own their padding; the grouped **card** draws the dividers. Chevron via
`DirectionalIcons.disclosure`. Re-tones on navy via `JeebSurfaceTone`.

#### `JeebSectionLabel` — `jeeb_section_label.dart` (plan #10)

```dart
class JeebSectionLabel extends StatelessWidget {
  const JeebSectionLabel(
    String label, {                 // POSITIONAL — natural casing; NEVER .toUpperCase() yourself
    super.key,
    String? hint,                   // inline non-uppercase w600 continuation; carries its own '·'
    bool small = false,             // true -> 11px; default 12.5px (both from sectionLabel token)
    TextAlign? textAlign,           // null -> TextAlign.start
    String? identifier,
  });
  static const Set<String> uppercaseExemptLanguages = {'ar', 'fa', 'he', 'ur'};
  static String resolveCase(String label, Locale? locale); // use in tests to derive find.text()
}
```

One Text/RichText node — `find.text('PICKUP ETA · ≤ 60 min')`. Uppercasing is internal and
locale-gated. **Ink is deliberately not tone-aware** (stays periwinkle on navy — 19/23 measured).

### 2.5 Tier & pricing

#### `JeebTierRow` — `jeeb_tier_row.dart` (plan #8)

```dart
class JeebTierRow extends StatelessWidget {
  const JeebTierRow.compact({   // screen 07
    super.key,
    required String mark,       // emoji String — kit imports no tier enum
    required String title,
    required String summary,
    required bool selected,
    required VoidCallback onTap,
    required String identifier,
    required String semanticLabel,
    required String selectedHint,
    String? badge,              // 'Most picked' — accentTint fill (the ONE legit accentTint use)
    double radius = 16,
    EdgeInsetsGeometry padding = compactPadding, // 14/16
  });
  const JeebTierRow.catalog({   // screen 08
    super.key,
    required String emoji,
    required String name,
    required int priceLevel,    // 0..4
    required String priceCaption,
    required String slaLabel,   // '≤ 1 hr' — LTR-isolated unless slaForceLtr: false
    required String metaLabel,
    required bool selected,
    required VoidCallback onTap,
    required String identifier,
    required String semanticLabel,
    required String selectedHint,
    IconData? metaIcon,
    String? badgeLabel,         // 'Recommended' — solid accent + onAccent 10/w800
    bool slaForceLtr = true,
    double radius = 16,
    EdgeInsetsGeometry padding = catalogPadding, // 13/16
  });
}
```

`.compact` a11y is byte-identical to `RequestTierCard` (`inMutuallyExclusiveGroup` + `checked`);
`.catalog` keeps `tier_card.dart:138-146`'s shape (`selected`). Selected indicator on `.compact` is
the **accent disc + white check** (07 HTML wins over plan §5 #8's inverted description). `.catalog`
delegates its meter to `JeebPriceMeter` and its SLA chip to `JeebTierChip.meta`; both invert via
tone. `.compact` has **no price meter** (07's HTML has zero meter dots).

#### `JeebPriceMeter` — `jeeb_price_meter.dart` (plan #21)

```dart
class JeebPriceMeter extends StatelessWidget {
  const JeebPriceMeter({
    super.key,
    required int level,     // clamped 0..dotCount (flash 4 … eco 1)
    required String caption,// the ONLY a11y signal — hence required
    int dotCount = 4, double dotSize = 7, double dotGap = 3, double captionGap = 3,
    String? identifier,
  });
}
```

No colour overrides, no `onNavy` — inverts via `JeebSurfaceTone` only. Dots are
`ExcludeSemantics`'d.

#### `JeebMoneyBreakdown` (+ `JeebMoneyLine`) — `jeeb_money_breakdown.dart` (plan #24)

```dart
class JeebMoneyLine {
  const JeebMoneyLine({ required String label, String? value /* null -> label spans the row */,
      String? identifier, String? semanticLabel });
}

class JeebMoneyBreakdown extends StatelessWidget {
  const JeebMoneyBreakdown({
    super.key,
    required List<JeebMoneyLine> rows,
    JeebMoneyLine? total,               // null -> no rule and no total row
    String? footnote,
    IconData? footnoteIcon = Icons.lock,// FILLED (R10); null drops the glyph
    String? footnoteIdentifier, String? identifier, String? semanticLabel,
    double radius = 16,
    EdgeInsetsGeometry padding = defaultPadding, // 15/16
    double rowSpacing = 8, double dividerSpacing = 10, double footnoteSpacing = 10,
    double footnoteIconSize = 14, double valueSpacing = 12,
  });

  static double platformFeeOn(double amount);  // amount * kJeebCommissionRate — THE fee derivation
  static double netKeptFrom(double amount);
  static int get feePercent;                   // kJeebCommissionPercent for label interpolation
}
```

**D41/D44 enforcement point:** debug asserts throw on any 'commission'/'عمولة' in any label, value
or footnote, and on any `N%` that is not `kJeebCommissionPercent`. Amounts baseline-align to the
label's first line; `value: null` is 17's deliberate pending state.

### 2.6 Avatars

#### `JeebAvatar` — `jeeb_avatar.dart` (plan #9)

```dart
enum JeebAvatarFill { primary, muted, accent, dormant, onAccent }
//   rotation = [primary, muted, accent]; JeebAvatarFill.forIndex(i) wraps every 3.
enum JeebAvatarDot { presence /* green, bottom-END */, unread /* orange, top-END */ }
enum JeebAvatarBadge { completed /* Ø26 accent + white check, bottom-END */ }

class JeebAvatar extends StatelessWidget {
  const JeebAvatar({
    super.key,
    required String initial,        // letter OR full name — initialFrom() normalises; '?' if empty
    double diameter = 42,
    double? initialSize,            // null -> initialSizeFor(diameter): exact on 30/42/46/74
    JeebAvatarFill fill = JeebAvatarFill.primary,
    String? imageUrl,               // blank normalised to null
    JeebAvatarDot? dot, JeebAvatarBadge? badge,   // dot XOR badge (asserted)
    double ringWidth = 0, Color? ringColor,       // ring painted OUTSIDE the disc
    VoidCallback? onTap,
    String? identifier, String? semanticLabel,
    Key? avatarKey,                 // forwarded to the composed OmdsProfileAvatar
  });
  const JeebAvatar.stack({...});   // Ø30, ring 2, no dot/badge — footprint 34×34
  const JeebAvatar.thread({...});  // Ø42, both slots
  const JeebAvatar.header({...});  // Ø46, dot slot
  const JeebAvatar.hero({...});    // Ø74, badge slot
  static const Key dotKey;   // ValueKey('jeeb_avatar.dot')
  static const Key badgeKey; // ValueKey('jeeb_avatar.badge')
  static double initialSizeFor(double diameter);
  static String initialFrom(String? name);
}
```

`dormant` is the honest unknown-person mark — never fabricate a name to escape it. `primary` and
`dormant` re-tone on navy. Odd sizes (16's Ø44, 20's Ø50) use the unnamed ctor with `diameter:`.

#### `JeebAvatarStack` — `jeeb_avatar_stack.dart` (plan #9)

```dart
class JeebAvatarEntry {
  const JeebAvatarEntry({ String initial = '', String? imageUrl, JeebAvatarFill? fill });
  // fill null -> rotation[i % 3] when known, dormant when neither name nor photo exists.
}

class JeebAvatarStack extends StatelessWidget {
  const JeebAvatarStack({
    super.key,
    required List<JeebAvatarEntry> avatars, // last paints on top; −9 directional overlap
    double diameter = 30, double? initialSize, double overlap = 9,
    double ringWidth = 2, Color? ringColor,
    Widget? trailing,                       // the caller's '+N' Text (type-pinned by replies tests)
    double trailingSpacing = 4,
    String? identifier, String? semanticLabel, // plain Semantics(identifier:, label:) wrapper
  });
}
```

Empty + no trailing collapses to `SizedBox.shrink()`.

### 2.7 Progress & meters

#### `JeebStepper` — `jeeb_stepper.dart` (plan #11)

```dart
class JeebStepper extends StatelessWidget {
  const JeebStepper({                    // NODE form — screen 12
    super.key,
    required int currentIndex,           // 0-based; out-of-range degrades, never throws
    required List<String> labels,        // 1:1 with stepIdentifiers
    required List<String> stepIdentifiers, // the frozen tracking_step_* ids
    bool pulseActive = false,            // bounded 3×900ms glow breathing; a11y-gated
    String? identifier, String? semanticLabel, // omit -> NO root node (12 owns tracking_stepper)
  });
  const JeebStepper.bars({               // BAR form — screen 18; ExcludeSemantics'd
    super.key,
    required int stepCount,
    required int currentIndex,
    List<Key>? segmentKeys,
    String? identifier, String? semanticLabel,
  });
}
```

Per-step node: `Semantics(identifier:, value: label, selected: isActive, container: true)` — both
polarities, label merges (shipped `_StepNode` shape). Bars: done navy / active accent + spread-3
glow / pending surfaceContainerHighest.

#### `JeebMeter` — `jeeb_meter.dart` (plan #20)

```dart
class JeebMeter extends StatelessWidget {
  const JeebMeter({                      // plain bar — 11's countdown
    super.key,
    double? value,                       // 0..1 clamped; NULL = track only (honest degraded state)
    double width = 70, double height = 5, double radius = 9,
    Color? trackColor, Color? fillColor, // null -> JeebSurfaceTone meterEmpty/meterFill
    String? identifier, String? semanticLabel,
  });
  const JeebMeter.scrubber({             // 06 — needs a bounded width (Expanded/SizedBox)
    // + double knobSize = 14, ValueChanged<double>? onSeek (0..1, RTL-mirrored)
  });
  const JeebMeter.segmented({            // 22 — n equal cells, h6 gap 8
    super.key, required int steps, required int filled, ...
  });
}
```

**Scrubber layout height is `max(height, knobSize)` = 14, not 5** — use a 4px gap to the time row
for the board's rhythm (06). No knob/gesture when `value`/`onSeek` null. Fill grows from the start
edge (mirrors). Emits no node unless asked — 06's own `Semantics(slider: true)` stays the only one.

### 2.8 Voice & code entry

#### `JeebWaveform` — `jeeb_waveform.dart` (plan #14)

```dart
enum JeebWaveformMode { cardMark, onNavy, inBubble, live }

class JeebWaveform extends StatelessWidget {
  const JeebWaveform({ super.key, required JeebWaveformMode mode,
      bool? outgoing /* inBubble; null -> tone.onNavy */,
      String? identifier, String? semanticLabel });
  const JeebWaveform.cardMark({...}); // h16, 4 bars, accent           — 01 04 10 16
  const JeebWaveform.onNavy({...});   // h24, 5 bars, onPrimary+accent — 04 hero
  const JeebWaveform.inBubble({...}); // h16, 5 bars, side-aware       — 21
  const JeebWaveform.live({...});     // h40, 10 bars, bottom-aligned  — 05
  static double heightOf(JeebWaveformMode mode);
}
```

**No geometry parameters, deliberately** — bar counts/heights are the measured design. Intrinsic
widths: 18 / 27 / 20.5 / 76.

#### `JeebMicHero` — `jeeb_mic_hero.dart` (plan #15)

```dart
class JeebMicGlow {
  static const JeebMicGlow compact; // Ø56 stack (04)
  static const JeebMicGlow large;   // Ø118 (01)
  static const JeebMicGlow hero;    // Ø128 (05)
  List<BoxShadow> resolve(Color accent);
}

class JeebMicHero extends StatefulWidget {
  const JeebMicHero({
    super.key,
    double size = 128,               // sizeCompact 56 · sizeLarge 118 · sizeHero 128
    bool isRecording = false,
    double? progress,                // max-duration arc; null = no arc/track; CLOCKWISE under RTL
    bool? halo,                      // null -> isRecording (NOT size)
    JeebMicGlow? glow,               // null -> nearest measured stack
    double? glyphSize,
    VoidCallback? onPressStart,      // touch-DOWN, no long-press delay
    VoidCallback? onPressEnd,
    VoidCallback? onSlideCancel,     // fires INSTEAD of onPressEnd at 64px toward START (RTL-flips)
    VoidCallback? onTap, VoidCallback? onLongPress,
    String? identifier, String? semanticLabel,
  });
  const JeebMicHero.decorative({...}); // 01: no gestures, no semantics node
  static double extentFor({required double size, bool halo = false, bool arc = false});
}
```

Arming changes no pixels (05 cut the caption swap). Layout extent grows with halo/arc — use
`extentFor`.

#### `JeebCodeCells` — `jeeb_code_cells.dart` (plan #12)

```dart
class JeebCodeCells extends StatelessWidget {
  const JeebCodeCells.input74({   // 03: keypad-driven, presentation-only, NO TextField
    super.key, required int length, required String value, bool hasError = false,
    String? identifier, String? cellIdentifier /* -> '<base>_0'.. */, String? semanticLabel,
  });
  const JeebCodeCells.input52({   // 18: wraps OmdsOtpInput (the ONE OMDS identifier pass-through)
    super.key, int length = 4, bool hasError = false,
    String? identifier, String? cellIdentifier, String? semanticLabel,
    ValueChanged<String>? onChanged, ValueChanged<String>? onCompleted,
    bool autoFocus = false,       // kit default FALSE (OMDS defaults true)
  });
  const JeebCodeCells.display(String value, { super.key, String? identifier, String? semanticLabel });
  const JeebCodeCells.strip(String value, { super.key, Key? textKey, String? identifier, String? semanticLabel });
}
```

All four forms sit in an LTR isolate — a code never reorders in Arabic. `input74`'s caret is
**static** (a blink would deadlock downstream `pumpAndSettle`). `display` is wrapped in
`FittedBox(scaleDown)` (335px row vs 360pt phones); `strip` is exactly ONE `Text` (12's tests pin
`find.text('1234')` + the Key).

#### `JeebNumericKeypad` — `jeeb_numeric_keypad.dart` (plan #13)

```dart
class JeebNumericKeypad extends StatelessWidget {
  const JeebNumericKeypad({
    super.key,
    required ValueChanged<String> onDigit,   // ASCII '0'..'9' always
    required VoidCallback onBackspace,
    required String backspaceLabel,          // l10n — the key is icon-only
    String? identifierPrefix,                // '<prefix>_0'.._9 + '<prefix>_backspace'
    String? identifier, String? semanticLabel,
    bool forceLtr = true,                    // false = genuinely mirrored pad
    EdgeInsetsGeometry padding = defaultPadding, // 0/20/30, applied OUTSIDE the LTR isolate
  });
}
```

Exactly 11 InkWells; the blank bottom-START cell is not a key (no node, no fill). Backspace is a
bare glyph, `matchTextDirection: true`.

### 2.9 Chat

#### `JeebChatBubble` — `jeeb_chat_bubble.dart` (plan #16)

```dart
enum JeebChatBubbleSide { incoming, outgoing }

class JeebChatStatus {
  const JeebChatStatus.icon(IconData icon, { Color? iconColor /* error for failed */,
      String? identifier, String? semanticLabel, Key? nodeKey });
  const JeebChatStatus.text(String label, { ... });   // the READ state — a word, never a tick
}

class JeebChatMedia {
  const JeebChatMedia.voice({ required Widget? waveform /* JeebWaveform.inBubble() */,
      required String? label, IconData playIcon = Icons.play_arrow_rounded,
      VoidCallback? onPlay /* MUST stay null today — B-04, no audio player */,
      String? playIdentifier, String? playSemanticLabel });
  const JeebChatMedia.photo({ Widget? photo, IconData photoIcon = Icons.image_outlined,
      VoidCallback? onPhotoTap, String? photoIdentifier, String? photoSemanticLabel });
}

class JeebChatBubble extends StatelessWidget {
  const JeebChatBubble({
    super.key,
    required JeebChatBubbleSide side,
    String? text,                   // xor child
    Widget? child,                  // pass AutoDirectionText(message.text) WITHOUT a style
    JeebChatMedia? media,
    String? time,                   // rendered in an LTR isolate
    JeebChatStatus? status,
    EdgeInsetsGeometry padding = defaultPadding, // 11/14
    double maxWidthFraction = 0.78,
    VoidCallback? onTap,
    Key? bubbleKey,                 // Key('chat-bubble-<messageId>') on the painted box
    String? identifier, String? semanticLabel, String? semanticHint,
  });
  // Style lookups for consumers: fillOf / bodyInkOf / metaInkOf / bodyStyleOf / metaStyleOf /
  // mediaLabelStyleOf / radiusOf.
}
```

Incoming: surfaceContainerHigh, tail at bottom-START, no shadow. Outgoing: primary fill, mirrored
tail, `JeebShadows.bubbleOut`. Publishes the matching `JeebSurfaceTone` per side. `readTick` is
never used — read state is the literal `9:25 · Read` text.

#### `JeebSystemChip` — see §2.3.

#### `JeebChatComposer` — `jeeb_chat_composer.dart` (plan #18)

```dart
class JeebChatComposer extends StatelessWidget {
  const JeebChatComposer({
    super.key,
    required TextEditingController controller,
    required String hintText,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    VoidCallback? onSend,            // null -> .38 faded circle + Semantics(enabled: false)
    VoidCallback? onAttach,
    bool isAttaching = false,        // spinner swaps in AND the tap is blocked
    int minLines = 1, int maxLines = 5,
    EdgeInsetsGeometry padding = defaultPadding, // 10/24
    bool useSafeArea = true,         // SafeArea(top: false)
    Key? fieldKey, Key? attachKey, Key? sendKey,   // pass the frozen ChatComposer.* keys
    String? inputIdentifier, String? attachIdentifier, String? sendIdentifier,
    String? inputSemanticLabel, String? attachSemanticLabel, String? sendSemanticLabel,
    IconData attachIcon = Icons.image_outlined,
    IconData sendIcon = Icons.send,  // matchTextDirection — mirrors itself
  });
}
```

**NO MIC (B-04):** `Icons.mic`/`mic_none` are asserted absent; no `chat_detail_voice_button` id
exists. The pill grows with the field (52 is a minimum).

#### `JeebQuickReplyRow` — `jeeb_quick_reply_row.dart` (plan #26)

```dart
class JeebQuickReply {
  const JeebQuickReply({ required String label, VoidCallback? onTap /* null = inert, enabled:false */,
      String? identifier /* intent-keyed: order_chat_quick_reply_home|_door|_thanks */,
      String? semanticLabel });
}

class JeebQuickReplyRow extends StatelessWidget {
  const JeebQuickReplyRow({ super.key, required List<JeebQuickReply> replies,
      EdgeInsetsGeometry padding = defaultPadding /* 10/24/0, inside the scroll view */,
      String? identifier, String? semanticLabel });
}
```

Never force-LTR (AR pill in an EN thread shapes itself — asserted).

### 2.10 Inputs & toggles

#### `JeebSegmentedToggle` — `jeeb_segmented_toggle.dart` (plan #19)

```dart
class JeebSegment {
  const JeebSegment({ required String label, Key? key, String? identifier, String? semanticLabel });
}

class JeebSegmentedToggle extends StatelessWidget {
  const JeebSegmentedToggle({
    super.key,
    required List<JeebSegment> segments,
    required int selectedIndex,      // out-of-range selects nothing, never throws
    required ValueChanged<int> onChanged, // re-tap of the selected segment still fires
    EdgeInsetsGeometry padding = EdgeInsetsDirectional.all(4),
    EdgeInsetsGeometry segmentPadding = defaultSegmentPadding, // 9/0
    double borderWidth = 1.5,
    String? identifier,              // track id; never swallows segment ids
  });
}
```

Per-segment node is 20 §8 K1 verbatim (`inMutuallyExclusiveGroup` + `selected` + button).
**17's ETA row is NOT this widget** (that is `JeebChipRow.expanded` of `role: choice` chips);
**01 keeps its screen-local `OnboardingLanguageToggle`**.

#### `JeebInfoNote` — `jeeb_info_note.dart` (plan #22)

```dart
enum JeebInfoNoteTone { muted, accent, success, warning, outlined, error }

class JeebInfoNote extends StatelessWidget {
  const JeebInfoNote({
    super.key,
    required JeebInfoNoteTone tone,
    IconData? icon,            // xor leading
    Widget? leading,           // escape hatch (11's Ø8 dot)
    String? title,             // PASSING IT SWITCHES TO THE STACKED FORM (pad 13, gap 12, glyph 19)
    String? text,              // body line — the param is `text:`, NOT `body:`; xor label
    Widget? label,             // body widget escape hatch
    Widget? trailing,          // THE single end slot: meter / code strip / money Text; xor linkLabel
    String? linkLabel,         // accent w700 trailing link (17's 'Top up'); requires onLink
    VoidCallback? onLink, String? linkIdentifier,
    VoidCallback? onTap,       // whole-note tap (12's door-code row)
    double radius = 16,
    EdgeInsetsGeometry? padding, double? gap, double? iconSize, Color? iconColor,
    String? identifier, String? semanticLabel, String? semanticHint,
  });
  // .muted / .accent / .success / .warning / .outlined / .error — same params minus tone.
  bool get isStacked; // == (title != null)
}
```

Strip form (no title): pad 12/16, gap 10, glyph 17. The form is **structural** — `title` moves all
four numbers. `muted`/`accent`/`outlined` re-tone on navy; `success`/`warning`/`error` keep their
role colours everywhere (the state is the message). The accent tone's orange is the LINK, never
the fill.

---

## 3. Inconsistencies found and reconciled

1. **`JeebListRow.enabled` → `isEnabled`** — the only `is`-less state bool in the kit
   (JeebCtaButton and JeebStepperPill both shipped `isEnabled`). Renamed, test updated.
2. **`JeebListRow.contentPadding` → `padding`** — every other widget's outer inset is `padding`;
   `contentPadding` now exists only on `JeebCtaButton` where it means the pill's internal inset.
3. Verified-consistent (no change needed): `selected` naming; `radius` naming; `identifier`
   plumbed through explicit `Semantics` in all 28 widgets; `super.key` everywhere; enum + named
   constructor pattern for variants; `EdgeInsetsDirectional` throughout; the
   `Semantics`-only-when-asked policy for decorative widgets.
4. Accepted asymmetries (documented, not bugs):
   - `JeebTierRow.compact(mark:, title:)` vs `.catalog(emoji:, name:)` — both spellings are pinned
     verbatim by 07's and 08's per-screen contracts.
   - `JeebCtaFooter` has no `identifier` param — children carry the ids.
   - `JeebStepperPill` always emits a Semantics node (button announcement) while other widgets
     emit only when asked.
   - `JeebPageDots` defaults 22×8/gap 7 (re-verified render) vs plan's 28×8/6;
     `planActiveWidth = 28` is provided.
   - `JeebCodeCells.input52` passes OMDS's `identifier:` — the sanctioned editable-leaf exception
     (§1.1).

### Deltas vs per-screen instruction files (this doc wins)

- **20-settings.md** sign-out row: pass `isEnabled: !state.isSigningOut` (doc says `enabled:`).
- Any draft calling `JeebInfoNote(body: …)`: the parameter is **`text:`** (23's drafts).
- 07-request-type.md W-3 describes the selected `.compact` treatment with `JeebShadows.ctaNavy`;
  the kit ships `JeebNavySurfaceCard.selectedShadow` (`0 10 22 @.28`) per 08 §3's correction —
  visually 2px of blur difference, contract-pinned in the kit tests.

---

## 4. Refusals & guards — confirmed held

- **No mic in `JeebChatComposer`** (B-04): asserted absent in code and test.
- **`JeebSemanticColors.readTick` has zero consumers**: `JeebChatBubble` renders `· Read` as text.
- **`JeebMoneyBreakdown`** says "Platform fee", never "Commission": debug asserts throw on
  'commission'/'عمولة' and on any non-`kJeebCommissionPercent` percentage.
- **The `JeebProfileHeader` rating star is navy** — not `starRatingColor`, not accent; test-pinned.
- **`accentTint` used exactly once** (07's "Most picked" badge).
- **Screen 12 does not get `JeebAccentFrameCard.filled`** (12 §A-1 cut it).

## 5. Still missing / left to lanes (deliberately)

- **`JeebMoneyField`** (17's `$ 8.00` money input, plan §4 ramp note): screen-17-local by
  assignment; `JeebStepperPill.spacing` (6) is the kit's contribution to its pair gap.
- 21's white "Track" pill and 23's starter-credit pill: screen-local (no on-navy unselected chip
  exists in the kit, by design).
- 01's dark-on-navy language toggle: stays `OnboardingLanguageToggle` (screen-local).
- The `+N` overflow text of `JeebAvatarStack`: caller-owned widget (type-pinned by replies tests).
- Min-48dp tap wrappers for `JeebSelectChip`: call-site responsibility (11's test pins the bare
  capsule).

## 6. Gate numbers (final, 2026-08-03)

| Gate | Result |
| --- | --- |
| `dart analyze lib/core/widgets/jeeb test/core/widgets/jeeb` | **No issues found** |
| `flutter analyze --no-pub` (whole repo) | **5 issues** — the 5 baseline `containsSemantics` infos; 0 errors, 0 new |
| `flutter test test/core/widgets/jeeb/ --no-pub` | **476 passed, 0 failed** |
| `grep -rn "Color(0x" lib/core/widgets/jeeb/` | 0 hits |
| Files | 31 lib (28 plan rows + `jeeb_surface_tone.dart` infra + split of #2/#9 across their natural files), 38 test |
