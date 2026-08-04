# 07 · Request type — REVISED instruction set (authoritative)

Verdict: **rebuild** (presentation only). Cubit, repository, routing, and every navigation edge
are unchanged. This revision was produced by independently re-reading the render, the HTML, the
note, `request_type_screen.dart`, `request_tier_card.dart`, `request_location_row.dart`,
`selectable_radio_glyph.dart`, `delivery_create_layout.dart`, both plans, the arb, the three test
files, and the Maestro flows. The original proposal was substantially correct; the deltas below
are binding.

## Revision deltas vs the original proposal

**CUT (do not build):**
- `request_type_root` identifier. No test, Maestro flow, or design element demands it. Wrapping
  the screen in a new `Semantics(container: true)` node risks perturbing the merge behavior around
  the eight frozen identifiers for zero benefit. The screen ships with no root Semantics wrapper.
- `request_type_most_picked_badge` identifier. **Unbuildable as specced**: the badge renders
  inside `JeebTierRow`'s mandatory `Semantics → ExcludeSemantics → …` structure, so any identifier
  inside it is excluded from the semantics tree and can never surface. Tests assert the badge via
  `find.text(...)` instead.

**CORRECTED:**
- `delivery_create_screens_test.dart` line citations: icons are at **:98-99** (not :96-97),
  `Choose your request` at **:100**, `Location` at **:101**, `Change Location` at **:102** and the
  tap at **:153-155**, AR `تغيير الموقع` at **:170**. Line **:167** (AR heading `اختر نوع طلبك`)
  keeps passing — the string moves to the top bar. Substance of T-1…T-9 was correct.
- Emoji size citation: the `.compact` mark is **20px** (HTML tpl-357 `font-size: 20px`; plan §5 #8
  says 20px for `.compact`, 17px is the `.catalog` size). The kit owns the px either way.
- `02-PLAN-ENHANCED.md` explicitly lists 07 as a `JeebPriceMeter` consumer ("08 (+07)", L143/L155).
  The refusal stands — the 07 HTML/render contain zero meter dots — but it is a **documented
  divergence from the plan**, so it is flagged to the kit lane in the wiring file (W-2), not
  silently dropped.

**VERIFIED AND KEPT** (spot-check confirmed, byte for byte where it matters):
- All `request_type_screen.dart` citations: appBar :98-102, duplicate heading :221-222,
  `_SectionHeading` :273-289, `_LoadedView.build` :215-231, tier gap :306, `_TierEntry.build`
  :322-344, `_tierIcon` :358-364, `_RequestTierCopy` :369-391, footer Key :143, CTA identifier
  :140, loading guard :130-132, `_onContinue` :153-170.
- HTML measurements (top bar 14/24/0 + Ø40 circle + 20/w700 title; list gap 9; rows r16 pad 14/16
  gap 12; selected navy + `0 10 22 rgba(11,19,81,.28)`; unselected `1.5px var(--jeeb-brown-outline)`
  no shadow; indicator Ø22 **orange disc + white 13px check** when selected, 2px
  `surface-highest` ring otherwise; badge `2/8` r999 `rgba(215,59,0,.12)` + 10.5/w800 orange;
  `Deliver to` 14/w700 navy at 22px top inset; address card `surface-high` r16 pad 14/16 with red
  `#E02020` pin and 13.5/w700 orange `Change`; `flex:1` spacer; footer `0/24/32` h56 pill
  17/w600 + `0 10 24` shadow).
- Wave-0 tokens exist in-tree: `context.jeebText.{h2 20/700, cardTitle 15.5/700, bodySmall 12/600,
  badge 10.5/800, button 17/600}`, `JeebShadows.ctaNavy`, `JeebSemanticColors.{mutedText,
  accentTint}`, `context.jeebRoles.accent` `#D73B00`.
- `Tier.recommended` exists (`tier.dart:53`), synthesized client-side as Flash in both
  `tier_repository.dart:100` and the fake (:189); its only live reader is dead code
  (`tier_selection_screen.dart:285`). Rendering the badge from it invents nothing.
