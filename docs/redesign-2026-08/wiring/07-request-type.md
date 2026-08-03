# Wiring requests — 07 · Request type

Source of truth: `docs/redesign-2026-08/per-screen-revised/07-request-type.md`.
Screen code is written as if every OPEN request below has been granted.

> **Status 2026-08-03.** The Wave-1 kit has since SHIPPED, so W-1/W-2/W-3 below are
> **CLOSED — no action**; they are kept only as the record of what 07 asked for and how
> the delivered kit differs. The screen now imports `lib/core/widgets/jeeb/`
> (`JeebTopBar.back`, `JeebTierRow.compact`, `JeebCtaButton.primary`) and hand-rolls
> nothing. **The only OPEN blocker is the l10n batch (W-4 + W-4b).**

### ~~cross-feature~~ CLOSED — W-1
file: lib/core/widgets/jeeb/jeeb_top_bar.dart (Wave-1 kit lane)
need: `JeebTopBar` per plan §5 #1 with `leading: JeebTopBarLeading.back`, `title`, an `identifier` param applied to the back circle's Semantics (button: true), and `onLeadingPressed`.
exact change: SHIPPED as asked. 07 consumes the `JeebTopBar.back` named constructor with `title`, `identifier: 'request_type_back'` and `onLeadingPressed`.
why: 07 replaces `OMDSAppBar` with this widget titled `requestTypeChooseHeading`; the back circle carries the new `request_type_back` identifier.

