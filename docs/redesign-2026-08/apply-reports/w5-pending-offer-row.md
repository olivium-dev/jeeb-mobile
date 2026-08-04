# w5 apply report — `pending-offer-row`

**Lane:** `pending-offer-row` (wave 5 leftovers)
**Status:** applied
**Branch:** `feat/redesign-24-migration` — no commit, no branch change, no push.

---

## 1. What this lane was

The wave-4 gate flagged `PendingOfferRow` as the last un-migrated file in the jeeber-offer journey:
zero diff, zero kit imports, and **shared by three surfaces**, which is precisely why neither
adjacent lane took it. The `jeeber_request_feed` lane's apply report listed it as "Untouched"; the
`jeeber_pending_offers` lane filed it as a paste-ready wiring request
(`wiring/w4-jeeber-pending-offers.md` R1) because the file sits outside its directory. This lane
closes that request.

### The three consumers (verified by grep, all re-checked after the change)

| # | Surface | Call site |
|---|---|---|
| 1 | standalone `/jeeber/pending-offers` route | `lib/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart:194` |
| 2 | jeeber-home feed, Pending-Response sub-tab | `lib/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart:932` (mounted from `jeeber_home_screen.dart:513`) |
| 3 | shell dashboard tab, same feed widget | `jeeber_feed_tab_view.dart:932` (mounted from `lib/features/shell/tabs/dashboard_tab.dart:522`) |

All three mount the row inside a `ListView` whose **horizontal padding is 0**, because the legacy
row supplied its own `horizontal: 16` inset.

---

## 2. The one structural decision that made this landable

The wiring request's plan required **paired consumer edits** — a `ListView.separated` + 24px
horizontal padding swap in each host — and one of those hosts (`jeeber_feed_tab_view.dart`, which
serves consumers 2 *and* 3) is outside this lane's directory. Shipping the card without them would
have left the cards at a 16px gutter on two of the three surfaces.

**Resolution: the gutter moved *into* the row.** `PendingOfferRow.rowPadding` is now
`EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge, vertical: Spacing.xSmall)` — byte-for-
byte the `rowPadding` already declared by the two migrated siblings in the same directory
(`RequestCard`, `JeeberFeedCard`). Consequences:

- all three surfaces get the board's 24px page margin and a 16px inter-card gap with **zero consumer
  edits**;
- every existing zero-horizontal-gutter list padding at the call sites stays correct rather than
  becoming a latent 40px double-indent;
- no `separatorBuilder` is needed — the 8px half-gap on each card *is* the separation;
- the vertical rhythm each host already owns (`top: 16 / bottom: 24` on the standalone screen,
  `vertical: 12` in the sub-tab) still composes.

This is a smaller diff than the filed request and reaches one more surface.

---

## 3. Changes

**File:** `lib/features/jeeber_request_feed/presentation/pending_offer_row.dart`

| Before | After | Why |
|---|---|---|
| bare `Padding` strip + a trailing `Divider(height: 1, outlineVariant)` | `Padding(rowPadding)` → `JeebOutlinedCard` (white, 1.5px `colorScheme.outline`, r16, **no shadow**) | outline-over-shadow; the outline *is* the separation, so the hairline had to go — a divider between two outlined cards draws a third line |
| price: `textTheme.titleMedium` inked with `colorScheme.secondaryContainer` | `context.jeebText.price` inked `colorScheme.primary` | `secondaryContainer` is a *container fill* used as text ink — periwinkle on white, the one thing §4.1 forbids. `price` is the ramp's declared "offer prices" style; navy, because the accent stays rationed |
| ETA: `textTheme.labelMedium` | `context.jeebText.caption` (ink unchanged: `onSurfaceVariant`) | `caption` is the ramp's "ETA and cash lines" style — the same one `RequestCard`'s countdown uses |
| awaiting: **italic periwinkle text on white** | `JeebSystemChip.filled(center: false)` | a system state, not body copy; moves the periwinkle onto `surfaceContainerHigh` where it is legal |
| status badge: hand-rolled `Container` + `OmdsBorderRadius.pill`, `secondaryContainer` / `surfaceContainerHighest` | `JeebSystemChip.filled(center: false)` | deletes a hand-rolled copy of a kit widget. Screen 21 renders *the same fact* (`Offer accepted` / `Offer rejected`) with exactly this chip |
| withdraw: `OmdsLoadingButton` with an `errorContainer` fill | `JeebCtaButton.outline(expand: false, isLoading:)`, carried in `JeebOutlinedCard.actions` | outline-over-fill; the kit pill keeps the in-flight spinner, so no capability is lost. `actions` lets the card own the body→decision gap, the same idiom `RequestCard` uses |
| gap price→status `Spacing.twoXSmall` (4) | `Spacing.small` (12) | the block rhythm the larger type needs |

