# 24 · Order history — REVISED instruction set (authoritative)

Reviewed against: `screens/24-order-history.{png,html,note.md}`, the live source of all six lane
files, every cited test, `_BASELINE.md`, `00-MIGRATION-PLAN.md` (STOP block, §4.4, §7.5, §7.6),
`02-PLAN-ENHANCED.md` (R1/R5/R7/R9/R12), `03-WAVE1-KIT.md` **and the shipped kit source**
(`jeeb_select_chip.dart`, `jeeb_tier_chip.dart`, `jeeb_outlined_card.dart`). Every `file:line`
below was re-checked on 2026-08-03. Where this document contradicts the original proposal,
**this document wins**. (The proposal's "HTML `1417`"-style citations are `data-dc-tpl` ids, not
line numbers — the file is 98 lines; all cited tpl ids were verified real.)

Verdict: **rebuild of the presentation tree only.** Cubit / state / repository / domain /
`orders_resume_refetcher.dart` / `order_history_date_filter_sheet.dart` need **zero** changes —
no new field, no new call, no new endpoint, no route, no DI, no theme edit. The only wiring
request is one l10n batch (§6).

## What changed vs the original proposal

- **CUT all three kit wiring requests (WR-1/WR-2/WR-3) — the kit already ships everything.**
  The proposal was written against the pre-kit plan. Shipped reality:
  `JeebSelectChip` has `count` (`jeeb_select_chip.dart:104-111`, rendered as a **separate
  `Text`**, never concatenated — the source comment names 24's pinned `find.text('Active')`) and
  `leading` (`:113-115` — the doc literally says "24's 14px tune icon");
  `JeebChipRow.scrollable` is designated for 24 (`:241`); `JeebTierChip.custom` exists and is
  annotated "24 WR-3" in source (`jeeb_tier_chip.dart:100-110`); the role table already
  normalizes 24's pills — `filter` names "24 `Active 1`" (`jeeb_select_chip.dart:22-23`),
  `inlineAction` names "24 `Track` / `Jeeb it again`" (`:38-40`). WR-2's pad-divergence worry is
  therefore settled by the kit itself: consume the roles as shipped, divergence accepted.
- **CUT** the hand-rolled `SingleChildScrollView(child: JeebChipRow(...))` from the proposal's
  §1.3 — use `JeebChipRow.scrollable` (the kit source forbids wrapping it in a second scroll
  view, and its `padding` becomes the scroll padding so the trailing gutter scrolls).
- **CUT** the `order_history_tab_count_${tab.name}` identifier and the
  `orderHistoryTabCountSemantic` l10n key. The count renders **inside** `JeebSelectChip`
  (kit-pinned separate `Text`), is non-interactive, and cannot carry its own id without fighting
  the kit; 04 and 16 ship the identical count pattern with no such key. l10n batch: 6 → 5 keys.
- **CUT** `Semantics(value: order.dropoffAddress)` on the card and `explicitChildNodes: true` on
  `order_history_root`. Neither is render-evidenced; the kit card provides the child-id
  protection (below), and the root today does not swallow ids (all existing
  `bySemanticsIdentifier` finds pass against it as-is). Minimal diff wins.
- **CUT** the `isLive` constructor param — derive it inside the card from `order.status`. The
  old test harness (`order_history_card_test.dart:27-34`) then compiles with just two new
  **nullable** callbacks, and there is a single source of truth for the frame/dot/ink logic.
- **CORRECTED the card-semantics mechanism.** Do not keep the manual
  `Semantics`+`InkWell` sandwich. Pass `identifier` / `semanticLabel` / `onTap` /
  `key` to the kit card: `JeebOutlinedCard` emits exactly one
  `Semantics(identifier:, label:, button:, container: true, explicitChildNodes: true)` node
  (`jeeb_outlined_card.dart:207-222`), which reproduces today's node — value-identical id and
  label — *plus* the `explicitChildNodes` the new nested pills need. A manual wrapper around the
  kit card would produce nested duplicate button nodes.
- **CORRECTED the glyph table — `pending` was missing.** The proposal's table covered 7 of the 8
  `OrderRequestStatus` values. `orders_stale_status_chip_test.dart` pumps `pending` rows into
  the **real screen** through a scripted repository (`:185-199`), so the card must render it:
  `pending` joins the accent-dot row (active bucket).
- **CORRECTED** `home_tab.dart:209` — that file does not exist. The real `request-type`
  precedents are `pending_requests_tab.dart:77`, `in_progress_tab.dart:131`,
  `no_offer_timeout_screen.dart:318` (all `pushNamed('request-type')`).
- **CORRECTED the amount style**: `context.jeebText.body.copyWith(fontWeight: FontWeight.w800)`,
  not `cardTitle`. Design is 14/w800; the ramp has `body` 13.5 and `cardTitle` 15.5 — 13.5 is
  the nearest entry **and** preserves the render's title(15) > amount(14) size ranking.
- **CORRECTED the identity-row gap**: `Spacing.xSmall` (8 ≈ design 9), not `Spacing.small` (12).
- **CORRECTED the date chip**: today's `OmdsChip` becomes
  `JeebSelectChip(role: JeebChipRole.quickReply, leading: <tune icon>)`. The kit's `leading` doc
  pairs "24's 14px tune icon" with "09's 14px category icon", and 09's category pills are the
  `quickReply` scale — the kit's navy-ink `8/13 · 12/w600`, the normalized nearest to the
  measured `8/14 · 12.5/w600` navy. (`filter` at `11/20 · 14.5` would render the date chip the
  same size as the tab pills, inverting the board's hierarchy.)
- **KEPT all three refusals** (§2), re-verified: `order_status_bucketing_test.dart:57` pins
  `expired` → `cancelled` (no `Re-broadcast` split possible); the kit's own `dormant` doc says
  "no shipping screen should reach for this today" (`jeeb_outlined_card.dart:15-20`); the
  money-truth tests (`order_history_card_test.dart:46-67`) pin `—` + `Amount unavailable` in the
  slot the board gives to `no offers`.
- **KEPT the Track routing decision** (same destination as the row tap). Verified:
  `/orders/:id/tracking` resolves a *delivery* id (`app_router.dart:1351`,
  `resolveTrackingDeliveryId`); working callers pass `?deliveryId=` from
  `ClientHomeRequest.trackingId`/`deliveryId` (`in_progress_tab.dart:55-70`) — fields
  `OrderSummary` does not have. A direct deep-link would fabricate an id.
- **KEPT the "cubit/state/data: zero changes" verdict.** The count badge is a pure derivation of
  the existing `OrderTabState` (`status`/`hasMore`/`orders`) — allowed by §7.6.

---

## 0. Preconditions & kit consumption

The kit **exists and is frozen** — import it, never copy it. This lane consumes:

| Kit widget | Import (`package:jeeb_mobile/core/widgets/jeeb/…`) | Params used |
|---|---|---|
| `JeebOutlinedCard` | `jeeb_outlined_card.dart` | `key`, `child`, `radius: 18`, `padding`, `onTap`, `identifier`, `semanticLabel` — defaults give `1.5px colorScheme.outline`, no shadow. **Never pass `state: dormant`** (§2) |
| `JeebAccentFrameCard` | `jeeb_accent_frame_card.dart` | same param set; `radius: 18` — its own doc says "18 for screens 18 and 24"; delegates to the outlined card with a `2px jeebRoles.accent` frame |
| `JeebSelectChip` | `jeeb_select_chip.dart` | `role`, `label`, `selected`, `onTap`, `count`, `leading`, `identifier` |
| `JeebChipRow.scrollable` | `jeeb_select_chip.dart` (co-located) | `children`, `padding` (becomes the scroll padding) |
| `JeebTierChip.custom` | `jeeb_tier_chip.dart` | `emoji: JeebTierChip.emojiFor(order.tier.name)`, `label:` — keeps the ⚡🚀🟦🤝🌿 lexicon central; `OrderTier` is this feature's own enum and is **not** mapped through a shared type |
| `JeebShadows.stepGlow` | `core/theme/jeeb_shadows.dart` | the live dot's halo (`0 0 0 5 @18%` ≈ the board's `0 0 0 3 @20%` — accepted kit normalization; no hand-rolled `BoxShadow` in this feature) |

Card padding: pass `EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: 14)`
— the kit card's own doc records "24 passes 14/16", and it folds the stroke width in itself
(border-box correction, `jeeb_outlined_card.dart:172-177`). Do not hand-correct the ±1.5px.
The `vertical: 14` literal is a kit *parameter* carrying a design-exact px the kit documents —
sanctioned by §4.4's two-tier rule; `tool/check_design_tokens.sh` does not flag
`EdgeInsetsDirectional`.

Token access: `context.jeebText`, `context.jeebRoles`, `Theme.of(context).colorScheme`,
`JeebShadows`. **Never `Theme.of(context).extension<JeebSemanticColors>()!`** — the shared test
harness (`test/support/sync_app_localizations.dart`) builds on a theme where the bang crashes,
and this screen needs nothing from it. Periwinkle = `colorScheme.onSecondaryContainer`; live
orange = `context.jeebRoles.accent`; success green = `context.jeebRoles.success` (#1B7A3D — the
board's raw `#2E7D32` fails the repo's contrast gate and is bridged per plan §4.1).

Files this lane may touch: `lib/features/order_history/presentation/order_history_screen.dart`,
`order_history_card.dart`, `order_status_chip.dart`, plus this screen's tests. Nothing else.

---

## 1. Semantics inventory

### 1.1 FROZEN — every value must still be emitted, byte-identical (verified 2026-08-03)

| Identifier | Source today | After the rebuild |
|---|---|---|
| `order_history_root` | `order_history_screen.dart:85` | same wrapper, **unchanged** (`container: true` only) |
| `order_history_active_tab` | `:97` | same `Semantics(container: true, button: true)` wrapper; child becomes `JeebSelectChip` (chip gets **no** `identifier` of its own — it then adds no node and merges into the frozen wrapper) |
| `order_history_completed_tab` | `:103` | ″ |
| `order_history_cancelled_tab` | `:109` | ″ |
| `order_history_filter_chip` | `:168` | same wrapper, moves into the new header row |
| `order_history_card_${order.id}` | `order_history_card.dart:46` | **re-homed onto the kit card's `identifier:` param** — value and `label:` (`orderHistoryCardSemanticLabel`) identical; kit emits `button/container/explicitChildNodes` (§0) |
| `order_history_sheet_from_cta` / `_to_cta` | `order_history_date_filter_sheet.dart:187` (`${fieldId}_cta`) | **file untouched** |
| `order_history_sheet_from_clear_cta` / `_to_clear_cta` | `:203` | **file untouched** |
| `order_history_sheet_clear_cta` / `_apply_cta` | `:112` / `:129` | **file untouched** |

Frozen widget `Key`s (asserted across the three test files): `order-history-filter-chip`,
`order-history-loading`, `order-history-error`, `order-history-empty-<tab>`,
`order-history-list-<tab>`, `order-history-loading-more`, `order-history-card-<id>`,
`order-history-filter-from|to|clear|apply` (sheet — untouched). `order-history-card-<id>` moves
from the deleted `InkWell` to the kit card's `key:` — `tester.tap(find.byKey(...))` taps the
widget's centre and lands on the kit card's internal `InkWell`.

### 1.2 NEW (convention `<screen>_<element>_<suffix>`)

| Identifier | Widget | How |
|---|---|---|
| `order_history_track_cta_${order.id}` | the navy `Track` pill | `JeebSelectChip(identifier: …)` — the chip then emits its own `button/selected/container/explicitChildNodes` node |
| `order_history_reorder_cta_${order.id}` | the outlined `Jeeb it again` pill | ″ |

These survive **because** the kit card's node has `explicitChildNodes: true` — without the §0
re-homing they would be swallowed by the card's `button: true` node and invisible to
`find.bySemanticsIdentifier` (silent failure).

---

## 2. Deliberate divergences from the board (each one-line reversible; note in the PR)

| Board | Ship | Why |
|---|---|---|
| `ETA 20 min` (tpl 1434) | omitted | no ETA field anywhere on `GET /v1/requests` (`dio_order_repository.dart:159-198` reads none). `// TODO(redesign-24): needs gateway eta on GET /v1/requests — omitted, not faked.` |
| item title `Medicine — Pharmacie du Musée` (tpl 1430) | `order.pickupAddress` (empty → `orderHistoryAddressMissing`) | no item/description field on the list DTO; pickup is the real "where from" the board is naming |
| `Karim` · `★ rated 4` (tpl 1444) | `date · status` | no jeeber identity or rating on the list DTO. (If rating data ever appears, ★ inherits surrounding ink — never `starRatingColor` here, plan §4.1) |
| `no offers` in the amount slot (tpl 1462) | `—` | **REFUSED** — no offer-count field exists, and `order_history_card_test.dart:46-67` pins `—` + `Amount unavailable` (T11/SW-02 money truth; this slot already regressed once as `$0.00`) |
| `Re-broadcast` (tpl 1464) | `Jeeb it again` (same pill as completed rows) | **REFUSED** — (1) `OrderRequestStatus.parse` folds `expired` into `cancelled` (`order_summary.dart:66-69`) and `order_status_bucketing_test.dart:57` pins it; (2) no re-broadcast endpoint exists (the only "Re-broadcast" in the app dead-ends terminal requests); (3) the word promises a server action the client cannot take. The designer's intent — a way forward instead of a dead end — is served by the same re-compose action |
| whole cancelled card at `opacity: .65` (tpl 1457) | full opacity; periwinkle ✕ glyph + periwinkle meta carry the de-emphasis | **REFUSED** — `.65` over 12/w600 periwinkle drops below AA on white; the kit's `dormant` state exists but its own doc says no shipping screen should use it (R9/§7.2-C4) |
| `Active 1` badge unconditional | badge only when `status == ready && !hasMore && orders.isNotEmpty` | a loaded-lower-bound count is a lie (`Completed 20` for 340 orders); a never-loaded tab has no number at all (`selectTab` is lazy, `order_history_cubit.dart:26-32`) |
| `Jun 26 · Karim · …` one string | date `Text` · Ø3 dot `Container` · status `Text` | `orders_stale_status_chip_test.dart:191/241/264` pin `find.text('Pending'/'Picked up'/'En route')` — concatenation breaks all of them. The dot is a shape, not a `'·'` string: no l10n key, no bidi hazard |
| tab pills `9/18 · 13`, date chip `8/14 · 12.5`, action pills `8/15 · 12` | kit `filter` (`11/20 · 14.5`), `quickReply` (`8/13 · 12`), `inlineAction` (`9/18 · 13`) | the kit normalized all five pill scales once (R2); lanes pass a role, never a size |

Dropped row content (owner-visible, per the board): the **dropoff address** and, on
non-active rows, the **tier chip** leave the card. Both remain on `/orders/:id`.

---

## 3. Task list — execute top to bottom

**Task 1 — Write the wiring file.** Create `docs/redesign-2026-08/wiring/24-order-history.md`
with the exact §6 block. From here on, write code as if the l10n batch were granted (the lane
won't compile until the integrator lands it — expected; say so in your report).

**Task 2 — `order_status_chip.dart`: slim to the label helper. DO NOT DELETE THE FILE.**
`test/core/theme/no_raw_semantic_colors_test.dart:36` lists this exact path and `:64-65` asserts
it exists. Delete the `OrderStatusChip` widget, `_paletteFor`, and `_ChipPalette` (no other file
in `lib/` constructs the widget — verified). Keep the status→string switch as a top-level
helper, verbatim logic:
```dart
String orderStatusLabel(OrderRequestStatus status, AppLocalizations l10n) { /* the switch from :62-81, unchanged */ }
```
Drop the now-unused imports (`omds`, `jeeb_color_roles`). The file stays hex-free, which the
gate re-checks.

**Task 3 — `order_history_card.dart`: rebuild.**
Constructor (old harness compiles unchanged — new params nullable):
```dart
const OrderHistoryCard({super.key, required this.order, required this.onTap, this.onTrack, this.onReorder});
```
Derivations inside `build`: `isLive = order.status == OrderRequestStatus.pickedUp ||
order.status == OrderRequestStatus.enRoute`; the existing money block (`:38-43`) copied
**verbatim**; `dateLabel = DateFormat.MMMd(locale).format(order.createdAt.toLocal())` —
`.toLocal()` preserved (SW-03 is that test's real subject).

Shell — one of two kit widgets, **status-driven, never index-driven** (R5: orange marks what is
moving *now*; `matched` is assigned-not-moving; in practice ≤1 frame renders, matching the
board):
```dart
// isLive → JeebAccentFrameCard, else JeebOutlinedCard; identical param set:
key: Key('order-history-card-${order.id}'),            // FROZEN
identifier: 'order_history_card_${order.id}',          // FROZEN value
semanticLabel: l10n.orderHistoryCardSemanticLabel(order.id),  // FROZEN
onTap: onTap,
radius: 18,
padding: const EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: 14),
child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min,
  children: [ _IdentityRow(...), const SizedBox(height: Spacing.small), _MetaRow(...) ]),
```
Delete: `_Header`, both `_AddressLine` usages + class, `_Footer`, `_TierBadge`, the
`order_status_chip.dart` widget import (keep the import for `orderStatusLabel`).

`_IdentityRow` — `Row[ glyph, SizedBox(width: Spacing.xSmall), Expanded(title), SizedBox(width:
Spacing.xSmall), amount ]`:

| Status | Glyph (all `Sizes.medium` = 16) |
|---|---|
| `pending`, `matched`, `pickedUp`, `enRoute`, `unknown` | Ø9 `Container` (`BoxShape.circle`, `jeebRoles.accent`); `boxShadow: isLive ? JeebShadows.stepGlow : null` — the halo belongs to motion only |
| `delivered` | `Icons.check_circle`, `jeebRoles.success` |
| `cancelled` | `Icons.cancel`, `colorScheme.onSecondaryContainer` |
| `disputed` | `Icons.error`, `colorScheme.error` |

Title: `context.jeebText.cardTitle` + `colorScheme.primary`, `maxLines: 1`, ellipsis.
Amount: `context.jeebText.body.copyWith(fontWeight: FontWeight.w800)`; ink
`colorScheme.primary` when known, `colorScheme.onSurfaceVariant` for the muted `—`; keep
`semanticsLabel: amountSemantics`.

`_MetaRow` — `Row[ tierChip?, date, dot, status, Spacer(), pill? ]`, gaps `Spacing.twoXSmall`
around the dot, `Spacing.xSmall` after the tier chip:
- tier chip — **active-bucket rows only** (`order.status.tab == OrderHistoryTab.active`):
  `JeebTierChip.custom(emoji: JeebTierChip.emojiFor(order.tier.name), label: _tierLabel(order.tier, l10n))`
  — keep the existing `_tierLabel` switch (`:195-208`) as a private helper.
- date: `Text(dateLabel)`, `jeebText.bodySmall` + `onSecondaryContainer`, `maxLines: 1`.
- dot: Ø3 `Container` circle, `onSecondaryContainer` — decorative.
- status: `Flexible(Text(orderStatusLabel(order.status, l10n), maxLines: 1, overflow: ellipsis))`,
  `jeebText.bodySmall`; ink `jeebRoles.accent` when `isLive`, else `onSecondaryContainer`.
  **Date and status stay separate `Text`s** (§2). `Flexible` is the 200%-text discipline — an
  ellipsized `Text` still matches `find.text(...)`.
- pill:
  - `isLive && onTrack != null` → `JeebSelectChip(role: JeebChipRole.inlineAction, selected:
    true, label: l10n.orderHistoryTrackCta, onTap: onTrack, identifier:
    'order_history_track_cta_${order.id}')` — selected = navy fill + white ink.
  - `(delivered || cancelled || disputed) && onReorder != null` → same chip, `selected: false`
    (white + 1.5px outline + navy), `label: l10n.orderHistoryReorderCta`, `identifier:
    'order_history_reorder_cta_${order.id}'`, `onTap: onReorder`.
  - `pending` / `matched` / `unknown` → no pill.

**Task 4 — `order_history_screen.dart`: header (`_FilterBar` → `_HistoryHeader`).**
```dart
Padding(
  padding: const EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0), // tpl 1417
  child: Row(children: [
    Expanded(child: Text(l10n.navDelivery,           // EN "Delivery" / AR "التوصيل" — existing key, NO new l10n
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: context.jeebText.h2.copyWith(color: colorScheme.primary))),
    const SizedBox(width: Spacing.xSmall),
    Semantics(identifier: 'order_history_filter_chip', container: true, button: true, // FROZEN wrapper
      child: JeebSelectChip(
        key: const Key('order-history-filter-chip'),                                  // FROZEN key
        role: JeebChipRole.quickReply,               // kit-normalized nearest scale — see "What changed"
        label: _rangeLabel(state.dateRange, locale, l10n),
        leading: Icon(Icons.tune, size: Sizes.medium, color: colorScheme.primary),
        onTap: () => _openFilter(state.dateRange))),
  ]))
```
- `_rangeLabel`: empty → `l10n.orderHistoryFilterCta` (existing); both ends →
  `l10n.orderHistoryFilterRange(fmt(range.from!), fmt(range.inclusiveToDay!))` with
  `fmt = DateFormat.MMMd(locale).format`; from-only → `orderHistoryFilterRangeFrom`; to-only →
  `orderHistoryFilterRangeTo`. `inclusiveToDay` (`order_summary.dart:246`) is the *displayed*
  end day. `range.from`/`inclusiveToDay` are already local — no `.toLocal()`.
  `orderHistoryFilterActive` becomes unused by this screen — **leave the key in the ARBs**
  (retiring keys is the integrator's call).
- **Large-text fallback survives, restructured**: keep `_kLargeFilterTextScaleThreshold` (`:17`);
  above 1.5× render a `Column` — title row, then the chip (leading icon dropped, as today) inside
  a horizontal `SingleChildScrollView`. `order_history_screen_test.dart:252-385` runs the whole
  flow at 2× and taps the chip; an overflow is a test failure.

**Task 5 — `order_history_screen.dart`: tab row (`TabBar` → pills).**
- **Keep** `TabController`, the `_onTabChanged` listener, and `TabBarView` (`:116-124`) — they
  carry swipe, `AutomaticKeepAliveClientMixin` retention, and `cubit.selectTab`. **Delete** the
  `TabBar` (`:93-115`) only — the board has three free-standing content-width pills, no
  indicator, no 48px Material row (tpl 1422 is a plain `flex; gap:8`).
```dart
JeebChipRow.scrollable(                              // never wrap in a second scroll view
  padding: const EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0),
  children: [
    for (final (index, tab) in OrderHistoryTab.values.indexed)
      Semantics(                                     // FROZEN wrappers, values verbatim
        identifier: 'order_history_${tab.name}_tab', // active|completed|cancelled — matches :97/:103/:109
        container: true, button: true,
        child: JeebSelectChip(
          role: JeebChipRole.filter,
          label: _tabLabel(tab, l10n),               // bare Text — find.text('Active') stays pinned
          selected: state.activeTab == tab,
          count: _tabCount(state, tab),              // int? — see below
          onTap: () => _tabController.animateTo(index))), // re-enters _onTabChanged → cubit.selectTab
  ])
```
- `_tabCount`: `final t = state.tabs[tab]!; return (t.status == OrderTabStatus.ready &&
  !t.hasMore && t.orders.isNotEmpty) ? t.orders.length : null;` — `hasMore` is the honesty gate;
  `pending` rows never reach this list (`dio_order_repository.dart` drops `isOnHold` rows), so
  the number is the true Delivery-tab count. Pure derivation of existing state (§7.6).
- The chip renders the count as its own `Text`/badge (selected → inline text, unselected → Ø18
  accent badge) — **never** build `'Active 1'` as one string.
- Scrollability is the 2×-text overflow escape; direction inherits, so AR mirrors for free.

**Task 6 — `order_history_screen.dart`: list chrome (`_OrderTabViewState.build`, `:302-333`).**
- **Delete** `separatorBuilder: (_, _) => const Divider(height: 1)` (`:309`) → `const
  SizedBox(height: Spacing.small)` (12 ≈ board 11; R7/R12 — outlines are the separation).
- Replace `padding:` (`:307`) with `EdgeInsetsDirectional.only(start: Spacing.xLarge, end:
  Spacing.xLarge, top: Spacing.medium, bottom: context.scrollBodyBottomInset + Spacing.xLarge)`
  (`scrollBodyBottomInset` from `core/layout/bottom_inset.dart`).
- Item builder: keep the role-aware `onTap` closure (`:325-329`) **byte-identical** — it is
  BUG-A, pinned by `order_history_screen_test.dart:229-250`. Add:
  `onTrack:` the **same** role-aware push (Track = the sanctioned entry to the detail surface;
  deep-linking `/orders/:id/tracking` would fabricate a delivery id — `// TODO(redesign-24):
  needs gateway trackingId on GET /v1/requests to deep-link tracking — routed to the detail
  surface instead, not faked.`), and
  `onReorder: () => GoRouter.of(context).pushNamed('request-type')` — the create-flow entry every
  sibling uses (`pending_requests_tab.dart:77`, `in_progress_tab.dart:131`,
  `no_offer_timeout_screen.dart:318`). Seeding a draft is impossible honestly
  (`RequestDraft.description` is required and `OrderSummary` has no description) —
  `// TODO(redesign-24): needs the request description/tier on GET /v1/requests to pre-fill the
  re-compose — entering the create flow unseeded, not faked.`
- Loading / error / empty branches (`:264-300`): keep widgets **and keys** unchanged. Do **not**
  wrap the empty state in `Center`/`Expanded` — R1: the residual space stays white and
  top-aligned. Keep `OmdsPullToRefresh` on both branches.

**Task 7 — Test updates (contracts kept, mechanisms changed).**
| Test | Change |
|---|---|
| `test/features/order_history/order_history_card_test.dart:78-87` | expectation `DateFormat.yMMMd('en').add_jm()` → `DateFormat.MMMd('en')` — deliberate (board meta reads `Jun 26`). **Keep** the `.toLocal()` subject |
| same file, `_pump` (`:27-34`) | compiles unchanged (nullable callbacks) — verify, don't edit |
| `test/order_history_screen_test.dart` | no edits required — all taps go through frozen ids/keys; run it |
| `orders_stale_status_chip_test.dart` | no edits — status is a standalone `Text`; refetcher/cubit untouched |
| sheet goldens (×3, `test/features/order_history/goldens/`) | this lane changes nothing inside the sheet; if Wave-0 theme flips moved them, regeneration is the Wave-5 sweep's job on the Mac Studio — not yours |

**Task 8 — New tests (additive).**
- Card: `enRoute`/`pickedUp` render `JeebAccentFrameCard`; every other status renders
  `JeebOutlinedCard` (`find.byType`); `pending` renders (stale-suite parity) with no pill.
- Card: Track pill present+tappable only when live; reorder pill on
  delivered/cancelled/disputed; neither for `matched`; ids
  `order_history_track_cta_*` / `order_history_reorder_cta_*` resolvable via
  `find.bySemanticsIdentifier` (proves the kit card's `explicitChildNodes` protection).
- Screen: add a `request-type` named `GoRoute` to `_host`; `Jeeb it again` reaches it; `Track`
  lands on `/orders/:id` (client) and `/jeeber/deliveries/:id/active` (jeeber role) — reuse the
  BUG-A harness pattern.
- Screen: count badge absent while `hasMore` is true (pageSize 2, 3 orders), present
  (`find.text('1')`) when the tab is fully loaded.
- AR smoke: pump the screen under `Locale('ar')` — header + one card, no overflow exception.
- 200% smoke: header row at 2× — no overflow exception (the Column fallback).

**Task 9 — Gates.**
`flutter analyze` (bar: the same 5 baseline infos, **0 errors, nothing new**);
`flutter test test/order_history_screen_test.dart test/features/order_history/
test/core/theme/no_raw_semantic_colors_test.dart test/decision_violations_test.dart`;
`bash tool/check_design_tokens.sh`;
`grep -rn "identifier:" lib/features/order_history/` diffed against §1 (every frozen value
present, nothing renamed). Report which steps were blocked on the l10n wiring batch.

---

## 4. Stop conditions

**Done means:** the three presentation files match §3; every §1 identifier and key greps
value-identical; `order_status_chip.dart` still exists and is hex-free; the Task-9 suites are
green except the date-format update in Task 7 and any compile dependency on the §6 l10n batch
(both called out in the report); zero new analyze issues; token script clean; the §2
divergences (count-badge gating, dropped dropoff/tier, full-opacity cancelled rows) are listed
in the PR notes for the owner.

**Do NOT touch:** `order_history_date_filter_sheet.dart` (its ids/keys/goldens are frozen and
the board is silent on it); `orders_resume_refetcher.dart`; anything under `application/`,
`data/`, `domain/`; `lib/core/**` (kit, router, DI, theme, layout); `lib/l10n/*`;
`pubspec.yaml`; `test/support/*`; any other feature; the four `_BASELINE.md` failures. Do not
delete `order_status_chip.dart`. Do not add `Opacity`/`dormant` to any card. Do not render an
ETA, a jeeber name, a rating, an offer count, or `Re-broadcast`. Do not concatenate date+status
or label+count into one string. Do not re-order or rename `OrderRequestStatus`/`OrderTier`
members. Do not convert the row `onTap` destination logic.

**Maestro (not CI — silent rot risk):**
`.maestro/jeeb/devices/RFCX306JSRT/flows/pages/_delivery-history.yaml` drives this screen **by
coordinates** (`50%,8%` filter; `17|50|83%,14%` tabs). The new title row pushes both bands down
(~14% / ~24%). The flow is screenshot-only, so a mis-tap produces wrong screenshots silently.
After landing, re-verify on the S22 — or better, convert the page object to `id:` selectors:
all four ids it needs are frozen and present.

---

## 5. Explicitly out of scope (cut from the original proposal)

- All three kit wiring requests (WR-1/WR-2/WR-3) — already shipped in Wave 1 (see "What changed").
- The `order_history_tab_count_*` identifier and `orderHistoryTabCountSemantic` key.
- `Semantics.value` for the dropoff address; root-node `explicitChildNodes`.
- The 5-tab bottom bar (tpl 1466-1487) — `_JeebBottomBar` in `shell_screen.dart`, another lane.
- The date-filter sheet restyle — zero design evidence, three committed goldens; separate
  follow-up if the owner wants it.
- Retiring `orderHistoryFilterActive` from the ARBs — integrator's call.
- `JeebTopBar` / `JeebProfileHeader` / `JeebCtaFooter` — shell tab body, no back affordance, no
  avatar, and the docked element is the shell's tab bar, not a CTA.

---

## 6. Wiring requests — final text for `docs/redesign-2026-08/wiring/24-order-history.md`

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: five new strings for the order-history redesign (date-range chip label ×3, two row CTAs).
exact change:
app_en.arb —
```json
  "orderHistoryFilterRange": "{from} – {to}",
  "@orderHistoryFilterRange": { "description": "Order-history date chip when both ends are set (order_history_filter_chip). {from}/{to} are DateFormat.MMMd outputs, e.g. 'Jun 1 – 30'.", "placeholders": { "from": { "type": "String", "example": "Jun 1" }, "to": { "type": "String", "example": "Jun 30" } } },
  "orderHistoryFilterRangeFrom": "From {from}",
  "@orderHistoryFilterRangeFrom": { "description": "Order-history date chip, open-ended start.", "placeholders": { "from": { "type": "String", "example": "Jun 1" } } },
  "orderHistoryFilterRangeTo": "Until {to}",
  "@orderHistoryFilterRangeTo": { "description": "Order-history date chip, open-ended end.", "placeholders": { "to": { "type": "String", "example": "Jun 30" } } },
  "orderHistoryTrackCta": "Track",
  "@orderHistoryTrackCta": { "description": "Navy pill on the live order-history row (order_history_track_cta_<id>). Routes to the role-aware delivery detail." },
  "orderHistoryReorderCta": "Jeeb it again",
  "@orderHistoryReorderCta": { "description": "Outlined pill on completed/cancelled order-history rows (order_history_reorder_cta_<id>). Enters the create flow (request-type), unseeded." },
```
app_ar.arb —
```json
  "orderHistoryFilterRange": "{from} – {to}",
  "orderHistoryFilterRangeFrom": "من {from}",
  "orderHistoryFilterRangeTo": "حتى {to}",
  "orderHistoryTrackCta": "تتبّع",
  "orderHistoryReorderCta": "اطلبها مرة ثانية",
```
app_localizations.dart (house pattern — `_get` + `replaceFirst`, alphabetical among the
`orderHistory*` getters) —
```dart
  String orderHistoryFilterRange(String from, String to) => _get('orderHistoryFilterRange')
      .replaceFirst('{from}', from)
      .replaceFirst('{to}', to);
  String orderHistoryFilterRangeFrom(String from) =>
      _get('orderHistoryFilterRangeFrom').replaceFirst('{from}', from);
  String orderHistoryFilterRangeTo(String to) =>
      _get('orderHistoryFilterRangeTo').replaceFirst('{to}', to);
  String get orderHistoryTrackCta => _get('orderHistoryTrackCta');
  String get orderHistoryReorderCta => _get('orderHistoryReorderCta');
```
why: the redesigned header replaces the bare "Filter by date"/"Date filter applied" chip with a
readable range label, and the rows gain the note's Track / "Jeeb it again" retention actions —
all user-visible, bilingual. No plural family needed (all placeholders are pre-formatted
strings). Title reuses the existing `navDelivery`; tab/status/empty/error strings are all
existing keys.
