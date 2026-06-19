import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_tracking_info.dart';
import '../live_tracking_l10n.dart';

/// JM-032 AC1 (with JM-031, CTO-D3): the pinned order-summary header injected at
/// the TOP of the tracking screen. Carries the signature id
/// `order_summary_pinned` plus the accepted-order fields the JM-031 contract
/// names (price/jeeber/ETA/tier + "Pay cash on delivery", D11/D71).
///
/// On the tracking surface the summary is sourced from the same delivery row the
/// `LiveTrackingCubit` already polls (`GET /v1/delivery/:id`) — no second fetch
/// and no cross-feature DI coupling. JM-031 owns the standalone pinned WIDGET
/// (chat + deep-link route); this header is its tracking-surface rendering and
/// uses the identical ids so the customer sees one consistent summary.
///
/// CUSTOMER-FACING: NO commission/finance line is ever shown here (D11).
class OrderSummaryPinnedHeader extends StatelessWidget {
  const OrderSummaryPinnedHeader({
    super.key,
    required this.info,
    this.onOpenChat,
    this.onTrack,
  });

  final DeliveryTrackingInfo info;

  /// `order_summary_open_chat` → order-chat (JM-025). Hidden when null.
  final VoidCallback? onOpenChat;

  /// `order_summary_track` → order-tracking (JM-032). On the tracking screen
  /// itself this is the current surface, so it is omitted (null) to avoid a
  /// self-navigating CTA; it exists for parity with the JM-031 chat rendering.
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final theme = Theme.of(context);
    final price = info.price;
    final tier = info.tier;
    final eta = info.etaMinutes;

    return Semantics(
      identifier: 'order_summary_pinned',
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(OMDSBorderRadius.lg),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Jeeber name + price row.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    identifier: 'order_summary_jeeber_name',
                    child: Text(
                      info.jeeberName ?? '',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (price != null)
                  Semantics(
                    identifier: 'order_summary_price',
                    child: Text(
                      _formatPrice(price, info.currency),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            // Tier + ETA chips.
            Row(
              children: [
                if (tier != null && tier.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: Spacing.medium,
                    ),
                    child: Semantics(
                      identifier: 'order_summary_tier',
                      child: Text(
                        '${l10n.summaryTierLabel}: ${l10n.tierName(tier)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                Semantics(
                  identifier: 'order_summary_eta',
                  child: Text(
                    eta == null
                        ? l10n.summaryEtaPending
                        : '${l10n.summaryEtaLabel}: ${l10n.summaryEtaMinutes(eta)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (info.itemSummary != null) ...[
              const SizedBox(height: Spacing.xSmall),
              Text(
                info.itemSummary!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: Spacing.xSmall),
            // "Pay cash on delivery" reminder (D11) — NO commission line.
            Semantics(
              identifier: 'order_summary_cash_label',
              child: Text(
                l10n.summaryCashLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onOpenChat != null || onTrack != null) ...[
              const SizedBox(height: Spacing.small),
              Row(
                children: [
                  if (onOpenChat != null)
                    Expanded(
                      child: Semantics(
                        identifier: 'order_summary_open_chat',
                        button: true,
                        child: OmdsPrimaryButton(
                          text: l10n.summaryOpenChat,
                          variant: OmdsButtonVariant.outlined,
                          onTap: onOpenChat!,
                        ),
                      ),
                    ),
                  if (onOpenChat != null && onTrack != null)
                    const SizedBox(width: Spacing.small),
                  if (onTrack != null)
                    Expanded(
                      child: Semantics(
                        identifier: 'order_summary_track',
                        button: true,
                        child: OmdsPrimaryButton(
                          text: l10n.summaryTrack,
                          onTap: onTrack!,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price, String? currency) {
    final amount = price.toStringAsFixed(2);
    return currency == null ? amount : '$amount $currency';
  }
}
