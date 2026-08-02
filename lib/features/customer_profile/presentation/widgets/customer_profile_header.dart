import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb_verified_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/widgets/auto_direction_text.dart';
import 'customer_profile_rating.dart';
// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class CustomerProfileHeader extends StatelessWidget {
  const CustomerProfileHeader({
    super.key,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isVerified,
    required this.rating,
    required this.ratingCount,
  });

  final String? name;
  final String? email;
  final String? avatarUrl;
  final bool isVerified;
  final double? rating;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Sizes.fiveXLarge,
        Spacing.xLarge,
        Spacing.medium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(name: name, avatarUrl: avatarUrl),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: _Identity(
              name: name,
              email: email,
              verified: isVerified,
              rating: rating,
              ratingCount: ratingCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.avatarUrl});

  final String? name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = (name?.trim().isNotEmpty ?? false) ? name!.trim()[0] : '?';
    return Semantics(
      identifier: 'customer_profile_avatar',
      image: true,
      child: OmdsProfileAvatar(
        key: const Key('customer-profile-avatar'),
        initial: initial,
        profilePicUrl: avatarUrl,
        size: Sizes.eightXLarge,
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.name,
    required this.email,
    required this.verified,
    required this.rating,
    required this.ratingCount,
  });

  final String? name;
  final String? email;
  final bool verified;
  final double? rating;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _NameRow(name: name, verified: verified),
        const SizedBox(height: Spacing.twoXSmall),
        CustomerProfileRating(rating: rating, ratingCount: ratingCount),
        if (email != null) ...[
          const SizedBox(height: Spacing.twoXSmall),
          _Email(email: email!),
        ],
      ],
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.name, required this.verified});

  final String? name;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: _NameText(name: name)),
        if (verified) ...[
          const SizedBox(width: Spacing.xSmall),
          const _NameBadge(),
        ],
      ],
    );
  }
}

class _NameText extends StatelessWidget {
  const _NameText({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'customer_profile_name',
      label: name ?? '',
      child: AutoDirectionText(
        name ?? '',
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
          AppLocalizations.of(context).customerProfileVerifiedBadgeLabel,
    );
  }
}

class _Email extends StatelessWidget {
  const _Email({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AutoDirectionText(
      email,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [CustomerProfileHeader] — run with

/// Phone width; holds the 56 dp top inset + the 80 dp avatar + a
/// single-line-per-row identity column, with room for the 320 dp the same
const Size _customerProfileHeaderHeaderBox = Size(390, 340);

/// For the states whose identity column wraps to a second line even at 1x
/// (long email, Arabic name) — 424 dp at 200% is the tallest of them.
const Size _customerProfileHeaderWrappingBox = Size(390, 440);

/// A whole phone viewport, because that is the point of the state it frames:
/// at 200% text the header alone fills the screen.
const Size _customerProfileHeaderPhoneScreenBox = Size(390, 600);

/// One specimen. Mirrors the argument list `CustomerProfileScreen` passes at
/// `lib/features/customer_profile/presentation/customer_profile_screen.dart:142`
Widget _customerProfileHeaderHosted({
  String? name,
  String? email,
  bool isVerified = false,
  double? rating,
  int ratingCount = 0,
}) {
  return CustomerProfileHeader(
    name: name,
    email: email,
    // Always null — see the section doc above.
    avatarUrl: null,
    isVerified: isVerified,
    rating: rating,
    ratingCount: ratingCount,
  );
}

/// The happy path: a rated, verified customer with an email on file
/// (`_ratedCustomer` from the screen test).
@JeebPreview(
  group: 'customer_profile',
  name: 'Rated + verified',
  size: _customerProfileHeaderHeaderBox,
)
Widget customerProfileHeaderRated() => _customerProfileHeaderHosted(
      name: 'Sami Fawaz',
      email: 'kamalhaaj@gmail.com',
      isVerified: true,
      rating: 4.8,
      ratingCount: 42,
    );

/// The seeded customer: verified, but never rated and with no email
/// (`_unratedCustomer` from the screen test — `user-client-001` carries
@JeebPreview(
  group: 'customer_profile',
  name: 'Unrated, no email',
  size: _customerProfileHeaderHeaderBox,
)
Widget customerProfileHeaderUnrated() => _customerProfileHeaderHosted(
      name: 'Nadia Client',
      isVerified: true,
    );

/// Cold start: `GET /user-management/users/me` has not resolved yet.
/// Not hypothetical — `lib/features/shell/shell_screen.dart:341` mounts the
@JeebPreview(
  group: 'customer_profile',
  name: 'Cold start (nothing loaded)',
  size: _customerProfileHeaderHeaderBox,
)
Widget customerProfileHeaderColdStart() => _customerProfileHeaderHosted();

/// A phone-only account, exactly as `getMe` returns it.
/// Jeeb mints synthetic identities for OTP-only signups — a `jeeb-<hash>` name
@JeebPreview(
  group: 'customer_profile',
  name: 'Phone-only synthetic identity',
  size: _customerProfileHeaderWrappingBox,
)
Widget customerProfileHeaderSyntheticIdentity() =>
    _customerProfileHeaderHosted(
      name: 'jeeb-e1a35ea8a520',
      email: 'phone-only+cb39e21caa82@jeeb.internal',
      isVerified: true,
      rating: 4.9,
      ratingCount: 312,
    );

/// An Arabic name beside a Latin email — the majority case for this app, and
/// the mixed-direction state `AutoDirectionText` exists to serve.
@JeebPreview(
  group: 'customer_profile',
  name: 'Arabic name, Latin email',
  size: _customerProfileHeaderWrappingBox,
)
Widget customerProfileHeaderArabicName() => _customerProfileHeaderHosted(
      name: 'كمال حاج الطرابلسي',
      email: 'kamalhaaj@gmail.com',
      isVerified: true,
      rating: 4.9,
      ratingCount: 312,
    );

/// The layout ceiling: longest plausible full name and a long email.
/// `_NameText` wraps its `AutoDirectionText` in a `Flexible` but passes no
@JeebPreview(
  group: 'customer_profile',
  name: 'Long name + long email',
  size: _customerProfileHeaderPhoneScreenBox,
)
Widget customerProfileHeaderLongName() => _customerProfileHeaderHosted(
      name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      email: 'abdulrahman.almuhandis@student-mail.university.edu.lb',
      isVerified: true,
      rating: 4.9,
      ratingCount: 312,
    );
