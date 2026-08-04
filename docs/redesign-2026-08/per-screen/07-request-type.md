# 07 · Request type — change proposal

Screen id: `07-request-type` · Verdict: **rebuild** (presentation only — cubit, repository, routing
and every navigation edge are unchanged).

Design source read in full: `screens/07-request-type.png` (render),
`screens/07-request-type.html` (literal source), `screens/07-request-type.note.md`.
Code read in full: `lib/features/request_type/presentation/{request_type_screen,request_tier_card,
request_location_row,request_type_radio_id,selectable_radio_glyph}.dart`,
`lib/features/tier_selection/{domain/tier,cubit/tier_selection_state,data/tier_repository}.dart`,
`lib/features/location/presentation/widgets/delivery_create_layout.dart`,
`lib/features/request_summary/application/compose_request_controller.dart`, plus every test and
Maestro flow that names this screen.

> ⚠️ **This file is also screen 08.** `screen-repo-map.md` routes **08 Tier catalog** to
> `request_type_screen.dart` too. The 07 and 08 lanes edit the *same file*. See §9 C-07-D — they
> must be serialized, and 08's "Recommended pre-selected" collides with a test that guards 07.

---

## 0. What the design actually is

Five tier rows in one scannable list; the selected row is a **solid navy card with an orange check
disc**, the other four are **white cards with a 1.5px warm-brown outline**; Standard carries a
`Most picked` micro badge in a 12%-orange tint; below the list a **`Deliver to`** block with a
filled grey address card and an orange **`Change`** word; then **real empty space**; then a docked
navy `Continue` pill.

Measured from the HTML (all values verbatim):

| Element | HTML | Today |
|---|---|---|
| Top bar | in-body row, `padding 14/24/0`, gap 14, Ø40 `surface-high` circle + 20px navy glyph, title **20/w700 navy** = `Choose your request` (L15–18) | Material `OMDSAppBar` titled `Request`, plus a **second** 24px in-body heading `Choose your request` |
| Tier list | gap **9px**, rows `radius 16`, `padding 14/16`, gap 12 (L19–60) | gap 12, radius 16, padding 16, two description lines |
| Tier mark | **emoji 20px** ⚡🚀🟦🤝🌿 (L22/30/38/46/54) | `Icons.bolt_outlined` … `Icons.eco_outlined` |
| Tier title | 16/w700; white when selected, navy otherwise (L24/32) | `labelLarge` w700 |
| Tier subtitle | **one** ellipsized line 12/w500, `rgba(255,255,255,.7)` on navy / periwinkle otherwise (L25/33) | **two** lines (`speed` then `value`) |
| Selected row | `background: var(--jeeb-navy)` + `0 10 22 rgba(11,19,81,.28)` (L21) | navy fill, 1px navy border, **no shadow** |
| Unselected row | `border: 1.5px var(--jeeb-brown-outline)` `#916F66`, **no shadow** (L29) | `1px outlineVariant` `#E5E1E5` |
| Indicator | Ø22 pill. Selected = **orange fill + 13px white check** (L27). Unselected = **2px `surface-highest` ring, no dot** (L35) | Ø24 ring in `primary` navy + navy dot when selected |
| Badge | `Most picked`, pad `2/8`, r999, `rgba(215,59,0,.12)` fill, **10.5/w800 orange** ink (L40) | does not exist |
| Section label | `Deliver to`, **14/w700 navy** — *not* uppercase, *not* periwinkle (L63) | `Location`, `headlineSmall` 24/w800 navy |
| Address card | `margin-top 10`, `padding 14/16`, r16, fill `var(--jeeb-surface-high)`, gap 12; 20px `#E02020` pin; title 14.5/w700 navy ellipsized; sub 12/w500 periwinkle; trailing **13.5/w700 orange `Change`** (L64–71) | a bare `Row`: navy w700 label ↔ navy `Change Location` + chevron |
| Spacer | `<div style="flex:1">` (L73) — content ends at **61%** of the canvas | `ListView` fills the viewport |
| Footer | `padding 0/24/32`, h**56** pill, navy, white 17/w600, `0 10 24 rgba(11,19,81,.28)` (L74–75) | `OmdsPrimaryButton` in `20/16/20/32` padding, no shadow |

**The single biggest change is not a color — it is density.** The redesign gutter is 24 (today 20),
the tier rows lose a description line, the 24px heading disappears, and 39% of the screen is
deliberately blank. Under the new tokens with today's structure this screen will look exactly like
today's screen. Plan R1/R3/R12.

---

## 1. Layout & structure

### S1 — Delete the Material app bar; adopt `JeebTopBar` in-body
**Where:** `request_type_screen.dart:96-115` (`_Scaffold.build`), specifically `appBar:` at `:98-102`.

