# 08 · Tier catalog — change proposal

Lane: Wave 3 · feature dir `lib/features/tier_selection/`
Design: `screens/08-tier-catalog.{png,html,note.md}`
Verdict: **new-surface** (a rebuilt widget file mounted on a route that does not exist today)

---

## 0. Which file, and why the two spec documents disagree

`00-MIGRATION-PLAN.md` contains two statements about screen 08 that read as contradictory:

- the STOP table (line 22) and `screen-repo-map.md` line 15 say `tier_selection_screen.dart` is
  **dead** and to edit `request_type_screen.dart`;
- the Wave-3 table (line 472) says 08 gets a **new `/tier-catalog` route** in feature dir
  `tier_selection`, must not resurrect `/tier-selection`, and notes the file is **contrast-gate-listed**
  — and the only gate-listed tier file is
  `test/core/theme/no_raw_semantic_colors_test.dart:39` →
  `lib/features/tier_selection/presentation/tier_selection_screen.dart`.

**Resolution (both are satisfiable, and this is the only reading that satisfies both):**

| Surface | File | Owner | What happens |
|---|---|---|---|
| 07 Request type — the **compact** in-flow tier picker | `request_type/presentation/request_type_screen.dart` + `request_tier_card.dart` | **Lane 07** | I do not touch it. It stays the create-flow step and the owner of tier selection. |
| 08 Tier catalog — the **standalone comparison** surface | `tier_selection/presentation/tier_selection_screen.dart` | **This lane** | Rebuilt to the board and mounted at the new `/tier-catalog`. |

Evidence this is right, not a compromise: the board draws 07 and 08 as *different anatomies of the
same five tiers* — 07 is a radio list with speed/value text lines and a `Most picked` nudge; 08 is a
comparison card with a 4-dot price meter, an SLA chip and a vehicle line. §5 #8 of the plan specs
exactly this as **two named constructors on one widget** (`JeebTierRow.compact` for 07,
`JeebTierRow.catalog` for 08). Collapsing 08 into 07 would delete one of the two constructors the
kit is being built for.

Consequence: **`tier_selection_screen.dart` stops being dead code.** The gate test at line 39 also
asserts the file still exists at that path — do **not** move or rename it.

---

## 1. Semantics inventory — FROZEN (must still be emitted after the rebuild)

Greped from `lib/features/tier_selection/`:

| identifier | today at | after |
|---|---|---|
| `tier_selection_root` | `tier_selection_screen.dart:92` | unchanged — still the single `<screen>_root` |
| `tier_selection_confirm_cta` | `tier_selection_screen.dart:191` | unchanged — re-homed onto `JeebCtaButton` |
| `tier_selection_card_flash` | `tier_selection_screen.dart:275` (`'tier_selection_card_${tier.id.name}'`) | unchanged |
| `tier_selection_card_express` | same | unchanged |
| `tier_selection_card_standard` | same | unchanged |
| `tier_selection_card_onTheWay` | same | unchanged — **note the camelCase**: `TierId.onTheWay.name == 'onTheWay'`, so the emitted value is `tier_selection_card_onTheWay`, not `..._on_the_way`. It is frozen as-is. Do not "fix" it. |
| `tier_selection_card_eco` | same | unchanged |

Widget `Key`s (also frozen, all declared `tier_selection_screen.dart:49-53`):
`tier-selection-root`, `tier-selection-list`, `tier-selection-confirm`, `tier-selection-retry`,
`tier-selection-card-<id.name>`. `listKey` and `retryButtonKey` have no test consumers today but
are public API — keep them declared and re-home `listKey` onto the new scroll view.

**New identifier (one):** `tier_selection_back` on the `JeebTopBar` back circle. Convention
confirmed against 13 existing `<screen>_back` values (`kyc_status_back`, `dispute_status_back`,
`pending_offers_back`, …). Keep the `tier_selection_` prefix, not a new `tier_catalog_` prefix —
§7.5 allows exactly one `<screen>_root` per surface and that value is already frozen as
`tier_selection_root`.

No other new interactive element exists on this board: the cards, the CTA and the back button are
the complete interactive set. The info note is static.

---

## 2. Layout & structure

### Today (`tier_selection_screen.dart`)

```
Scaffold(appBar: OMDSAppBar(title))
└ SafeArea > BlocConsumer
  └ Column
    ├ _CachedBanner            (dead — see §2.5)
    ├ Padding(subtitle)
    ├ Expanded(ListView.separated)   ← list EXPANDS into the empty half
    └ Padding(OmdsPrimaryButton)     ← CTA scrolls with nothing, sits in the body Column
```

### Target (board)

```
Scaffold(bottomNavigationBar: JeebCtaFooter.single)
└ SafeArea
  └ Column
    ├ JeebTopBar(leading: back, title: 'Delivery tiers')      pad 14/24/0
    ├ subtitle                                                pad 14/24/0
    ├ Expanded(SingleChildScrollView( key: listKey            pad 16/24/0
    │   └ Column(mainAxisSize: min)
    │     ├ 5 × JeebTierRow.catalog, gap 9
    │     └ JeebInfoNote.muted                                margin-top 16
    │   ))                                    ← content is TOP-ALIGNED, does not stretch
    └ (docked footer via bottomNavigationBar)                 pad 0/24/32
```

