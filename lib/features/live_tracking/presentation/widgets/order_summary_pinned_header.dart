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
                  // Flexible, not rigid: the name beside it is Expanded, so a
                  // long price would otherwise starve the name to zero width
                  // and then overflow the row itself.
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
            // Tier + ETA facts. See [_HeaderFactStrip] for why this is not a Row.
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

/// The tier + ETA line of the pinned header.
///
/// ## Why this is a [Wrap] and not a [Row]
///
/// It used to be a `Row` holding two bare `Text` children with no `Expanded`,
/// no `Flexible`, no `maxLines` and no `overflow`. A `Row` lays non-flex
/// children out with `maxWidth: infinity`, so each `Text` claimed its full
/// unwrapped intrinsic width and `RenderFlex` painted the overflow stripe: on a
/// Samsung A33 (411.4 dp wide, less `Spacing.medium` padding either side =
/// 379.4 dp of content) the strip reported **RIGHT OVERFLOWED BY 75 PIXELS**.
/// There was no shrink capacity anywhere in the row, so any excess was a hard
/// overflow rather than a wrap or a truncation.
///
/// Three things stack to produce that excess, and all three are ordinary:
///   * text scaling — the app clamps at 2.0 and the a11y AC requires 200%
///     without overflow, which doubles both labels while the box does not;
///   * Arabic — `summaryEtaPending` is 11 characters in English and 25 in
///     Arabic ("الوقت المقدّر قيد التحديد"), so RTL is materially worse;
///   * an unmapped tier id — `LiveTrackingL10n.tierName` echoes the raw id back
///     for anything outside its five known slugs, and since #208 that id comes
///     straight off the wire, so it can be arbitrarily long.
///
/// A `Wrap` cannot overflow horizontally: when the two facts no longer fit side
/// by side they stack onto a second run, which keeps both readable at 200%
/// instead of truncating them. The [ConstrainedBox] is what handles the third
/// case — `Wrap` hands its children unbounded main-axis constraints, so a
/// single token longer than the line would still overflow without an explicit
/// ceiling; bounded to the strip's own width it ellipsises instead.
///
/// The durable fix belongs one level down, in `omds-flutter`: `OmdsChip`
/// centres its capsule with a `Center` (expanding to its constraints) and
/// renders an un-ellipsisable label, which is why it could not simply be
/// dropped in here — the same substitution was tried and reverted on the chat
/// header (`order_chat_pinned_summary.dart`). Until `OmdsChip` shrink-wraps and
/// ellipsises, this local strip is the fix.
class _HeaderFactStrip extends StatelessWidget {
  const _HeaderFactStrip({required this.tier, required this.eta});

  /// Pre-composed tier label, or null when the delivery carries no tier.
  final String? tier;

  /// Pre-composed ETA label. Always rendered — it has a "pending" form.
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