**File:** `lib/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart`
— **comments only**, no code. Two doc blocks asserted that the row was un-migrated and that "the
row still supplies its own 16px inset"; both are now false and would misdirect the next reader.

Nothing else changed: no flow, no navigation, no copy, no behaviour, no l10n key, no pubspec, no
endpoint, no contract.

---

## 4. Contract preservation

**Semantics — all six ids byte-identical, verified in place:**
`pending_offer_<i>` (still `container: true, explicitChildNodes: true`) ·
`pending_offer_<i>_price` · `pending_offer_<i>_eta` · `pending_offer_<i>_status` ·
`pending_offer_awaiting_label` · `pending_offer_<i>_withdraw_cta` (still `button: true`), plus
`Key('pending-offer-withdraw-<i>')`.

Two deliberate details:

1. **No `identifier:` is passed to any kit widget.** Each id stays on this file's own explicit
   `Semantics` wrapper. The kit's wrappers differ in shape (`JeebCtaButton` adds
   `enabled:`/`container:`; `JeebSystemChip` adds a `label:`), and a kit node *inside* the frozen
   wrapper would nest two button nodes under `pending_offer_<i>_withdraw_cta`.
2. **The withdraw `Semantics` node stays inside the `Align`**, not around it. Around it, the node's
   rect would be the full card width and `tester.tap` / a Maestro tap would land in dead space
   beside the pill instead of on it.

Behaviour preserved verbatim: `onTap: onWithdraw ?? () {}` (the control stays tappable when a host
omits the callback), terminal offers still show no withdraw control, `isTerminal` still drives the
branch, `Localizations`/`NumberFormat.simpleCurrency` money formatting untouched.

**RTL:** every inset stayed `EdgeInsetsDirectional`, every alignment `AlignmentDirectional`. The row
adds no `Directionality` and no `left:`/`right:`.

**D-rules:** no fee/commission copy exists in this file; no plural is implied — one private offer per
jeeber per request, and the reused strings are unchanged.

---

## 5. Deliberate losses — flag them if you disagree

1. **The withdraw pill drops its `errorContainer` tint.** The board has no destructive-fill
   affordance: 12's "Report no-show", the closest destructive action on it, is a plain outline pill,
   and the error family is reserved for actual error surfaces. If product wants the destructive read
   back, the honest form is `labelStyle:` with `colorScheme.error` ink on the *same* outline pill —
   not a filled pill.
2. **Accepted and lost now share one chip tone.** Previously `secondaryContainer` vs
   `surfaceContainerHighest` — a difference of a few percent luminance that carried no reliable
   signal, on top of the periwinkle-on-periwinkle contrast problem. Screen 21 renders both outcomes
   with `JeebSystemChip.filled` and lets the copy carry the decision, so that is what this row does.
   The kit has no success-toned chip; adding a green pill here would be hand-rolling a 34th kit
   widget for one row. Escape hatch if product wants the positive read: `jeebRoles.successContainer`
   / `onSuccessContainer` — but that is a kit change, not a call-site one.

---

## 6. Gates

| Gate | Result |
|---|---|
| `flutter analyze --no-pub` (whole repo) | **8 issues, 0 errors, 0 warnings** — all 8 are the baseline `containsSemantics` deprecation infos in pre-existing test files; none in either file touched |
| `dart analyze` on the two lanes + `jeeber_home` | **No issues found** |
| `test/features/jeeber_pending_offers/jeeber_pending_offers_screen_test.dart` (7) + `test/jeeber_feed_make_offer_test.dart` (3) | **10/10 pass** — these are the row's entire id-based contract, across consumers 1 and 2 |
| `test/jeeber_feed_card_test.dart` (29) | pass — the migrated sibling this row now shares a rhythm with |
| `flutter test --no-pub` (full suite) | **4664 pass / 61 skip / 1 fail** — exactly the stated baseline. The single failure is the pre-existing `test/core/diagnostics/gesture_log_test.dart` "button-merged nested Semantics records the OUTER exposed id" (local-SDK skew, green in CI), reproduced in isolation to confirm it is not this change |
| new `.dart` files | none created, so nothing to `git add -N` |
| files touched outside this lane | one — the row itself, which is the assignment; the paired edit is comment-only and inside the lane |