### 2.1 App bar → in-body `JeebTopBar`
**Where:** `tier_selection_screen.dart:96-99` (`OMDSAppBar(title: l10n.tierSelectionTitle, centerTitle: false)`).
**Becomes:** delete the `appBar:` argument; first child of the body `Column` is
`JeebTopBar(leading: JeebTopBarLeading.back, title: l10n.tierCatalogTitle, identifier: 'tier_selection_back', onBack: () => Navigator.of(context).maybePop())`.
**Evidence:** HTML `data-dc-tpl="412-416"` — an in-body row, `padding: 14px 24px 0`, gap 14, a
Ø40 `--jeeb-surface-high` circle holding a 20px navy arrow, then the title at 20/w700 navy.
There is no Material app bar, no elevation, no divider.
**Title copy changes:** `tierSelectionTitle` is `"Choose speed"`; the board says **"Delivery tiers"**
(the surface is now a comparison catalog, not the chooser — 07 is the chooser). New key.

### 2.2 Subtitle
**Where:** `tier_selection_screen.dart:159-172`.
**Becomes:** `Padding(EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.small, Spacing.xLarge, 0), child: Text(l10n.tierCatalogSubtitle, style: context.jeebText.body.copyWith(color: semantic.mutedText)))`.
**Evidence:** HTML `417` — `padding: 14px 24px 0`, `14.5px / w500 / --jeeb-periwinkle`,
copy `"Same errand, five speeds — pick what it's worth."`. Today's copy is
`tierSelectionSubtitle = "Price varies by Jeeber"` and today's style is `bodyMedium` +
`onSurfaceVariant` (brown). New key + periwinkle ink.
**Divergence to accept:** the ramp has no 14.5/w500; `jeebText.body` is 13.5/w500. Use it (R3: do
not invent a size, and do not reach for a bigger one).

### 2.3 The list stops expanding — this is the single biggest visual change
**Where:** `tier_selection_screen.dart:173-187` (`Expanded(child: ListView.separated(...))`).
**Becomes:** `Expanded(child: SingleChildScrollView(key: TierSelectionScreen.listKey, padding: EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0), child: Column(mainAxisSize: MainAxisSize.min, children: [...cards, note])))`.
**Evidence:** R1 + the render. Five cards + the note end at ~68% of the 956px canvas; the bottom
~30% is plain white, then the docked CTA. A `ListView` inside `Expanded` distributes its own
height and visually "fills" — content that ends at 68% is the whole point of the redesign.
`SingleChildScrollView` keeps content top-aligned, leaves real emptiness, and still survives 200%
text scale and small devices (which a fixed `Column` would not).
**Separator:** `Spacing.small` (12) → `Spacing.xSmall` (8). HTML `418` `gap: 9px`; R12 puts 08 at
9px, and 8 is the nearest token.
**Gutter:** `Spacing.large` (20) → `Spacing.xLarge` (24) everywhere on this screen. HTML uses
`24px` on every block; §4.3 maps `--screen-gutter: 24` → `Spacing.xLarge`. Today's screen is at 20.

### 2.4 CTA moves out of the body into a docked footer
**Where:** `tier_selection_screen.dart:188-201`.
**Becomes:** `Scaffold.bottomNavigationBar: JeebCtaFooter.single(...)` wrapping
`JeebCtaButton.primary(key: TierSelectionScreen.confirmButtonKey, identifier: 'tier_selection_confirm_cta', label: l10n.tierCatalogConfirm, isEnabled: state.canConfirm, onTap: () => context.read<TierSelectionCubit>().confirm())`.
**Evidence:** HTML `504` is a bare `flex:1` spacer and `505/506` is the footer: `padding: 0 24 32`,
`height 56`, `border-radius 999`, `--jeeb-navy` fill, white `17px/w600`, shadow
`rgba(11,19,81,.28) 0 10 24` → `JeebShadows.ctaNavy`. Today it is `EdgeInsets.all(Spacing.large)`
(20 on all four sides) inside the body column with an `OmdsPrimaryButton`.
**Pattern precedent in-repo:** `request_type_screen.dart:111-114` already docks its Continue CTA in
`bottomNavigationBar` with `SafeArea(top: false)` — copy that shape exactly.
**Copy:** `tierSelectionConfirm` is `"Confirm"`; the board says **"Confirm tier"**. New key.
**Keep the hide-on-not-loaded behaviour** (`request_type_screen.dart:130-132` idiom): the footer
renders `SizedBox.shrink()` unless `status == loaded`, so it never floats over the spinner or the
error state. Today's screen has the CTA inside `_LoadedView`, which achieves the same thing — the
docked version must reproduce it explicitly.

### 2.5 Delete `_CachedBanner` (dead code)
**Where:** `tier_selection_screen.dart:157-158` + `207-251`.
**Why:** `TierSelectionCubit` sets `usingCachedFallback: false` in the constructor default,
in `_emitLoaded` (`tier_selection_cubit.dart:59`) and in `_emitFailure` (line 75). JEBV4-300
removed the fallback catalog entirely; nothing can ever set it true. The board has no such banner.
**Test safety:** `tier_selection_screen_test.dart:53-56` and `:105-108` assert
`find.byKey(const Key('tier-selection-cached-banner'))` **findsNothing** — deleting the widget keeps
both green. Keep the `usingCachedFallback` field on the state (it is cubit API and `copyWith`
surface).

