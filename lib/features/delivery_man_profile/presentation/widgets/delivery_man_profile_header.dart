import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb_verified_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/widgets/auto_direction_text.dart';
import 'delivery_man_meta_row.dart';

/// Identity header for the delivery-man public profile: large circular avatar +
/// (name row with verified badge) + rating summary + location/availability.
///
/// redesign-2026-08: the avatar is the kit [JeebAvatar] hero disc (Ø74 — the
/// board's identity-block size) and the type comes off `context.jeebText`.
/// The row keeps its own name node because `delivery_man_profile_name` is a
/// frozen Maestro id and `JeebProfileHeader` has no name slot to carry it (nor
/// a place for the verified badge) — see the apply report.
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
    this.isColdStart = false,
  });

  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;

  /// D59 cold-start: when true (jeeber has < 5 reviews) the aggregate score is
  /// hidden — only the review count is shown.
  final bool isColdStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The board's 24px side gutter (§4.3).
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
        vertical: Spacing.xSmall,
      ),
      child: _HeaderRow(
        name: name,
        avatarUrl: avatarUrl,
        isVerified: isVerified,
        rating: rating,
        reviewCount: reviewCount,
        location: location,
        isAvailable: isAvailable,
        isColdStart: isColdStart,
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
    required this.isColdStart,
  });

  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;
  final bool isColdStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(name: name, avatarUrl: avatarUrl),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: _Details(
            name: name,
            isVerified: isVerified,
            rating: rating,
            reviewCount: reviewCount,
            location: location,
            isAvailable: isAvailable,
            isColdStart: isColdStart,
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
    // `JeebAvatar.hero` normalises the initial itself (first non-blank
    // character, '?' when there is none) — the same fallback this widget used
    // to compute by hand.
    return JeebAvatar.hero(
      initial: name,
      imageUrl: avatarUrl,
      avatarKey: const Key('delivery-man-profile-avatar'),
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
    required this.isColdStart,
  });

  final String name;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;
  final bool isColdStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _NameRow(name: name, isVerified: isVerified),
        const SizedBox(height: Spacing.xSmall),
        _RatingRow(
          rating: rating,
          reviewCount: reviewCount,
          isColdStart: isColdStart,
        ),
        const SizedBox(height: Spacing.twoXSmall),
        _AvailabilityRow(location: location, isAvailable: isAvailable),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.reviewCount,
    required this.isColdStart,
  });

  final double rating;
  final int reviewCount;
  final bool isColdStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // D59 cold-start (< 5 reviews): HIDE the aggregate score. We still surface
    // the review count (no star score), so the header stays coherent without an
    // unverified score. `profile_score` is present ONLY when the score shows,
    // so QA can assert it is absent during cold-start.
    if (isColdStart) {
      return DeliveryManMetaRow(
        icon: Icons.reviews_outlined,
        text: l10n.deliveryManProfileReviewsCount(reviewCount),
        semanticsId: 'delivery_man_profile_rating_summary',
      );
    }
    return DeliveryManMetaRow(
      // The star stays navy (§4.1 rations the one warm ink): this profile's
      // score is a meta line, not a rating stat, so it must NOT be tinted with
      // `omdsColorTokens.starRatingColor`.
      icon: Icons.star,
      text: l10n.deliveryManProfileRatingSummary(
        rating.toStringAsFixed(1),
        reviewCount,
      ),
      semanticsId: 'profile_score',
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
    final availability = _availabilityLabel(l10n);
    // F9: only join location + availability with the separator dot when a
    // location is actually present; otherwise show availability alone so we
    // never render a stray leading "· Available".
    final text = location.trim().isEmpty
        ? availability
        : l10n.deliveryManProfileLocationAvailability(location, availability);
    return DeliveryManMetaRow(
      icon: Icons.location_on,
      text: text,
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
        // The board's identity name: navy `h2` (20/w700), not a headline.
        style: context.jeebText.h2.copyWith(color: theme.colorScheme.primary),
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