**Becomes:**
```dart
Scaffold(
  backgroundColor: Theme.of(context).colorScheme.surface,
  body: SafeArea(
    child: Semantics(
      identifier: 'request_type_root',
      container: true,
      explicitChildNodes: true,
      child: Column(children: [
        JeebTopBar(
          leading: JeebTopBarLeading.back,
          title: l10n.requestTypeChooseHeading,
          identifier: 'request_type_back',
          onLeadingPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(child: BlocBuilder<TierSelectionCubit, TierSelectionState>(...)),
      ]),
    ),
  ),
  bottomNavigationBar: ...,
)
```
`OMDSAppBar` and the `omds.dart` `OMDSAppBar` import go. The back handler is preserved verbatim
(`Navigator.of(context).maybePop()`).

**Design evidence:** HTML L15–18 is a plain flex row inside the body — 40px circle, 14px gap, 20px
title. The render shows no Material bar, no elevation, no divider, no centred title. Plan §5 #1
`JeebTopBar(leading: back)`; 07 is listed as a consumer.

### S2 — Delete the in-body `Choose your request` heading
**Where:** `request_type_screen.dart:221-222` and the `_SectionHeading` class at `:273-289`.

The string appears **once** in the HTML (L17, in the top bar). Today it appears twice over: the app
bar says `Request` (`requestTypeTitle`) and the body repeats `Choose your request` at
`headlineSmall` (24px) w800. Both `_SectionHeading` call sites are replaced (this one deleted, the
`Deliver to` one re-typed in S6), so the class is deleted with them.

`requestTypeTitle` ("Request") loses its only call site. **Leave the arb key in place** — deleting a
key is an integrator/parity-gate action with no benefit here.

### S3 — Body becomes `scroll → column → flex:1 spacer`
**Where:** `_LoadedView.build`, `request_type_screen.dart:216-230`.

`ListView` → `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)` holding a `Column`
whose last-but-one child is a `Spacer()`:

```dart
CustomScrollView(
  slivers: [
    SliverPadding(
      padding: _bodyPadding,                 // 24 / 20 / 24 / 0  (see below)
      sliver: SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TierList(state: state),
            const SizedBox(height: Spacing.large),      // 20  (HTML 22)
            _DeliverToLabel(),
            const SizedBox(height: Spacing.small),      // 12  (HTML 10)
            _LocationSection(onChangeLocation: onChangeLocation),
            const Spacer(),
          ],
        ),
      ),
    ),
  ],
)
```

`SliverFillRemaining(hasScrollBody: false)` is the exact idiom that gives the design's `flex:1`
emptiness on a tall device **and** still scrolls on a short device or at 200% text scale (a DoD
item). A plain `Column` would overflow; a plain `ListView` cannot produce the spacer.

**Design evidence:** HTML L73 `<div style="flex:1"></div>`; the render's content stops at y≈1170 of
1912 (61%) and the remaining 39% is plain white. Plan §3 "The spacer is real emptiness … never let a
list expand into it", R1.

**Padding:** `DeliveryCreateLayout.pagePadding` (`20/16/20/32`) is **owned by the `location/` feature
and shared with `client_location_screen.dart:350,725`** — the 09 lane's file. Do **not** edit it.
Declare two screen-local consts in `request_type_screen.dart`:
```dart
const _bodyPadding =
    EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.large, Spacing.xLarge, 0);
const _footerPadding =
    EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge);
```
(`Spacing.xLarge` = 24 = the design gutter; `Spacing.twoXLarge` = 32 = the design footer inset.)
Promoting these into `DeliveryCreateLayout` is a sensible integration follow-up once the 09 lane has
also moved to a 24 gutter — see §10.

### S4 — Tier list rhythm
**Where:** `_TierList`, `request_type_screen.dart:291-311`.

`SizedBox(height: Spacing.small)` (12) → `SizedBox(height: Spacing.xSmall)` (8). HTML L19
`gap: 9px`; 8 is the nearest token and 9–12 is the measured board range (R12). Everything else in
`_TierList` is unchanged — same order, same `state.tiers`, same `selectedTierId` comparison.

### S5 — `RequestTierCard` → `JeebTierRow.compact`
**Where:** `_TierEntry.build`, `request_type_screen.dart:322-344`; delete
`lib/features/request_type/presentation/request_tier_card.dart` entirely.

```dart
JeebTierRow.compact(
  mark: _tierMark(tier.id),                 // emoji String, see S6
  title: copy.title,
  summary: copy.summary,                    // ONE line now
  badge: tier.recommended ? l10n.requestTypeMostPickedBadge : null,
  selected: selected,
  identifier: requestTypeRadioId(tier.id),  // unchanged
  semanticLabel: l10n.requestTypeTierSummarySemanticLabel(
    title: copy.title, summary: copy.summary),
  selectedHint: l10n.requestTypeTierSelectedHint,
  onTap: () => context.read<TierSelectionCubit>().selectTier(tier.id),
)
```

`JeebTierRow.compact` must reproduce `RequestTierCard`'s a11y node **byte for byte** — it is what
two tests read:
```dart
Semantics(
  identifier: identifier,
  inMutuallyExclusiveGroup: true,
  checked: selected,
  label: semanticLabel,
  hint: selected ? selectedHint : null,
  button: true,
  child: ExcludeSemantics(child: /* Material + InkWell */),
)
```
See §7 wiring request W-2.

