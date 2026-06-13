import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Chat header composed from OMDS primitives.
///
/// Lays the Figma cluster out **left-aligned** (node 56560:1605: chevron →
/// circular peer avatar → name): a directional back affordance, an optional
/// circular counterpart avatar, and the [title] (the counterpart name
/// post-approval, or the order id during broadcasting — Figma 02 "ORD-23748",
/// node 56535:6659). The avatar slot is omitted when no counterpart is
/// resolved yet so the broadcasting header stays title-only.
///
/// RTL: the back chevron is chosen via [Directionality] so it always points
/// "back" (left in LTR, right in RTL) and the whole cluster mirrors to the
/// start edge — no stray forward-arrow leaks into the actions area.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.title,
    this.avatarUrl,
    this.avatarImage,
    this.showAvatar = false,
    this.onAvatarTap,
  });

  /// Header title — counterpart display name or order/request id.
  final String title;

  /// Counterpart avatar URL (CDN-hosted via cdn-service). Falls back to the
  /// title initial inside a circular [OmdsProfileAvatar] when null.
  final String? avatarUrl;

  /// Pre-resolved avatar image provider. Lets a caller bind a non-network
  /// source (e.g. a bundled [AssetImage] in the dev capture seam) through the
  /// same circular treatment as the production CDN path; takes precedence over
  /// [avatarUrl] when both are set.
  final ImageProvider? avatarImage;

  /// Whether to render the leading avatar (post-approval state only).
  final bool showAvatar;

  /// Tapping the counterpart avatar opens their public profile (D-P1). The
  /// caller (chat screen) supplies a closure that branches on [RoleCubit] —
  /// pushing `/profile/delivery-man` (client viewing a jeeber) or
  /// `/profile/customer` (jeeber viewing a client) with the typed view-data
  /// extra. Null leaves the avatar non-interactive.
  final VoidCallback? onAvatarTap;

  /// Leading-slot width when the avatar cluster (back + avatar) is shown.
  /// Back-button tap target + inter-gap + avatar, expressed in tokens.
  static const double _avatarLeadingWidth = Sizes.fiveXLarge + Sizes.fourXLarge;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return OMDSAppBar(
      title: title,
      centerTitle: false,
      showBackButton: !showAvatar,
      leading: showAvatar
          ? _ChatHeaderLeading(
              title: title,
              url: avatarUrl,
              image: avatarImage,
              onAvatarTap: onAvatarTap,
            )
          : null,
      leadingWidth: showAvatar ? _avatarLeadingWidth : null,
    );
  }
}

/// Directional back chevron + circular counterpart avatar packed into the
/// app-bar leading slot. Mirrors to the start edge in RTL.
class _ChatHeaderLeading extends StatelessWidget {
  const _ChatHeaderLeading({
    required this.title,
    required this.url,
    required this.image,
    required this.onAvatarTap,
  });

  final String title;
  final String? url;
  final ImageProvider? image;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ChatBackButton(),
        _ChatHeaderAvatar(
          title: title,
          url: url,
          image: image,
          onTap: onAvatarTap,
        ),
      ],
    );
  }
}

/// Back affordance whose chevron points "back" in both reading directions.
class _ChatBackButton extends StatelessWidget {
  const _ChatBackButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      identifier: 'chat_detail_back_button',
      button: true,
      label: l10n.chatBackA11y,
      child: IconButton(
        icon: Icon(isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios),
        iconSize: Sizes.large,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// 44dp circular peer avatar. Renders, in priority order: a provided
/// [image] (e.g. bundled asset in the dev seam), then the CDN [url] via
/// [OmdsProfileAvatar]'s cached image, then an initial inside a visible
/// circle — never a bare glyph (D1 fix).
class _ChatHeaderAvatar extends StatelessWidget {
  const _ChatHeaderAvatar({
    required this.title,
    required this.url,
    required this.image,
    required this.onTap,
  });

  final String title;
  final String? url;
  final ImageProvider? image;

  /// When non-null, the avatar becomes a button that opens the counterpart's
  /// public profile (D-P1). The role-branching + view-data construction lives
  /// in the caller; this widget only exposes the tappable affordance.
  final VoidCallback? onTap;

  static const double _size = Sizes.fourXLarge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatar = image != null
        ? _CircularImageAvatar(image: image!, size: _size)
        : _UrlOrInitialAvatar(title: title, url: url, size: _size);
    return Semantics(
      identifier: 'chat_detail_avatar',
      button: onTap != null,
      label: l10n.chatAvatarA11y,
      child: onTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: avatar,
            )
          : avatar,
    );
  }
}

/// Circular avatar for a pre-resolved [ImageProvider] (e.g. a non-network
/// source bound by a caller). OMDS's [OmdsProfileAvatar] only accepts a URL, so
/// the image-provider case keeps a thin circular treatment of its own.
class _CircularImageAvatar extends StatelessWidget {
  const _CircularImageAvatar({required this.image, required this.size});

  final ImageProvider image;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// CDN [url] via [OmdsProfileAvatar]'s cached image, falling back to an initial
/// inside a visible circle — never a bare glyph (D1 fix).
class _UrlOrInitialAvatar extends StatelessWidget {
  const _UrlOrInitialAvatar({
    required this.title,
    required this.url,
    required this.size,
  });

  final String title;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsProfileAvatar(
      initial: title.isEmpty ? 'J' : title.characters.first,
      profilePicUrl: url,
      size: size,
      backgroundColor: colorScheme.primaryContainer,
      initialColor: colorScheme.onPrimaryContainer,
    );
  }
}
