import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb_verified_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/widgets/auto_direction_text.dart';
import 'customer_profile_rating.dart';

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