Internals per HTML (the kit owns the exact px — `lib/core/widgets/jeeb/` is exempt from
`tool/check_design_tokens.sh`):
- container r16, pad `14/16`, gap 12;
- selected → `colorScheme.primary` fill + `JeebShadows.ctaNavy` (`0 10 24 rgba(11,19,81,.28)`,
  the ramp's nearest to the HTML's `0 10 22`), **no border**;
- unselected → `colorScheme.surface` fill + `1.5px colorScheme.outline` (`#916F66`), **no shadow**
  (R7: a white card with a shadow does not exist on this board);
- title `context.jeebText.cardTitle` (15.5/w700) in `onPrimary` / `primary`;
- summary `context.jeebText.bodySmall` (12/w600) in `onPrimary.withValues(alpha: .7)` /
  `JeebSemanticColors.mutedText`, `maxLines: 1`, `TextOverflow.ellipsis`.

### S6 — Emoji tier marks replace the vector icons
**Where:** `_tierIcon`, `request_type_screen.dart:358-364`.

```dart
/// Emoji tier lexicon — load-bearing per the DS (07 HTML L22/30/38/46/54).
static String _tierMark(TierId id) => switch (id) {
      TierId.flash => '⚡',
      TierId.express => '🚀',
      TierId.standard => '🟦',
      TierId.onTheWay => '🤝',
      TierId.eco => '🌿',
    };
```
Kept in this file, not in the kit: `lib/core/widgets/jeeb/` must not import `lib/features`, and
`TierId` lives in `features/tier_selection/domain`. The 08 catalog section reuses this map.

**Design evidence:** HTML L22 etc.; plan R10 "Tier marks are **emoji at 17px**, never icons".
**Risk (plan §9-7):** 🟦 is a cross-platform rendering gamble. If it renders badly on the S22,
substitute a rounded-square glyph tinted `JeebTierColors.standard()` — decided once, here, for both
07 and 08.

### S7 — `Deliver to` section
**Where:** `request_type_screen.dart:225-227` and `request_location_row.dart`.

Label: a **navy 14/w700 non-uppercase** line. **Do NOT use `JeebSectionLabel`** — that widget is
uppercase / ls 1.2 / `mutedText` / 12.5px, which the 07 board does not draw anywhere (HTML L63 is
`font-size:14px; font-weight:700; color: var(--jeeb-navy)`). Nearest ramp entry:
```dart
Text(l10n.requestTypeLocationHeading,
     style: context.jeebText.cardTitle.copyWith(color: cs.primary))
```
(15.5/w700 vs the design's 14/w700 — within the ±1.5px tolerance the plan accepts for `sectionLabel`
in §4.2; no new ramp entry.)

Card: `RequestLocationRow` is rebuilt as the filled card, **keeping its existing constructor
signature source-compatible** (see §8 T-9):

```dart
class RequestLocationRow extends StatelessWidget {
  const RequestLocationRow({
    super.key,
    required this.currentLabel,   // unchanged — primary line + a11y fallback
    required this.changeLabel,    // unchanged — the a11y label ("Change Location")
    required this.onChange,       // unchanged
    this.addressLabel,            // NEW, optional — the resolved destination
    this.qualifierLabel,          // NEW, optional — the second line
    this.changeCtaLabel,          // NEW, optional — the visible word ("Change")
  });
```

Rendered as a `Container` → `surfaceContainerHigh` fill, `OmdsBorderRadius.medium` (16),
`EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: Spacing.medium)`, a `Row` of:
1. 20px pin glyph (`Icons.location_on`) — see §9 C-07-E for the colour decision;
2. `SizedBox(width: Spacing.small)` (12);
3. `Expanded` column: primary line `context.jeebText.cardTitle` navy, `maxLines: 1`,
   `TextOverflow.ellipsis` — **this node keeps `identifier: 'request_type_current_location_label'`**;
   optional second line `context.jeebText.bodySmall` in `mutedText`;
4. the `Change` action — `Semantics(identifier: 'request_type_change_location_button', button: true,
   label: changeLabel)` wrapping an `InkWell` whose child is a `Text(changeCtaLabel ?? changeLabel,
   style: context.jeebText.body.copyWith(fontWeight: FontWeight.w700, color: context.jeebRoles.accent))`.

The trailing **chevron is deleted** (`DirectionalIcons.disclosure` at `request_location_row.dart:108`)
— HTML L70 is a bare orange word. `explicitChildNodes: true` on the outer `Semantics` stays; it is
the only reason both inner identifiers survive the ambient merge (see the comment at
`request_location_row.dart:24-28` and `semantics_identifier_surfacing_test.dart:279-299`).

**What data feeds the primary line:** nothing at this step — see §5.

### S8 — Footer
**Where:** `_ContinueFooter.build`, `request_type_screen.dart:135-150`.

