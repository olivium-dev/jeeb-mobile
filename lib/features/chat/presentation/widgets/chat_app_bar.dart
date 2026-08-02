import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.title,
    this.avatarUrl,
    this.avatarImage,
    this.showAvatar = false,
    this.onAvatarTap,
    this.actions,
  });

  final String title;

  final String? avatarUrl;

  final ImageProvider? avatarImage;

  final bool showAvatar;

  final VoidCallback? onAvatarTap;

  final List<Widget>? actions;

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
      actions: actions ?? const <Widget>[],
    );
  }
}

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
