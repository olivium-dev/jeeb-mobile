import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb_verified_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/widgets/auto_direction_text.dart';
import 'delivery_man_meta_row.dart';

/// Identity header for the delivery-man public profile: large circular avatar +
/// (name row with verified badge) + rating summary + location/availability.
/// Composed from OMDS primitives (design §6: [OmdsProfileCard] is an
/// image-background card, not an inline identity block).
class DeliveryManProfileHeader extends StatelessWidget {
  const DeliveryManProfileHeader({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.isAvailable,
  });

  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.large,
        vertical: Spacing.small,
      ),
      child: _HeaderRow(
        name: name,
        avatarUrl: avatarUrl,
        isVerified: isVerified,
        rating: rating,
        reviewCount: reviewCount,
        location: location,
        isAvailable: isAvailable,
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.name,
    required this.avatarUrl,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.isAvailable,
  });

  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(name: name, avatarUrl: avatarUrl),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _Details(
            name: name,
            isVerified: isVerified,
            rating: rating,
            reviewCount: reviewCount,
            location: location,
            isAvailable: isAvailable,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0] : '?';
    return OmdsProfileAvatar(
      key: const Key('delivery-man-profile-avatar'),
      initial: initial,
      profilePicUrl: avatarUrl,
      size: Sizes.nineXLarge,
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.name,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.isAvailable,
  });

  final String name;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _NameRow(name: name, isVerified: isVerified),
        const SizedBox(height: Spacing.xSmall),
        _RatingRow(rating: rating, reviewCount: reviewCount),
        const SizedBox(height: Spacing.twoXSmall),
        _AvailabilityRow(location: location, isAvailable: isAvailable),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.reviewCount});

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DeliveryManMetaRow(
      icon: Icons.star,
      text: l10n.deliveryManProfileRatingSummary(
        rating.toStringAsFixed(1),
        reviewCount,
      ),
      semanticsId: 'delivery_man_profile_rating_summary',
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({required this.location, required this.isAvailable});

  final String location;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DeliveryManMetaRow(
      icon: Icons.location_on,
      text: l10n.deliveryManProfileLocationAvailability(
        location,
        _availabilityLabel(l10n),
      ),
      semanticsId: 'delivery_man_profile_availability',
    );
  }

  String _availabilityLabel(AppLocalizations l10n) => isAvailable
      ? l10n.deliveryManProfileAvailable
      : l10n.deliveryManProfileUnavailable;
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.name, required this.isVerified});

  final String name;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: _NameText(name: name)),
        if (isVerified) ...[
          const SizedBox(width: Spacing.xSmall),
          const _NameBadge(),
        ],
      ],
    );
  }
}

class _NameText extends StatelessWidget {
  const _NameText({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'delivery_man_profile_name',
      child: AutoDirectionText(
        name,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.secondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NameBadge extends StatelessWidget {
  const _NameBadge();

  @override
  Widget build(BuildContext context) {
    return JeebVerifiedBadge(
      semanticsLabel:
          AppLocalizations.of(context).deliveryManProfileVerifiedBadgeLabel,
    );
  }
}
