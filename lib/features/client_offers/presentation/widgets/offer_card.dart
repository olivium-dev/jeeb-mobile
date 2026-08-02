import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/formatting/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_vehicle.dart';
import '../../domain/offer.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.index,
    required this.onAccept,
    required this.onTapName,
    this.isAccepting = false,
    this.acceptDisabled = false,
  });

  final Offer offer;

  final int index;

  final VoidCallback onAccept;

  final VoidCallback onTapName;

  final bool isAccepting;

  final bool acceptDisabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feeFormatted = MoneyFormat.format(
      offer.fee,
      currency: offer.currency,
    );
    final vehicleLabel = _vehicleLabel(l10n, offer.vehicle);

    final note = offer.note?.trim();
    final hasNote = note != null && note.isNotEmpty;

    final displayName =
        displayNameOrNull(offer.jeeberName) ?? l10n.offersCardJeeberFallback;
    final hasRatings = offer.ratingCount > 0;

    final baseSemanticLabel = hasRatings
        ? l10n.offersCardSemanticLabel(
            name: displayName,
            rating: offer.rating.toStringAsFixed(1),
            vehicle: vehicleLabel,
            fee: feeFormatted,
            currency: offer.currency,
            minutes: offer.etaMinutes,
          )
        : l10n.offersCardSemanticLabelUnrated(
            name: displayName,
            vehicle: vehicleLabel,
            fee: feeFormatted,
            currency: offer.currency,
            minutes: offer.etaMinutes,
          );
    final semanticLabel = hasNote
        ? '$baseSemanticLabel. $note'
        : baseSemanticLabel;

    return _DualId(
      indexId: 'offer_card_$index',
      patternId: 'offer_card_${offer.jeeberId}',
      label: semanticLabel,
      child: Card(
        key: Key('offer-card-${offer.id}'),
        margin: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
        elevation: UIConstants.elevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: OmdsBorderRadius.medium,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OfferCardHeader(
                displayName: displayName,
                avatarUrl: offer.avatarUrl,
                averageRating: offer.rating,
                ratingCount: offer.ratingCount,
                hasRatings: hasRatings,
                noRatingsLabel: l10n.offersCardNoRatingsYet,
                feeFormatted: feeFormatted,
                nameIndexId: 'offer_card_${index}_name',
                namePatternId: 'offer_card_${offer.jeeberId}_name',
                priceIndexId: 'offer_card_${index}_price',
                pricePatternId: 'offer_card_${offer.jeeberId}_price',
                onTapName: onTapName,
              ),
              const SizedBox(height: Spacing.small),
              Wrap(
                spacing: Spacing.xSmall,
                runSpacing: Spacing.xSmall,
                children: [
                  _IdWrap(
                    indexId: 'offer_card_${index}_eta',
                    patternId: 'offer_card_${offer.jeeberId}_eta',
                    child: _MetaChip(
                      icon: Icons.access_time,
                      label: l10n.offersCardEtaMinutes(offer.etaMinutes),
                    ),
                  ),
                  _MetaChip(
                    icon: _vehicleIcon(offer.vehicle),
                    label: vehicleLabel,
                  ),
                ],
              ),
              if (hasNote) ...[
                const SizedBox(height: Spacing.small),
                _IdWrap(
                  indexId: 'offer_card_${index}_note',
                  patternId: 'offer_card_${offer.jeeberId}_note',
                  child: _OfferNoteLine(note: note),
                ),
              ],
              const SizedBox(height: Spacing.small),
              _IdWrap(
                indexId: 'offer_card_${index}_cash_on_delivery_label',
                patternId:
                    'offer_card_${offer.jeeberId}_cash_on_delivery_label',
                child: Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: Sizes.medium,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.xSmall),
                    Expanded(
                      child: Text(
                        l10n.offerCardCashOnDelivery(
                          feeFormatted,
                          offer.currency,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.medium),
              _AcceptCta(
                indexId: 'offer_card_${index}_accept_cta',
                patternId: 'offer_card_${offer.jeeberId}_accept_cta',
                label: isAccepting
                    ? l10n.offersCardAccepting
                    : l10n.offersCardAccept,
                offerId: offer.id,
                enabled: !acceptDisabled && !isAccepting,
                loading: isAccepting,
                onTap: onAccept,
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

class _OfferCardHeader extends StatelessWidget {
  const _OfferCardHeader({
    required this.displayName,
    required this.avatarUrl,
    required this.averageRating,
    required this.ratingCount,
    required this.hasRatings,
    required this.noRatingsLabel,
    required this.feeFormatted,
    required this.nameIndexId,
    required this.namePatternId,
    required this.priceIndexId,
    required this.pricePatternId,
    required this.onTapName,
  });

  final String displayName;
  final String? avatarUrl;
  final double averageRating;
  final int ratingCount;
  final bool hasRatings;
  final String noRatingsLabel;
  final String feeFormatted;
  final String nameIndexId;
  final String namePatternId;
  final String priceIndexId;
  final String pricePatternId;
  final VoidCallback onTapName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmdsProfileAvatar(
              initial: OfferCard._initial(displayName),
              profilePicUrl: avatarUrl,
              size: Sizes.fourXLarge,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: _NameTapTarget(
                indexId: nameIndexId,
                patternId: namePatternId,
                name: displayName,
                onTap: onTapName,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Wrap(
          spacing: Spacing.small,
          runSpacing: Spacing.twoXSmall,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (hasRatings)
              _RatingSummary(
                averageRating: averageRating,
                ratingCount: ratingCount,
              )
            else
              _NoRatingsYet(label: noRatingsLabel),
            _IdWrap(
              indexId: priceIndexId,
              patternId: pricePatternId,
              child: _FeePill(amount: feeFormatted),
            ),
          ],
        ),
      ],
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({
    required this.averageRating,
    required this.ratingCount,
  });

  final double averageRating;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OmdsStarRatingDisplay(
          averageRating: averageRating,
          starSize: Sizes.medium,
          showReviewCount: false,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Flexible(
          child: Text(
            '($ratingCount)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

const int _kOfferNoteMaxLines = 3;

class _OfferNoteLine extends StatelessWidget {
  const _OfferNoteLine({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: Sizes.medium,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            note,
            maxLines: _kOfferNoteMaxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoRatingsYet extends StatelessWidget {
  const _NoRatingsYet({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      identifier: 'offer_card_no_ratings',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_border,
            size: Sizes.medium,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdWrap extends StatelessWidget {
  const _IdWrap({
    required this.indexId,
    required this.patternId,
    required this.child,
  });

  final String indexId;
  final String patternId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: indexId,
      child: Semantics(identifier: patternId, child: child),
    );
  }
}

class _DualId extends StatelessWidget {
  const _DualId({
    required this.indexId,
    required this.patternId,
    required this.label,
    required this.child,
  });

  final String indexId;
  final String patternId;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: indexId,
      container: true,
      label: label,
      explicitChildNodes: true,
      child: Semantics(
        identifier: patternId,
        explicitChildNodes: true,
        child: child,
      ),
    );
  }
}

class _NameTapTarget extends StatelessWidget {
  const _NameTapTarget({
    required this.indexId,
    required this.patternId,
    required this.name,
    required this.onTap,
  });

  final String indexId;
  final String patternId;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: indexId,
      button: true,
      label: name,
      onTap: onTap,
      child: Semantics(
        identifier: patternId,
        child: ExcludeSemantics(
          child: InkWell(
            key: Key('offer-card-name-$name'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.fourXLarge),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1.0,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptCta extends StatelessWidget {
  const _AcceptCta({
    required this.indexId,
    required this.patternId,
    required this.label,
    required this.offerId,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String indexId;
  final String patternId;
  final String label;
  final String offerId;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: indexId,
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onTap : null,
      child: Semantics(
        identifier: patternId,
        child: ExcludeSemantics(
          child: SizedBox(
            width: double.infinity,
            child: OmdsPrimaryButton(
              key: Key('offer-card-accept-$offerId'),
              text: label,
              isEnabled: enabled,
              onTap: onTap,
              icon: loading ? const OmdsButtonLoading() : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeePill extends StatelessWidget {
  const _FeePill({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Text(
        amount,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: colors.onPrimaryContainer,
        ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.medium, color: colors.onSurfaceVariant),
          const SizedBox(width: Spacing.xSmall),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