- padding `DeliveryCreateLayout.pagePadding` → `_footerPadding` (`0/24/32`, HTML L74);
- `OmdsPrimaryButton` → `JeebCtaButton.primary` — h56, `OmdsBorderRadius.pill`, `colorScheme.primary`
  fill, white `context.jeebText.button` (17/w600), `JeebShadows.ctaNavy` (HTML L75);
- **keep `key: const Key('request-type-continue')`** and the
  `Semantics(identifier: 'request_type_continue_cta', button: true)` wrapper exactly as they are
  (`:139-148`);
- keep `isEnabled: hasSelection` and keep `_onContinue` (`:153-170`) **untouched** — the
  `ComposeRequestController.setTier` write and `context.pushNamed('client-location')` are the
  iter6 B11 fix and JM-024 AC1; nothing in the redesign touches them;
- keep the `state.status != loaded → SizedBox.shrink()` guard at `:130-132` (the design does not draw
  a loading state; floating a disabled CTA over the spinner is worse, and every Maestro flow reaches
  the CTA through `extendedWaitUntil`).

---

## 2. Tokens — every literal that changes

Nothing in these files is a raw hex today (the screens are already token-clean); what changes is
*which* token, plus the new Wave-0 ramps.

| Where (file:line) | Today | Becomes | Why |
|---|---|---|---|
| `request_type_screen.dart:283-287` `_SectionHeading` | `textTheme.headlineSmall` + `w800` + `primary` | **deleted** (S2) / `context.jeebText.cardTitle` + `primary` (S7) | HTML L63 = 14/w700, not 24/w800 |
| `request_type_screen.dart:222,224,226` | `Spacing.medium` / `Spacing.twoXLarge` | `Spacing.large` (20) / `Spacing.small` (12) | HTML L62 `22px`, L64 `margin-top:10` — nothing on this board is spaced at 32 (R12) |
| `request_type_screen.dart:306` | `Spacing.small` (12) | `Spacing.xSmall` (8) | HTML L19 `gap: 9px` |
| `request_type_screen.dart:138,219` | `DeliveryCreateLayout.pagePadding` (20/16/20/32) | `_footerPadding` (0/24/32) / `_bodyPadding` (24/20/24/0) | HTML L74 & L19; design gutter is 24 |
| `request_tier_card.dart:59,61,75` | `OmdsBorderRadius.uiLarge` (16) | `OmdsBorderRadius.medium` (16) inside the kit | same value; the kit uses the design-exact 16 |
| `request_tier_card.dart:71` | `selected ? primary : outlineVariant`, width 1 | selected → **no border**; unselected → `colorScheme.outline` **1.5px** | HTML L29 `1.5px var(--jeeb-brown-outline)` `#916F66` = `colorScheme.outline` |
| `request_tier_card.dart` (no shadow today) | — | `JeebShadows.ctaNavy` on the **selected** row only | HTML L21 `0 10 22 rgba(11,19,81,.28)` |
| `request_tier_card.dart:120-123` title | `textTheme.labelLarge` + `w700` | `context.jeebText.cardTitle` (15.5/w700) | §4.6 ramp |
| `request_tier_card.dart:113-114` two lines | `textTheme.bodySmall` ×2 | **one** `context.jeebText.bodySmall` (12/w600) | HTML L25 — a single ellipsized line |
| `request_tier_card.dart:99` desc colour | `selected ? onPrimary : onSecondaryContainer` | `selected ? onPrimary.withValues(alpha: .7) : JeebSemanticColors.mutedText` | HTML L25 `rgba(255,255,255,.7)`; the `.7` lives inside the kit widget, never in the feature file |
| `selectable_radio_glyph.dart:25` | ring = `selected ? onPrimary : primary` | kit indicator: unselected ring `colorScheme.surfaceContainerHighest` 2px; selected disc `context.jeebRoles.accent` + `Icons.check` in `onAccent` | HTML L27 & L35 |
| badge (new) | — | fill `JeebSemanticColors.accentTint`, ink `context.jeebRoles.accent`, `context.jeebText.badge` (10.5/w800), `OmdsBorderRadius.pill` | HTML L40 `rgba(215,59,0,.12)` — plan §4.1 records this as **the one legitimate `accentTint` use board-wide** |
| `request_location_row.dart` (no fill today) | — | `colorScheme.surfaceContainerHigh` + `OmdsBorderRadius.medium` | HTML L64 `var(--jeeb-surface-high)` `#EAE7EB`, r16 |
| `request_location_row.dart:55-58,94-97` | `textTheme.labelLarge` + `primary` | `context.jeebText.cardTitle` (primary) / `context.jeebText.bodySmall` (`mutedText`) | HTML L67–68 |
| `request_location_row.dart:97,109` `Change` ink | `scheme.primary` navy | `context.jeebRoles.accent` `#D73B00` | HTML L70 — orange marks the escape hatch |
| footer button | `OmdsPrimaryButton` defaults | h56 `OmdsBorderRadius.pill` + `context.jeebText.button` + `JeebShadows.ctaNavy` | HTML L75 |

