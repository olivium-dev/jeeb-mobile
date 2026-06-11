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
          ? _ChatHeaderLeading(title: title, url: avatarUrl, image: avatarImage)
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
  });

  final String title;
  final String? url;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ChatBackButton(),
        _ChatHeaderAvatar(title: title, url: url, image: image),
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
  });

  final String title;
  final String? url;
  final ImageProvider? image;

  static const double _size = Sizes.fourXLarge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'chat_detail_avatar',
      label: l10n.chatAvatarA11y,
      child: image != null ? _circularPhoto() : _urlOrInitial(context),
    );
  }

  Widget _circularPhoto() {
    return ClipOval(
      child: Image(
        image: image!,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _urlOrInitial(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsProfileAvatar(
      initial: title.isEmpty ? 'J' : title.characters.first,
      profilePicUrl: url,
      size: _size,
      backgroundColor: colorScheme.primaryContainer,
      initialColor: colorScheme.onPrimaryContainer,
    );
  }
}
