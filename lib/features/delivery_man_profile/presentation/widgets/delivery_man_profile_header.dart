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
///
/// MIDNIGHT (M3-10): R15's identity block — a CENTRED Ø74 glass disc over the
/// field with the name and the meta lines stacked under it, not a list row.
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
    this.showCount = true,
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

  /// False while the real review count is still unknown — DMP-01: never print
  /// a pushed count above a band that says "No reviews yet".
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The board's 24px side gutter (§4.3).
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.xSmall,
        Spacing.xLarge,
        0,
      ),
      child: _HeaderColumn(
        name: name,
        avatarUrl: avatarUrl,
        isVerified: isVerified,
        rating: rating,
        reviewCount: reviewCount,
        location: location,
        isAvailable: isAvailable,
        isColdStart: isColdStart,
        showCount: showCount,
      ),
    );
  }
}

class _HeaderColumn extends StatelessWidget {
  const _HeaderColumn({
    required this.name,
    required this.avatarUrl,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.isAvailable,
    required this.isColdStart,
    this.showCount = true,
  });

  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;
  final bool isColdStart;

  /// False while the real review count is still unknown — DMP-01: never print
  /// a pushed count above a band that says "No reviews yet".
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(name: name, avatarUrl: avatarUrl),
        // R15's disc→meta gap is 10; 12 is the nearest 4-scale rung.
        const SizedBox(height: Spacing.small),
        _NameRow(name: name, isVerified: isVerified),
        const SizedBox(height: Spacing.xSmall),
        _RatingRow(
          rating: rating,
          reviewCount: reviewCount,
          isColdStart: isColdStart,
          showCount: showCount,
        ),
        const SizedBox(height: Spacing.twoXSmall),
        _AvailabilityRow(location: location, isAvailable: isAvailable),
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
    // to compute by hand. `glass` is R15's own Ø74 rung (wave-B ruling 3): the
    // opaque navy fill vanishes into the field this screen now mounts.
    return JeebAvatar.hero(
      initial: name,
      imageUrl: avatarUrl,
      fill: JeebAvatarFill.glass,
      avatarKey: const Key('delivery-man-profile-avatar'),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.reviewCount,
    required this.isColdStart,
    required this.showCount,
  });

  final double rating;
  final int reviewCount;
  final bool isColdStart;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!showCount) {
      // Count unknown: show the score alone, or nothing when cold start hides
      // the score too.
      if (isColdStart) return const SizedBox.shrink();
      return DeliveryManMetaRow(
        icon: Icons.star,
        text: rating.toStringAsFixed(1),
        semanticsId: 'profile_score',
      );
    }
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
      // Aggregate score: board ink, never amber — the same call the kit's own
      // R16 rating pill makes for this exact datum (§4.1).
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
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
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
        // R15's identity headline: `h2` (20/w700) in `onSurface`. It rode
        // `primary`, which MIDNIGHT re-points to the rationed orange.
        style: context.jeebText.h2.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _NameBadge extends StatelessWidget {
  const _NameBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The shared badge inks itself from `secondaryContainer`, which MIDNIGHT
    // values as raised navy — invisible on the field. Same re-point as R4's.
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          secondaryContainer: theme.colorScheme.onSurface,
        ),
      ),
      child: JeebVerifiedBadge(
        semanticsLabel:
            AppLocalizations.of(context).deliveryManProfileVerifiedBadgeLabel,
      ),
    );
  }
}
