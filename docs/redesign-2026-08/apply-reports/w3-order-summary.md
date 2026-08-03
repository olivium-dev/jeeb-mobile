# w3 — `order-summary` onto the Jeeb design system

**Screen:** `order-summary` (JM-031) · route `/orders/:id/summary` · reached from redesigned 21 via
`order_chat_view_summary_link`.
**Render:** none — this is one of the 46 screens the board never drew. Reference language taken from
the neighbour **10 `Review & send`** (`screens/10-request-summary.png` / `.html`) and from the two
already-redesigned screens in-repo (`request_summary/…/request_ticket.dart`, `wallet_hub_screen.dart`).

**Files changed (2, both inside `lib/features/order_summary`):**

- `lib/features/order_summary/presentation/order_summary_screen.dart`
- `lib/features/order_summary/presentation/widgets/order_summary_pinned.dart`

No shared file touched → **no wiring request needed**. No new l10n keys (every string already
resolves through `OrderSummaryL10n`). No pubspec, no router, no kit edit.

---

## 1. What the screen looked like before

- `OMDSAppBar` + a `ListView` holding one bespoke `Container`: `surfaceContainerHighest` fill,
  `outlineVariant` hairline, `OmdsBorderRadius.medium`.
- Inside it: an `OmdsProfileAvatar`, a `titleMedium.copyWith(w600)` name, a `primaryContainer`
  "price pill" in the header row, two icon+label+value `_Fact` cells side by side (ETA, tier), an
  optional third `_Fact` for the item, a `labelLarge` cash line, and a `Row` of two
  `OmdsPrimaryButton`s.
- Every text style was an ad-hoc `theme.textTheme.*.copyWith(...)`; no `context.jeebText`, no kit
  widget, no `JeebSemanticColors`. Next to 10 it read like a different product: a grey slab of
  labelled cells versus 10's white outlined ticket.

## 2. What it is now

`JeebTopBar.back` (in-body, tonal Ø40 circle + 20/w700 navy title — 10 `tpl 570`), then one
**`JeebOutlinedCard.grouped`** "ticket" (r20, 1.5px outline, hairline dividers between the rows that
have data — 10 `tpl 575`), then the trust line, then the CTAs:

| Band | Before | After |
| --- | --- | --- |
| Header | `OMDSAppBar` | `JeebTopBar.back` + new `order_summary_back` id, `canPop ? pop : go('/')` mirroring `backFallbacks['order-summary']` |
| Card | bespoke `Container` (grey fill) | `JeebOutlinedCard.grouped(radius: 20)` — white, outline-over-shadow |
| Jeeber row | `OmdsProfileAvatar` + `titleMedium` | `JeebAvatar.thread` (Ø42, `initialFrom` normalises the full name) + `jeebText.cardTitle`; rating display + its JEBV4-285 `FittedBox` kept verbatim |
| Tier / ETA | two icon `_Fact` cells | 10's tier row: `JeebTierChip` + muted ETA run (`jeebText.bodySmall` on `mutedText`) in an overflow-proof `Wrap` |
| Item | `_Fact` cell | 10's stop pattern — muted qualifier over `cardTitle` value |
| Price | `primaryContainer` pill in the header | its own ticket row, `jeebText.price` (21/w800) navy, end-aligned, LTR-isolated |
| Cash reminder (D11) | inline `labelLarge` row | `JeebInfoNote.muted(icon: Icons.payments)` under the ticket — where 10 puts "Free to cancel any time…" |
| CTAs | `Row` of `OmdsPrimaryButton` | `JeebCtaFooter.split` / `.single` of `JeebCtaButton.outline` + `JeebCtaButton` (both 56 tall) |

Kit widgets used: `JeebTopBar` · `JeebOutlinedCard.grouped` · `JeebAvatar` · `JeebTierChip` ·
`JeebInfoNote` · `JeebCtaButton` · `JeebCtaFooter`.
Tokens used: `context.jeebText.{cardTitle,bodySmall,price}` · `JeebSemanticColors.mutedText` ·
`colorScheme.{primary,onSurface}`. Zero `Color(0x…)`, zero raw `TextStyle(` in the feature.

## 3. Behaviour, contracts, refusals

- **Flow unchanged.** Same data, same block order (identity → facts → item → money), same two nav
  edges (`chat-detail`, `live-tracking`), same null-callback-hides-its-CTA rule, same states
  (loading / error+retry / loaded), same repository + cubit + test seams.
- **Every `Semantics(identifier:)` preserved byte-identically:** `order_summary_root`,
  `order_summary_pinned`, `_jeeber_name`, `_tier`, `_eta`, `_item`, `_price`, `_cash_label`,
  `_open_chat`, `_track`. One new id for a newly interactive element: **`order_summary_back`**
  (`<screen>_<element>`).
- **Nothing invented.** No band, badge, photo strip or "Change" link from 10 was copied in —
  `OrderSummary` carries no request-mode, media or editable field, and an accepted order has nothing
  to edit. The screen renders exactly the fields it has.
- **D11 held:** the cash reminder stays, and there is still no commission/fee/finance line anywhere
  on this customer surface (`JeebMoneyBreakdown` deliberately NOT used — its own doc names 17 as its
  only consumer and refuses customer surfaces).
- **Overflow:** the tier/ETA line is a `Wrap` + `ConstrainedBox` (the shape
  `tracking_header_overflow_test` forced on the tracking header). An **unmapped tier slug** degrades
  from the chip to a muted ellipsised run: `JeebTierChip`'s label cannot ellipsise (its internal
  `Row` hands the `Text` unbounded constraints) and an unknown id arrives raw off the wire at
  arbitrary length. Verified with a throwaway stress harness (EN + AR × 1.0/2.0 text scale × 360px
  wide × long name / long item / unmapped tier / no ETA / both CTAs): **no RenderFlex overflow.**
- RTL: `EdgeInsetsDirectional` / `AlignmentDirectional` throughout; the amount sits in an LTR isolate
  so it cannot be reordered by surrounding Arabic.

## 4. Gates

| Gate | Result |
| --- | --- |
| `dart analyze lib/features/order_summary` | **No issues found** |
| `flutter test test/features/order_summary/ --no-pub` | **22 passed, 0 failed** |
| `flutter test test/core/router/w1_routes_resolve_test.dart --no-pub` | **8 passed** (route still resolves to `OrderSummaryScreen`) |

## 5. Known divergences from the neighbour (deliberate)

1. **The CTA is not docked to the foot of the viewport.** 10 pushes it with a flex-1 spacer. The
   CTAs live *inside* the injectable `OrderSummaryPinned` (its own tests mount it bare inside an
   unbounded scroll view), so it cannot own a viewport-height spacer without crashing there. It
   flows inline instead — the same inline `JeebCtaFooter` the redesigned wallet uses.
2. **No tonal top band and no overhanging navy badge** on the ticket: this screen has no audio and
   no request-mode field to put in them.
3. **Orange appears nowhere.** 10 rations it onto its Edit/Change links; an accepted order has
   nothing to edit, so the accent stays unspent (the star rating is the only warm ink).
4. **`OmdsStarRatingDisplay` is still OMDS** — the kit has no rating display, so its type ramp and
   review-count ink are not Jeeb tokens. Left alone rather than hand-rolled.
5. **Ticket radius 20**, matching 10's ticket rather than §5's default 16.
6. **`dense: true` has no production consumer** — chat and tracking both ship their own headers
   today, so the compact variant is exercised only by tests.