- Five l10n keys (`requestTypeTitle/ChooseHeading/LocationHeading/CurrentLocation/ChangeLocation`)
  have **no call site outside this screen** — the `requestTypeLocationHeading` value change
  ripples nowhere.
- `selectable_radio_glyph.dart` is imported by
  `location/presentation/widgets/client_location_option_card.dart` — it MUST stay in the tree.
- `decision_violations_test.dart` contains zero references to this screen. No locked decision
  (D20/D41/D44/D52/D56/B04) is in play.
- The stale Maestro flow `09-request-type-client.yaml` asserts pre-rename ids
  (`request_type_tier_flash` :80, `request_type_tier_onTheWay` :90) — already broken before this
  lane; do not touch it.
- All refusals stand: **C-07-A** (no pre-selection — `request_type_deliberate_selection_test.dart`
  :40-50 pins unchecked-on-first-paint + disabled Continue; the render depicts the post-tap
  state), **C-07-F** (HTML wins over plan §5 #8: orange disc + white check), **C-07-G** (no price
  meter on 07), **D2** (no GPS/reverse-geocode — it would move the permission prompt onto this
  screen).

---

## Blocking preconditions

1. **The kit does not exist yet.** `lib/core/widgets/jeeb/` is absent from the tree. Tasks 3–9
   compile only after the Wave-1 kit lane delivers `JeebTopBar`, `JeebCtaButton`, and
   `JeebTierRow.compact` per the contracts in W-1/W-2/W-3 below. Write the wiring file (Task 1)
   first; do not start Task 3+ until the kit widgets are importable.
2. **The l10n batch (W-4) must be applied by the integrator** before the screen compiles
   (`l10n.tierFlashSummary` etc.). Write the code as if granted.
3. **07 and 08 edit the same file.** Do not run concurrently with the 08 lane. 07 owns the screen
   shell + `.compact` rows; 08 owns only whatever catalog section/route it adds (C-07-D, W-5).

## Frozen inventory — must survive byte-identical

| Item | Where today |
|---|---|
| `request_type_flash_radio` … `request_type_eco_radio` (5, via `requestTypeRadioId`) | `request_tier_card.dart:50` |
| `request_type_continue_cta` | `request_type_screen.dart:140` |
| `request_type_current_location_label` | `request_location_row.dart:52` |
| `request_type_change_location_button` | `request_location_row.dart:74` |
| `Key('request-type-continue')` | `request_type_screen.dart:143` |
| Radio a11y node shape: `Semantics(identifier:, inMutuallyExclusiveGroup: true, checked:, label:, hint: selected ? hint : null, button: true) → ExcludeSemantics → Material/InkWell` | `request_tier_card.dart:49-67` |
| `RequestLocationRow(currentLabel:, changeLabel:, onChange:)` required params (constructed directly by `semantics_identifier_surfacing_test.dart:128-132`) | `request_location_row.dart:11-16` |
| `explicitChildNodes: true` boundary on the location row | `request_location_row.dart:29` |
| `_onContinue` body (ComposeRequestController.setTier + `pushNamed('client-location')`) | `request_type_screen.dart:153-170` |
| `_LocationSection._onChange` body (iter6 tier-carry fix) | `request_type_screen.dart:248-270` |
| `state.status != loaded → SizedBox.shrink()` footer guard | `request_type_screen.dart:130-132` |
| `requestTypeRadioId()` mapping (`on-the-way → on_the_way`) | `request_type_radio_id.dart` |

New identifier allowed: **`request_type_back`** on the kit top bar's back circle (new interactive
widget, `<screen>_<element>` convention). No other new identifiers.

---

## Tasks — execute in order

### Task 1 — Write the wiring file
Create `docs/redesign-2026-08/wiring/07-request-type.md` with the exact content of the
**Wiring requests** section at the bottom of this document. Then write all screen code as if
granted.

