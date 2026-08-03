# Wiring requests — 08 · Tier catalog

Lane: screen id `08-tier-catalog` · **feature dir `lib/features/request_type/`** (corrected).

> **REWRITTEN 2026-08-03 after the file-path correction.** The first version of this file was
> written against the per-screen instruction set, which rebuilt the standalone
> `tier_selection_screen.dart` behind a NEW `/tier-catalog` route. The 🛑 STOP block in
> `00-MIGRATION-PLAN.md` (row 08) and `screen-repo-map.md` supersede that: `tier_selection_screen.dart`
> is **dead code** (devtool-only importer) and the live tier picker is a **section of
> `/request-type`**. The catalog therefore shipped as
> `lib/features/request_type/presentation/widgets/tier_catalog_section.dart`, consumed by
> `request_type_screen.dart`.
>
> **W-R1 (route) is WITHDRAWN — do not apply it.** No `/tier-catalog` route, no
> `backFallbacks['tier-catalog']`, no import of `tier_selection_screen.dart` into the router.
> Adding it would resurrect the surface `app_router.dart:1088-1092` deliberately deleted and would
> mount a screen this lane did not rebuild.

---

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart (the standard
4-step hand-authored batch: EN key, AR key, typed getter, no generated file)
need: 14 new `tierCatalog*` keys for the catalog section of `/request-type`. No existing key is
edited or deleted.
exact change:

app_en.arb:
```json
  "tierCatalogSubtitle": "Same errand, five speeds — pick what it's worth.",
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
```

app_ar.arb (proposed — please have a native reviewer confirm before merge):
```json
  "tierCatalogSubtitle": "المشوار نفسه، خمس سرعات — اختر ما يستحقه.",
  "tierCatalogSlaFlexible": "مرن",
  "tierCatalogPriceHighest": "أعلى سعر",
  "tierCatalogPriceHigher": "سعر أعلى",
  "tierCatalogPriceBalanced": "سعر متوازن",
  "tierCatalogPriceLower": "سعر أقل",
  "tierCatalogPriceLowest": "أقل سعر",
  "tierCatalogMetaFlash": "دراجة / سكوتر",
  "tierCatalogMetaExpress": "سكوتر / سيارة",
  "tierCatalogMetaStandard": "أي مركبة",
  "tierCatalogMetaOnTheWay": "يطابقك جيبر في طريقه",
  "tierCatalogMetaEco": "مسار مجمّع · الأكثر مراعاة للبيئة",
  "tierCatalogPricingNote": "الجيبرز هم من يحددون السعر — تقارن العروض الحقيقية وتختار واحدًا. لا أسعار ثابتة.",
  "tierCatalogCardSemanticLabel": "فئة {name}. {sla}، {meta}، {price}."
```

app_localizations.dart getters (exact signatures the screen calls):
```dart
  // Tier catalog (redesign-2026-08 · 08) — the enhanced picker section of
  // /request-type.
  String get tierCatalogSubtitle => _get('tierCatalogSubtitle');
  String get tierCatalogSlaFlexible => _get('tierCatalogSlaFlexible');
  String get tierCatalogPriceHighest => _get('tierCatalogPriceHighest');
  String get tierCatalogPriceHigher => _get('tierCatalogPriceHigher');
  String get tierCatalogPriceBalanced => _get('tierCatalogPriceBalanced');
  String get tierCatalogPriceLower => _get('tierCatalogPriceLower');
  String get tierCatalogPriceLowest => _get('tierCatalogPriceLowest');
  String get tierCatalogMetaFlash => _get('tierCatalogMetaFlash');
  String get tierCatalogMetaExpress => _get('tierCatalogMetaExpress');
  String get tierCatalogMetaStandard => _get('tierCatalogMetaStandard');
  String get tierCatalogMetaOnTheWay => _get('tierCatalogMetaOnTheWay');
  String get tierCatalogMetaEco => _get('tierCatalogMetaEco');
  String get tierCatalogPricingNote => _get('tierCatalogPricingNote');
  String tierCatalogCardSemanticLabel({
    required String name,
    required String sla,
    required String meta,
    required String price,
  }) => _get('tierCatalogCardSemanticLabel')
      .replaceFirst('{name}', name)
      .replaceFirst('{sla}', sla)
      .replaceFirst('{meta}', meta)
      .replaceFirst('{price}', price);
```

