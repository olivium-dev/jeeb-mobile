import 'package:flutter/widgets.dart';

import '../../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_tracking_info.dart';
import 'tracking_courier_card.dart' show formatTrackingPrice;

/// JM-031/JM-032: the accepted-order facts, as SEMANTICS ONLY.
///
/// MIDNIGHT R3 draws no pinned header — the grey slab, then the two-line top
/// bar, are both gone. Every fact the JM-031 contract names is now *visible*
/// somewhere the board does draw (name + price + cash on the courier line, ETA
/// on the map chip, chat on the courier circle), so what remains here is the
/// frozen id set on zero-size nodes: assistive tech and Maestro keep reading
/// `order_summary_*`, and no pixel is spent hosting them.
///
/// The doc-13 P1 carry-in is settled by construction: with nothing laid out
/// there is no five-run wrap, no missing middot and no three-line overflow.
///
/// CUSTOMER-FACING: NO commission/finance line is ever exposed here (D11).
class OrderSummaryPinnedHeader extends StatelessWidget {
  const OrderSummaryPinnedHeader({
    super.key,
    required this.info,
    this.onOpenChat,
    this.onTrack,
  });

  final DeliveryTrackingInfo info;

  /// Retained for API stability. The chat CTA is the courier row's circle now,
  /// which is where the board draws it; passing a callback here draws nothing.
  final VoidCallback? onOpenChat;

  /// Retained for API stability — `order_summary_track` has never rendered on
  /// the tracking surface itself (it would be a self-navigating CTA).
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final price = info.price;
    final tier = info.tier;
    final eta = info.etaMinutes;
    final hasTier = tier != null && tier.isNotEmpty;

    return Semantics(
      identifier: 'order_summary_pinned',
      container: true,
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 1 — tier. Absent entirely when the row carries none (pinned by
          // `tracking_header_overflow_test`).
          if (hasTier)
            _Fact(
              'order_summary_tier',
              '${JeebTierChip.emojiFor(tier)} ${_tierName(l10n, tier)}',
            ),
          // 2 — price, formatted exactly as the courier line renders it.
          if (price != null)
            _Fact(
              'order_summary_price',
              formatTrackingPrice(price, info.currency),
            ),
          // 3 — the D11 cash reminder, as the full sentence rather than the
          // courier line's short qualifier.
          _Fact('order_summary_cash_label', l10n.orderSummaryCashLabel),
          // 4 — D-12-1: the jeeber name run C1 pins.
          _Fact('order_summary_jeeber_name', info.jeeberName ?? ''),
          // 5 — D-12-2: ETA, the same value the map chip announces.
          _Fact(
            'order_summary_eta',
            eta == null
                ? l10n.trackingEtaPending
                : '${l10n.trackingEtaLabel}: '
                    '${l10n.trackingEtaMinutes(eta)}',
          ),
        ],
      ),
    );
  }

  /// Tier id → localized display name; unknown ids fall back to the raw id.
  static String _tierName(AppLocalizations l10n, String tierId) {
    switch (tierId.toLowerCase().replaceAll('_', '-')) {
      case 'flash':
        return l10n.tierSelectionTierFlash;
      case 'express':
        return l10n.tierSelectionTierExpress;
      case 'standard':
        return l10n.tierSelectionTierStandard;
      case 'on-the-way':
      case 'ontheway':
        return l10n.tierSelectionTierOnTheWay;
      case 'eco':
        return l10n.tierSelectionTierEco;
      default:
        return tierId;
    }
  }
}

/// One addressable, unrendered fact.
class _Fact extends StatelessWidget {
  const _Fact(this.identifier, this.value);

  final String identifier;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
        identifier: identifier,
        label: value,
        container: true,
        child: const SizedBox.shrink(),
      );
}
