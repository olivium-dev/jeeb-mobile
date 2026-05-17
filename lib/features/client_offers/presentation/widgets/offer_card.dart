import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_vehicle.dart';
import '../../domain/offer.dart';

/// One offer card in the client offer list. Renders the Jeeber's identity,
/// the price + ETA + vehicle facts, the rating, and the Accept CTA.
///
/// The card is intentionally self-contained — it takes the offer payload plus
/// two flags from the cubit ([isAccepting], [acceptDisabled]) and emits a tap
/// callback. No cubit access here so the widget can be golden-tested with
/// fixture data.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    this.isAccepting = false,
    this.acceptDisabled = false,
  });

  final Offer offer;
  final VoidCallback onAccept;

  /// True while the cubit's accept call is in-flight on this offer.
  final bool isAccepting;

  /// True when another offer is mid-accept, or the window has expired, or the
  /// request is closed — the CTA stays visible but inert so the layout
  /// doesn't jump.
  final bool acceptDisabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feeFormatted = offer.fee.toStringAsFixed(2);
    final vehicleLabel = _vehicleLabel(l10n, offer.vehicle);

    final semanticLabel = l10n.offersCardSemanticLabel(
      name: offer.jeeberName,
      rating: offer.rating.toStringAsFixed(1),
      vehicle: vehicleLabel,
      fee: feeFormatted,
      currency: offer.currency,
      minutes: offer.etaMinutes,
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Card(
        key: Key('offer-card-${offer.id}'),
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OmdsProfileAvatar(
                    initial: _initial(offer.jeeberName),
                    profilePicUrl: offer.avatarUrl,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.jeeberName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        OmdsStarRatingDisplay(
                          averageRating: offer.rating,
                          totalReviews: offer.ratingCount,
                          starSize: 14,
                          reviewsLabelBuilder: l10n.offersRatingCount,
                        ),
                      ],
                    ),
                  ),
                  _FeePill(
                    amount: feeFormatted,
                    currency: offer.currency,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MetaChip(
                    icon: Icons.access_time,
                    label: l10n.offersCardEtaMinutes(offer.etaMinutes),
                  ),
                  const SizedBox(width: 8),
                  _MetaChip(
                    icon: _vehicleIcon(offer.vehicle),
                    label: vehicleLabel,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OmdsPrimaryButton(
                  key: Key('offer-card-accept-${offer.id}'),
                  text: isAccepting
                      ? l10n.offersCardAccepting
                      : l10n.offersCardAccept,
                  isEnabled: !acceptDisabled && !isAccepting,
                  onTap: onAccept,
                  icon: isAccepting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  static IconData _vehicleIcon(JeeberVehicle vehicle) {
    switch (vehicle) {
      case JeeberVehicle.car:
        return Icons.directions_car_outlined;
      case JeeberVehicle.motorcycle:
        return Icons.two_wheeler_outlined;
      case JeeberVehicle.bicycle:
        return Icons.pedal_bike_outlined;
      case JeeberVehicle.scooter:
        return Icons.electric_scooter_outlined;
      case JeeberVehicle.walker:
        return Icons.directions_walk_outlined;
      case JeeberVehicle.van:
        return Icons.local_shipping_outlined;
    }
  }

  static String _vehicleLabel(AppLocalizations l10n, JeeberVehicle vehicle) {
    switch (vehicle) {
      case JeeberVehicle.car:
        return l10n.offersCardVehicleCar;
      case JeeberVehicle.motorcycle:
        return l10n.offersCardVehicleMotorcycle;
      case JeeberVehicle.bicycle:
        return l10n.offersCardVehicleBicycle;
      case JeeberVehicle.scooter:
        return l10n.offersCardVehicleScooter;
      case JeeberVehicle.walker:
        return l10n.offersCardVehicleWalker;
      case JeeberVehicle.van:
        return l10n.offersCardVehicleVan;
    }
  }
}

class _FeePill extends StatelessWidget {
  const _FeePill({required this.amount, required this.currency});

  final String amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onPrimaryContainer,
            ),
          ),
          Text(
            currency,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
