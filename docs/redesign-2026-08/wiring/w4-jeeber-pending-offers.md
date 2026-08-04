# Wiring request — `w4-jeeber-pending-offers`

Lane: `jeeber-pending-offers` (`lib/features/jeeber_pending_offers/`).
Status: **not applied by this lane** — the file below is outside this lane's directory.

---

## R1 — restyle `PendingOfferRow` onto the kit (SHARED FILE)

**File:** `lib/features/jeeber_request_feed/presentation/pending_offer_row.dart`
**Owner:** the `jeeber_request_feed` lane (its apply report explicitly lists this file as
"Untouched"), consumed by **two** surfaces:

| Consumer | Call site |
|---|---|
| `lib/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart` | the standalone `/jeeber/pending-offers` route (this lane) |
| `lib/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart` | the feed's Pending-Response sub-tab |

### Why this cannot be done in the consumer

The row is the *entire visual body* of the standalone screen, and it is the only part of it still
on the legacy language: an un-carded strip with a hairline `Divider` under it, `titleMedium`/
`labelMedium` raw text styles, an italic periwinkle status line on white (the DS forbids
periwinkle body ink on white), and an `errorContainer`-filled withdraw pill.

Wrapping it in a `JeebOutlinedCard` **from the consumer** does not work: the row supplies its own
`horizontal: 16` inset (so a 24px board gutter would indent it to 40) and paints a trailing
`Divider`, which inside a card renders as a stray 1px line 12px above the card's own border. The
card therefore has to move *into* the row, where both consumers get it. Until then this lane keeps
the list's horizontal gutter at 0 and only owns the vertical rhythm — a deliberately smaller diff
over a knowingly broken one.

### Semantics — every id below is preserved byte-identically

`pending_offer_<i>` · `pending_offer_<i>_price` · `pending_offer_<i>_eta` ·
`pending_offer_<i>_status` · `pending_offer_awaiting_label` · `pending_offer_<i>_withdraw_cta`,
plus the `Key('pending-offer-withdraw-<i>')`. Asserted by
`test/features/jeeber_pending_offers/jeeber_pending_offers_screen_test.dart` (7 tests) and
`test/jeeber_feed_make_offer_test.dart` (AC1/AC3) — both are **id-based only**, so nothing in
either file needs editing.

The `pending_offer_awaiting_label` / `_status` / `_withdraw_cta` wrappers stay as explicit
`Semantics(...)` in this file rather than being passed into the kit widget's `identifier` param:
the kit's own wrapper adds `explicitChildNodes: true`, which would split the label off the node
and change what a Maestro `assertVisible` reads.

### Paste-ready — replace the body of `pending_offer_row.dart`

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_system_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/submitted_offer.dart';

/// A single submitted-offer row … (existing doc comment kept verbatim)
///
/// redesign-2026-08: the strip became a [JeebOutlinedCard] (white, 1.5px
/// `colorScheme.outline`, r16, no shadow — outline-over-shadow), so the row no
/// longer paints its own trailing `Divider`: the outline IS the separation and
/// a divider between two outlined cards draws a third line nobody asked for
/// (R7/R12). Consumers now supply the board's 24px gutter and a 12px gap.
class PendingOfferRow extends StatelessWidget {
  const PendingOfferRow({
    super.key,
    required this.index,
    required this.offer,
    required this.isWithdrawing,
    this.onWithdraw,
  });

  final int index;
  final SubmittedOffer offer;
  final bool isWithdrawing;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'pending_offer_$index',
      container: true,
      explicitChildNodes: true,
      child: JeebOutlinedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PriceEtaRow(index: index, offer: offer),
            const SizedBox(height: Spacing.small),
            // sprint-009: a terminal offer (accepted / lost) shows an outcome
            // badge and NO withdraw control; a still-open offer keeps the
            // "awaiting" label + Withdraw (unchanged contract).
            if (offer.status.isTerminal)
              _StatusBadge(index: index, status: offer.status)
            else ...[
              _AwaitingLabel(),
              const SizedBox(height: Spacing.small),
              _WithdrawAction(
                index: index,
                isWithdrawing: isWithdrawing,
                onWithdraw: onWithdraw,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

The four private widgets change only their paint:

```dart
// _PriceText — the fact, at the board's money weight.
style: context.jeebText.price.copyWith(color: theme.colorScheme.primary),

// _EtaText — its qualifier ("ETA/cash lines" own `caption`).
style: context.jeebText.caption.copyWith(
  color: theme.colorScheme.onSurfaceVariant,
),

// _AwaitingLabel — a system state, not italic body copy. Periwinkle ink on a
// `surfaceContainerHigh` pill instead of periwinkle text on white (§4.1).
Semantics(
  identifier: 'pending_offer_awaiting_label',
  child: JeebSystemChip.filled(
    label: AppLocalizations.of(context).jeeberFeedStatusPending,
    center: false,
  ),
)

// _StatusBadge — same pill, re-toned. Accepted was periwinkle-on-navy (fails
// the ink ranking); the positive tint is the sanctioned pair.
final JeebColorRoles roles = context.jeebRoles;
final Color fg = isAccepted ? roles.onSuccessContainer : theme.colorScheme.onSurfaceVariant;
final Color bg = isAccepted ? roles.successContainer : theme.colorScheme.surfaceContainerHigh;
// … Text(label, style: context.jeebText.badge.copyWith(color: fg))

// _WithdrawAction — outline-over-fill. `JeebCtaButton` keeps the in-flight
// spinner `OmdsPrimaryButton` lacks, so no capability is lost.
Align(
  alignment: AlignmentDirectional.centerEnd,
  child: Semantics(
    identifier: 'pending_offer_${index}_withdraw_cta',
    button: true,
    child: JeebCtaButton.outline(
      key: Key('pending-offer-withdraw-$index'),
      label: AppLocalizations.of(context).offerSubmissionWithdrawButton,
      isLoading: isWithdrawing,
      expand: false,
      onTap: onWithdraw,
    ),
  ),
)
```

**Deliberate loss, flag it if you disagree:** the withdraw control drops its `errorContainer`
tint. The board has no destructive-fill affordance — 12's "Report no-show" (the closest
destructive action on the board) is a plain outline pill, and the error family is reserved for
actual error surfaces. If the product wants the destructive read preserved, the honest form is
`labelStyle:` with `colorScheme.error` ink on the same outline pill, **not** a filled pill.

### Paired consumer edits (apply in the SAME change — they are meaningless apart)

`lib/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart`
(this lane will take this edit itself once R1 lands — it is inside our directory):

```dart
return OmdsPullToRefresh(
  onRefresh: cubit.load,
  child: ListView.separated(
    padding: const EdgeInsetsDirectional.fromSTEB(
      Spacing.xLarge, Spacing.medium, Spacing.xLarge, Spacing.xLarge,
    ),
    itemCount: state.offers.length,
    separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
    itemBuilder: (_, index) { /* unchanged */ },
  ),
);
```

`lib/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart` — the same padding +
`ListView.separated` swap on `_pendingBody`'s list (keep `JeeberFeedTabView.pendingListKey`).

---

## Not requested

- **No l10n keys.** The re-skin adds no copy; `pendingOffersTitle` / `pendingOffersEmptyTitle` /
  `pendingOffersEmptyBody` and the reused `offerSubmission*` keys all already exist.
- **No route, DI or theme changes.**
- **No "your offers" plural anywhere** — one private offer per jeeber per request; the existing
  copy is correct and stays.