why: board copy (08 HTML nodes 417/430/435/447/450/463/466/481/483/484/496/498/499/503).
`tierCatalogSlaFlexible` replaces the engineer-facing `tierSelectionSlaNone` ("No SLA") for the
opportunistic tier; the numeric bands keep rendering through the existing
`tierSelectionSlaHours/Minutes`. `tierCatalogCardSemanticLabel` is required, not optional: the old
`tierSelectionCardSemanticLabel` reads "…indicative price {price}", which becomes the nonsense
"indicative price Highest price" now that the dollar range is gone. Meta keys are new per C7 and
collide with none of the D20-banned vehicle strings (`decision_violations_test.dart:161-168`).

**Still needed from lane 07's batch** (this lane calls them too): `requestTypeMostPickedBadge`,
`requestTypeChangeCta`.
**No longer consumed by the screen after 08:** `tierFlashSummary`, `tierExpressSummary`,
`tierStandardSummary`, `tierOnTheWaySummary`, `tierEcoSummary`,
`requestTypeTierSummarySemanticLabel`. The catalog row decomposes that one-line summary into an SLA
chip + meta line + price caption, so those six keys land orphaned. Harmless (no orphan-key gate
exists) — drop them from the batch or keep them, integrator's call.

---

### cross-feature
file: lib/core/widgets/jeeb/jeeb_tier_row.dart (Wave-1 kit lane)
need: `JeebTierRow.catalog` overflows horizontally at large text scale — same defect class as 07's
W-7, one row further in.
exact change: in `_CatalogBody`, (a) let the price meter shrink or wrap — the `JeebPriceMeter`
column is unconstrained, so at `TextScaler.linear(2.0)` its `Balanced price` caption eats the whole
row and the emoji/name/badge `Expanded` is left 13px, overflowing by 30px; wrapping the meter in a
`Flexible` (or dropping the caption below a threshold) fixes it. (b) the badge in the same row is
non-flexible, so a long `Most picked` overflows by ~9px before the meter does.
why: measured on a throwaway probe reproducing the exact section tree — 360×640 @ 2.0 text scale
produced 5 `RenderFlex overflowed` exceptions inside `jeeb_tier_row.dart:374`; 440×956 at 1.0 is
clean, LTR and RTL. Not fixable from the feature side: the row internals are the kit's, and the
feature only passes strings in.

**Already satisfied by the frozen kit — no action:** `isEnabled` on `JeebCtaButton` (present);
`emoji`/`metaIcon` as `String`/`IconData` on `.catalog` (present); the `slaForceLtr` LTR isolate
with an opt-out for the prose label (present, and this screen passes
`slaForceLtr: tier.slaMinutes != null`); `JeebPriceMeter` dots as a plain Row with
`ExcludeSemantics` (present); the solid orange 10/w800 catalog badge and the
`0 10 22 rgba(11,19,81,.28)` selected-card shadow (present).

---

## Not requested (verified, no action needed)

- **No `route` request** — withdrawn, see the banner above.
- **No `di` request.** `TierRepository` is registered at `injection_container.dart:406`; the screen
  already resolves it through `RequestTypeScreen._resolveRepository()`.
- **No `theme` request.** Wave 0 landed; the section reads `context.jeebText.body` and
  `JeebSemanticColors.mutedText` only.

## Owner questions (decisions, not wiring)

1. **The badge sits on Flash, not Standard.** `tier_repository.dart:100` / `:189` flag **Flash** as
   `recommended`; the board draws the badge on **Standard**. The code renders the flag and never
   hardcodes a tier — moving it is a gateway/back-office call. (Same item as lane 07's W-6.)
2. **Badge wording.** The 08 board says `Recommended`, the 07 board says `Most picked`, and both
   now render in the same place on the same screen. This lane kept **lane 07's
   `requestTypeMostPickedBadge`** rather than reverting a shipped decision; if product prefers the
   08 wording, change the ARB value, not the call site.
3. **`Confirm tier` never ships.** The board's docked CTA belongs to the standalone screen; inside
   `/request-type` the docked CTA is 07's `Continue`, which is the same gesture. One CTA, one
   frozen identifier (`request_type_continue_cta`).
