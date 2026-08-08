import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
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
/// MIDNIGHT M3-07: this is R22's identity card (`22-r22-settings.png`
/// `tpl 1354-1360`), the same geometry `settings_identity_card.dart` ships from
/// the same measurement — emphasis glass, radius `lg`, `16/15` padding, gap 13,
/// Ø50 disc. **No shadow**: the fill step and the 1px stroke are what raise it
/// (`JeebNavySurfaceCard` doc; theme ruling 1 retires the navy-tinted set).
///
/// F5: the avatar disc is tappable when [onAvatarTap] is given — this tab is
/// the only reachable Profile surface for both roles, so it is the entry into
/// the existing pick/crop/compress avatar flow (`settings-profile` route).
///
/// Exposes the JM-035 AC1 identifiers `customer_profile_avatar`,
/// `customer_profile_name` and `customer_profile_rating` (the wallet chip + bell
/// are shell-owned, painted by `ShellHeaderActions` — NOT here, to avoid
/// duplicate ids). All three survive every state: the card is mounted whether or
/// not `GET /users/me` has landed.
class CustomerProfileHeader extends StatelessWidget {
  const CustomerProfileHeader({
    super.key,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isVerified,
    required this.rating,
    required this.ratingCount,
    this.onAvatarTap,
  });

  /// Board 20 → the `lg` rung of the §5 ladder, inside its ±2 tolerance.
  static const double radius = JeebRadii.lg;

  /// `15px 16px` (board `tpl 1354`).
  static const EdgeInsetsGeometry padding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 15);

  /// Avatar diameter (board `tpl 1355`). Ø50 is off the kit's four named sizes,
  /// so it uses [JeebAvatar]'s unnamed constructor; its measured initial size
  /// for Ø50 is the board's 18px.
  static const double avatarDiameter = 50;

  /// Gap between the disc and the text block (board `gap:13`).
  static const double gap = 13;

  final String? name;
  final String? email;
  final String? avatarUrl;
  final bool isVerified;
  final double? rating;
  final int ratingCount;
  final VoidCallback? onAvatarTap;

  bool get _hasName => (name ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return JeebNavySurfaceCard(
      radius: radius,
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(
            name: name,
            avatarUrl: avatarUrl,
            known: _hasName,
            onTap: onAvatarTap,
          ),
          const SizedBox(width: gap),
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
  const _Avatar({
    required this.name,
    required this.avatarUrl,
    required this.known,
    required this.onTap,
  });

  final String? name;
  final String? avatarUrl;
  final bool known;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disc = JeebAvatar(
      // `JeebAvatar` normalises a full name to its first letter (and to '?'
      // when there is none), so the seed's null name still renders a disc.
      initial: name ?? '',
      diameter: CustomerProfileHeader.avatarDiameter,
      imageUrl: avatarUrl,
      // No name on file is the kit's `dormant` mark — the honest "we do not
      // know this person" rung, never a fabricated initial.
      fill: known ? JeebAvatarFill.primary : JeebAvatarFill.dormant,
      avatarKey: const Key('customer-profile-avatar'),
    );
    return Semantics(
      identifier: 'customer_profile_avatar',
      image: true,
      button: onTap != null,
      child: onTap == null
          ? disc
          : InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: disc,
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
    final resolved = (name ?? '').trim().isEmpty
        ? AppLocalizations.of(context).profileNamePlaceholder
        : name!;
    return Semantics(
      identifier: 'customer_profile_name',
      label: resolved,
      child: AutoDirectionText(
        resolved,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // `onSurface` (#EDEFFC), not `onPrimary` (#FFFFFF): §1 is the heading
        // ink app-wide and a tile reading pure white does not override it.
        style: context.jeebText.cardTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
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
    // The shared badge inks itself from `secondaryContainer` (surfaceHigh) and
    // would be invisible on this navy card; re-point that one role to §1's ink.
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          secondaryContainer: theme.colorScheme.onSurface,
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
      // Periwinkle on navy — R22's identity subtitle ink (`tpl 1357`).
      style: context.jeebText.bodySmall.copyWith(color: muted),
    );
  }
}
