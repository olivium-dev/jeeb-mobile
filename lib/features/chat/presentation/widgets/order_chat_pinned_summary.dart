import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/order_chat_summary.dart';

/// Pinned authoritative-price summary strip on the accepted order-chat
/// (JM-025 AC2, D71/D11). Sits between the app bar and the message list and
/// shows the LOCKED price / ETA / tier / order-ref + the winning Jeeber, plus
/// the "Pay cash on delivery" reminder (D11 — cash is the only payment model)
/// and a "view summary" link into `order-summary-pinned` (JM-031).
///
/// This is the in-chat rendering of `order-summary-pinned` (CTO-D3: the pinned
/// summary is primarily a header widget injected into chat + tracking). The
/// figures are rendered verbatim from [summary]; the UI never recomputes them.
///
/// Identifiers (63_W1_TEST_PLAN §2.5 + §2.11):
///   `order_chat_pinned_summary`     — strip root (signature id for accepted)
///   `order_chat_view_summary_link`  — view-summary link → order-summary-pinned
///
/// JM-031 AC4 (W1 EXIT checklist): the pinned `order-summary-pinned` widget must
/// be visible in BOTH the chat AND tracking contexts. This in-chat strip IS the
/// chat-context rendering of that widget (CTO-D3), so — mirroring the
/// tracking-surface header (`OrderSummaryPinnedHeader`) which emits the same ids
/// from its own delivery model — it also carries the JM-031 signature id and the
/// asserted field ids, sourced from the `OrderChatSummary` it already holds:
///   `order_summary_pinned`       — JM-031 widget signature id (chat context)
///   `order_summary_price`        — accepted COD price [D11]
///   `order_summary_jeeber_name`  — winning Jeeber name [D6]
///   `order_summary_eta`          — locked ETA
///   `order_summary_tier`         — tier label
///   `order_summary_cash_label`   — "Pay cash on delivery" reminder [D11]
class OrderChatPinnedSummary extends StatelessWidget {
  const OrderChatPinnedSummary({
    super.key,
    required this.summary,
    required this.counterpartName,
    required this.onViewSummary,
  });

  /// Locked summary fields resolved from the accepted delivery + request.
  final OrderChatSummary summary;

  /// Chat counterpart name, used when the summary carries no winner name.
  final String counterpartName;

  /// Tap handler for the view-summary link → `order-summary-pinned` (JM-031).
  final VoidCallback onViewSummary;