Not tokenised, deliberately: the `#E02020` pin (§9 C-07-E) and the emoji marks (a product lexicon,
not colour).

---

## 3. Shared components consumed

| Kit widget (plan §5) | Replaces | Notes |
|---|---|---|
| **#1 `JeebTopBar`** (`leading: back`) | `OMDSAppBar` at `:98-102` | owns the new `request_type_back` identifier |
| **#2 `JeebCtaButton.primary` / `JeebCtaFooter.single`** | `OmdsPrimaryButton` at `:142-147` | **must forward `key:` and expose `isEnabled`** — see W-1 |
| **#8 `JeebTierRow.compact`** | the whole of `request_tier_card.dart` + `selectable_radio_glyph.dart`'s use here | the a11y node must be identical — W-2 |
| **#3 `JeebOutlinedCard` / #4 `JeebNavySurfaceCard`** | — | consumed *transitively*, inside `JeebTierRow.compact`; 07 never instantiates them directly (selection is one state machine, plan §5.1 step 1) |

**`SelectableRadioGlyph` stays in the tree, untouched.** It is also consumed by the client-location
option cards (`location/` — the 09 lane). Retiring it is not this lane's call; 07 simply stops
importing it.

### Components the plan lists for 07 that 07 must NOT get
- **#21 `JeebPriceMeter`.** Plan §5 #21 and `02-PLAN-ENHANCED.md` §3.2 both name 07 as a consumer.
  **The 07 render and HTML contain zero price-meter dots** — the price signal on 07 is the words
  inside the one-line summary ("Highest price", "Balanced price"). The meter belongs to the **08**
  catalog rows, which land in the same file through the 08 lane. Refused for the 07 list. See §9 C-07-G.
- **#10 `JeebSectionLabel`.** Wrong type for `Deliver to` — see S7.
- **#22 `JeebInfoNote`.** 08 has the "Jeebers set the price" note; 07 does not. Do not add it here.

---

## 4. New functionality

Almost none — and that is the honest read of this screen. The designer note claims two things:

1. *"speed + price value on every row"* — already true; it is being **compressed** from two lines to
   one, not added. Copy work (§6), not behaviour.
2. *"the delivery location is confirmed on the same step with a one-tap Change"* — this is the one
   genuinely new idea, and it is **data-blocked at this step**. See §5.

Everything else (`Most picked`) is a **badge over an existing flag**, not new behaviour:
`Tier.recommended` already exists (`tier.dart:53`) and is already parsed
(`tier_repository.dart:100`). It has **zero live consumers today** — its only reader is the dead
`tier_selection_screen.dart:285`. Rendering the badge from it costs nothing at the cubit/state layer.

**No change is required to `TierSelectionCubit`, `TierSelectionState`, `TierRepository`, `Tier`,
`ComposeRequestController` or `app_router.dart`.**

---

## 5. The data gap: what the `Deliver to` card can honestly say

**Finding: at `/request-type` the app does not know the destination.** The destination is chosen on
the *next* screen (`/client-location`, `LocationSelectCubit`). There is no field, on any object this
screen can reach, that yields `Home — Achrafieh, Beirut`.

**D0 — what to build now (in scope, zero risk).** Render the card with
`addressLabel: null, qualifierLabel: null`, so the primary line falls back to
`l10n.requestTypeCurrentLocation` ("Current Location") — today's exact meaning and today's exact
identifier placement — and add, at the `_LocationSection` call site:

```dart
// TODO(redesign-24): needs a resolved destination label at this step; the flow
// picks the destination on the NEXT screen. Omitted, not faked (JEBV4-176).
```

**D1 — the enrichment path, if the owner wants the board's literal card (OWNER DECISION).** It is
buildable from **existing** endpoints, no invention:
`LocationSelectRepository.fetchSavedAddresses(userId)` → the `isDefault` `SavedLocation` →
`'${label} — ${address}'` (`saved_location.dart:37-42,46` — `label`, `address`, `isDefault` all
exist, and the mock seeds `Home` as default). Cost, stated plainly:
- a `userId` resolution (`AuthTokenStore.userId`, the `FutureBuilder` idiom at
  `client_location_screen.dart:170-212`);
- `LocationSelectRepository` is **not** DI-registered — the 09 screen resolves it through a
  `_resolveRepository()` ladder (`client_location_screen.dart:139-151`); 07 would need the same
  ladder or a DI registration (integrator-owned file);
- one extra GET on a screen that has none today. It must be **non-blocking** — render D0
  immediately and upgrade in place; never a spinner (the design has no loading state).

**D2 — refused.** Deriving the line from GPS (`CurrentLocationResolver.resolve()` →
`LocationRepository.reverseGeocode()`) would move the **location-permission prompt** from
`/client-location` onto `/request-type`. That is a permissions-UX change, not a restyle. Do not do
it inside this migration.

Note the board's own card is internally inconsistent: `Home — Achrafieh, Beirut` is a *saved-address*
shape while the qualifier says `Current location` (a GPS shape). Under D1 the qualifier must become
the address category, not "Current location".

