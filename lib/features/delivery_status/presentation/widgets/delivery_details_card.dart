import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_snapshot.dart';
import '../../domain/delivery_tier.dart';

/// Pickup / drop-off / tier section. Pure-presentational — relies on the
/// caller to embed it inside the scrolling column.
class DeliveryDetailsCard extends StatelessWidget {
  const DeliveryDetailsCard({super.key, required this.snapshot});

  static const Key rootKey = Key('delivery-status-details');

  final DeliverySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OMDSSectionCard(
      key: rootKey,
      title: l10n.deliveryDetailsTitle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailRow(
            icon: Icons.adjust,
            label: l10n.deliveryPickupLabel,
            primary: snapshot.pickup.label,
            secondary: snapshot.pickup.detail,
          ),
          const SizedBox(height: Spacing.medium),
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: l10n.deliveryDropoffLabel,
            primary: snapshot.dropoff.label,
            secondary: snapshot.dropoff.detail,
          ),
          const SizedBox(height: Spacing.medium),
          _DetailRow(
            icon: _iconForTier(snapshot.tier),
            label: l10n.deliveryTierLabel,
            primary: _labelForTier(l10n, snapshot.tier),
          ),
        ],
      ),
    );
  }

  IconData _iconForTier(DeliveryTier tier) {
    switch (tier) {
      case DeliveryTier.bike:
        return Icons.pedal_bike;
      case DeliveryTier.scooter:
        return Icons.two_wheeler;
      case DeliveryTier.car:
        return Icons.directions_car;
      case DeliveryTier.pickup:
        return Icons.local_shipping;
    }
  }

  String _labelForTier(AppLocalizations l10n, DeliveryTier tier) {
    switch (tier) {
      case DeliveryTier.bike:
        return l10n.deliveryTierBike;
      case DeliveryTier.scooter:
        return l10n.deliveryTierScooter;
      case DeliveryTier.car:
        return l10n.deliveryTierCar;
      case DeliveryTier.pickup:
        return l10n.deliveryTierPickup;
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.primary,
    this.secondary,
  });

  final IconData icon;
  final String label;
  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: Sizes.twoXLarge,
          height: Sizes.twoXLarge,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                primary,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (secondary != null && secondary!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondary!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