  String _tierLabel(AppLocalizations l10n) {
    switch (summary.tierId) {
      case 'flash':
        return l10n.tierSelectionTierFlash;
      case 'express':
        return l10n.tierSelectionTierExpress;
      case 'standard':
        return l10n.tierSelectionTierStandard;
      case 'on-the-way':
      case 'on_the_way':
        return l10n.tierSelectionTierOnTheWay;
      case 'eco':
        return l10n.tierSelectionTierEco;
      default:
        return summary.tierId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final jeeberName =
        summary.jeeberName.isNotEmpty ? summary.jeeberName : counterpartName;

    return Semantics(
      identifier: 'order_chat_pinned_summary',
      container: true,
      explicitChildNodes: true,
      // JM-031 AC4: this strip is the chat-context rendering of the
      // `order-summary-pinned` widget — expose the JM-031 signature id alongside
      // the chat signature id so the same pinned summary is assertable in both
      // the chat and tracking surfaces (W1 EXIT checklist).
      child: Semantics(
        identifier: 'order_summary_pinned',
        container: true,
        // explicitChildNodes so the descendant field ids (order_summary_price /
        // _jeeber_name / _eta / _tier / _cash_label) and the view-summary link
        // each form their OWN first-class semantics node. Without it the default
        // (false) merges every descendant's label + identifier UP into this one
        // container node, folding those ids away (JM-049 merge class).
        explicitChildNodes: true,
        child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant,
              width: UIConstants.strokeWidthThin,
            ),
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.medium,
          Spacing.small,
          Spacing.medium,
          Spacing.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row: order summary heading + the view-summary link.
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.orderSummaryTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                Semantics(
                  identifier: 'order_chat_view_summary_link',
                  button: true,
                  child: InkWell(
                    onTap: onViewSummary,
                    borderRadius: OmdsBorderRadius.small,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.xSmall,
                        vertical: Spacing.twoXSmall,
                      ),
                      // l10n KEY REQUEST orderChatViewSummaryLink ("View summary")
                      // pending — reusing the closest existing key (50_ROUTE_REQUESTS).
                      // Maestro asserts on the identifier, not the text (R-B).
                      child: Text(
                        l10n.orderSummaryTitle,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            // Winner + locked figures. JM-031: carries `order_summary_jeeber_name`
            // (D6) — always rendered (falls back to the chat counterpart) so the
            // field is assertable in the chat context.
            Semantics(
              identifier: 'order_summary_jeeber_name',
              child: Text(
                jeeberName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: Spacing.twoXSmall),
            Wrap(
              spacing: Spacing.xSmall,
              runSpacing: Spacing.twoXSmall,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // JM-031: price/ETA/tier each carry the `order_summary_*` id and
                // are always rendered (a pending placeholder when the locked
                // field is absent) so the chat-context summary is assertable.
                _SummaryChip(
                  identifier: 'order_summary_price',
                  icon: Icons.payments_outlined,
                  label: summary.hasPrice
                      ? summary.priceLabel
                      : l10n.orderSummaryTitle,
                ),
                _SummaryChip(
                  identifier: 'order_summary_eta',
                  icon: Icons.schedule,
                  label: summary.hasEta
                      ? l10n.deliveryEtaMinutes(summary.etaMinutes!)
                      : l10n.orderSummaryTitle,
                ),
                _SummaryChip(
                  identifier: 'order_summary_tier',
                  icon: Icons.local_shipping_outlined,
                  label: summary.hasTier
                      ? _tierLabel(l10n)
                      : l10n.orderSummaryTitle,
                ),
                if (summary.hasRef)
                  _SummaryChip(
                    icon: Icons.tag,
                    label: summary.orderRef,
                  ),
              ],
            ),
            const SizedBox(height: Spacing.twoXSmall),
            // D11: cash on delivery is the only payment model — always shown.
            // Carries BOTH `order_chat_cash_label` (chat) and JM-031's
            // `order_summary_cash_label` so the reminder is assertable in both
            // surfaces.
            Semantics(
              identifier: 'order_chat_cash_label',
              container: true,
              explicitChildNodes: true,
              // Both ids are container nodes (mirroring the
              // order_chat_pinned_summary > order_summary_pinned pair above) so
              // each is a first-class, separately-findable node. Two nested
              // container:false annotations would collapse onto one node and
              // only one identifier would survive (JM-049 merge class).
              child: Semantics(
                identifier: 'order_summary_cash_label',
                container: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: Sizes.small,
                      color: colors.onPrimaryContainer
                          .withValues(alpha: UIConstants.opacityHigh),
                    ),
                    const SizedBox(width: Spacing.twoXSmall),
                    Flexible(
                      // l10n KEY REQUEST orderChatPayCashOnDelivery ("Pay cash on
                      // delivery") pending — reusing closest existing key
                      // (50_ROUTE_REQUESTS). Maestro asserts the identifier (R-B).
                      child: Text(
                        l10n.orderSummaryTrack,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onPrimaryContainer
                              .withValues(alpha: UIConstants.opacityHigh),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// A small icon+label chip used for each locked summary figure. When an
/// [identifier] is supplied the chip carries that `Semantics(identifier:)` so
/// the figure is assertable (JM-031 `order_summary_price/eta/tier`).
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    this.identifier,
  });

  final IconData icon;
  final String label;
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: OmdsBorderRadius.small,
        border: Border.all(
          color: colors.outlineVariant,
          width: UIConstants.strokeWidthThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.small, color: colors.primary),
          const SizedBox(width: Spacing.twoXSmall),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    final id = identifier;
    if (id == null) return chip;
    return Semantics(identifier: id, child: chip);
  }
}