---

## 6. l10n

Integrator-owned, append-only batch (`app_en.arb` + real `app_ar.arb` + getter + call site — the
parity gate fails both directions).

**New keys (8):**

| Key | EN | Notes |
|---|---|---|
| `tierFlashSummary` | `Under 1 hour · Highest price · Priority pickup` | HTML L25 |
| `tierExpressSummary` | `1–2 hours · Higher price · Fast pickup` | HTML L33 |
| `tierStandardSummary` | `2–4 hours · Balanced price` | HTML L41 |
| `tierOnTheWaySummary` | `Someone already heading there · Lower price` | HTML L49 |
| `tierEcoSummary` | `Today, no rush · Lowest price · Greenest` | HTML L57 |
| `requestTypeMostPickedBadge` | `Most picked` | HTML L40 — see §9 C-07-B before shipping this wording |
| `requestTypeChangeCta` | `Change` | HTML L70 — the **visible** word |
| `requestTypeTierSummarySemanticLabel` | `{title}. {summary}.` | replaces the 3-arg label for this screen |

**Value change (1):** `requestTypeLocationHeading` `Location` → `Deliver to` (AR: `التوصيل إلى`);
update its `@description`.

**Kept, re-purposed, value unchanged:**
- `requestTypeChooseHeading` → now the **top-bar title** (was the in-body heading).
- `requestTypeChangeLocation` ("Change Location") → now the **Semantics label only**, so the a11y
  announcement stays descriptive while the visible word shortens to `Change`. This is the reason
  `changeLabel` stays a required param (§8 T-9).
- `requestTypeCurrentLocation` → the primary-line fallback (D0).
- `requestTypeTierSelectedHint`, `requestTypeContinue` → unchanged.

**Kept but now unused by this screen (do NOT delete):** `requestTypeTitle`, and the ten
`tier<X>Speed` / `tier<X>Value` keys plus `requestTypeTierSemanticLabel` — still referenced by the
`tier_selection` devtool catalog surface. Removing arb keys is an integrator action with a parity
gate and no upside here.

`·` (U+00B7) inside the summary strings is part of the localized string, so the AR translator
supplies their own separator — never build the summary by concatenating in Dart.

---

## 7. Semantics identifiers

**Inventory that MUST survive (8 + 1 key):**

| Identifier | Today | After |
|---|---|---|
| `request_type_flash_radio` | `request_tier_card.dart:50` via `requestTypeRadioId` | `JeebTierRow.compact.identifier` — value unchanged |
| `request_type_express_radio` | ″ | ″ |
| `request_type_standard_radio` | ″ | ″ |
| `request_type_on_the_way_radio` | ″ | ″ |
| `request_type_eco_radio` | ″ | ″ |
| `request_type_continue_cta` | `request_type_screen.dart:140` | unchanged wrapper around `JeebCtaButton` |
| `request_type_current_location_label` | `request_location_row.dart:52` | moves onto the card's **primary line** |
| `request_type_change_location_button` | `request_location_row.dart:74` | unchanged, on the `Change` word |
| `Key('request-type-continue')` | `request_type_screen.dart:143` | must be forwarded through `JeebCtaButton` |

`requestTypeRadioId()` (`request_type_radio_id.dart`) is untouched — it is the contract
(`on-the-way → on_the_way`) that six Maestro flows assert.

**New identifiers proposed (`<screen>_<element>`):**
- `request_type_back` — the top-bar back circle. **New affordance for test drivers**: today's
  `OMDSAppBar` back button carries no identifier at all.
- `request_type_root` — the screen root (`container: true, explicitChildNodes: true`, the
  `active_request_card.dart` idiom, so it does not swallow the eight nested ids).
- `request_type_most_picked_badge` — non-interactive, but it gives Maestro a locale-invariant way to
  assert the badge rendered (same precedent as `request_type_current_location_label`).

---

## 8. Test impact

Nine touch points. Seven are legitimate design changes; two are hard constraints on the kit.

| # | Test | Effect | Verdict |
|---|---|---|---|
| T-1 | `delivery_create_screens_test.dart:15` imports `request_tier_card.dart`; `:93` `find.byType(RequestTierCard) findsNWidgets(5)` | **compile break** once the file is deleted | legitimate — retarget to `find.byType(JeebTierRow)` |
| T-2 | `:96-97` `find.byIcon(Icons.bolt_outlined)` / `Icons.eco_outlined` | fails — icons become emoji | legitimate (R10). Replace with `find.text('⚡')` / `find.text('🌿')` |
| T-3 | `:99` `find.text('Choose your request')` | **passes** — the string moves to the top bar | no change |
| T-4 | `:100` `find.text('Location')` | fails — copy is `Deliver to` | legitimate |
| T-5 | `:101,152` `find.text('Change Location')` | fails — the visible word is `Change`; the old string survives only as the Semantics label | legitimate. Retarget the tap to `find.bySemanticsIdentifier('request_type_change_location_button')` — which is what Maestro already does |
| T-6 | `:168` AR `find.text('تغيير الموقع')` | same as T-5 | legitimate — retarget to the new AR value of `requestTypeChangeCta` |
| T-7 | `request_type_deliberate_selection_test.dart:40-50,56-59,70-78` — `isChecked` on all five radios, `CheckedState.isFalse` on first paint | **must keep passing unchanged** | this is the guard on C-07-A. If it fails, the proposal is wrong, not the test |
| T-8 | `request_type_deliberate_selection_test.dart:92-93` `tester.widget<OmdsPrimaryButton>(find.byKey(Key('request-type-continue'))).isEnabled` | passes **iff** `JeebCtaButton` composes `OmdsPrimaryButton` and forwards the key (W-1); otherwise a one-line type swap | legitimate either way; W-1 is cheaper |
| T-9 | `semantics_identifier_surfacing_test.dart:34,125-150` constructs `RequestLocationRow(currentLabel:, changeLabel:, onChange:)` directly | **compile break if those three params change** | not legitimate — keep them required and add only optional params (S7) |

