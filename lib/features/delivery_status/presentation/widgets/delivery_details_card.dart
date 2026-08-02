import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_snapshot.dart';
import '../../domain/delivery_tier.dart';

import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/delivery_address.dart';
import '../../domain/delivery_stage.dart';

/// Pickup / drop-off / tier section. Pure-presentational — relies on the
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
              const SizedBox(height: Sizes.threeXSmall),
              Text(
                primary,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (secondary != null && secondary!.isNotEmpty) ...[
                const SizedBox(height: Sizes.threeXSmall),
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

// ============================== JEEB PREVIEWS ==============================
const Size _deliveryDetailsCardShortCardBox = Size(390, 420);

/// The normal band — sub-lines present, or a label that wraps to two lines.
const Size _deliveryDetailsCardBox = Size(390, 840);

/// The wrapping ceiling. 1918 dp is over three phone screens of card, and that
const Size _deliveryDetailsCardTallCardBox = Size(390, 1960);

/// A delivery address as customers actually dictate one — a full street line
const String _deliveryDetailsCardLongPickupLabel =
    'Rue Abdel Aziz, off Hamra Main Street, Ras Beirut, Beirut Governorate';

/// The matching drop-off: the run-on "which door" instruction that arrives in
const String _deliveryDetailsCardLongDropoffDetail =
    'Building B, the beige one facing the pharmacy, 4th floor, apartment 12, '
    'please ring the intercom twice because the doorbell has been broken since '
    'last week and leave it with the concierge if nobody answers';

/// Builds a snapshot whose only meaningful fields are the three the card reads.
DeliverySnapshot _deliveryDetailsCardSnapshot({
  required DeliveryAddress pickup,
  required DeliveryAddress dropoff,
  required DeliveryTier tier,
}) {
  return DeliverySnapshot(
    id: 'd-1',
    stage: DeliveryStage.inTransit,
    lifecycle: DeliveryLifecycle.active,
    stageTimestamps: const <DeliveryStage, DateTime>{},
    pickup: pickup,
    dropoff: dropoff,
    tier: tier,
  );
}

Widget _deliveryDetailsCardHosted({
  required DeliveryAddress pickup,
  required DeliveryAddress dropoff,
  required DeliveryTier tier,
}) =>
    DeliveryDetailsCard(
      snapshot: _deliveryDetailsCardSnapshot(pickup: pickup, dropoff: dropoff, tier: tier),
    );

/// The fixture the screen test already uses: bare neighbourhood names, no
@JeebPreview(group: 'delivery_status', name: 'Minimal (no sub-lines)', size: _deliveryDetailsCardShortCardBox)
Widget deliveryDetailsCardMinimal() => _deliveryDetailsCardHosted(
      pickup: const DeliveryAddress(label: 'Hamra'),
      dropoff: const DeliveryAddress(label: 'Verdun'),
      tier: DeliveryTier.scooter,
    );

/// The realistic happy path: a geocoded street line plus the floor/landmark
@JeebPreview(group: 'delivery_status', name: 'Sub-lines on both legs', size: _deliveryDetailsCardBox)
Widget deliveryDetailsCardWithDetails() => _deliveryDetailsCardHosted(
      pickup: const DeliveryAddress(
        label: 'Hamra Main St, Beirut',
        detail: 'Costa Coffee, ground floor',
      ),
      dropoff: const DeliveryAddress(
        label: 'Verdun 730, Beirut',
        detail: 'Building B, 4th floor, Apt 12',
      ),
      tier: DeliveryTier.car,
    );

/// The label collision, made visible.
@JeebPreview(group: 'delivery_status', name: 'Pickup-truck tier', size: _deliveryDetailsCardBox)
Widget deliveryDetailsCardPickupTruckTier() => _deliveryDetailsCardHosted(
      pickup: const DeliveryAddress(label: 'Achrafieh, Sassine Square'),
      dropoff: const DeliveryAddress(label: 'Jounieh, Old Souk'),
      tier: DeliveryTier.pickup,
    );

/// Degraded data: the gateway has not resolved the pickup yet, so its label is
@JeebPreview(group: 'delivery_status', name: 'Unresolved pickup', size: _deliveryDetailsCardBox)
Widget deliveryDetailsCardUnresolvedPickup() => _deliveryDetailsCardHosted(
      pickup: const DeliveryAddress(label: '', detail: 'Awaiting geocode'),
      dropoff: const DeliveryAddress(label: 'Mar Mikhael, Beirut', detail: ''),
      tier: DeliveryTier.bike,
    );

/// The layout ceiling: longest-plausible label AND longest-plausible sub-line
@JeebPreview(group: 'delivery_status', name: 'Longest content', size: _deliveryDetailsCardTallCardBox)
Widget deliveryDetailsCardLongContent() => _deliveryDetailsCardHosted(
      pickup: const DeliveryAddress(
        label: _deliveryDetailsCardLongPickupLabel,
        detail: 'Ask for Nadia at the service counter, not the till',
      ),
      dropoff: const DeliveryAddress(
        label: 'Sin El Fil, Horch Tabet, Boulevard Camille Chamoun',
        detail: _deliveryDetailsCardLongDropoffDetail,
      ),
      tier: DeliveryTier.bike,
    );

/// Bidi: Arabic addresses inside an English UI.
@JeebPreview(group: 'delivery_status', name: 'Arabic addresses in EN UI', size: _deliveryDetailsCardBox)
Widget deliveryDetailsCardArabicAddresses() => _deliveryDetailsCardHosted(
      pickup: const DeliveryAddress(
        label: 'شارع الحمرا، بيروت',
        detail: 'الطابق الأرضي، مقهى كوستا',
      ),
      dropoff: const DeliveryAddress(
        label: 'فردان ٧٣٠، بيروت',
        detail: 'المبنى ب، الطابق الرابع، شقة ١٢',
      ),
      tier: DeliveryTier.scooter,
    );
