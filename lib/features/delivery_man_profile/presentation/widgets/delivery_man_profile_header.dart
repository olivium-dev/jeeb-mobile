import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb_verified_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/widgets/auto_direction_text.dart';
import 'delivery_man_meta_row.dart';

import '../../../../core/previews/jeeb_preview.dart';

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

  /// D59: when true (< 5 reviews) aggregate score is hidden.
  final bool isColdStart;

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
        const SizedBox(width: Spacing.small),
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
    if (isColdStart) {
      return DeliveryManMetaRow(
        icon: Icons.reviews_outlined,
        text: l10n.deliveryManProfileReviewsCount(reviewCount),
        semanticsId: 'delivery_man_profile_rating_summary',
      );
    }
    return DeliveryManMetaRow(
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
    // F9: join location + availability only when location is present
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
        style: theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.primary,
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [DeliveryManProfileHeader] — run with

/// Phone width, for the states whose details column stays one line per row:
/// 112 dp at 1x, 244 dp at 200% text.
const Size _deliveryManProfileHeaderBox = Size(390, 260);

/// For the state whose name already wraps at 1x: 140 dp, 308 dp at 200%.
const Size _deliveryManProfileHeaderWrappingBox = Size(390, 320);

/// Over half a 390 × 844 phone, because that is the point of the state it
/// frames: at 200% text this header alone is 436 dp.
const Size _deliveryManProfileHeaderPhoneScreenBox = Size(390, 460);

/// One specimen, under the width the header really gets.
/// The 390 dp is pinned in the fixture rather than left to the canvas [Size],
Widget _deliveryManProfileHeaderHosted({
  required String name,
  required double rating,
  required int reviewCount,
  required String location,
  bool isVerified = true,
  bool isAvailable = true,
  bool isColdStart = false,
}) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: 390,
      child: DeliveryManProfileHeader(
        name: name,
        // Always null — see the library doc above.
        avatarUrl: null,
        isVerified: isVerified,
        rating: rating,
        reviewCount: reviewCount,
        location: location,
        isAvailable: isAvailable,
        isColdStart: isColdStart,
      ),
    ),
  );
}

/// The happy path, and the only fixture that ships: `Kamal Hajj`, 4.3 over 113
/// reviews, Lebanon, online (`DevDeliveryManProfileFixtures.sample`).
@JeebPreview(group: 'delivery_man_profile', name: 'Populated (shipped fixture)', size: _deliveryManProfileHeaderBox)
Widget deliveryManProfileHeaderPopulated() => _deliveryManProfileHeaderHosted(
      name: 'Kamal Hajj',
      rating: 4.3,
      reviewCount: 113,
      location: 'Lebanon',
    );

/// D59 cold start: fewer than five reviews, so the aggregate score is hidden.
/// The catalog's own cold-start state (`batch_03_entries.dart`): Rana Ahmad,
@JeebPreview(group: 'delivery_man_profile', name: 'Cold start · score hidden (D59)', size: _deliveryManProfileHeaderBox)
Widget deliveryManProfileHeaderColdStart() => _deliveryManProfileHeaderHosted(
      name: 'Rana Ahmad',
      rating: 5,
      reviewCount: 2,
      location: 'Lebanon',
      isColdStart: true,
    );

/// What a client actually sees, because the offer card is the only route in.
/// `ClientOffersScreen._openJeeberProfile` builds the view data with
@JeebPreview(group: 'delivery_man_profile', name: 'From offer card · no location (F9)', size: _deliveryManProfileHeaderBox)
Widget deliveryManProfileHeaderNoLocation() => _deliveryManProfileHeaderHosted(
      name: 'New Jeeber',
      rating: 0,
      reviewCount: 0,
      location: '',
      isColdStart: true,
    );

/// Offline and unverified: the negative branch of both booleans at once.
/// The `'Sami' / 4.8 / 12 / 'Riyadh'` jeeber from
@JeebPreview(group: 'delivery_man_profile', name: 'Unavailable + unverified', size: _deliveryManProfileHeaderBox)
Widget deliveryManProfileHeaderUnavailable() => _deliveryManProfileHeaderHosted(
      name: 'Sami',
      rating: 4.8,
      reviewCount: 12,
      location: 'Riyadh',
      isVerified: false,
      isAvailable: false,
    );

/// An Arabic name over a Latin location — the majority case for this app, and
/// the mixed-direction state `AutoDirectionText` exists to serve.
@JeebPreview(group: 'delivery_man_profile', name: 'Arabic name, Latin location', size: _deliveryManProfileHeaderWrappingBox)
Widget deliveryManProfileHeaderArabicName() => _deliveryManProfileHeaderHosted(
      name: 'كمال حاج الطرابلسي',
      rating: 4.9,
      reviewCount: 312,
      location: 'Lebanon',
    );

/// The layout ceiling: longest plausible name, longest plausible location, and
/// a four-digit review count.
@JeebPreview(group: 'delivery_man_profile', name: 'Longest plausible content', size: _deliveryManProfileHeaderPhoneScreenBox)
Widget deliveryManProfileHeaderLongest() => _deliveryManProfileHeaderHosted(
      name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      rating: 4.96,
      reviewCount: 1284,
      location: 'Beirut, Mount Lebanon Governorate',
    );
