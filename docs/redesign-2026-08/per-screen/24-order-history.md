# 24 · Order history — change proposal

**Target files (lane-owned):** `lib/features/order_history/`
- `presentation/order_history_screen.dart` (348 LOC)
- `presentation/order_history_card.dart` (248 LOC) — **rebuilt**
- `presentation/order_status_chip.dart` (88 LOC) — **deleted as a pill, its labels survive as text**
- `presentation/order_history_date_filter_sheet.dart` (216 LOC) — **untouched** (§9-R3)
- `presentation/orders_resume_refetcher.dart`, `application/*`, `data/*`, `domain/*` — **untouched**

**Verdict: rebuild.** The cubit/state/repository/refetcher layers need **zero** changes — no new
field, no new call, no new endpoint. The presentation tree is replaced end to end: the bare filter
bar becomes a title + date-range header, the Material `TabBar` becomes a pill row with counts, and
the 4-row divider-separated list row becomes a 2-row outlined card with a live orange frame and a
trailing action pill.

Design sources read in full: `screens/24-order-history.png` (render, 440×956 @2x),
`screens/24-order-history.html` (every `data-dc-tpl` cited below), `screens/24-order-history.note.md`.

---

## 0. What the render actually shows (measured, before any opinion)

| Band | HTML | Measured |
|---|---|---|
| Header row | `1417–1421` | pad `16/24/0`; title `Delivery` 20/w700 navy, `flex:1`; trailing pill pad `8/14` r999 `1.5px --jeeb-brown-outline`, 12.5/w600 navy, 14px tune glyph, gap 6, label `Jun 1 – 30` |
| Tab row | `1422–1425` | pad `16/24/0`, gap 8; selected pill pad `9/18` r999 navy fill / white 13/w600, label `Active 1`; unselected pill same pad, `1.5px --jeeb-brown-outline`, ink `--jeeb-brown-subtitle` (= `onSurfaceVariant`) |
| List | `1426` | pad `16/24/0`, **column gap 11**, no dividers |
| Live card | `1427–1436` | `2px --jeeb-orange` r18 pad `14/16`. Row 1: Ø9 orange dot + `0 0 0 3 rgba(215,59,0,.2)` halo, gap 9, title 15/w700 navy 1-line ellipsis `flex:1`, amount 14/w800 navy. Row 2 (`margin-top 11`): tier chip pad `4/10` r999 `--jeeb-surface-high` 11.5/w700 navy → status text 12/w600 **orange** → `flex:1` spacer → `Track` pill pad `8/15` r999 navy/white 12/w600 |
| Completed card | `1437–1446` | `1.5px --jeeb-brown-outline` r18 pad `14/16`. Row 1: 16px filled check `#2E7D32`, title, amount. Row 2 (`margin-top 11`): meta 12/w600 **periwinkle** `Jun 26 · Karim · ★ rated 4` → spacer → `Jeeb it again` pill pad `8/15` `1.5px outline` navy 12/w700 |
| Cancelled card | `1457–1464` | same outline card at **`opacity .65`**; 16px filled ✕ periwinkle; trailing slot reads `no offers` 13/w700 periwinkle; row 2 is a single 12/w600 periwinkle line `Jun 20 · expired · ` + `Re-broadcast` in orange w700 — **no action pill** |
| Spacer + tab bar | `1465–1487` | `flex:1` real emptiness (~45% of the viewport is white), then the shared 5-tab bar |

Three of those measurements are the whole argument of this document: **11px card gaps and no
dividers** (R12), **a `flex:1` spacer nobody may fill** (R1), and **exactly one orange frame** (R5).

---

## 1. Layout & structure

### 1.1 Screen skeleton — `order_history_screen.dart:84-127`

Keep the outer `Semantics(identifier: 'order_history_root', container: true)` and the `Column`.
Add `explicitChildNodes: true` (§7.5) — the card now contains nested interactive children and the
root must not swallow them.

```
Semantics(identifier: 'order_history_root', container: true, explicitChildNodes: true,
  child: Column(children: [
    _HistoryHeader(range: state.dateRange, onFilterTap: …),   // NEW — replaces _FilterBar
    _HistoryTabRow(controller: _tabController, state: state), // NEW — replaces TabBar
    Expanded(child: TabBarView(controller: _tabController, children: [ … ])),
  ]))
```

**Keep** `TabController` + `TabBarView` (`:116-124`). They carry swipe-between-tabs,
`AutomaticKeepAliveClientMixin` scroll retention, and `_onTabChanged → cubit.selectTab`. Only the
*indicator widget* changes. Replacing the controller as well would be a gratuitous behaviour change.

**Delete** `TabBar` (`:93-115`). The design has no underline indicator, no 48px Material tab height
and no ripple-filling row — it has three free-standing pills at 24px gutters.

