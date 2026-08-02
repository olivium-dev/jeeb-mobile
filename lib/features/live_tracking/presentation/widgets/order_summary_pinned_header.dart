import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_tracking_info.dart';
import '../live_tracking_l10n.dart';

import '../../../../core/previews/jeeb_preview.dart';

class OrderSummaryPinnedHeader extends StatelessWidget {
  const OrderSummaryPinnedHeader({
    super.key,
    required this.info,
    this.onOpenChat,
    this.onTrack,
  });

  final DeliveryTrackingInfo info;

  final VoidCallback? onOpenChat;

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
      explicitChildNodes: true,
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
                  Flexible(
                    child: Semantics(
                      identifier: 'order_summary_price',
                      child: Text(
                        _formatPrice(price, info.currency),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            _HeaderFactStrip(
              tier: tier == null || tier.isEmpty
                  ? null
                  : '${l10n.summaryTierLabel}: ${l10n.tierName(tier)}',
              eta: eta == null
                  ? l10n.summaryEtaPending
                  : '${l10n.summaryEtaLabel}: ${l10n.summaryEtaMinutes(eta)}',
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

/// case — `Wrap` hands its children unbounded main-axis constraints, so a
class _HeaderFactStrip extends StatelessWidget {
  const _HeaderFactStrip({required this.tier, required this.eta});

  final String? tier;

  final String eta;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget fact(String identifier, String text) => ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Semantics(
                identifier: identifier,
                child: Text(
                  text,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
        return Wrap(
          spacing: Spacing.medium,
          runSpacing: Spacing.xSmall,
          children: [
            if (tier != null) fact('order_summary_tier', tier!),
            fact('order_summary_eta', eta),
          ],
        );
      },
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
const Size _orderSummaryPinnedHeaderBox = Size(390, 448);

/// The long-name state needs its own box, and the reason IS the finding.
const Size _orderSummaryPinnedHeaderLongNameBox = Size(390, 736);

/// Builds the header exactly as a surface mounts it.
Widget _orderSummaryPinnedHeaderHosted(
  DeliveryTrackingInfo info, {
  bool trackCta = false,
}) =>
    OrderSummaryPinnedHeader(
      info: info,
      onOpenChat: () {},
      onTrack: trackCta ? () {} : null,
    );

/// An accepted-order row, with every summary field overridable.
DeliveryTrackingInfo _orderSummaryPinnedHeaderInfo({
  required String deliveryId,
  String? jeeberName = 'Kamal Hajj',
  double? price = 12.5,
  String? currency = 'USD',
  String? tier = 'express',
  int? etaMinutes = 8,
  String? itemSummary = 'painkillers from the pharmacy',
}) =>
    DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: TrackingStage.inTransit,
      stageTimestamps: const <TrackingStage, DateTime>{},
      price: price,
      currency: currency,
      jeeberName: jeeberName,
      tier: tier,
      etaMinutes: etaMinutes,
      itemSummary: itemSummary,
    );

/// The production tracking-surface rendering: every field resolved, chat CTA
@JeebPreview(group: 'live_tracking', name: 'Tracking surface', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderTracking() =>
    _orderSummaryPinnedHeaderHosted(_orderSummaryPinnedHeaderInfo(deliveryId: 'd-32-tracking'));

/// The JM-031 chat/deep-link rendering, which is the ONLY one with two CTAs.
@JeebPreview(group: 'live_tracking', name: 'Chat parity (both CTAs)', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderBothCtas() =>
    _orderSummaryPinnedHeaderHosted(_orderSummaryPinnedHeaderInfo(deliveryId: 'd-32-chat'), trackCta: true);

/// The reported overflow, made visible: no ETA yet and no tier.
@JeebPreview(group: 'live_tracking', name: 'ETA pending, no tier', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderEtaPending() => _orderSummaryPinnedHeaderHosted(
      _orderSummaryPinnedHeaderInfo(deliveryId: 'd-32-pending', tier: null, etaMinutes: null),
    );

/// An unmapped tier id, echoed raw — the #208 regression class.
@JeebPreview(group: 'live_tracking', name: 'Unmapped tier id', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderUnmappedTier() => _orderSummaryPinnedHeaderHosted(
      _orderSummaryPinnedHeaderInfo(
        deliveryId: 'd-32-tier',
        tier: 'premium-white-glove-same-day-metropolitan',
      ),
    );

/// A high-magnitude price beside a long name — the top row's own ceiling, and
@JeebPreview(group: 'live_tracking', name: 'Long name + huge price', size: _orderSummaryPinnedHeaderLongNameBox)
Widget orderSummaryPinnedHeaderHugePrice() => _orderSummaryPinnedHeaderHosted(
      _orderSummaryPinnedHeaderInfo(
        deliveryId: 'd-32-price',
        jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        price: 1234567.89,
        currency: 'SYP',
      ),
    );

/// Bidi: an Arabic item summary inside an English UI.
@JeebPreview(group: 'live_tracking', name: 'Arabic item in EN UI', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderArabicItem() => _orderSummaryPinnedHeaderHosted(
      _orderSummaryPinnedHeaderInfo(
        deliveryId: 'd-32-bidi',
        itemSummary: '٢ كيلو تفاح من سبينيس',
      ),
    );
