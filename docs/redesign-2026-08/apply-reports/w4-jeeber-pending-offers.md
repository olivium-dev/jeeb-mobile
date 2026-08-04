# Apply report — `w4-jeeber-pending-offers`

**Screen:** `jeeber-pending-offers` (`/jeeber/pending-offers`, JM-047 / D15) — no render on the
board; language applied from the neighbour, **17 offer-composer**.
**File touched (1):** `lib/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart`
**Status: partial.** The chrome is on the system; the screen's *content* is not, and cannot be
from this lane — see §3.

---

## 1. What the neighbour does, and what this screen did

17 is an in-body header (Ø40 tonal circle + `h2` navy title + periwinkle sub) over a top-aligned
column at 24px gutters: outlined r16 cards with **no shadow**, uppercase periwinkle section labels,
one navy pill docked at the bottom, orange used exactly once (the `Top up` link), and the bottom
~35% left plain white.

This screen shipped a Material `OMDSAppBar` (elevation/surface-tint chrome, centred-ish title in
the M3 `titleLarge` ramp) over an edge-to-edge list of uncarded strips separated by hairline
`Divider`s at a 16px gutter, with a vertically-centred empty state.

## 2. Applied (this lane's file only)

| Change | Why |
|---|---|
| `OMDSAppBar` → in-body **`JeebTopBar.back`**, `Scaffold.appBar` removed, body wrapped in `SafeArea` | §5 #1 — the header is a body row on 17 of 24 screens; board padding `14/24/0`, `jeebText.h2` title, Ø40 `surfaceContainerHigh` circle. Matches the `_SettlementScaffold` house shape |
| `pending_offers_back` moved onto the kit's leading circle via `identifier:` | The kit emits the identical `Semantics(identifier:, button: true, container: true)` node, so the frozen id is byte-identical. The `canPop ? pop : go('/')` fallback stays in the screen (the kit never imports go_router) |
| Empty state **top-aligned** in a `SingleChildScrollView` instead of vertically centred | R1 — "the spacer is real emptiness; never vertically centre". Same idiom `order_history` used. Scrollable so it survives a large text scale |
| List rhythm: `top 16 / bottom 24` instead of a flat `vertical 12` | ~28px between the header and the first row once the row's own 12px inset is counted; the last row now clears the bottom edge |
| Body extracted to `_buildBody` + a `_PendingOffersEmptyState` widget | The `Column`/`Expanded` shell made the inline builder unreadable; no behaviour change |

**Not changed on purpose:** the cubit, the repository seams, the three state branches and their
order, the `OmdsPullToRefresh` on the populated list (and its *absence* on the empty state — adding
a gesture affordance is a product change, not a re-skin), and every string. **No new l10n keys, no
pubspec edit, no shared-file edit.**

## 3. What is still off-system — and why this lane could not fix it

The entire visual body of this screen is `PendingOfferRow`, which lives in
**`lib/features/jeeber_request_feed/presentation/pending_offer_row.dart`** — another lane's
directory (the `jeeber_request_feed` apply report lists it as "Untouched"), shared with the feed's
Pending-Response sub-tab and the jeeber home feed. Constraint 9 forbids editing it, so it is filed
as a paste-ready request: **`docs/redesign-2026-08/wiring/w4-jeeber-pending-offers.md` (R1)**.

Still legacy, all inside that row: uncarded strips + hairline `Divider`s instead of
`JeebOutlinedCard`; `titleMedium`/`labelMedium` raw styles instead of `jeebText.price`/`.caption`;
an **italic periwinkle status line on white** (the one thing the DS names outright as forbidden);
and an `errorContainer`-filled withdraw pill where the board has no destructive fill.

**Why the card was not added from the consumer:** the row supplies its own `horizontal: 16` inset
(a 24px board gutter would indent it to 40px) and paints a trailing `Divider` — inside a
`JeebOutlinedCard` that renders as a stray 1px line 12px above the card's own border. Wrapping it
today would ship a visibly wrong screen in exchange for a bigger diff. The list therefore keeps a
0 horizontal gutter until R1 lands; the paired consumer edit (24px gutter + `ListView.separated`)
is written out in the wiring file and is a two-line change for this lane afterwards.

## 4. Constraints

- **Semantics:** `jeeber_pending_offers_root` and `pending_offers_back` preserved byte-identically;
  the `pending_offer_*` family is untouched (it comes from the row). No new interactive widgets, so
  no new identifiers.
- **Screen warning honoured:** nothing in the copy or layout implies more than one offer per jeeber
  per request — the plural "Pending offers" is across requests, and the empty-state body
  ("Offers you send that are awaiting a customer decision") is unchanged.
- **RTL:** `EdgeInsetsDirectional` throughout; the back glyph is the kit's `DirectionalIcons.back`.
- **D-decisions:** none of D20/D41/D44/D52/D56 touch this surface. No money wording, no rating, no
  KYC.
- **Orphan tag:** the `ORPHAN (JEBV4-227)` comment is left in place — this lane does not adjudicate
  reachability.

## 5. Verification

- `dart analyze lib/features/jeeber_pending_offers` → **No issues found.**
- `flutter test test/features/jeeber_pending_offers/jeeber_pending_offers_screen_test.dart` →
  **7/7 pass** (root + back ids, AC1/AC2/AC3, withdraw-failure, empty, error, terminal badge).
- `flutter test test/core/router/w2_routes_resolve_test.dart` → **7/7 pass** (the no-Dio harness
  still resolves and mounts to the empty state).
- `tool/check_design_tokens.sh` → 3 violations repo-wide, **none in this lane's directory**
  (`client_location_screen.dart`, `wallet_activity_list_screen.dart`, `reviews_list_screen.dart` —
  pre-existing, other lanes).