**Design evidence:** HTML `1422` is a plain `display:flex; gap:8` of three `border-radius:999px`
spans; there is no track, no indicator and no equal-width distribution (the pills are
content-width). Render confirms: `Active 1` is visibly narrower than `Completed`.

### 1.2 `_HistoryHeader` — replaces `_FilterBar` (`order_history_screen.dart:152-200`)

```
Padding(
  padding: const EdgeInsetsDirectional.fromSTEB(
    Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0),   // 24 / 16 / 24 / 0  ← HTML 1417
  child: Row(children: [
    Expanded(child: Text(l10n.navDelivery,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: context.jeebText.h2.copyWith(color: cs.primary))),   // 20/w700 navy
    const SizedBox(width: Spacing.small),
    <the filter chip, unchanged identifier>,
  ]))
```

- **Title string reuses `l10n.navDelivery`** — EN `"Delivery"`, AR `"التوصيل"`, already shipped and
  already the shell tab's own label. **No new l10n key.** (HTML `1418` literally reads `Delivery`.)
- The chip keeps `Semantics(identifier: 'order_history_filter_chip')` and
  `Key('order-history-filter-chip')` verbatim (`:167-178`) — two tests tap it.
- **Large-text fallback survives, restructured.** `_kLargeFilterTextScaleThreshold` (`:17`) stays,
  but above 1.5× the header becomes a `Column` (title, then a horizontally scrollable icon-free
  chip) instead of the current icon-free-`Row`. A title + chip on one row at 2× overflows;
  `order_history_screen_test.dart:252` runs the whole screen at 2× and taps that chip.

### 1.3 `_HistoryTabRow` — NEW

```
Padding(
  padding: const EdgeInsetsDirectional.fromSTEB(
    Spacing.xLarge, Spacing.medium, Spacing.xLarge, 0),   // HTML 1422
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: JeebChipRow(children: [ for each tab → JeebSelectChip(...) ])))
```

Each pill keeps its existing `Semantics(identifier: 'order_history_{active|completed|cancelled}_tab',
container: true, button: true)` wrapper — **values frozen**, only the child changes from `Tab` to
`JeebSelectChip`. `onTap` → `_tabController.animateTo(index)` (which re-enters `_onTabChanged` and
drives `cubit.selectTab`, exactly as the `TabBar` did).

The label stays a plain `Text` of `l10n.orderHistoryTab*` so `find.text('Active')` keeps matching
(`order_history_screen_test.dart:187-189`). **The count is a separate badge widget, never string
concatenation** — `'Active 1'` as one string would break that test.

`SingleChildScrollView` (not a fixed `Row`) because at 2× text three pills at pad `9/18` exceed
390pt; it also must NOT force a direction — direction inherits so AR mirrors.

### 1.4 The list — `order_history_screen.dart:302-333`

```
OmdsPullToRefresh(
  onRefresh: …,                                            // unchanged
  child: ListView.separated(
    key: Key('order-history-list-${widget.tab.name}'),      // FROZEN
    controller: _scrollController,                          // unchanged (infinite scroll)
    padding: EdgeInsetsDirectional.only(
      start: Spacing.xLarge, end: Spacing.xLarge,           // 24 gutters ← HTML 1426
      top: Spacing.medium,                                  // 16
      bottom: context.scrollBodyBottomInset + Spacing.xLarge),
    separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),   // 12 ≈ design 11
    …))
```

- **Delete `const Divider(height: 1)` (`:309`).** R7/R12: this board has no list dividers; card
  outlines are the separation.
- **Delete `padding: EdgeInsets.symmetric(vertical: Spacing.xSmall)` (`:307`)** — replaced above.
- `OrderHistoryCard` gains `isLive` (§1.5) and two callbacks; the `onTap` closure at `:325-329`
  (role-aware `/orders/:id` vs `/jeeber/deliveries/:id/active`) is **unchanged** — that is BUG-A and
  it is pinned by `order_history_screen_test.dart:229`.
- Loading / error / empty branches (`:264-300`) keep their widgets **and their keys**
  (`order-history-loading`, `order-history-error`, `order-history-empty-<tab>`,
  `order-history-loading-more`). Only the empty branch's outer padding needs no change — but
  **do not** wrap the empty state in a `Center` or an `Expanded`: R1 says the residual space stays
  white and top-aligned.

### 1.5 The card — `order_history_card.dart` rebuilt

**Delete:** `_AddressLine` ×2 (`:67-81`, class `:122-151`), `_TierBadge` (`:211-248`), `_Header`'s
`OrderStatusChip` slot (`:116`), and the 4-row `Column`. **Delete the `OrderStatusChip` pill
entirely** — its *labels* survive as meta text (§1.6).

