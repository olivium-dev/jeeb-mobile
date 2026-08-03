import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../../core/widgets/jeeb_verified_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/widgets/auto_direction_text.dart';
import 'customer_profile_rating.dart';

/// Profile identity card: navy surface holding the avatar, the name (+ verified
/// badge), the per-role rating and the account email (JM-035 AC1).
///
/// redesign-2026-08: this is the same navy identity card the neighbouring
/// Settings screen opens with (`settings_identity_card.dart`, board
/// `20-settings` `tpl 1171-1177`) — Ø50 avatar, r18, and the ONE shadowed
/// surface on the screen, every card below it being outline-over-shadow. It is
/// deliberately **not** tappable: unlike Settings, this tab exposes no
/// edit-profile edge today, and the restyle adds no navigation.
///
/// Exposes the JM-035 AC1 identifiers `customer_profile_avatar`,
/// `customer_profile_name` and `customer_profile_rating` (the wallet chip + bell
/// are shell-owned, painted by `ShellHeaderActions` — NOT here, to avoid
/// duplicate ids).
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

  /// Card radius — 18 (board `tpl 1171`), matching the Settings identity card.
  static const double radius = 18;

  /// Avatar diameter (board `tpl 1172`). Ø50 is off the kit's four named sizes,
  /// so it uses [JeebAvatar]'s unnamed constructor; its measured initial size
  /// for Ø50 is the board's 18px.
  static const double avatarDiameter = 50;

  final String? name;
  final String? email;
  final String? avatarUrl;
  final bool isVerified;
  final double? rating;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
    return JeebNavySurfaceCard(
      radius: radius,
      shadow: JeebShadows.ctaNavy,
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
    return Semantics(
      identifier: 'customer_profile_avatar',
      image: true,
      child: JeebAvatar(
        // `JeebAvatar` normalises a full name to its first letter (and to '?'
        // when there is none), so the seed's null name still renders a disc.
        initial: name ?? '',
        diameter: CustomerProfileHeader.avatarDiameter,
        imageUrl: avatarUrl,
        // The disc re-tones on navy (onPrimary @14%) — the board's
        // `rgba(255,255,255,.14)` — with no parameter.
        avatarKey: const Key('customer-profile-avatar'),
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
    return Semantics(
      identifier: 'customer_profile_name',
      label: name ?? '',
      child: AutoDirectionText(
        name ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.jeebText.cardTitle.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
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
    // The shared badge inks itself from `secondaryContainer` (navy) and would be
    // invisible on this navy card. Re-point that one role for the badge subtree
    // rather than forking a private copy of a shared widget.
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          secondaryContainer: theme.colorScheme.onPrimary,
        ),
      ),
      child: JeebVerifiedBadge(
        size: Sizes.medium,
        semanticsLabel:
            AppLocalizations.of(context).customerProfileVerifiedBadgeLabel,
      ),
    );
  }
}

class _Email extends StatelessWidget {
  const _Email({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<JeebSemanticColors>()?.mutedText;
    return AutoDirectionText(
      email,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // Periwinkle on navy — the same subtitle ink the Settings identity card
      // uses (board `tpl 1175`).
      style: context.jeebText.bodySmall.copyWith(color: muted),
    );
  }
}