`request_type_continue_navigation_test.dart` — unaffected; it drives the real router by identifier
only.

**Maestro (not in CI — silent rot risk):** `jm-024`, `jm-023`, `jm-025`, `jm-026`, `jm-049`,
`08-request-empty-state` all address the surviving identifiers and are unaffected.
`09-request-type-client.yaml` asserts `request_type_tier_flash` / `_tier_onTheWay` — **identifiers
that no longer exist in source** (they were renamed to `request_type_<tier>_radio` before this
migration). That flow is already broken; **do not "fix" it as part of this lane** — flag it.

No goldens exist for this screen (the committed goldens are 18 and the 24-sheet).

---

## 9. Conflicts and refusals

**C-07-A — REFUSED: the render's pre-selected Flash.** The PNG shows Flash solid navy with the
orange check on first paint, and the designer note says "selected tier snaps to solid navy".
`request_type_deliberate_selection_test.dart:40-50` pins the opposite: *every* tier reports
`CheckedState.isFalse` on first paint and Continue is disabled until a deliberate tap. **Build
nothing pre-selected.** The render is depicting the post-tap state. (This is also why
`Tier.recommended` may drive a *badge* but must never drive `selectedTierId` — `tier.dart:5-8` says
so in as many words: "That flag never selects a tier on the customer's behalf.")
⚠️ **This directly contradicts 08's designer note — "Recommended pre-selected" — and 08 is the same
file.** The 08 lane must be told: it is refused there too, by this same test.

**C-07-B — OWNER DECISION: `Most picked` is a claim with no data behind it.** `GET /tiers` carries
no popularity or recommendation field; `DioTierRepository:100` synthesises
`recommended: id == TierId.flash` **client-side**, and `FakeTierRepository:189` flags Flash too. The
board draws the badge on **Standard** (07 `Most picked`, 08 `Recommended`). Three positions:
- **Build:** render the badge from `tier.recommended` — never hardcode `TierId.standard`. Zero
  invention.
- **Placement:** to match the board it needs `recommended` flipped Flash → Standard in
  `tier_selection/data/tier_repository.dart` (both the Dio synthesis and the fake catalog). That is
  a **client-side constant edit in another lane's directory** — a wiring request, not a fabrication.
- **Wording:** "Most picked" asserts popularity we do not measure. The conservative alternative is
  08's word, `Recommended` (the key `tierSelectionRecommendedBadge` already exists). Recommend
  shipping the board's `Most picked` only if the owner accepts it as editorial copy.

**C-07-C — data gap: the `Deliver to` address.** See §5. Build D0 with a `TODO(redesign-24)`; D1 is
an owner decision with real cost; D2 is refused.

**C-07-D — file collision: 07 and 08 are the same file.** `screen-repo-map.md` routes 08 to
`request_type_screen.dart` ("the live tier picker is a section of it") while
`00-MIGRATION-PLAN.md` §6/Wave-3 additionally proposes a **new `/tier-catalog` route** for 08. The
two documents do not agree, and either way both lanes edit this file. Proposed ownership split:
07 owns the screen shell (top bar, body structure, spacer, `Deliver to`, footer) and the
`.compact` row; 08 owns only the catalog section/route it adds. **Serialize; do not run them in
parallel.** Related: **07's render draws no "Compare tiers" affordance**, so the plan's stated entry
point into `/tier-catalog` does not exist on this board. Do not invent one — raise it (§10 W-4).

