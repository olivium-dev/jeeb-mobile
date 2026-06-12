import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb_verified_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/widgets/auto_direction_text.dart';

/// Profile header: circular avatar + (name row with verified badge) + email.
///
/// Composed from OMDS primitives because [OmdsProfileCard] is an
/// image-background card, not an inline identity row (design §6 anticipates
/// composing from primitives here). Navy name on muted email matches the
/// Figma navy-dominant palette via [ColorScheme] roles only.
class CustomerProfileHeader extends StatelessWidget {
  const CustomerProfileHeader({
    super.key,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isVerified,
  });

  final String? name;
  final String? email;
  final String? avatarUrl;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
        vertical: Spacing.medium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(name: name, avatarUrl: avatarUrl),
          const SizedBox(width: Spacing.small),
          Expanded(child: _Identity(name: name, email: email, verified: isVerified)),
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
    return OmdsProfileAvatar(
      key: const Key('customer-profile-avatar'),
      initial: initial,
      profilePicUrl: avatarUrl,
      size: Sizes.eightXLarge,
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.name,
    required this.email,
    required this.verified,
  });

  final String? name;
  final String? email;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _NameRow(name: name, verified: verified),
        const SizedBox(height: Spacing.twoXSmall),
        if (email != null) _Email(email: email!),
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
    return AutoDirectionText(
      name ?? '',
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.secondaryContainer,
        fontWeight: FontWeight.w700,
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
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
  }
}
