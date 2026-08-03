# 08 · Tier catalog — REVISED instruction set (authoritative)

Lane: Wave 3 · feature dir `lib/features/tier_selection/` · Verdict: **new-surface**
Design: `screens/08-tier-catalog.{png,html,note.md}` · Reviewed against the actual tree 2026-08-03.

Every claim below was re-verified against the files. Where the original proposal was wrong or
padded, this document wins.

---

## 0. File resolution — VERIFIED, follow it

Rebuild **`lib/features/tier_selection/presentation/tier_selection_screen.dart`** (369 lines) in
place. Do **not** touch `request_type_screen.dart` (lane 07's compact picker) and do **not** move
or rename the file:

- `test/core/theme/no_raw_semantic_colors_test.dart:39` gate-lists this exact path.
- Plan Wave-3 row (`00-MIGRATION-PLAN.md:472`) assigns 08 to feature dir `tier_selection`, a NEW
  `/tier-catalog` route (name `tier-catalog`), `backFallbacks['tier-catalog'] = '/request-type'`,
  and forbids resurrecting `/tier-selection`.
- The STOP table's "dead code" note is true only until the route lands — the Wave-3 row is the
  operative instruction.

Preserve all four constructor seams exactly: `cubit`, `repository`, `onConfirmed`, and
`_resolveRepository()`'s `FakeTierRepository` fallback. Verified consumer:
`lib/devtool/catalog/entries/batch_11_entries.dart:407-424` mounts three states through
`repository:` — the seams are load-bearing.

**Baseline correction (supersedes the agent prompt):** per `docs/redesign-2026-08/_BASELINE.md`,
`flutter analyze` = **5 issues / 0 errors** and there are exactly **4 named pre-existing test
failures** — none in this lane. Your bar: 0 analyze errors, no new warnings, no fifth failure.

**Wave 0 is DONE** (verified in tree): `context.jeebText` (`lib/core/theme/jeeb_text_styles.dart`),
`JeebShadows` (`jeeb_shadows.dart`, `ctaNavy` at :64), `JeebSemanticColors.mutedText` (#777FC0 =
the board's periwinkle), and the `jeebRoles.accent` quartet all exist. **No theme wiring request
is needed.** The kit (`lib/core/widgets/jeeb/`) does **not** exist yet — see the gate in task 1.

---

## 1. Frozen Semantics inventory (verified line numbers)

| identifier | today | after |
|---|---|---|
| `tier_selection_root` | `tier_selection_screen.dart:92` | unchanged, still the single `<screen>_root` |
| `tier_selection_confirm_cta` | `:191` | re-homed onto the docked CTA, value identical |
| `tier_selection_card_flash/express/standard/onTheWay/eco` | `:275` (`'tier_selection_card_${tier.id.name}'`) | unchanged. `onTheWay` stays camelCase — `TierId.onTheWay.name` — do not "fix" it |

New identifier (exactly one): **`tier_selection_back`** on the top-bar back circle. Convention
verified: 13 existing `<screen>_back` values in `lib/`. Keep the `tier_selection_` prefix — the
root value is frozen, so no `tier_catalog_` prefix family.

Widget `Key`s (declared `:49-53`, all kept): `tier-selection-root` (Scaffold),
`tier-selection-list` (re-homed onto the new scroll view), `tier-selection-confirm` (re-homed onto
the new CTA), `tier-selection-retry` (declared, no consumer — keep declared),
`tier-selection-card-<id.name>` (wrapper of each row).

§7.5 rules apply: identifiers via an **explicit `Semantics` wrapper** (`container: true`; add
`explicitChildNodes: true` when it wraps children with their own ids) — never an OMDS widget's
`identifier:` param. The interactive set is complete at: back, 5 cards, confirm. The info note is
static — no identifier.

---

## 2. What changed vs the original proposal

**Cut (scope creep / wrong channel):**
1. l10n key `tierCatalogBackLabel` — use `MaterialLocalizations.of(context).backButtonTooltip`
   (built-in, already localized AR/EN); the kit's back circle owns the label. Zero keys.
2. l10n key `tierCatalogPriceMeterSemanticLabel` — the meter dots are decorative; the caption text
   is already in the card-level semantic label. Ask the kit to `excludeSemantics` the dots instead.
3. Editing `test/semantics_identifier_surfacing_test.dart` — it is a **shared** test file across
   24 lanes; ownership rules forbid it. The same 8 identifier assertions go into this lane's own
   new test file instead (task 8).
4. The `TierPriceBand` enum in the lexicon — a plain per-tier switch resolves captions; do not
   grow an enum nobody else consumes.
5. The 07 "Compare tiers" entry-point snippet — lane 07 / owner territory. The board's 07 HTML has
   **no** such affordance (verified: zero matches for "Compare"). It is an owner note in the
   wiring file, not a request. Until decided, `/tier-catalog` is deep-link/route-only. Still ship
   the route: the Wave-3 row mandates it.

**Corrected (proposal said / reality is):**
1. Old semantic label reuse: `tierSelectionCardSemanticLabel` renders
   `"{name} tier. {sla}, {radius}, indicative price {price}."` — feeding the meter caption into
   `price` produces the nonsense "indicative price Highest price". The NEW key
   `tierCatalogCardSemanticLabel` is **required**, not optional. Old key orphaned.
2. Test cites: the `OmdsPrimaryButton` reads are at `test/tier_selection_screen_test.dart:74-77`,
   `:98-101`, `:120-123`; cached-banner `findsNothing` at `:56` and `:151` (not 105-108); retry
   test ends ~`:163`.
3. Selected-card shadow is `0 10 22 rgba(11,19,81,.28)` per plan §5 #4/#8 — **not**
   `JeebShadows.ctaNavy` (`0 10 24`, verified `jeeb_shadows.dart:64`). Kit-internal; the CTA pill
   uses `ctaNavy`, the selected card does not. The screen passes neither.
4. Board badge font is **10px** w800 (HTML node 455), `jeebText.badge` is 10.5/w800 — kit lane's
   call, flagged in the wiring file.
5. LTR-isolate precedent path: `lib/features/otp_handover/presentation/widgets/
   handover_code_display.dart` (~:60-63), not `handover/`.
6. Deliberate-selection test path: `test/features/request_type/
   request_type_deliberate_selection_test.dart`.
7. No DI change confirmed: `TierRepository` registered at `injection_container.dart:406`. Route
   name `tier-catalog` is free (verified). `_wrapGoRoute` (`app_router.dart:534-550`) preserves
   only path/name/builder/redirect/routes — so plain `builder:` in the route request.

**Confirmed against the render/HTML (node-by-node) — the proposal's design readings hold:** top
bar 412-416 (Ø40 `surfaceContainerHigh` circle, 20px navy arrow, title 20/w700 "Delivery tiers");
subtitle 417 (14.5/w500 periwinkle); list 418 (pad 16/24/0, gap 9); card 419 (r16, 1.5px
`colorScheme.outline`, pad 13/16, white); emoji 17px ⚡🚀🟦🤝🌿; meter Ø7 dots gap 3, orange /
`surfaceContainerHighest`, caption 10.5/w700; SLA chip pad 3/9 `surfaceContainerHigh` navy w700;
meta line 11.5/w600 periwinkle; selected Standard = navy fill, no border, re-toned internals
(chip `rgba(255,255,255,.14)`, ink `.7`, empty dots `.25`), white 15px trailing check; vehicle
glyph 14px on Flash only (C7 mandates all five); note 500-503 (`surfaceContainerHigh`, r16, text
12.5/w500 lh18 "Jeebers set the price — you compare real offers and pick one. No fixed prices.");
spacer 504; footer 505/506 (pad 0/24/32, h56 navy pill, white 17/w600, "Confirm tier").

**Refusals — all four verified and upheld:**
- **"Recommended pre-selected" (designer note) — REFUSED.** Three pins: the cubit doc invariant
  ("Loading a catalog never chooses a tier", `tier_selection_cubit.dart:20-22`),
  `tier_selection_screen_test.dart:108-123`, and
  `test/features/request_type/request_type_deliberate_selection_test.dart`. Badge renders; card
  starts unselected; Confirm starts disabled. Zero cubit changes.
- **"≤ 2 hr" (Express) / "Today" (Eco) as literals — REFUSED.** Render from `Tier.slaMinutes` via
  the existing `_slaCopy` (kept verbatim except the null branch → `tierCatalogSlaFlexible`).
- **`Recommended` hardcoded on Standard — REFUSED.** Render `tier.recommended` (data currently
  flags Flash — `tier_repository.dart:100`, `:189`). Gateway change = owner question.
- **Vehicle glyph on Flash only — REFUSED** per C7: all five cards, via the kept `_vehicleIcon`
  mapping passed as `metaIcon`.

---

## 3. Task list — execute in order

**Task 1 — Gate: verify the kit exists.** `lib/core/widgets/jeeb/` must contain `JeebTopBar`
(back mode), `JeebCtaButton` + `JeebCtaFooter` (single), `JeebTierRow` (`.catalog`),
`JeebPriceMeter`, `JeebInfoNote` (`.muted`). As of 2026-08-03 the directory **does not exist**.
If any is missing: do task 2 only, then stop and report BLOCKED-ON-WAVE-1. Never hand-roll a kit
widget "temporarily".

**Task 2 — Write the wiring file.** Create `docs/redesign-2026-08/wiring/08-tier-catalog.md` with
the exact content of §5 below. Do this first so the integrator can run in parallel. Write all
screen code as if granted.

**Task 3 — Lexicon.** New file `lib/features/tier_selection/domain/tier_display_lexicon.dart`:
a `const` per-`TierId` table of `(String emoji, int priceLevel)` — flash `⚡`/4, express `🚀`/3,
standard `🟦`/2, onTheWay `🤝`/2, eco `🌿`/1 — plus two small resolvers taking
`AppLocalizations`: price caption (`tierCatalogPriceHighest/Higher/Balanced/Lower/Lowest`) and
meta line (`tierCatalogMetaFlash/Express/Standard/OnTheWay/Eco`). One short why-comment: client
lexicon for a closed 5-value product vocabulary, sanctioned by plan §7.6; Standard and On-the-Way
both 2/4 as drawn (designer flagged). No `Tier` field additions, no parser changes.

**Task 4 — Scaffold restructure** (`tier_selection_screen.dart`, `_Scaffold`):
- Delete the `appBar:` argument. Body = `SafeArea > Column`: first child
  `JeebTopBar(leading: back, title: l10n.tierCatalogTitle, identifier: 'tier_selection_back',
  onBack: () => Navigator.of(context).maybePop())` — rendered in **every** status (the Material
  app bar is gone, so loading/error must still expose the back affordance); then the existing
  `BlocConsumer` (listener kept verbatim) → `_Body`.
- Add `bottomNavigationBar:` = `BlocBuilder<TierSelectionCubit, TierSelectionState>` returning
  `const SizedBox.shrink()` unless `state.status == TierSelectionStatus.loaded`, else
  `SafeArea(top: false, child: JeebCtaFooter.single(...))` hosting
  `JeebCtaButton.primary(key: TierSelectionScreen.confirmButtonKey,
  label: l10n.tierCatalogConfirm, isEnabled: state.canConfirm,
  onTap: () => context.read<TierSelectionCubit>().confirm())`, wrapped in
  `Semantics(identifier: 'tier_selection_confirm_cta', container: true, button: true)`.
  Mirror the `request_type_screen.dart:111-133` idiom exactly (verified in tree). Footer padding
  `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)` if the
  kit takes padding; otherwise kit default (spec is `0/24/32`).
- `Semantics(identifier: 'tier_selection_root', container: true)` and
  `Scaffold(key: TierSelectionScreen.rootKey)` unchanged.

**Task 5 — `_Body` / `_LoadedView`:**
- `_Body` branches unchanged in content: `Center(child: OmdsLoadingState())` and the existing
  `OmdsErrorState(message/onRetry/retryLabel)` **verbatim** — tests find `OmdsErrorState` by type
  and tap its `FilledButton` (`tier_selection_screen_test.dart:59`, `:149`, `:158`). They now sit
  below the top bar by construction of task 4.
- `_LoadedView` becomes: subtitle
  `Padding(EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.small, Spacing.xLarge, 0),
  Text(l10n.tierCatalogSubtitle, style: context.jeebText.body.copyWith(color: <JeebSemanticColors>.mutedText)))`
  (13.5/w500 per R3 — do not invent 14.5), then
  `Expanded(child: SingleChildScrollView(key: TierSelectionScreen.listKey,
  padding: EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0),
  child: Column(mainAxisSize: MainAxisSize.min, children: [...])))` — 5 rows separated by
  `SizedBox(height: Spacing.xSmall)` (gap 9 → 8, R12), then `SizedBox(height: Spacing.medium)`,
  then `JeebInfoNote.muted(text: l10n.tierCatalogPricingNote)` (pass the info glyph only if the
  API requires one). Add one short comment on the scroll view: a ListView here re-fills the
  deliberate empty bottom third (R1).
- Delete the `_CachedBanner` call (`:157-158`) and class (`:207-251`). Keep
  `TierSelectionState.usingCachedFallback` untouched (cubit API; verified nothing sets it true).

**Task 6 — Rows.** Each row: wrapper keyed `TierSelectionScreen.cardKey(tier.id)` (KeyedSubtree or
the kit's `key:` param) around `JeebTierRow.catalog(` `emoji` + `priceLevel` from the lexicon,
`priceCaption` from the lexicon resolver, `name: _tierName(...)` (kept), `slaLabel: _slaCopy(...)`
(kept verbatim except `null` → `l10n.tierCatalogSlaFlexible`), `metaLabel:` lexicon meta resolver,
`metaIcon: _vehicleIcon(tier.vehicleClass)` (kept — all five cards per C7),
`badgeLabel: tier.recommended ? l10n.tierSelectionRecommendedBadge : null`,
`selected: state.selectedTierId == tier.id`,
`onTap: () => context.read<TierSelectionCubit>().selectTier(tier.id)`,
`identifier: 'tier_selection_card_${tier.id.name}'`,
`semanticLabel: l10n.tierCatalogCardSemanticLabel(name:…, sla:…, meta:…, price: caption)`,
`selectedHint: l10n.tierSelectionCardSelectedHint)`.

**Task 7 — Deletions and hygiene.**
- Delete `lib/features/tier_selection/presentation/tier_card.dart` (verified: its only importer is
  this screen). Delete `_tierFooter` and `_formatPrice`; keep `_tierName`, `_slaCopy`,
  `_vehicleIcon`. Remove now-dead imports: `tier_card.dart`, `money_format.dart`,
  `jeeb_color_roles.dart` (was only used by `_CachedBanner`).
- Rewrite the class doc comment (`:15-22`): the file now hosts the standalone comparison catalog
  at `/tier-catalog`; drop the stale ORPHAN line. Keep it short.
- Lint pass: `const` constructors wherever possible, `final` locals, constructors before fields in
  any new/edited widget class, `EdgeInsetsDirectional` only, no `print`, no async gaps before
  `context` use (there are none — `confirm()`/`selectTier()` are sync). No `Color(0x`, no
  `.tertiary*`, no `Colors.*`, no literal px in `lib/features`
  (`tool/check_design_tokens.sh` + the gate test both police this file). The file shrinks
  (~369 → ~300); no `presentation/widgets/` extraction required.

**Task 8 — Tests (lane-owned files only).**
- `test/tier_selection_screen_test.dart`: swap the three `tester.widget<OmdsPrimaryButton>` casts
  (`:74`, `:98`, `:120`) to the kit CTA type, still asserting `.isEnabled`; adjust the import. Do
  NOT weaken to `findsOneWidget`. Everything else in the file must pass unchanged — the card keys,
  no-pre-selection, cached-banner `findsNothing`, and retry-recovers tests all survive by design.
- New `test/features/tier_selection/tier_catalog_render_test.dart` pumping
  `TierSelectionScreen(repository: FakeTierRepository())`: 5 cards; exactly one Recommended badge
  (assert the count, not the tier — it follows data); meter levels 4/3/2/2/1 via widget props;
  the pricing-note text; CTA footer absent (or disabled) until a card tap, enabled after;
  top-bar title still present in the error state; and the 8 identifiers surfaced via
  `find.bySemanticsIdentifier` (`tier_selection_root`, `tier_selection_back`,
  `tier_selection_confirm_cta`, 5 × `tier_selection_card_*`) — this replaces the shared
  surfacing-test edit.
- Same file or a sibling: one `ar`-locale smoke — renders without exception, back glyph is
  `Icons.arrow_forward` (`DirectionalIcons.back`, `directional_icons.dart:16`), SLA chip text
  intact. Keep it small; deep bidi behavior is kit-tested.

**Task 9 — Gates.** `flutter analyze` (no new issues vs `_BASELINE.md`'s 5/0);
`flutter test test/tier_selection_screen_test.dart test/tier_selection_cubit_test.dart
test/features/tier_selection/ test/devtool/tier_catalog_fixture_test.dart
test/core/theme/no_raw_semantic_colors_test.dart`; `bash tool/check_design_tokens.sh`. The devtool
catalog entries must still compile (constructor seams untouched).

---

## 4. Stop conditions

**Done means:** tasks 1-9 complete; the loaded screen matches the render (top bar, periwinkle
subtitle, 5 two-row cards, muted note, empty lower third, docked navy "Confirm tier"); all 7
frozen identifiers + `tier_selection_back` emitted; all listed tests green; zero new analyze
issues; token script clean; wiring file written.

**Do NOT touch:** `app_router.dart`, `injection_container.dart`, `lib/core/theme/*`,
`lib/l10n/*.arb`, `pubspec.yaml`, `lib/core/widgets/jeeb/*` (kit lane's), `request_type/*`
(lane 07), `lib/devtool/*`, `test/semantics_identifier_surfacing_test.dart`,
`test/core/router/back_nav_all_routes_test.dart`, `TierSelectionCubit`/`TierSelectionState`,
`tier_repository.dart` (parser stays; no `priceLevel` field), `test/decision_violations_test.dart`.
Do not rename/move the screen file. Do not resurrect `/tier-selection`. Do not pre-select any
tier. Do not delete orphaned `tierSelection*` l10n keys. Do not fix the 4 pre-existing baseline
failures.

---

## 5. Wiring requests — paste verbatim into `docs/redesign-2026-08/wiring/08-tier-catalog.md`

```
### route
file: lib/core/router/app_router.dart
need: mount the tier catalog at NEW route /tier-catalog with a back fallback to /request-type; do not resurrect /tier-selection.
exact change: (a) inside _wrapRootAware, immediately after the legacy-removal comment at lines 1088-1092 (keep that comment; append the line `// redesign-2026-08: remounted as the standalone comparison catalog at /tier-catalog.`):
GoRoute(
  path: '/tier-catalog',
  name: 'tier-catalog',
  builder: (context, state) => TierSelectionScreen(
    onConfirmed: (tier) => context.pop(tier.id),
  ),
),
(b) in backFallbacks (near line 482, beside 'request-type': '/'):
    'tier-catalog': '/request-type',
(c) add the import for tier_selection_screen.dart if absent. Plain builder only — _wrapGoRoute (534-550) drops pageBuilder/parentNavigatorKey.
why: plan Wave-3 row for 08; Confirm pops the chosen TierId so 07 stays the sole writer of ComposeRequestController.setTier (the iter6 tier-required-400 fix stays single-path). backFallbacks auto-adds one passing case to back_nav_all_routes_test. NOTE for the owner: the board's 07 HTML has no "Compare tiers" affordance — until lane 07/product adds an entry point, this route is reachable by name only.
```

```
### l10n
file: lib/l10n/app_en.arb (+ app_ar.arb with real AR + getters, the standard 4-step batch)
need: 16 new tierCatalog* keys; no existing key edited or deleted (tierSelectionTitle/Subtitle/Confirm/PriceRange/SlaNone/Footer*/Vehicle*/CardSemanticLabel become orphans, kept).
exact change:
  "tierCatalogTitle": "Delivery tiers",
  "tierCatalogSubtitle": "Same errand, five speeds — pick what it's worth.",
  "tierCatalogConfirm": "Confirm tier",
  "tierCatalogSlaFlexible": "Flexible",
  "tierCatalogPriceHighest": "Highest price",
  "tierCatalogPriceHigher": "Higher price",
  "tierCatalogPriceBalanced": "Balanced price",
  "tierCatalogPriceLower": "Lower price",
  "tierCatalogPriceLowest": "Lowest price",
  "tierCatalogMetaFlash": "Bike / scooter",
  "tierCatalogMetaExpress": "Scooter / car",
  "tierCatalogMetaStandard": "Any vehicle",
  "tierCatalogMetaOnTheWay": "Matched with a passing Jeeber",
  "tierCatalogMetaEco": "Bundled route · greenest",
  "tierCatalogPricingNote": "Jeebers set the price — you compare real offers and pick one. No fixed prices.",
  "tierCatalogCardSemanticLabel": "{name} tier. {sla}, {meta}, {price}.",
  "@tierCatalogCardSemanticLabel": { "placeholders": { "name": {}, "sla": {}, "meta": {}, "price": {} } }
why: board copy (HTML nodes 416/417/435/450/455/466/483/484/496/498/499/503/506); slaFlexible replaces engineer-speak "No SLA" for a null-SLA tier; CardSemanticLabel replaces the old "indicative price {price}" sentence, which would read "indicative price Highest price" now that dollar ranges are deleted. Meta keys are new per C7 — none collide with the D20 banned list (decision_violations_test.dart:161-168).
```

```
### cross-feature
file: lib/core/widgets/jeeb/ (Wave-1 kit lane)
need: four API/behavior points on kit widgets this screen consumes.
exact change: (1) JeebCtaButton exposes `isEnabled` (not just nullable onTap) — tier_selection_screen_test.dart asserts `.isEnabled` at three sites; (2) JeebTierRow.catalog takes `emoji` as String and `metaIcon` as IconData (kit stays feature-agnostic, no TierId import), and wraps latin-numeric SLA labels ("≤ 1 hr") in Directionality(TextDirection.ltr) with an opt-out for pure-Arabic labels like Flexible (precedent: otp_handover/…/handover_code_display.dart:60-63); (3) JeebPriceMeter builds dots as a plain Row (start-edge fill mirrors under RTL) and excludes them from semantics — the caption is the a11y signal; (4) spec nits: board badge font is 10px/w800 (jeebText.badge is 10.5) and the selected-card shadow is 0 10 22 rgba(11,19,81,.28) (plan §5 #4/#8), NOT JeebShadows.ctaNavy — kit decides, recording it here so it is not lost.
why: screen 08 cannot keep its existing disabled-state tests, RTL correctness, or shadow fidelity without these; all four are kit-internal decisions this lane may not implement itself.
```

No `di` request (`TierRepository` registered, `injection_container.dart:406`). No `theme` request
(Wave 0 landed). Owner questions carried in the route note plus one more: data flags **Flash** as
recommended while the board draws **Standard** — the screen renders the flag; moving it is a
gateway/back-office call.