**C-07-E — the `#E02020` pin.** Plan §4.1 explicitly says this red is *not* a token ("existing marker
assets"), and `tool/check_design_tokens.sh` bans `Color(0xFF…)` in `lib/features`. Options:
(a) render `Icons.location_on` in `colorScheme.primary` navy — consistent with R10 ("icons: filled,
single-colour, navy or periwinkle") and shippable today; (b) keep the literal red, which then must
live inside a `lib/core/widgets/jeeb/` widget (gate-exempt). **Recommend (a)**; this card is an
address row, not a map marker. Flag the divergence in the lane notes.

**C-07-F — plan §5 #8 describes the indicator backwards.** It says selected = "solid navy + orange
check (check ink `jeebRoles.accent` on white disc)". The HTML (L27) is the inverse: the **disc is
`var(--jeeb-orange)`** and the **check svg is `fill="#fff"`**. The HTML wins (plan §3: "the screens,
not the token files, are pixel truth"). Build orange disc + white check.

**C-07-G — 07 is not a `JeebPriceMeter` consumer.** See §3. Refused for this screen; it belongs to
the 08 section.

**No conflict with:** `decision_violations_test.dart` (this screen touches none of D20/D41/D44/D52/
D56/B04 — there is no money figure, no commission, no rating, no chat composer on it), the pre-accept
cancel rule, or the deep-link guard. No backend contract is touched: no field is added, no endpoint
is called that is not called today (under D0).

---

## 10. Wiring requests (other lanes / integrator)

- **W-1 → Wave-1 kit lane (`JeebCtaButton`).** Accept and forward a `Key` and expose `isEnabled`;
  ideally compose `OmdsPrimaryButton` internally (it already takes `height`, `borderRadius`,
  `backgroundColor`, `textStyle`, `isEnabled`) wrapped in a `DecoratedBox` for `JeebShadows.ctaNavy`.
  That keeps `request_type_deliberate_selection_test.dart:92-93` compiling untouched.
- **W-2 → Wave-1 kit lane (`JeebTierRow.compact`).** Emit exactly
  `Semantics(identifier:, inMutuallyExclusiveGroup: true, checked:, label:, hint:, button: true)
  → ExcludeSemantics → Material/InkWell`. Two tests read `flagsCollection.isChecked` off that node.
  Also: `mark` is a `String` (emoji), **not** an `IconData` — the kit cannot import `TierId`.
- **W-3 → l10n integrator.** The 8 new keys + the one value change in §6, EN + real AR.
- **W-4 → owner / 08 lane.** (a) `Most picked` wording + whether `recommended` flips to Standard
  (C-07-B); (b) 07 draws no entry point to a `/tier-catalog` surface — decide catalog-as-section
  (per `screen-repo-map.md`) vs. a new route, before 08 starts (C-07-D); (c) 08's "Recommended
  pre-selected" is refused by 07's test (C-07-A).
- **W-5 → integration sweep.** `09-request-type-client.yaml` is already stale (asserts the
  pre-rename `request_type_tier_*` ids). Out of this lane's scope; needs an owner.
- **W-6 → 09 lane / integrator (optional).** Once `client_location_screen` also moves to a 24
  gutter, promote `_bodyPadding` / `_footerPadding` into `DeliveryCreateLayout`. Until then 07 keeps
  them screen-local — the 07 lane must not edit a file in `location/`.

## 11. Risks

1. **Density is the whole change.** Apply S3 (real spacer), S4 (8px gaps) and S2 (heading deleted) or
   the screen will look identical to today under new tokens. It is unreviewable in a diff — compare
   against the PNG at the same scale.
2. **Two lanes, one file (C-07-D).** The single highest-probability merge conflict in Wave 3.
3. **🟦 rendering** on the S22 (plan §9-7). Decide once, here, for 07 and 08.
4. **`SliverFillRemaining(hasScrollBody: false)`** must be verified at 200% text scale and in `ar` —
   it is the one structural construct in this proposal that can overflow.
5. **Emoji + RTL.** The mark sits in the Row's start slot and mirrors automatically; but verify the
   AR summary strings do not force-LTR around the `·` separators.
6. **`w800` is not real** (plan §4.6): the `Most picked` badge at `jeebText.badge` (10.5/w800) will
   render at the bundled w700 until an ExtraBold face ships. Do not add a pubspec font entry.

## 12. RTL

Everything mirrors by construction if these rules hold:
- Every gap uses `SizedBox` in a `Row`/`Column` or `EdgeInsetsDirectional` — **no `EdgeInsets.only(left:)`, no `Alignment.centerLeft`**. The screen is already clean here (`request_tier_card.dart:73`, `request_location_row.dart:99-102`).
- The back glyph is `DirectionalIcons.back(context)`, owned by `JeebTopBar`.
- The trailing radio/check and the `Change` word are the last children of their `Row`s → they land at
  the end edge under both directions automatically.
- The `Most picked` badge follows the title inside the same `Row` with a `SizedBox` gap — never a
  left-padded absolute.
- `Icons.check` and `Icons.location_on` are direction-neutral; the deleted
  `DirectionalIcons.disclosure` was the only directional glyph in the location row.
- No digits, money or LTR-only tokens appear on this screen, so no `Directionality`/LTR isolate is
  needed anywhere.
- `TextOverflow.ellipsis` on the tier summary and the address line truncates at the correct edge in
  RTL without extra work.
- Regression cover already exists: `delivery_create_screens_test.dart:160-170` renders the whole
  screen under `Locale('ar')` and asserts `Directionality.of(...) == TextDirection.rtl`.
