import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/submitted_offer.dart';

import '../../../core/previews/jeeb_preview.dart';

/// Pending-offer row: price + ETA + awaiting status + Withdraw control (D15).
/// Semantic IDs (`pending_offer_<index>_*`) for QA automation; explicitChildNodes
/// keeps each child queryable.
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
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'pending_offer_$index',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PriceEtaRow(index: index, offer: offer),
            const SizedBox(height: Spacing.twoXSmall),
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
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Spacing.small),
              child: Divider(height: 1, color: colorScheme.outlineVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceEtaRow extends StatelessWidget {
  const _PriceEtaRow({required this.index, required this.offer});

  final int index;
  final SubmittedOffer offer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _PriceText(index: index, offer: offer)),
        if (offer.etaMinutes != null) ...[
          const SizedBox(width: Spacing.small),
          _EtaText(index: index, etaMinutes: offer.etaMinutes!),
        ],
      ],
    );
  }
}

class _PriceText extends StatelessWidget {
  const _PriceText({required this.index, required this.offer});

  final int index;
  final SubmittedOffer offer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatted = NumberFormat.simpleCurrency(
      locale: locale,
      name: offer.currency,
    ).format(offer.price);
    return Semantics(
      identifier: 'pending_offer_${index}_price',
      child: Text(
        formatted,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EtaText extends StatelessWidget {
  const _EtaText({required this.index, required this.etaMinutes});

  final int index;
  final int etaMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'pending_offer_${index}_eta',
      child: Text(
        '$etaMinutes ${l10n.offerSubmissionEtaSuffix}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
      ),
    );
  }
}

/// Terminal-offer badge (accepted/lost). Semantic id is the contract (not the
/// localized text).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.index, required this.status});

  final int index;
  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isAccepted = status == OfferStatus.accepted;
    final label = isAccepted
        ? l10n.requestStatusAccepted
        : l10n.requestFeedActionDeclinedSnack;
    final fg = isAccepted
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final bg = isAccepted
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    return Semantics(
      identifier: 'pending_offer_${index}_status',
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.twoXSmall,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: OmdsBorderRadius.pill,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

class _AwaitingLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'pending_offer_awaiting_label',
      child: Text(
        // Semantic id is the contract (not the localized text).
        AppLocalizations.of(context).jeeberFeedStatusPending,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _WithdrawAction extends StatelessWidget {
  const _WithdrawAction({
    required this.index,
    required this.isWithdrawing,
    required this.onWithdraw,
  });

  final int index;
  final bool isWithdrawing;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: IntrinsicWidth(
        child: Semantics(
          identifier: 'pending_offer_${index}_withdraw_cta',
          button: true,
          // OmdsLoadingButton shows spinner while DELETE is in flight; outline
          child: OmdsLoadingButton(
            key: Key('pending-offer-withdraw-$index'),
            text: AppLocalizations.of(context).offerSubmissionWithdrawButton,
            isLoading: isWithdrawing,
            backgroundColor: theme.colorScheme.errorContainer,
            textColor: theme.colorScheme.onErrorContainer,
            loadingColor: theme.colorScheme.onErrorContainer,
            borderRadius: OmdsBorderRadius.pill,
            onTap: onWithdraw ?? () {},
          ),
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [PendingOfferRow] — run with

/// The width the row actually lays out at on a phone. A widget test pumps an
/// 800 dp surface, where every truncation below disappears, so the previews pin
const double _pendingOfferRowPhoneWidth = 390;

/// An OPEN offer: price + ETA + awaiting label + a 48 dp Withdraw button +
/// divider. Measures 141 dp at 1x and 181 dp at 200% text, so the box is tall
const Size _pendingOfferRowOpenBox = Size(390, 200);

/// A TERMINAL offer: no awaiting label and no Withdraw button, so the row drops
/// to 89 dp (129 dp at 200% text). A pending list mixing open and terminal
const Size _pendingOfferRowTerminalBox = Size(390, 140);

/// The row as the feed and the standalone screen build it, pinned to phone
/// width.
Widget _pendingOfferRowHosted(
  SubmittedOffer offer, {
  int index = 0,
  bool isWithdrawing = false,
}) {
  final Widget row = PendingOfferRow(
    index: index,
    offer: offer,
    isWithdrawing: isWithdrawing,
    onWithdraw: () {},
  );
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: _pendingOfferRowPhoneWidth,
      // The row's own [Column] is `MainAxisSize.max`, so handed a bounded
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isWithdrawing) TickerMode(enabled: false, child: row) else row,
        ],
      ),
    ),
  );
}

/// The default reading, and the state JM-047 AC1/AC2 assert: an offer still
/// awaiting the customer's decision.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Awaiting decision',
  size: _pendingOfferRowOpenBox,
)
Widget pendingOfferRowAwaiting() => _pendingOfferRowHosted(
      const SubmittedOffer(
        id: 'pending-offer-jeeber-001',
        requestId: 'req-pending-offer-jeeber-001',
        price: 12.5,
        currency: 'USD',
        etaMinutes: 25,
      ),
    );

/// `DELETE /offer-service/v1/offers/:id` is in flight (D15).
/// This is the state [OmdsLoadingButton] was chosen for over
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Withdraw in flight',
  size: _pendingOfferRowOpenBox,
)
Widget pendingOfferRowWithdrawing() => _pendingOfferRowHosted(
      const SubmittedOffer(
        id: 'pending-offer-jeeber-002',
        requestId: 'req-pending-offer-jeeber-002',
        price: 18,
        currency: 'USD',
        etaMinutes: 40,
      ),
      isWithdrawing: true,
    );

/// `etaMinutes` is nullable and the ETA slot disappears entirely when it is
/// null — a jeeber may quote a price without committing to a time.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'No ETA',
  size: _pendingOfferRowOpenBox,
)
Widget pendingOfferRowNoEta() => _pendingOfferRowHosted(
      const SubmittedOffer(
        id: 'pending-offer-jeeber-003',
        requestId: 'req-pending-offer-jeeber-003',
        price: 7.25,
        currency: 'USD',
      ),
    );

/// sprint-009 terminal state: the customer accepted THIS offer.
/// The branch that must never regress — a terminal offer shows an outcome badge
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Accepted · terminal',
  size: _pendingOfferRowTerminalBox,
)
Widget pendingOfferRowAccepted() => _pendingOfferRowHosted(
      const SubmittedOffer(
        id: 'accepted-1',
        requestId: 'r1',
        price: 9,
        currency: 'USD',
        etaMinutes: 15,
        status: OfferStatus.accepted,
      ),
    );

/// sprint-009 terminal state: the customer accepted somebody else's offer.
/// The badge's copy is borrowed: `requestFeedActionDeclinedSnack` ("Request
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Not selected · terminal',
  size: _pendingOfferRowTerminalBox,
)
Widget pendingOfferRowLost() => _pendingOfferRowHosted(
      const SubmittedOffer(
        id: 'lost-1',
        requestId: 'r2',
        price: 6.5,
        currency: 'USD',
        etaMinutes: 30,
        status: OfferStatus.lost,
      ),
    );

/// The width ceiling: the widest money string the app can produce, next to the
/// widest plausible ETA.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Long price + ETA',
  size: _pendingOfferRowOpenBox,
)
Widget pendingOfferRowLongContent() => _pendingOfferRowHosted(
      const SubmittedOffer(
        id: 'pending-offer-jeeber-004',
        requestId: 'req-pending-offer-jeeber-004',
        price: 2750000,
        currency: 'LBP',
        etaMinutes: 1440,
      ),
    );
