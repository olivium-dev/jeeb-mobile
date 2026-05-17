import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/order_summary.dart';
import 'order_status_chip.dart';

/// Single row in the order history list. Tap surface, two-line address
/// summary, status pill, formatted amount, and a tier icon.
///
/// The card is intentionally self-contained — it takes the locale and an
/// [onTap] callback and renders. No BLoC subscription, so it's trivial to
/// embed in goldens or storybook.
class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = DateFormat.yMMMd(locale).add_jm().format(
          order.createdAt.toLocal(),
        );
    final amountLabel = NumberFormat.simpleCurrency(
      locale: locale,
      name: order.currency,
    ).format(order.amountMinor / 100);

    return Semantics(
      button: true,
      label: l10n.orderHistoryCardSemanticLabel(order.id),
      child: InkWell(
        key: Key('order-history-card-${order.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                dateLabel: dateLabel,
                status: order.status,
              ),
              const SizedBox(height: 8),
              _AddressLine(
                icon: Icons.trip_origin,
                iconColor: scheme.primary,
                label: order.pickupAddress.isEmpty
                    ? l10n.orderHistoryAddressMissing
                    : order.pickupAddress,
              ),
              const SizedBox(height: 4),
              _AddressLine(
                icon: Icons.location_on_outlined,
                iconColor: scheme.error,
                label: order.dropoffAddress.isEmpty
                    ? l10n.orderHistoryAddressMissing
                    : order.dropoffAddress,
              ),
              const SizedBox(height: 8),
              _Footer(tier: order.tier, amountLabel: amountLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dateLabel, required this.status});

  final String dateLabel;
  final OrderRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            dateLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        OrderStatusChip(status: status),
      ],
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.tier, required this.amountLabel});

  final OrderTier tier;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        _TierBadge(tier: tier),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _tierLabel(tier, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          amountLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static String _tierLabel(OrderTier tier, AppLocalizations l10n) {
    switch (tier) {
      case OrderTier.flash:
        return l10n.tierSelectionTierFlash;
      case OrderTier.express:
        return l10n.tierSelectionTierExpress;
      case OrderTier.standard:
        return l10n.tierSelectionTierStandard;
      case OrderTier.onTheWay:
        return l10n.tierSelectionTierOnTheWay;
      case OrderTier.eco:
        return l10n.tierSelectionTierEco;
    }
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final OrderTier tier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _iconFor(tier),
        size: 16,
        color: scheme.onSecondaryContainer,
      ),
    );
  }

  static IconData _iconFor(OrderTier tier) {
    switch (tier) {
      case OrderTier.flash:
        return Icons.flash_on;
      case OrderTier.express:
        return Icons.rocket_launch_outlined;
      case OrderTier.standard:
        return Icons.local_shipping_outlined;
      case OrderTier.onTheWay:
        return Icons.alt_route;
      case OrderTier.eco:
        return Icons.eco_outlined;
    }
  }
}