### 2.6 Loading / error keep OMDS, but move under the top bar
**Where:** `tier_selection_screen.dart:127-141`.
**Change:** `_Body`'s three branches become the *scroll-area* content, not the whole body — the
`JeebTopBar` and the subtitle render in every status. Today the entire body is replaced by a
`Center`, so a failed fetch shows a bare spinner/error with only the Material app bar.
**Keep `OmdsErrorState` and `OmdsLoadingState` verbatim.** The board draws neither, and
`tier_selection_screen_test.dart:137,155` asserts `find.byType(OmdsErrorState)` and taps its retry
via `find.byWidgetPredicate((w) => w is FilledButton)`. Swapping them for a bespoke error surface
breaks two tests for zero design evidence.

### 2.7 Delete `tier_card.dart`
`lib/features/tier_selection/presentation/tier_card.dart` (245 lines) is replaced wholesale by
`JeebTierRow.catalog`. Its only importer is `tier_selection_screen.dart:13`. Deleting it also
removes the feature's last `.tertiaryContainer` / `.onTertiaryContainer` usage (`tier_card.dart:102-103`).

---

## 3. Card anatomy — `TierCard` → `JeebTierRow.catalog`

Today's card (`tier_card.dart:92-132`) is a **five-row vertical stack**: name+badge / description /
`⏱ eta` meta row / `🛵 vehicle` meta row / price. The board's card is **two rows**:

```
row 1:  [emoji 17]  [name 15.5/w700]  [Recommended pill]  ——spacer——  [●●●● meter]
                                                                       [caption 10.5/w700]
row 2:  [SLA chip]  [vehicle glyph 14]  [meta line 11.5/w600]  ——spacer——  [✓ 15px, selected only]
        margin-top 8
```