```
Semantics(
  identifier: 'order_history_card_${order.id}',   // FROZEN
  container: true, button: true, explicitChildNodes: true,   // ← explicitChildNodes is NEW
  label: l10n.orderHistoryCardSemanticLabel(order.id),       // FROZEN
  value: order.dropoffAddress,                               // NEW — see §1.7
  child: <card shell>(
    onTap: onTap,                                            // Key('order-history-card-${id}') FROZEN
    child: Column(children: [
      _IdentityRow(),                       // glyph · title · amount
      const SizedBox(height: Spacing.small),   // 12 ≈ design 11 (HTML margin-top:11)
      _MetaRow(),                           // tier chip · date · status · action pill
    ])))
```

**Card shell = one of two kit widgets, chosen by status:**

| Condition | Widget | Spec |
|---|---|---|
| `status == pickedUp \|\| status == enRoute` | `JeebAccentFrameCard` (kit #5) | white, `2px context.jeebRoles.accent`, r18, **no shadow**, pad `14/16` |
| everything else | `JeebOutlinedCard` (kit #3) | white, `1.5px colorScheme.outline` (#916F66), r18, **no shadow**, pad `14/16` |

**Why status-driven and not index-driven:** R5 — orange marks *what is moving right now*. `matched`
(accepted, not yet picked) is not moving; `pickedUp`/`enRoute` are. In practice a client has 0–1
in-flight orders so exactly one frame renders, matching the render. (Alternative considered and
rejected: "frame the first Active row" — index-aware styling makes the card impure and makes the
frame jump when a page loads.)

**No `dormant` / `.65`-opacity state.** HTML `1457` dims the cancelled card and deletes its action
row. Applying `Opacity(.65)` to a whole card drops the meta text below AA against white and, per
R9/§7.2-C4, "de-emphasis that removes affordances" is the pattern the plan already refuses on 11.
Cancelled rows render at full opacity with the periwinkle glyph carrying the de-emphasis. **Refused
— see §9-C2.**

### 1.6 `_IdentityRow` (replaces `_Header` `:97-120`)

`Row(children: [ leadingGlyph, SizedBox(width: Spacing.small), Expanded(title), amount ])`

| Slot | Source | Style |
|---|---|---|
| leading glyph | `order.status` → table below | 16px, `flex-shrink:0` |
| title | `order.pickupAddress` (empty → `l10n.orderHistoryAddressMissing`) | `context.jeebText.cardTitle` (15.5/w700) + `colorScheme.primary`, `maxLines: 1`, `TextOverflow.ellipsis` |
| amount | existing `MoneyFormat.format(...)` / `'—'` logic (`order_history_card.dart:38-43`) — **unchanged** | `context.jeebText.cardTitle.copyWith(fontWeight: FontWeight.w800)` (design 14/w800; the ramp has no 14/w800 entry and features may not write `fontSize:`), navy; unknown amount stays muted `onSurfaceVariant` |

Leading glyph table (design draws three; the enum has four buckets, so `disputed` needs one):

| Status | Glyph | Colour |
|---|---|---|
| `pickedUp`, `enRoute`, `matched`, `unknown` | Ø9 dot `Container` + `JeebShadows.stepGlow` halo | `context.jeebRoles.accent` |
| `delivered` | `Icons.check_circle`, 16px | `context.jeebRoles.success` (#1B7A3D) — **not** the HTML's `#2E7D32` |
| `cancelled` | `Icons.cancel`, 16px | `colorScheme.onSecondaryContainer` (periwinkle) |
| `disputed` | `Icons.error`, 16px | `colorScheme.error` |

`#2E7D32` (HTML `1439`, `1449`) is mapped to `jeebRoles.success` per the plan's token bridge
(§4.1, "KYC quality green → `jeebRoles.success`"): the raw green fails the WCAG gate that
`color_role_contrast_test.dart` enforces. The halo is `JeebShadows.stepGlow` (`0 0 0 5 @18%`)
rather than a bespoke `0 0 0 3 @20%` — a 2px difference nobody can see, and it keeps the feature
file free of hand-rolled shadows (§4.5).

### 1.7 `_MetaRow` (replaces `_Footer` `:153-209`)

`Row(children: [ tierChip?, dateText, dot, statusText, Spacer(), actionPill? ])`

| Slot | Rule | Style |
|---|---|---|
| tier chip | **Active tab only** (`status.tab == active`) | `JeebTierChip` (kit #7): `surfaceContainerHigh` pill pad `4/10`, emoji + `_tierLabel(tier, l10n)` (the existing switch at `order_history_card.dart:195-208`, unchanged) |
| date | `DateFormat.MMMd(locale).format(order.createdAt.toLocal())` | `jeebText.bodySmall` (12/w600) + `colorScheme.onSecondaryContainer` |
| separator | Ø3 `Container` circle, **not** a `'·'` string | same periwinkle; decorative, so no l10n key and no bidi hazard |
| status | `OrderStatusChip._labelFor(...)` moved into a top-level `orderStatusLabel(status, l10n)` helper | `jeebText.bodySmall`; ink = `jeebRoles.accent` when `isLive`, else `colorScheme.onSecondaryContainer` |
| action pill | §1.8 | `JeebSelectChip(role: inlineAction)` |

**Each of date / status is its own `Text`.** `orders_stale_status_chip_test.dart` asserts
`find.text('Pending')`, `find.text('En route')`, `find.text('Picked up')` — a concatenated
`"Jul 31 · En route"` breaks all four of its cases. This is the single most important structural
constraint in the card.

**Date format changes from `yMMMd + jm` to `MMMd`.** The design's meta reads `Jun 26`, not
`May 17, 2026 10:30 AM`. This **breaks** `order_history_card_test.dart:78` deliberately — see §8.
`.toLocal()` is preserved (that test's actual subject, SW-03).

### 1.8 The action pill — the note's "killer retention action"

| Tab / status | Pill | Destination |
|---|---|---|
| `pickedUp` / `enRoute` (live) | `Track` — `JeebSelectChip(role: inlineAction, selected: true)` → navy fill, white 12/w600 | **the same role-aware destination as the row tap**: `/orders/${id}` for a client, `/jeeber/deliveries/${id}/active` for an acting jeeber |
| `delivered` | `Jeeb it again` — `JeebSelectChip(role: inlineAction, selected: false)` → white, `1.5px outline`, navy w700 | `GoRouter.of(context).pushNamed('request-type')` |
| `cancelled` / `disputed` | `Jeeb it again` (same widget, same label) | same |
| `matched` (accepted, not picked) | none | — |

**Why `Track` does not deep-link to `/orders/:id/tracking`:** that route resolves a *delivery* id
(`app_router.dart:1352`, `resolveTrackingDeliveryId`), and callers that work pass it as
`?deliveryId=` from a field the history DTO does not have (`in_progress_tab.dart:58-66` uses
`ClientHomeRequest.trackingId`). `OrderSummary` has only the request id, and
`GET /v1/delivery/<requestId>` 404s. Routing to `/orders/:id` — whose `Live tracking` row
(`delivery_detail_screen.dart:339`) is the sanctioned entry — is honest; a direct link would be a
fabricated id. `// TODO(redesign-24): needs gateway trackingId on GET /v1/requests to deep-link
tracking — routed to the detail surface instead, not faked.`

**Why `Jeeb it again` goes to `request-type`:** every create entry in the app already does exactly
this (`home_tab.dart:209`, `pending_requests_tab.dart:77`, `in_progress_tab.dart:131`,
`no_offer_timeout_screen.dart:318` — the last is literally the existing *re-target* action).
Seeding a `RequestDraft` from the row is **not** possible honestly: `OrderSummary` carries no
description (`RequestDraft.description` is required and `RequestSummaryScreen:59` renders it
read-only), so a seeded draft would land the user on a submit screen describing nothing.
`// TODO(redesign-24): needs the request description/tier on GET /v1/requests to pre-fill the
re-compose — entering the create flow unseeded, not faked.`

---

## 2. Tokens — every literal that changes hands

The current files are already hex-free; what changes is *which* role and *which* ramp entry.

| Where (file:line today) | Today | Becomes |
|---|---|---|
| `order_history_card.dart:53` | `OmdsBorderRadius.medium` (16) on the InkWell | card radius owned by `JeebOutlinedCard` / `JeebAccentFrameCard` (design-exact 18 inside the kit; §4.4 two-tier rule) |
| `order_history_card.dart:55-58` | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: Spacing.small)` | kit-owned pad `14/16` |
| `order_history_card.dart:111-113` | `textTheme.bodyMedium` + `onSurfaceVariant` (date) | `context.jeebText.bodySmall` + `colorScheme.onSecondaryContainer` (periwinkle — HTML `1444`) |
| `order_history_card.dart:145` | `textTheme.bodyMedium` (address) | `context.jeebText.cardTitle` + `colorScheme.primary` |
| `order_history_card.dart:177-180` | `textTheme.bodySmall` + `onSurfaceVariant` (tier label) | inside `JeebTierChip` — 11.5/w700 navy on `surfaceContainerHigh` |
| `order_history_card.dart:185-189` | `textTheme.titleSmall.copyWith(w600)` (amount) | `context.jeebText.cardTitle.copyWith(fontWeight: FontWeight.w800)` |
| `order_history_card.dart:71/78` | `scheme.primary` / `scheme.error` address icons | **deleted** with `_AddressLine` |
| `order_history_card.dart:220-224` | `scheme.secondaryContainer` + `OmdsBorderRadius.xSmall` (tier square) | **deleted**; `JeebTierChip` uses `surfaceContainerHigh` + pill |
| `order_status_chip.dart:20-33` | `OmdsBorderRadius.small` pill + `roles.{success,error,primary}Container` | **deleted**; status becomes text, ink = `jeebRoles.accent` (live) / `onSecondaryContainer` (rest) |
| `order_history_screen.dart:174` | `Icon(Icons.tune, size: Sizes.medium)` | kept, 14px inside the kit chip's `leading` slot (HTML `1420`) |
| `order_history_screen.dart:180-185` | `Spacing.medium` / `Spacing.small` / `Spacing.twoXSmall` | `Spacing.xLarge` (24 gutter) / `Spacing.medium` (16 top) |
| `order_history_screen.dart:307` | `EdgeInsets.symmetric(vertical: Spacing.xSmall)` | `EdgeInsetsDirectional` 24-gutter + `scrollBodyBottomInset` |
| `order_history_screen.dart:309` | `Divider(height: 1)` | `SizedBox(height: Spacing.small)` |
| — (new) title | — | `context.jeebText.h2` + `colorScheme.primary` |
| — (new) live dot | — | `context.jeebRoles.accent` + `JeebShadows.stepGlow` |
| — (new) completed glyph | — | `context.jeebRoles.success` |

**Gate note:** `order_status_chip.dart` is listed in `no_raw_semantic_colors_test.dart:36` and that
test **asserts the file exists at that path** (`:64-65`). Do **not** delete the file. Keep it as the
home of `orderStatusLabel(status, l10n)` (the switch at `:62-81`, unchanged) and delete only the
`Container` pill at `:19-36`. If the widget class itself is removed, the file must still exist and
must still be hex-free — which it will be.

---

## 3. Shared components consumed

| Kit widget (plan §5) | Used for | Notes / wiring request |
|---|---|---|
| **#3 `JeebOutlinedCard`** | every non-live row | radius 18, pad `14/16`, no shadow. **Do not** use its `dormant` state (§9-C2) |
| **#5 `JeebAccentFrameCard`** | the in-motion row | plain (non-`filled`) variant: `2px jeebRoles.accent`, r18 |
| **#6 `JeebSelectChip` / `JeebChipRow`** | the three tab pills (`role: filter`) and the row action pills (`role: inlineAction`) | **WR-1:** `filter` needs an optional **`leading` glyph** slot (the header chip's 14px tune icon, HTML `1420`) and an optional **count badge** (`Active 1`, HTML `1423`). The plan's §5 #6 spec mentions the badge but not a leading glyph. **WR-2:** screen 24's tab pills measure pad `9/18` @13/w600 against the kit's `filter` role at `11/20` @14.5/w600 — a 2px/1.5px divergence. Consume `filter` as-is; do **not** invent a sixth role (risk #15) |
| **#7 `JeebTierChip`** | the tier meta chip on Active rows | **WR-3:** must accept `(emoji, label)` strings — `OrderTier` is `order_history`'s own enum and must not import `tier_selection`'s `Tier`. The ⚡🚀🟦🤝🌿 lexicon and the 🟦 fallback stay centralised in the kit (§9-Q7) |
| `JeebShadows.stepGlow` | the live dot halo | already shipped (Wave 0) |
| `context.jeebText` (`h2`, `cardTitle`, `bodySmall`) | all type | already shipped |
| `context.jeebRoles` (`accent`, `success`) | all state colour | already shipped |

**Not consumed:** `JeebTopBar` (#1) — this screen is a shell tab body with no back affordance;
`JeebProfileHeader` (#23) — no avatar/eyebrow in the render; `JeebCtaFooter` (#2) — the docked
element here is the shell's tab bar, not a CTA.

**Explicitly out of this lane:** the 5-tab bottom bar (HTML `1466–1487`). It is
`_JeebBottomBar` in `lib/features/shell/shell_screen.dart:345-387`, another lane's tree
(§7.4), and the plan already rules that the per-role tab sets stay (§9-Q1). This lane must render
nothing bar-like.

---

## 4. New functionality, and what the cubit/state must supply

### 4.1 Tab counts — **buildable today, no state change**

`Active 1` (HTML `1423`) is `state.tabs[tab]!.orders.length`. Render the badge **only** when that
tab is fully known:

```dart
final t = state.tabs[tab]!;
final count = (t.status == OrderTabStatus.ready && !t.hasMore) ? t.orders.length : null;
```

`hasMore` is the honest gate: with more pages outstanding the loaded count is a lower bound, and
showing `Completed 20` for 340 orders is a lie. A never-loaded tab shows no badge (its list has not
been fetched — `selectTab` is lazy, `order_history_cubit.dart:26-32`). `pending` rows are dropped
by `DioOrderRepository._parsePage:137`, so the count is the true Delivery-tab count. This is a
client-side derivation of existing state → allowed by §7.6.

### 4.2 Date-range chip label — **buildable today, needs l10n keys**

`Jun 1 – 30` (HTML `1419`) is `state.dateRange` formatted with `DateFormat.MMMd(locale)` — the same
`OrderDateRange` the sheet already returns, with `inclusiveToDay` (`order_summary.dart:246`) giving
the *displayed* end day. Four cases: empty → `l10n.orderHistoryFilterCta` ("Filter by date",
existing); both ends → new `orderHistoryFilterRange`; from only → new `orderHistoryFilterRangeFrom`;
to only → new `orderHistoryFilterRangeTo`. `orderHistoryFilterActive` ("Date filter applied")
becomes unused by this screen — **leave the key in the ARBs** (l10n parity gate; deletion is the
integrator's call, not this lane's).

### 4.3 Live status text — **buildable today**

`In transit` is `orderStatusLabel(order.status, l10n)` — the existing
`l10n.orderHistoryStatusEnRoute`. No change.

### 4.4 What the design asks for and the app does not have — **omit, do not fake**

| Design element | HTML | Why it cannot be built |
|---|---|---|
| `ETA 20 min` | `1434` | No ETA field on `GET /v1/requests`; `OrderSummary` has no ETA and the repository parser (`dio_order_repository.dart:159-198`) reads none. `// TODO(redesign-24): needs gateway eta on GET /v1/requests — omitted, not faked.` |
| Item name `Medicine — Pharmacie du Musée` | `1430` | There is no item/description field on the list DTO. Title falls back to `pickupAddress`, which is the real "where from" the design is naming |
| Jeeber name `Karim` | `1444` | No jeeber identity on the requests list. Slot reused for `date · status` |
| `★ rated 4` | `1444` | No rating on the list DTO. (Separately, per §4.1, ★ on screen 24 would inherit surrounding ink and **must not** be tinted `starRatingColor` even if the data appeared) |
| `no offers` in the amount slot | `1462` | No offer-count field. `amountMinor == null` already means *unknown*, and `order_history_card_test.dart:46-67` pins that it renders `—` with an `Amount unavailable` a11y label. Rendering `no offers` would fabricate a claim about offers → **refused, §9-C1** |
| `Re-broadcast` | `1464` | See §9-C3 — refused, replaced by the same re-compose action |

**Cubit/state/repository verdict: no changes required.** Everything above is either existing state,
a client-side derivation of it, or a documented omission.

---

## 5. New routes

**None.** Every destination already exists and is already reachable:

| Action | Route | Registered at |
|---|---|---|
| row tap (client) | `/orders/:id` | `app_router.dart:849` |
| row tap (acting jeeber) | `/jeeber/deliveries/:id/active` | `app_router.dart:1483` |
| `Track` | same as row tap (§1.8) | — |
| `Jeeb it again` | `pushNamed('request-type')` → `/request-type` | `app_router.dart:1095` |

No `backFallbacks` entry, no `_wrapRootAware` change, no DI registration. This lane touches
**zero** integrator-owned files except the l10n batch (§6).

---

## 6. l10n (integrator batch — 4-edit recipe each, EN + real AR + getter)

| Key | EN | AR | Used by |
|---|---|---|---|
| `orderHistoryFilterRange` | `{from} – {to}` | `{from} – {to}` | header chip, both ends set |
| `orderHistoryFilterRangeFrom` | `From {from}` | `من {from}` | open-ended start |
| `orderHistoryFilterRangeTo` | `Until {to}` | `حتى {to}` | open-ended end |
| `orderHistoryTrackCta` | `Track` | `تتبّع` | live row action |
| `orderHistoryReorderCta` | `Jeeb it again` | `اطلبها مرة ثانية` | completed + cancelled row action |
| `orderHistoryTabCountSemantic` | `{count} orders` | `{count} طلبات` | `semanticsLabel` on the count badge (a bare digit is unreadable to a screen reader) |

Reused, no new key: `navDelivery` (title), `orderHistoryTab*`, `orderHistoryStatus*`,
`orderHistoryAddressMissing`, `orderHistoryAmountUnavailable`, `orderHistoryCardSemanticLabel`,
`orderHistoryFilterCta`, `orderHistoryEmpty*`, `orderHistoryError*`, all `tierSelectionTier*`.

`orderHistoryTabCountSemantic` needs the AR plural family — run
`qa/t-mob-fix-002/ar_plurals_check.sh` after landing, or ship it as a non-plural `{count}` string.

---

## 7. Semantics identifiers

### 7.1 Frozen — every one must still be emitted after the rebuild (10 values)

| Identifier | Today | After |
|---|---|---|
| `order_history_root` | `order_history_screen.dart:85` | same `Semantics`, `+ explicitChildNodes: true` |
| `order_history_active_tab` | `:97` | wraps `JeebSelectChip` instead of `Tab` |
| `order_history_completed_tab` | `:103` | ″ |
| `order_history_cancelled_tab` | `:109` | ″ |
| `order_history_filter_chip` | `:168` | moves into the header `Row`, same wrapper |
| `order_history_card_${order.id}` | `order_history_card.dart:46` | same wrapper, `+ explicitChildNodes: true` |
| `order_history_sheet_from_cta` / `_to_cta` | `date_filter_sheet.dart:187` (`${fieldId}_cta`) | **file untouched** |
| `order_history_sheet_from_clear_cta` / `_to_clear_cta` | `:203` | **file untouched** |
| `order_history_sheet_clear_cta` | `:112` | **file untouched** |
| `order_history_sheet_apply_cta` | `:129` | **file untouched** |

Also frozen (widget `Key`s, asserted by four test files): `order-history-filter-chip`,
`order-history-loading`, `order-history-error`, `order-history-empty-<tab>`,
`order-history-list-<tab>`, `order-history-loading-more`, `order-history-card-<id>`,
`order-history-filter-from|to|clear|apply`.

### 7.2 New (convention `<screen>_<element>[_suffix]`)

| Identifier | Widget |
|---|---|
| `order_history_track_cta_${order.id}` | the navy `Track` pill |
| `order_history_reorder_cta_${order.id}` | the outlined `Jeeb it again` pill |
| `order_history_tab_count_${tab.name}` | the count badge (non-interactive; `container: true` only) |

**`explicitChildNodes: true` is load-bearing, not cosmetic.** The card's root `Semantics` is
`button: true` (`order_history_card.dart:47`); once it contains two more buttons it swallows their
ids unless the flag is set (§7.5, canonical idiom in `active_request_card.dart`). Without it the two
new identifiers exist in source and are invisible to `find.bySemanticsIdentifier` — a silent
failure.

---

## 8. Test impact

### 8.1 Will break — legitimately

| Test | Assertion | Why it breaks | Fix |
|---|---|---|---|
| `test/features/order_history/order_history_card_test.dart:78-87` | `find.text(DateFormat.yMMMd('en').add_jm().format(...))` | date format drops to `MMMd` (design `Jun 26`, HTML `1444`) | update the expectation to `DateFormat.MMMd('en')`; **keep** the `.toLocal()` subject (SW-03) |
| `test/features/order_history/order_history_card_test.dart:27-34` (`_pump`) | constructs `OrderHistoryCard(order:, onTap:)` | the constructor gains `isLive` / `onTrack` / `onReorder` | give the new params defaults (`isLive: false`, nullable callbacks) so this harness compiles unchanged |
| `test/features/order_history/order_history_date_filter_sheet_golden_test.dart` ×3 | committed PNGs | **only if Wave 0's `chipTheme` → `StadiumBorder` and error-quartet edits already moved them.** This lane changes nothing inside the sheet | regenerate on the Mac Studio in the Wave-5 sweep (§9-R10), not here |

### 8.2 Must keep passing — these are the guard rails

| Test | What it pins | How the proposal honours it |
|---|---|---|
| `orders_stale_status_chip_test.dart:191/241/264` | `find.text('Pending' / 'Picked up' / 'En route')` on the real screen | status stays a **standalone `Text`** in `_MetaRow` (§1.7) |
| `orders_stale_status_chip_test.dart` (all 6) | refetcher read-count semantics | `OrdersResumeRefetcher` and the cubit are untouched |
| `order_history_card_test.dart:37-76` | `$1,234.00` LTR-isolated · `—` for null/0 · `Amount unavailable` label | the money block (`order_history_card.dart:38-43`) is copied verbatim; `no offers` refused (§9-C1) |
| `order_history_screen_test.dart:180-190` | `find.text('Active'/'Completed'/'Cancelled')` | pill labels stay bare `Text`; the count is a separate badge |
| `order_history_screen_test.dart:151-178, 252-385` | filter chip tap at 1× and 2×, sheet flow, range application | identifier + key preserved; large-text header becomes a `Column` (§1.2) |
| `order_history_screen_test.dart:216-250` | `/orders/:id` vs `/jeeber/deliveries/:id/active` (BUG-A) | the `onTap` closure is unchanged |
| `e24_tab_semantics_split_test.dart`, `order_status_bucketing_test.dart`, `dio_order_repository_role_aware_test.dart` | parser + bucketing | **no domain or data change at all** |
| `no_raw_semantic_colors_test.dart:36` | `order_status_chip.dart` exists and is hex-free | file kept (§2 gate note) |
| `tool/check_design_tokens.sh` | no `fontSize:` / hex / `BorderRadius.circular(N)` / `EdgeInsets.all(N)` in `lib/features` | all type via `context.jeebText`, all colour via roles, all radii kit-owned, all spacing via `Spacing.*` |

### 8.3 New tests this lane should add

- card renders the `2px accent` frame for `enRoute`/`pickedUp` and the `1.5px outline` for the rest;
- `Track` fires the role-aware destination; `Jeeb it again` reaches `request-type`;
- the count badge is absent while `hasMore` is true and present when it is false;
- an AR (`Locale('ar')`) smoke of the header + a card (`Directionality.of(...) == rtl`, no overflow);
- 200%-text smoke of the header row.

---

## 9. Conflicts, refusals, risks

### C1 — `no offers` in the amount slot: **REFUSED**
HTML `1462` puts `no offers` where every other card puts money. There is no offer-count field on
`GET /v1/requests`, and `order_history_card_test.dart:46-67` pins that an unknown amount renders `—`
with an explicit `Amount unavailable` a11y label — the T11/SW-02 money-truth rule. Substituting a
claim about *offers* for a statement about *price* would fabricate data in the one slot the repo has
already fought over twice (`$0.00` regression). Renders `—`.

### C2 — the `.65`-opacity dormant card: **REFUSED**
HTML `1457` dims the whole cancelled card. `Opacity` over a card drops its 12/w600 periwinkle meta
below AA on white, and the plan already refuses the same treatment on screen 11 (§7.2-C4 / R9:
"de-emphasis that removes affordances"). Cancelled rows render at full opacity; the periwinkle ✕
glyph and the periwinkle meta line carry the de-emphasis honestly.

### C3 — `Re-broadcast` as a distinct action: **REFUSED (owner-visible)**
Three independent blockers:
1. **The status vocabulary cannot isolate `expired`.** `OrderRequestStatus.parse` folds `expired`
   into `cancelled` (`order_summary.dart:66-69`), and `order_status_bucketing_test.dart:57` pins
   exactly that mapping. Splitting out an `expired` value would rewrite a parser regression guard —
   a domain change dressed as a restyle.
2. **There is no re-broadcast endpoint.** The only `Re-broadcast` in the app is the no-show sheet
   (`tracking_noshow_sheet.dart:90`) navigating to `waiting-no-coverage` — and for an already
   cancelled/expired request that screen lands on `waiting_terminal_state` with a Home exit. A dead
   end, which is precisely what the designer note says the change should remove.
3. **The wording implies server confirmation** the client cannot give (the same rule the plan
   applies to pre-accept cancel, §7.2 "No pre-accept cancel endpoint").

**Resolution:** cancelled/expired rows get the *same* `Jeeb it again` re-compose as completed rows.
The designer's intent — "expired requests offer a way forward instead of a dead end" — is fully
served; only the word changes. If the owner wants the two labels visually distinct, that is a copy
decision (`orderHistoryRebroadcastCta` pointing at the same handler), not a behaviour change.

### C4 — no locked-decision violation
`decision_violations_test.dart`'s pinned items (D20 vehicle keys, D41/D44 fee wording,
`kJeebCommissionRate`, D52, D56, B04, accept-sheet tense, pinned chat summary) touch nothing on this
screen. There is **no** money breakdown, **no** commission line and **no** composer here. The board's
one money token (`$8`) is the order amount, already rendered through `MoneyFormat`.

### R1 — density is the real deliverable
The render is ~45% white below the fourth card and the app is currently a full-bleed divided list.
The 24px gutters, 12px card gaps, no dividers and a top-aligned `ListView` are what make it look
like the board; a reviewer diffing colours will not see whether this landed. Compare against the PNG
at matching scale, per §9-R13.

### R2 — Maestro `_delivery-history.yaml` drives this screen **by coordinate**
`.maestro/jeeb/devices/RFCX306JSRT/flows/pages/_delivery-history.yaml` taps `50%,8%` (filter) and
`17|50|83%,14%` (tabs) on a 1080×2340 device. Adding the `Delivery` title pushes both bands down.
Estimated new positions: header row ~`14%`, pill row ~`24%`. The flow is screenshot-only, so a
mis-tap produces *wrong screenshots silently*, and Maestro is not in CI. **Re-verify on the S22 and
update the four coordinates** — or, better, convert the page object to `id:` selectors, since the
four identifiers it needs are frozen and already present.

### R3 — the date-filter sheet is deliberately left alone
The board is silent on it (no sheet render on the 24-screen set), and it owns three committed
goldens. Restyling it on inference would burn goldens for zero design evidence. If the owner wants
the sheet migrated, it is a separate, cheap follow-up.

### R4 — information deliberately dropped from the row
The design's 2-row card has no room for the **dropoff address** or (on completed rows) the **tier**.
Dropoff moves to the card's `Semantics.value` and stays on `/orders/:id`; tier stays on Active rows
only (the urgency tier stops being actionable once delivered). Both are the board's calls, both are
reversible, and both are worth an owner glance.

### R5 — count badge honesty vs. the design
The board shows `Active 1` unconditionally. This proposal hides the badge whenever `hasMore` is
true. On the Completed tab with a long history that means *no* badge — visibly less than the render.
That is the correct trade (a wrong number is worse than no number), but it is a visible divergence.

### R6 — `JeebSelectChip` is doing double duty
The three tab pills are genuinely a selection; the two row pills are actions wearing selection
clothing (`inlineAction`, which the plan sanctions for 04's `View offers` and 11's `Accept`). If the
kit owner tightens `JeebSelectChip` to emit `Semantics(selected:)` rather than `button:`, the row
pills must move to a plain `InkWell` + `JeebOutlinedCard`-style pill instead. Coordinate with the
Wave-1 kit lane before that widget lands.