### Task 2 — Screen-local padding consts
In `request_type_screen.dart`, above `_Scaffold`, add:
```dart
// Design gutter is 24 (HTML `padding … 24px`); DeliveryCreateLayout.pagePadding
// (20/16/20/32) is owned by location/ and shared with the 09 lane — not edited.
const _bodyPadding =
    EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.large, Spacing.xLarge, 0);
const _footerPadding =
    EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge);
```
Remove the now-unused `delivery_create_layout.dart` import once Tasks 4 and 8 land. Do NOT edit
`DeliveryCreateLayout` (`location/` feature — 09 lane).

### Task 3 — Replace the app bar (S1)
`_Scaffold.build` (:96-115): drop `appBar: OMDSAppBar(...)`. Body becomes:
```dart
body: SafeArea(
  child: Column(children: [
    JeebTopBar(
      leading: JeebTopBarLeading.back,
      title: l10n.requestTypeChooseHeading,
      identifier: 'request_type_back',
      onLeadingPressed: () => Navigator.of(context).maybePop(),
    ),
    Expanded(
      child: BlocBuilder<TierSelectionCubit, TierSelectionState>(
        builder: (context, state) =>
            _Body(state: state, onChangeLocation: onChangeLocation),
      ),
    ),
  ]),
),
```
The back handler is preserved verbatim. `bottomNavigationBar` stays exactly where it is. Loading/
error states (`OmdsLoadingState` / `OmdsErrorState`, :186-196) are untouched — they now center
under the top bar, which is fine; the design draws no loading state. No root Semantics wrapper
(cut — see deltas).

### Task 4 — Body structure: real spacer (S2 + S3)
`_LoadedView.build` (:215-231): delete `_SectionHeading(text: l10n.requestTypeChooseHeading)` and
its trailing `SizedBox(height: Spacing.medium)`; delete the `_SectionHeading` class (:273-289)
entirely. Replace the `ListView` with:
```dart
return CustomScrollView(
  slivers: [
    SliverPadding(
      padding: _bodyPadding,
      sliver: SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TierList(state: state),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.requestTypeLocationHeading,
              style: context.jeebText.cardTitle
                  .copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: Spacing.small),
            _LocationSection(onChangeLocation: onChangeLocation),
            const Spacer(),
          ],
        ),
      ),
    ),
  ],
);
```
`SliverFillRemaining(hasScrollBody: false)` gives the HTML's `flex:1` emptiness on tall devices
and still scrolls at 200% text scale. Do **not** use `JeebSectionLabel` for `Deliver to` — the
board draws it 14/w700 navy, not uppercase periwinkle (HTML tpl-391). `cardTitle` (15.5/w700) is
within the plan's accepted tolerance; no new ramp entry.

### Task 5 — Tier list rhythm (S4)
`_TierList` :306: `Spacing.small` (12) → `Spacing.xSmall` (8). HTML gap is 9; 8 is the nearest
token. Nothing else in `_TierList` changes.