| # | What | Today | Becomes | Evidence |
|---|---|---|---|---|
| 3.1 | Leading mark | `Icons.schedule_rounded` / `Icons.two_wheeler_rounded` on separate meta rows; no tier mark at all | **17px emoji** `⚡ 🚀 🟦 🤝 🌿` as the first element of row 1 | HTML `421/438/453/472/487` `font-size:17px`; R10 "tier marks are **emoji** at 17px, never icons". Note 07 went the opposite way in June (`request_type_screen.dart:353-364` replaced emoji with `IconData`) — the board reverses that for 08 |
| 3.2 | Tier name | `textTheme.titleLarge` (22px) + `copyWith(w700)` | `context.jeebText.cardTitle` (15.5/w700), ink `colorScheme.primary` | HTML `422` `15.5px/700/--jeeb-navy`. R3 — the current 22px is 6.5px too big; weight already carries it |
| 3.3 | Description line | `_tierFooter()` → `tierSelectionFooterFlash` etc., `bodyMedium` under the title | **deleted** | The board has no third line. The value proposition now lives in the meter caption ("Highest price") and the meta line |
| 3.4 | Price range | `MoneyFormat.format(...)` `"$120.00 – $160.00"` at `titleMedium/w700` (`tier_selection_screen.dart:265-268`, `tier_card.dart:125-131`) | **deleted** — replaced by the 4-dot meter | The designer note is explicit: "a relative price-level meter per tier … **instead of unpredictable dollar figures**". This is also the only honest rendering: Jeebers set the price via offers, so a per-tier range is a number the platform cannot stand behind. Drop the `money_format.dart` import |
| 3.5 | Price meter | — (new) | `JeebPriceMeter(level: n, of: 4, caption: …, onNavy: selected)` at the END of row 1, right-aligned column, gap 3 | HTML `424-430`: `inline-flex column align-items:flex-end gap 3`, 4 × Ø7 r999 dots gap 3, `--jeeb-orange` filled / `--jeeb-surface-highest` empty, caption `10.5/w700 --jeeb-periwinkle` |
| 3.6 | SLA chip | `⏱` + text meta row | pill, pad `3/9`, r999, `surfaceContainerHigh` fill, navy `11.5/w700` | HTML `432/449/465/483/498`. R2's "meta chip" scale. Baked into `JeebTierRow.catalog` per §5 #8 |
| 3.7 | Vehicle glyph | `Icons.two_wheeler_rounded` etc. on its own row, `Sizes.medium`, ink = foreground | 14px, periwinkle, inline before the meta text, **on all five cards** | HTML `433` draws it on Flash only — C7 calls that a design slip and mandates all five. Ink `--jeeb-periwinkle` per `fill` on `433` |
| 3.8 | Meta line | `_vehicleLabel()` (vehicle class only) | a per-tier **meta line** — vehicle class for Flash/Express/Standard, a match descriptor for On-the-Way/Eco | HTML `435` "Bike / scooter", `450` "Scooter / car", `466` "Any vehicle", `484` "Matched with a passing Jeeber", `499` "Bundled route · greenest". Style `11.5/w600 --jeeb-periwinkle` |
| 3.9 | Recommended badge | `Container(tertiaryContainer, labelSmall/w600)` at `tier_card.dart:189-205` | **solid `jeebRoles.accent` pill, `onAccent` ink, `jeebText.badge` (10.5/w800), pad `2/8`, r999**, inline right after the name | HTML `455`. §4.1 is explicit: `accentTint` has exactly one board-wide consumer (07's "Most picked") — 08's badge is the solid treatment. Today's `tertiaryContainer` is also a gate violation waiting to happen |
| 3.10 | Selected state | `primaryContainer` fill (peach) + `primary` border widened 1→2 + `Icons.check_circle_rounded` | **navy `colorScheme.primary` fill, no border**, `JeebShadows.ctaNavy`, all internals re-toned, 15px white `Icons.check_rounded` at the END of row 2 | HTML `451`: `background: --jeeb-navy`, `box-shadow: rgba(11,19,81,.28) 0 10 22`, **no border**. R8: "selection is a fill swap, never a border swap". Re-tone table below |
| 3.11 | Unselected border | `scheme.outlineVariant` (#E5E1E5) at 1px | `colorScheme.outline` (#916F66) at **1.5px** | HTML `419` `1.5px solid var(--jeeb-brown-outline)`; §4.1 "`--jeeb-brown-outline` … **This IS the 1.5px card border**". R7 — flat, no shadow, ever |
| 3.12 | Card fill / radius / padding | `surfaceContainerLow`, `OmdsBorderRadius.medium`, `EdgeInsets.all(Spacing.medium)` (16) | `colorScheme.surface` (white), r16, pad `13/16` (kit-internal exact px) | HTML `419` `border-radius:16px; padding:13px 16px`, no background declared → white |

**On-navy re-tone (R8, `JeebNavySurfaceCard` contract, §5 #4) — all four must be applied together:**

| element | unselected | selected |
|---|---|---|
| card fill | `colorScheme.surface` + 1.5px `colorScheme.outline` | `colorScheme.primary`, no border, `JeebShadows.ctaNavy` |
| name / SLA-chip ink | `colorScheme.primary` | `colorScheme.onPrimary` |
| SLA chip fill | `colorScheme.surfaceContainerHigh` | `onPrimary.withValues(alpha: 0.14)` (HTML `465`) |
| meta line + meter caption | `JeebSemanticColors.mutedText` | `onPrimary.withValues(alpha: 0.7)` (HTML `463/464`) |
| meter dots filled / empty | `jeebRoles.accent` / `surfaceContainerHighest` | `onPrimary` / `onPrimary.withValues(alpha: 0.25)` (HTML `459-462`) |

This inversion is exactly why §5 #21 splits `JeebPriceMeter` out of `JeebTierRow` — it is the one
piece of this screen that will drift if hand-rolled.

---

## 4. Tokens — every hardcoded value in the current files

`tier_selection_screen.dart` and `tier_card.dart` carry **zero** `Color(0x…)` literals (the gate
holds). The problem is wrong *roles* and wrong *sizes*, not raw hex:

| Current | file:line | Becomes | Why |
|---|---|---|---|
| `scheme.primaryContainer` / `onPrimaryContainer` (selected fill) | `tier_card.dart:70,71,73` | `colorScheme.primary` / `onPrimary` | R8 + the "peach selected-states" defect named in plan §2 |
| `scheme.tertiaryContainer` / `onTertiaryContainer` (badge) | `tier_card.dart:102,103` | `context.jeebRoles.accent` / `.onAccent` | §7.3 — `.tertiary*` is banned in the gated file; `jeebRoles.accent` is the only sanctioned orange |
| `scheme.outlineVariant`, `width: selected ? 2 : 1` | `tier_card.dart:75,89` | `colorScheme.outline`, constant `1.5` (kit-internal) | HTML `419` |
| `scheme.surfaceContainerLow` | `tier_card.dart:70` | `colorScheme.surface` | HTML `419` declares no background → white |
| `textTheme.titleLarge?.copyWith(fontWeight: w700)` | `tier_card.dart:180` | `context.jeebText.cardTitle` | §4.6 |
| `textTheme.titleMedium?.copyWith(w700)` (price) | `tier_card.dart:127` | deleted | §3.4 |
| `textTheme.bodyMedium` (description, meta) | `tier_card.dart:108,238` | `context.jeebText.caption` for the meta line | HTML `431` 11.5/w600 |
| `textTheme.labelSmall?.copyWith(w600)` (badge) | `tier_card.dart:200` | `context.jeebText.badge` | §4.6 |
| `theme.textTheme.bodyMedium` + `onSurfaceVariant` (subtitle) | `tier_selection_screen.dart:168-170` | `context.jeebText.body` + `JeebSemanticColors.mutedText` | HTML `417` periwinkle, not brown |
| `Sizes.large` / `Sizes.medium` icon sizes | `tier_card.dart:209,233` | kit-internal 15 (check) / 14 (vehicle glyph) | HTML `468` 15px, `433` 14px |
| `Spacing.large` gutters (20) | `tier_selection_screen.dart:160,162,176,189` | `Spacing.xLarge` (24) | §4.3 `--screen-gutter: 24` |
| `Spacing.small` separator (12) | `tier_selection_screen.dart:178` | `Spacing.xSmall` (8) | HTML `418` gap 9 → R12 |
| `EdgeInsets.all(Spacing.large)` footer | `tier_selection_screen.dart:189` | `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)` | HTML `505` `0 24 32` |
| `EdgeInsets.symmetric(horizontal: …)` | `tier_selection_screen.dart:176` | `EdgeInsetsDirectional.symmetric(...)` | §7.1-5 directional APIs only |
| `context.jeebRoles.infoContainer`, `OmdsBorderRadius.small` | `tier_selection_screen.dart:230-231` | deleted with `_CachedBanner` | §2.5 |
| no shadow anywhere | — | `JeebShadows.ctaNavy` on the CTA **and** on the selected card only | HTML `506` and `451` are the only two shadows on this screen. R7 — the four unselected cards stay flat |

**Values that stay design-exact inside `lib/core/widgets/jeeb/` (§4.4 tier-two rule):** card pad
`13/16`, dot Ø7 gap 3, chip pad `3/9`, badge pad `2/8`, CTA h56, check 15px, glyph 14px, and the
`alpha` fractions `.14/.25/.7`. None of these may appear in `lib/features` —
`tool/check_design_tokens.sh` bans literal `EdgeInsets.*(N`, `SizedBox(width|height: N)`,
`BorderRadius.circular(N)` and `fontSize: N` there.

---

## 5. Shared components consumed (all Wave 1, none exist yet — `lib/core/widgets/jeeb/` is empty)

| Kit widget | Used for | API this screen needs |
|---|---|---|
| `JeebTopBar` (§5 #1) | header | `leading: back`, `title`, `identifier`, `onBack` |
| `JeebTierRow.catalog` (§5 #8) | the 5 cards | `emoji`, `name`, `slaLabel`, `metaLabel`, `metaIcon`, `priceLevel`, `priceCaption`, `badgeLabel?`, `selected`, `onTap`, `identifier`, `semanticLabel`, `selectedHint` |
| `JeebPriceMeter` (§5 #21) | the 4-dot meter | `level`, `total: 4`, `caption`, `onNavy` — **consumed via `JeebTierRow.catalog`, not directly** |
| `JeebInfoNote.muted` (§5 #22) | the "Jeebers set the price" panel | `icon`, `text` |
| `JeebCtaFooter.single` + `JeebCtaButton.primary` (§5 #2) | docked Confirm | `label`, `isEnabled`, `onTap`, `identifier`, `key` |

`JeebOutlinedCard` / `JeebNavySurfaceCard` (§5 #3/#4) are consumed *inside* `JeebTierRow.catalog`,
not by this screen — that is the whole point of the one-state-machine rule (§5.1 step 1).

**Blocking asks on the kit lanes** (see §11 wiring requests): `JeebCtaButton` must expose
`isEnabled` (not just a nullable `onTap`) or `tier_selection_screen_test.dart` cannot assert the
disabled state the way it does today; `JeebTierRow.catalog` must take the emoji as a `String`
param rather than importing `TierId`, so the kit stays feature-agnostic.

---

## 6. New data the design needs — what exists, what does not, what is a lexicon

### 6.1 Price level (the headline new thing) — **client-side lexicon, sanctioned**

Board values, read off the HTML dot fills:

| Tier | dots | caption | HTML |
|---|---|---|---|
| Flash | 4 / 4 | Highest price | `426-430` |
| Express | 3 / 4 | Higher price | `443-447` |
| Standard | 2 / 4 | Balanced price | `459-463` |
| On-the-Way | 2 / 4 | Lower price | `477-481` |
| Eco | 1 / 4 | Lowest price | `492-496` |

There is **no `priceLevel` field** on `Tier` and none on the gateway response
(`DioTierRepository._parseTier`, `tier_repository.dart:85-102`, reads `id`/`name`/`slaHours`/
`priceHint` only). Plan §7.6 explicitly permits this case: *"per-tier ETA bands / vehicle class /
price level … tier metadata may be a client-side constant table if the gateway has none, since
tiers are a fixed product lexicon."*

**Proposal:** a new `lib/features/tier_selection/domain/tier_display_lexicon.dart` — a `const`
map `TierId → ({String emoji, int priceLevel, TierPriceBand band})`. It is display metadata for a
closed 5-value enum, not a fabricated server field, and it is the **central** home the plan asks
for in §9-7 ("decided centrally … never per screen"); 07 can import the same table for its emoji.

**Rejected alternative:** deriving the level by ranking the loaded catalog on `Tier.priceHigh`.
It uses only existing fields, but `_pricesForHint` (`tier_repository.dart:153-163`) collapses every
unrecognised `priceHint` to the same `(30000, 55000)` band, and if the gateway sells only three
tiers the ranking would relabel Standard as "Lowest price". Deterministic lexicon wins.

**Flag (design inconsistency, not a bug):** Standard and On-the-Way are both drawn at 2/4 with
different captions. Five tiers do not fit four dots monotonically. Ship the board's exact values —
the caption is the primary signal and the dots are the secondary — and note it for the designer.

### 6.2 SLA chip — **render from data, do not hardcode the board's strings**

`Tier.slaMinutes` exists and is populated (`slaHours * 60`, `tier_repository.dart:88-89`), and
`_slaCopy` (`tier_selection_screen.dart:327-335`) already produces "≤ N hr" / "≤ N min". Keep that
function verbatim. Two board strings disagree with live data and **the data wins**:

| Tier | board chip | from `slaMinutes` | resolution |
|---|---|---|---|
| Flash | `≤ 1 hr` | 60 → `≤ 1 hr` | ✅ match |
| Express | `≤ 2 hr` | fake 180 → `≤ 3 hr`; live sends `slaHours` | render from data |
| Standard | `≤ 4 hr` | 240 → `≤ 4 hr` | ✅ match |
| On-the-Way | `Flexible` | `null` → today `"No SLA"` | **change the null copy to "Flexible"** — new key `tierCatalogSlaFlexible`; "No SLA" is engineer-speak and the board's word is better |
| Eco | `Today` | 2880 → `≤ 48 hr` | render from data. "Today" contradicts a 48h SLA — do not hardcode it |

### 6.3 Meta line — new l10n keys, D20-safe
`tier.vehicleClass` exists and maps to the glyph. The *text* is per-tier, not per-vehicle-class
(On-the-Way and Eco say something that is not a vehicle at all), so it is a new per-tier key set
rather than a reuse of `tierSelectionVehicle*`. C7 requires these be **new** keys; the D20 banned
list (`test/decision_violations_test.dart:161-168`) is
`dmOnboardingAddressVehicleNumberLabel/Hint`, `kycWizardStepVehicleLabel`, `kycVehicleStepTitle`,
`kycVehicleRegistrationLabel`, `kycStatusResubmitCta`, `dmOnboardingServiceAreaDistanceLabel` —
none of the proposed keys collide.

### 6.4 `recommended` comes from data and the data disagrees with the board
`DioTierRepository._parseTier:100` sets `recommended: id == TierId.flash`;
`FakeTierRepository.defaultCatalog:189` also flags Flash. The board puts `Recommended` on
**Standard** (and 07's board puts `Most picked` on Standard too). **Render the badge from
`tier.recommended`** — do not hardcode Standard. If the product wants Standard to be the
recommendation, that is a back-office/gateway change, not a UI change. Owner question.

### 6.5 Nothing else is missing
No reach counts, no ratings, no distances on this screen. **08 has no data gap** — a rarity on this
board. Nothing here needs a `TODO(redesign-24)`.

---

## 7. New route + wiring

```dart
// app_router.dart — inside _wrapRootAware([...]), at the W1 customer-journey band,
// replacing the "legacy /tier-selection was removed" comment block at line 1088-1092
// (keep that comment: it explains why the path is /tier-catalog and not /tier-selection).
GoRoute(
  path: '/tier-catalog',
  name: 'tier-catalog',
  builder: (context, state) => TierSelectionScreen(
    onConfirmed: (tier) => context.pop(tier.id),
  ),
),
```

```dart
// app_router.dart backFallbacks (near line 482, beside 'request-type': '/')
'tier-catalog': '/request-type',
```

Both edits are **integrator-owned** (§7.4). Notes:
- `/tier-selection` is **not** resurrected. The removal comment at `app_router.dart:1088-1092`
  stays, extended with one line explaining the new secondary surface.
- No `pageBuilder`, no `parentNavigatorKey` — `_wrapGoRoute` (`app_router.dart:534-550`) silently
  drops them.
- The route is **not** in the `excluded` list of `back_nav_all_routes_test.dart:72-85`, so the
  `backFallbacks` entry auto-generates one new parameterized case which passes by construction
  (`/request-type` is already a registered distinct-fallback destination).
- `TierRepository` is already registered in DI — **no `injection_container.dart` edit needed.**

**Return contract:** Confirm pops the chosen `TierId`. 07 owns tier selection; the catalog is a
comparison side-trip that hands its answer back:

```dart
// request_type_screen.dart — LANE 07 / integrator, not this lane
final chosen = await context.pushNamed<TierId>('tier-catalog');
if (chosen != null && context.mounted) {
  context.read<TierSelectionCubit>().selectTier(chosen);
}
```

This keeps `ComposeRequestController.setTier` on the single existing path
(`request_type_screen.dart:160-163` and `:257-259`) — the catalog never writes the compose
controller, so the `tier-required` 400 defect fixed in iter6 cannot reappear through a second door.

---

## 8. l10n

**New keys (integrator batch — EN + real AR + getter, all four steps):**

| key | EN |
|---|---|
| `tierCatalogTitle` | Delivery tiers |
| `tierCatalogSubtitle` | Same errand, five speeds — pick what it's worth. |
| `tierCatalogConfirm` | Confirm tier |
| `tierCatalogSlaFlexible` | Flexible |
| `tierCatalogPriceHighest` | Highest price |
| `tierCatalogPriceHigher` | Higher price |
| `tierCatalogPriceBalanced` | Balanced price |
| `tierCatalogPriceLower` | Lower price |
| `tierCatalogPriceLowest` | Lowest price |
| `tierCatalogMetaFlash` | Bike / scooter |
| `tierCatalogMetaExpress` | Scooter / car |
| `tierCatalogMetaStandard` | Any vehicle |
| `tierCatalogMetaOnTheWay` | Matched with a passing Jeeber |
| `tierCatalogMetaEco` | Bundled route · greenest |
| `tierCatalogPricingNote` | Jeebers set the price — you compare real offers and pick one. No fixed prices. |
| `tierCatalogBackLabel` | Back (a11y label for the top-bar circle) |
| `tierCatalogPriceMeterSemanticLabel` | `{caption}, level {level} of {total}` |

**Reused unchanged:** `tierSelectionTierFlash/Express/Standard/OnTheWay/Eco`,
`tierSelectionSlaHours`, `tierSelectionSlaMinutes`, `tierSelectionRecommendedBadge`,
`tierSelectionCardSemanticLabel`, `tierSelectionCardSelectedHint`, `requestSummaryErrorNetwork`,
`requestSummaryRetry`.

**Orphaned but NOT deleted** (removing keys risks the bidirectional parity gate for no gain, and
`tierSelectionTitle`/`Subtitle`/`Confirm` may still be referenced by AR translation memory):
`tierSelectionPriceRange`, `tierSelectionPriceLabel`, `tierSelectionSlaNone`,
`tierSelectionFooter*` (×5), `tierSelectionVehicle*` (×5), `tierSelectionTitle`,
`tierSelectionSubtitle`, `tierSelectionConfirm`, `tierSelectionWhatDifference`,
`tierSelectionLocked`, `tierSelectionRadiusKm`.

**`tierSelectionCardSemanticLabel(name:, sla:, radius:, price:)`** takes a `price` placeholder that
no longer has a value. Pass the meter caption ("Highest price") into `price` and the meta line into
`radius` rather than adding a key — the screen-reader sentence stays truthful and the parity gate
stays untouched. If the integrator prefers a clean signature, add
`tierCatalogCardSemanticLabel(name:, sla:, meta:, priceLevel:)` and leave the old key orphaned.

---

## 9. RTL

The board is a directional-easy screen, with three traps:

1. **The 4-dot meter must be a plain `Row`, never a `Stack`/`Positioned`/`FractionallySizedBox`.**
   A magnitude meter should fill from the *start* edge, so under `ar` the filled dots correctly
   appear on the right. A `Row` gives that for free; anything positioned does not. Same for the
   `CrossAxisAlignment.end` on the meter's caption column — `end` mirrors, `right` does not.
2. **The SLA chip needs an LTR isolate.** `"≤ 1 hr"` mixes a math symbol, a Latin digit and a Latin
   unit inside an RTL paragraph; without isolation the `≤` migrates to the wrong side of the digit.
   Wrap the chip's `Text` in `Directionality(textDirection: TextDirection.ltr, …)` **inside
   `JeebTierRow.catalog`**, so all five cards and 07 get it once. Precedent:
   `handover_code_display.dart:61` and `chat_message_bubble.dart:566`. Note the AR `Flexible`
   string is pure Arabic and must **not** be isolated — isolate only when the label came from
   `tierSelectionSlaHours`/`SlaMinutes`.
3. **Everything else is order, and order mirrors automatically** — emoji→name→badge→meter in row 1,
   chip→glyph→meta→check in row 2. Use `Row` + `Spacer()` and `EdgeInsetsDirectional` throughout;
   the trailing check must be the *last* child, not `Positioned(right:)`.

`JeebTopBar`'s back glyph resolves through `DirectionalIcons.back(context)`
(`lib/core/widgets/directional_icons.dart:16`) — kit's job, but assert it in the RTL smoke test.

The `·` in `"Bundled route · greenest"` is bidi-neutral and safe inside an Arabic string.

---

## 10. Test impact

| Test | Effect | Legitimate? |
|---|---|---|
| `test/tier_selection_screen_test.dart:73-76, 99-102, 118-122` — `tester.widget<OmdsPrimaryButton>(confirmButtonKey)` | **BREAKS** (type cast) | ✅ Yes. The CTA genuinely becomes `JeebCtaButton`. One-token fix in three places: `tester.widget<JeebCtaButton>(...)`, still reading `.isEnabled`. Do **not** weaken to `findsOneWidget` |
| same file `:12-32` (3 cards render), `:95-106` (tap → confirm → `onConfirmed`), `:107-124` (**does not pre-select the recommended tier**), `:135-165` (retry recovers) | **PASS unchanged** | The card keys, the confirm callback and the no-pre-selection invariant all survive by design |
| same file `:53-56, 105-108` cached-banner findsNothing | **PASS** after `_CachedBanner` is deleted | findsNothing is satisfied by absence |
| `test/tier_selection_cubit_test.dart` | untouched — no cubit behaviour changes | — |
| `test/core/theme/no_raw_semantic_colors_test.dart:39` | **PASS**, and it is the reason the file must not be moved. All orange moves into non-gated kit files; no `Color(0x`, no `.tertiary*`, no `Colors.*` remain | — |
| `test/dio_tier_repository_test.dart`, `test/devtool/tier_catalog_fixture_test.dart` | untouched — parser and fixture unchanged | — |
| `test/core/router/back_nav_all_routes_test.dart` | **+1 auto-generated case** from the new `backFallbacks` entry; passes by construction | — |
| `test/delivery_create_screens_test.dart`, `test/features/request_type/*` | untouched **by this lane**. If the "Compare tiers" entry point lands on 07, whoever lands it must keep `find.text('Choose your request')`, `find.text('Location')`, the 5 `request_type_*_radio` ids and the unchecked-on-first-paint assertion | ⚠️ cross-lane |
| `test/semantics_identifier_surfacing_test.dart` | **ADD** a `/tier-catalog` case asserting `tier_selection_root`, `tier_selection_back`, `tier_selection_confirm_cta` and the 5 `tier_selection_card_*` ids. §8 permits adding only | — |
| **NEW** `test/features/tier_selection/tier_catalog_render_test.dart` | 5 cards; exactly one `Recommended` badge; dot counts 4/3/2/2/1; the pricing note text; CTA disabled until a tap; loading and error states render *below* the top bar | — |
| **NEW** RTL smoke under `ar` | back glyph mirrors; SLA chip reads "≤ 1 hr" left-to-right; meter fills from the start edge | — |
| Goldens | none exist for this feature — nothing to regenerate | — |

---

## 11. Conflicts — refused, and why

**R1 — "Recommended pre-selected" (designer note) is REFUSED.**
Three independent pins say a tier is never chosen for the customer:
- `tier_selection_screen_test.dart:107-123` — *"does not pre-select the recommended tier on first
  load … A recommendation is display metadata, not a customer choice."*
- `request_type_deliberate_selection_test.dart:41-50` — every tier radio must report
  `CheckedState.isFalse` on first paint.
- `tier_selection_cubit.dart:20-22` documents it as an invariant, and `_retainedSelection`
  (`:94-97`) only ever *retains* a selection the user made.

**What ships:** `Recommended` renders as the solid-orange badge (that is what the board actually
*draws* on the badge), the card starts **unselected**, and Confirm starts **disabled**. The render's
navy Standard card is the selected-state illustration, reproduced after a tap. Zero cubit change.

**R2 — "≤ 2 hr" on Express and "Today" on Eco are REFUSED as literals.** They contradict
`slaMinutes` from the same catalog the screen renders. Render from data (§6.2).

**R3 — `Recommended` on Standard is REFUSED as a literal.** `recommended` is a repository-supplied
flag currently set on Flash (`tier_repository.dart:100`, `:189`). Render the flag. Owner question:
should the gateway flag Standard instead?

**R4 — the vehicle glyph on Flash only is REFUSED** (C7 — a design slip). All five.

**R5 — resurrecting `/tier-selection` is REFUSED.** New path `/tier-catalog`, per plan §6 Wave 3
and the in-code CTO note at `app_router.dart:1088-1092`.

**Not conflicts, checked and cleared:** D20 (§6.3), D41/D44 (no money on this screen at all),
`kJeebCommissionRate` (not referenced), B04, D52, D56 — none touch 08.

---

## 12. Risks / open questions

1. **`/tier-catalog` has no entry point in the design.** Plan §6 says it is "opened from 07's
   *Compare tiers*", but screen 07's HTML contains no such affordance (`Most picked` is the only
   extra string on it). The link is an invention of the plan, sits in **lane 07's file**, and is a
   product call. Until it lands, `/tier-catalog` is deep-link-only. Plan §9-6 already flags this
   for the owner — this lane confirms the affordance genuinely does not exist on the board.
2. **07 vs 08 emoji direction.** June's `request_type_screen.dart:353-364` deliberately *replaced*
   the tier emoji with `IconData` ("renders crisply in dark mode + RTL"). The board reverses that.
   Shipping emoji on 08 and icons on 07 would look like two products. Recommend the lexicon
   (§6.1) be adopted by both, and that plan §9-7's 🟦 fallback be verified on the S22 before the
   Wave-5 sweep.
3. **Standard and On-the-Way both draw 2/4 dots.** Five tiers on a four-dot meter (§6.1). Shipping
   as drawn; flagged to the designer.
4. **Density (plan risk 13) is the delivery risk here too.** 08 is one of the seven screens whose
   bottom third is deliberately white. The `Expanded(ListView)` → `Expanded(SingleChildScrollView)`
   swap in §2.3 is the whole mechanism — if a later reviewer "fixes" it back to a `ListView` for
   long-list hygiene, the redesign is silently undone. Worth a `// why` comment on that line.
5. **Blocked on Wave 1.** `lib/core/widgets/jeeb/` does not exist yet. Nothing in this proposal is
   buildable until steps 1, 2, 3, 4 and 7 of §5.1 land (`JeebOutlinedCard`+`JeebNavySurfaceCard`,
   `JeebInfoNote`, `JeebTopBar`, `JeebCtaButton`+`JeebCtaFooter`, `JeebPriceMeter`) plus
   `JeebTierRow` from step 12. This lane should not hand-roll any of them "temporarily".
6. **Dark mode** (plan §9-4): all the re-tone values are alpha-on-`onPrimary` and role-based, so the
   screen stays legible under the navy-seed dark scheme, but the brown 1.5px outline and the
   periwinkle meta ink are light-spec. Out of scope, noted.
