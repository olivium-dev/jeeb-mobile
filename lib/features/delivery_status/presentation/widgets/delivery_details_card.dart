import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_snapshot.dart';
import '../../domain/delivery_tier.dart';

/// Pickup / drop-off / tier section. Pure-presentational — relies on the
/// caller to embed it inside the scrolling column.
///
/// redesign-2026-08: `OMDSSectionCard` + three hand-rolled rows (each with a
/// peach `primaryContainer` icon disc) become the house shape — a
/// [JeebSectionLabel] over one grouped [JeebOutlinedCard] of [JeebListRow]s.
/// The address is the FACT so it takes the row title; the field name is the
/// qualifier and rides the subtitle beside the optional second address line
/// (`Pickup · Floor 3`), which is the ranking every other redesigned list on
/// this journey uses.
class DeliveryDetailsCard extends StatelessWidget {
  const DeliveryDetailsCard({super.key, required this.snapshot});

  static const Key rootKey = Key('delivery-status-details');

  final DeliverySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: rootKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.deliveryDetailsTitle),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard.grouped(
          children: [
            JeebListRow(
              icon: Icons.adjust,
              title: snapshot.pickup.label,
              subtitle: _qualifier(l10n.deliveryPickupLabel, snapshot.pickup.detail),
              showChevron: false,
            ),
            JeebListRow(
              // Filled glyph (R10).
              icon: Icons.location_on,
              title: snapshot.dropoff.label,
              subtitle:
                  _qualifier(l10n.deliveryDropoffLabel, snapshot.dropoff.detail),
              showChevron: false,
            ),
            JeebListRow(
              icon: _iconForTier(snapshot.tier),
              title: _labelForTier(l10n, snapshot.tier),
              subtitle: l10n.deliveryTierLabel,
              showChevron: false,
            ),
          ],
        ),
      ],
    );
  }

  /// `Pickup`, or `Pickup · Floor 3` when the address carries a second line.
  /// Never fabricates a detail — an absent one simply leaves the field name.
  String _qualifier(String label, String? detail) =>
      (detail == null || detail.isEmpty) ? label : '$label · $detail';

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