### ~~cross-feature~~ CLOSED — W-2
file: lib/core/widgets/jeeb/jeeb_tier_row.dart (Wave-1 kit lane)
need: `JeebTierRow.compact` whose a11y node is byte-identical to today's `RequestTierCard` node — two tests read `flagsCollection.isChecked` off it.
exact change: SHIPPED with the requested signature and the byte-identical `Semantics(identifier:, inMutuallyExclusiveGroup: true, checked:, label:, hint:, button:) → ExcludeSemantics` node, r16 / pad `14/16` / gap 12, the orange-disc-plus-white-check indicator (HTML tpl-361 wins over plan §5 #8, as asked), the `accentTint` badge, and no price meter on `.compact` (C-07-G honoured).
why: replaces `request_tier_card.dart` on 07 (now deleted); `request_type_deliberate_selection_test.dart` and `delivery_create_screens_test.dart` assert the checked state and the five ids through this exact node shape.

### cross-feature — W-3 SUPERSEDED (kit shipped differently; 07 adapted, no kit change wanted)
file: lib/core/widgets/jeeb/jeeb_cta_button.dart (Wave-1 kit lane) — **informational, do NOT change the kit**
need: 07 originally asked for `JeebCtaButton.primary` to forward a `Key` to an internally-composed `OmdsPrimaryButton` so `request_type_deliberate_selection_test.dart` could keep reading `tester.widget<OmdsPrimaryButton>(...).isEnabled` unedited.
exact change: none. The frozen kit paints its own pill (`DecoratedBox` + `InkWell`) and exposes `label:`/`isEnabled:` directly — its own doc prescribes `tester.widget<JeebCtaButton>(find.byKey(k)).isEnabled`. 07 therefore retargeted the ONE helper at `request_type_deliberate_selection_test.dart:92-93` to `JeebCtaButton`; the `Key('request-type-continue')`, the assertion and its intent are unchanged. Recorded here because the per-screen instruction set says that file must pass *unchanged* — that clause was written against the un-shipped W-3 contract and is no longer satisfiable.
why: keeps the frozen kit frozen; the enablement assertion survives verbatim.

### cross-feature — W-7 (NEW, kit lane) `JeebTierRow.compact` badge overflows at 200% text scale
file: lib/core/widgets/jeeb/jeeb_tier_row.dart (`_CompactBody`)
need: the title Row is `Flexible(title) + SizedBox(8) + _Badge`. `_Badge` is inflexible with `softWrap: false`, so on a narrow viewport at a large text scale it overflows the row instead of the title ellipsizing further.
exact change: wrap the compact badge in `Flexible(child: _Badge(...))` (or give `_Badge`'s `Text` `overflow: TextOverflow.ellipsis` inside a `Flexible`) so the row can never overflow.
why: reproduced on a 360dp-wide viewport at `TextScaler.linear(2.0)` with a badged row — `A RenderFlex overflowed by 64 pixels on the right`. Removing the badge makes it clean. 07 cannot fix this from the feature side because the badge string is passed *into* the kit. (Test-font metrics exaggerate the width, so the real-device margin is larger — but the row has no ellipsis escape hatch at all today.)

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

### l10n — W-4b (**OPEN — the only thing blocking 07 from compiling**)
file: lib/l10n/app_localizations.dart
need: ADDENDUM discovered while implementing — `AppLocalizations` in this repo is **hand-authored**, not `flutter gen-l10n` output (see its header comment), so adding the ARB entries above is NOT sufficient: the eight typed getters must be hand-added in the same commit or the app does not compile.
exact change: add alongside the existing `requestType*` getters (~:645-680):
```dart
  String get tierFlashSummary => _get('tierFlashSummary');
  String get tierExpressSummary => _get('tierExpressSummary');
  String get tierStandardSummary => _get('tierStandardSummary');
  String get tierOnTheWaySummary => _get('tierOnTheWaySummary');
  String get tierEcoSummary => _get('tierEcoSummary');
  String get requestTypeMostPickedBadge => _get('requestTypeMostPickedBadge');
  String get requestTypeChangeCta => _get('requestTypeChangeCta');

  String requestTypeTierSummarySemanticLabel({
    required String title,
    required String summary,
  }) => _get('requestTypeTierSummarySemanticLabel')
      .replaceAll('{title}', title)
      .replaceAll('{summary}', summary);
```
(match the exact placeholder-substitution idiom used by the neighbouring `requestTypeTierSemanticLabel` getter — copy its body shape rather than the sketch above if it differs.)
why: until this lands, `request_type_screen.dart` and `request_location_row.dart` report `undefined_getter` on the eight new keys. This is the ONLY source of new analyze errors in the 07 lane.

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

### ~~cross-feature~~ VOID — promotion note (kit stand-ins)
file: (no file edit)
need: an earlier run of this lane wrote local stand-ins under `lib/features/request_type/presentation/widgets/` because `lib/core/widgets/jeeb/` did not exist yet.
exact change: none — **the stand-ins were never created in the shipped tree**. The kit exists and 07 imports it directly (`core/widgets/jeeb/jeeb_top_bar.dart`, `…/jeeb_tier_row.dart`, `…/jeeb_cta_button.dart`). No promotion, no `git mv`, nothing to repoint.
why: kept so nobody hunts for stand-in files that are not there.

### cross-feature — dead file left behind
file: lib/features/request_type/presentation/selectable_radio_glyph.dart
need: its last importer (`request_tier_card.dart`) was deleted by this lane. A tree-wide grep now finds **zero** importers — the per-screen instruction set claimed `location/presentation/widgets/client_location_option_card.dart` imports it, which is no longer true (the 09 lane appears to have dropped it).
exact change: none applied — the instruction set names this file under "must NOT touch". Owner call: delete it, or keep it if the 09 lane still intends to consume it.
why: it is now unreachable code; flagged rather than unilaterally removed.

### theme
file: (divergence flags — no file edit required, recorded for the design owner)
need: two deliberate divergences from the board's literal pixels, both forced by existing repo gates.
exact change: none. (1) The `Deliver to` card's pin is `colorScheme.primary` navy, NOT the render's `#E02020` — `tool/check_design_tokens.sh` bans `Color(0xFF…)` in `lib/features` and R10 says icons are navy or periwinkle (C-07-E option (a)). (2) `JeebPriceMeter` is NOT rendered on 07 although plan §5 #21 and `02-PLAN-ENHANCED.md` L143/L155 list 07 as a consumer — the 07 HTML/render contain zero meter dots (C-07-G).
why: if the owner wants the red pin or the meter, both need a token/board decision, not a silent feature-side hex.