### Task 6 — Tier rows via the kit (S5 + S6)
`_TierEntry.build` (:322-344):
```dart
return JeebTierRow.compact(
  mark: _tierMark(tier.id),
  title: copy.title,
  summary: copy.summary,
  badge: tier.recommended ? l10n.requestTypeMostPickedBadge : null,
  selected: selected,
  identifier: requestTypeRadioId(tier.id),
  semanticLabel: l10n.requestTypeTierSummarySemanticLabel(
    title: copy.title,
    summary: copy.summary,
  ),
  selectedHint: l10n.requestTypeTierSelectedHint,
  onTap: () => _onTap(context),
);
```
`_onTap` stays as-is (selection only, no navigation). Replace `_tierIcon` (:358-364) with:
```dart
/// Emoji tier lexicon — load-bearing per the DS (07 HTML). Kept here, not in
/// the kit: lib/core/widgets/jeeb/ cannot import TierId.
static String _tierMark(TierId id) => switch (id) {
      TierId.flash => '⚡',
      TierId.express => '🚀',
      TierId.standard => '🟦',
      TierId.onTheWay => '🤝',
      TierId.eco => '🌿',
    };
```
Re-type `_RequestTierCopy` (:369-391) to `(title, summary)`, reading the five new
`tier<X>Summary` keys (constructor first — `sort_constructors_first`). The badge renders wherever
`tier.recommended` is true (Flash today; placement is the owner's call — W-6). Never hardcode
`TierId.standard`. Never pre-select (C-07-A).

Then delete `lib/features/request_type/presentation/request_tier_card.dart` and its import at
`request_type_screen.dart:16`. Its only other importer is the test updated in Task 9. Leave
`selectable_radio_glyph.dart` in the tree untouched — the 09 lane's option cards import it.

### Task 7 — `Deliver to` card (S7, D0 only)
Rebuild `request_location_row.dart` as the filled card. Constructor stays source-compatible:
```dart
class RequestLocationRow extends StatelessWidget {
  const RequestLocationRow({
    super.key,
    required this.currentLabel,
    required this.changeLabel,
    required this.onChange,
    this.addressLabel,
    this.qualifierLabel,
    this.changeCtaLabel,
  });
```
Render: outer `Semantics(explicitChildNodes: true)` (keep the existing *why* comment about the
merge boundary, shortened if needed) → `Container` with `colorScheme.surfaceContainerHigh` fill,
`OmdsBorderRadius.medium`, padding
`EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: Spacing.medium)` → `Row`:
1. `Icon(Icons.location_on, size: Sizes.large, color: scheme.primary)` — navy, NOT the render's
   `#E02020` (C-07-E option (a): raw hex is banned in `lib/features` and R10 says icons are navy
   or periwinkle; the divergence is flagged in the wiring file);
2. `SizedBox(width: Spacing.small)`;
3. `Expanded` column: primary line `Text(addressLabel ?? currentLabel)` in
   `context.jeebText.cardTitle` + `scheme.primary`, `maxLines: 1`, `TextOverflow.ellipsis`,
   wrapped in `Semantics(identifier: 'request_type_current_location_label')`; second line only
   when `qualifierLabel != null`, `context.jeebText.bodySmall` + `JeebSemanticColors.mutedText`;
4. `Semantics(identifier: 'request_type_change_location_button', button: true, label: changeLabel)`
   → `InkWell(borderRadius: OmdsBorderRadius.uiSmall, onTap: onChange)` → padded
   `Text(changeCtaLabel ?? changeLabel, style: context.jeebText.body.copyWith(
   fontWeight: FontWeight.w700, color: context.jeebRoles.accent))`.

The trailing chevron (`DirectionalIcons.disclosure`, :108) is deleted — the board draws a bare
orange word. Drop the `directional_icons.dart` import.

Call site `_LocationSection.build` (:239-246) becomes:
```dart
// TODO(redesign-24): needs a resolved destination label at this step; the flow
// picks the destination on the NEXT screen. Omitted, not faked (JEBV4-176).
return RequestLocationRow(
  currentLabel: l10n.requestTypeCurrentLocation,
  changeLabel: l10n.requestTypeChangeLocation,
  changeCtaLabel: l10n.requestTypeChangeCta,
  onChange: () => _onChange(context),
);
```
`_onChange` (:248-270) is untouched. D1 (saved-address enrichment) is NOT built — it is an owner
decision recorded in W-6. D2 (GPS) is refused.

### Task 8 — Footer (S8)
`_ContinueFooter.build`: swap `DeliveryCreateLayout.pagePadding` → `_footerPadding`; swap
`OmdsPrimaryButton` → `JeebCtaButton.primary` keeping, exactly:
- `key: const Key('request-type-continue')` forwarded through the kit widget;
- the `Semantics(identifier: 'request_type_continue_cta', button: true)` wrapper outside it;
- `isEnabled: hasSelection`, `text: l10n.requestTypeContinue`,
  `onTap: () => _onContinue(context, hasSelection)`;
- the `:130-132` loading guard and the whole `_onContinue` body untouched.

### Task 9 — Test updates (scoped)
`test/features/request_type/*` are this lane's. `test/delivery_create_screens_test.dart` is
**shared** — the ClientLocation/CaptureLocation groups belong to the 09/10 lanes. Edit ONLY the
import block and the `RequestTypeScreen (Figma 56535:2392)` group:
- :15 import `request_tier_card.dart` → the kit's `jeeb_tier_row.dart`; :93
  `find.byType(RequestTierCard)` → `find.byType(JeebTierRow)`, still `findsNWidgets(5)`;
- :98-99 `find.byIcon(Icons.bolt_outlined/eco_outlined)` → `find.text('⚡')` / `find.text('🌿')`;
- :100 `find.text('Choose your request')` — keep (moves to the top bar, still one widget);
- :101 `find.text('Location')` → `find.text('Deliver to')`;
- :102 `find.text('Change Location')` → `find.text('Change')`;
- :153-155 retarget the tap to
  `find.bySemanticsIdentifier('request_type_change_location_button')`;
- :170 `find.text('تغيير الموقع')` → the shipped AR value of `requestTypeChangeCta`; :167 stays.

Do NOT edit `test/features/request_type/request_type_deliberate_selection_test.dart` — it must
pass unchanged (its `:92-93` helper reads `tester.widget<OmdsPrimaryButton>` by the forwarded Key;
that is what W-1 guarantees). Do NOT edit `request_type_continue_navigation_test.dart` (drives by
identifier only). Do NOT edit `test/semantics_identifier_surfacing_test.dart` (the
source-compatible constructor in Task 7 keeps it compiling and passing).

### Task 10 — Verify
1. `flutter analyze` — zero NEW errors/warnings (baseline: 11 issues / 6 errors pre-exist; do not
   fix them).
2. Run: `test/features/request_type/`, `test/delivery_create_screens_test.dart`,
   `test/semantics_identifier_surfacing_test.dart`.
3. Manual: compare against `screens/07-request-type.png` at the same scale — the lower ~39% must
   be empty; check `ar` locale (RTL mirroring: mark at start, check/`Change` at end, ellipsis at
   the correct edge) and 200% text scale (screen must scroll, no overflow).
4. Note in the lane log whether 🟦 renders acceptably on-device (plan §9-7); the fallback (rounded
   square tinted `JeebTierColors.standard()`) is a follow-up decision shared with 08, not a
   unilateral swap.

## Stop conditions — "done" means

- All five tier rows + badge + `Deliver to` card + footer match the render's geometry and inks;
  bottom ~39% is real emptiness on a 956dp-class viewport.
- All 8 identifiers + the Key survive, spelled identically; `request_type_back` added; no other
  new identifiers.
- The three test files pass with only the Task-9 edits; deliberate-selection passes UNCHANGED.
- No new analyze issues; lints satisfied (`prefer_const_constructors`, `prefer_final_locals`,
  `sort_constructors_first`, `use_build_context_synchronously`, `avoid_print`).
- Wiring file written; no edit outside `lib/features/request_type/`, the two named test scopes,
  and `docs/redesign-2026-08/wiring/07-request-type.md`.

**Must NOT touch:** `app_router.dart`, `injection_container.dart`, `lib/core/theme/*`,
`lib/l10n/*.arb`, `pubspec.yaml`, anything under `lib/features/location/` or
`lib/features/tier_selection/`, `lib/core/widgets/` (kit lane's), `selectable_radio_glyph.dart`,
`request_type_radio_id.dart`, `.maestro/*` (including the already-stale
`09-request-type-client.yaml`), the ClientLocation/CaptureLocation test groups, and the six
pre-existing analyze errors.

---

## Wiring requests — final text for `docs/redesign-2026-08/wiring/07-request-type.md`

### cross-feature
file: lib/core/widgets/jeeb/jeeb_top_bar.dart (Wave-1 kit lane)
need: `JeebTopBar` per plan §5 #1 with `leading: JeebTopBarLeading.back`, `title`, an `identifier` param applied to the back circle's Semantics (button: true), and `onLeadingPressed`.
exact change: `JeebTopBar({required JeebTopBarLeading leading, required String title, String? identifier, VoidCallback? onLeadingPressed})` — back mode renders the Ø40 `surfaceContainerHigh` circle + 20px `DirectionalIcons.back(context)` in `colorScheme.primary`, gap 14, padding `14/24/0` directional, title `context.jeebText.h2` in `colorScheme.primary`.
why: 07 replaces `OMDSAppBar` with this widget titled `requestTypeChooseHeading`; the back circle carries the new `request_type_back` identifier.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_tier_row.dart (Wave-1 kit lane)
need: `JeebTierRow.compact` whose a11y node is byte-identical to today's `RequestTierCard` node — two tests read `flagsCollection.isChecked` off it.
exact change: `JeebTierRow.compact({required String mark, required String title, required String summary, String? badge, required bool selected, required String identifier, required String semanticLabel, required String selectedHint, required VoidCallback onTap})` emitting `Semantics(identifier: identifier, inMutuallyExclusiveGroup: true, checked: selected, label: semanticLabel, hint: selected ? selectedHint : null, button: true, child: ExcludeSemantics(child: Material/InkWell(...)))`. Internals: r16 (`OmdsBorderRadius.medium`), pad `14/16`, gap 12; `mark` is a `String` (20px emoji — the kit cannot import `TierId`); selected = `colorScheme.primary` fill + `JeebShadows.ctaNavy`, NO border; unselected = `colorScheme.surface` + `1.5px colorScheme.outline`, NO shadow; title `jeebText.cardTitle` (`onPrimary`/`primary`); summary `jeebText.bodySmall` maxLines 1 ellipsis (`onPrimary.withValues(alpha: .7)` on navy, else `JeebSemanticColors.mutedText`); indicator Ø22: selected = `jeebRoles.accent` disc + 13px white check, unselected = 2px `surfaceContainerHighest` ring (NOTE: plan §5 #8 describes this inverted — the 07 HTML tpl-361 is `background: var(--jeeb-orange)` + `fill="#fff"`, and the HTML wins); badge slot = pill pad `2/8`, `JeebSemanticColors.accentTint` fill, `jeebText.badge` in `jeebRoles.accent`, gap 8 after the title inside the same Row. `.compact` has NO price meter — plan §5 #21 and 02-PLAN-ENHANCED list 07 as a `JeebPriceMeter` consumer, but the 07 render/HTML contain zero meter dots; the meter is `.catalog`-only (08).
why: replaces `request_tier_card.dart` on 07; `request_type_deliberate_selection_test.dart` and `delivery_create_screens_test.dart` assert the checked state and the five ids through this exact node shape.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_cta_button.dart (Wave-1 kit lane)
need: `JeebCtaButton.primary` must forward a `Key` to, and expose `isEnabled` on, an internally-composed `OmdsPrimaryButton`.
exact change: `JeebCtaButton.primary({Key? key, required String text, required bool isEnabled, required VoidCallback onTap})` → `DecoratedBox(boxShadow: JeebShadows.ctaNavy, borderRadius: OmdsBorderRadius.pill)` wrapping `OmdsPrimaryButton(key: key, height: 56, borderRadius: OmdsBorderRadius.pill, textStyle: context.jeebText.button, isEnabled: isEnabled, ...)`.
why: `request_type_deliberate_selection_test.dart:92-93` reads `tester.widget<OmdsPrimaryButton>(find.byKey(const Key('request-type-continue'))).isEnabled` and must keep passing without edits.

### l10n
file: lib/l10n/app_en.arb (+ lib/l10n/app_ar.arb — parity gate, both directions)
need: 8 new keys and 1 value change for the 07 rebuild; no deletions.
exact change (EN; AR drafts for translator review in parentheses — the `·` separators are part of the localized string, never concatenated in Dart):
```json
"tierFlashSummary": "Under 1 hour · Highest price · Priority pickup",
"tierExpressSummary": "1–2 hours · Higher price · Fast pickup",
"tierStandardSummary": "2–4 hours · Balanced price",
"tierOnTheWaySummary": "Someone already heading there · Lower price",
"tierEcoSummary": "Today, no rush · Lowest price · Greenest",
"requestTypeMostPickedBadge": "Most picked",
"requestTypeChangeCta": "Change",
"requestTypeTierSummarySemanticLabel": "{title}. {summary}.",
```
(AR drafts: `أقل من ساعة · أعلى سعر · أولوية الاستلام` / `1–2 ساعة · سعر أعلى · استلام سريع` / `2–4 ساعات · سعر متوازن` / `شخص متجه إلى هناك بالفعل · سعر أقل` / `اليوم، دون استعجال · أدنى سعر · الأكثر بيئية` / `الأكثر اختيارًا` / `تغيير` / `{title}. {summary}.`)
`requestTypeTierSummarySemanticLabel` needs `@` placeholders for `title` and `summary`. VALUE CHANGE: `requestTypeLocationHeading` `"Location"` → `"Deliver to"` (AR `"التوصيل إلى"`), update its `@description`; verified zero call sites outside 07. Kept untouched (do NOT delete): `requestTypeTitle`, the ten `tier<X>Speed`/`tier<X>Value` keys, `requestTypeTierSemanticLabel`, `requestTypeChangeLocation` (survives as the a11y label), `requestTypeChooseHeading`, `requestTypeCurrentLocation`, `requestTypeTierSelectedHint`, `requestTypeContinue`.
why: tier summaries compress to one line (HTML tpl-360 etc.), the badge, the visible `Change` word, the 2-arg semantic label, and the `Deliver to` heading all render from these.

### cross-feature
file: lib/features/tier_selection/data/tier_repository.dart (OWNER DECISION — do not apply until resolved)
need: the board draws the badge on Standard, but `recommended` is synthesized client-side as Flash (`:100` Dio, `:189` fake). If the owner wants board placement, flip both constants Flash → Standard; 07's code renders from `tier.recommended` either way and never hardcodes a tier. Second owner call in the same breath: `Most picked` asserts unmeasured popularity — the conservative wording is the existing `tierSelectionRecommendedBadge` ("Recommended").
exact change: `tier_repository.dart:100` `recommended: id == TierId.flash` → `recommended: id == TierId.standard`; in `FakeTierRepository.defaultCatalog` move `recommended: true` from the Flash entry to the Standard entry (and fix the stale "default selected card" comment — nothing pre-selects, per `request_type_deliberate_selection_test.dart`).
why: badge placement fidelity to the 07/08 boards; the file belongs to the tier_selection directory, not the 07 lane.

### cross-feature
file: (coordination note — no file edit) 07/08 same-file collision + stale Maestro flow
need: (a) serialize the 07 and 08 lanes — both edit `request_type_screen.dart`; 07 owns the shell and `.compact` rows, 08 owns only its catalog section/route; (b) 08's designer note "Recommended pre-selected" is refused by 07's deliberate-selection test — applies to 08 too; (c) 07's board draws no entry point to `/tier-catalog` — do not invent one; (d) `.maestro/flows/09-request-type-client.yaml` asserts pre-rename ids (`request_type_tier_flash`/`_tier_onTheWay`) and was broken before this lane — needs an owner, out of 07's scope.
exact change: none in code; integrator scheduling + owner triage.
why: prevents the highest-probability Wave-3 merge conflict and a silent-rot Maestro flow being misattributed to this lane.
