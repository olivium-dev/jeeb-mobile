import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

import 'dart:typed_data';
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================= JEEB PREVIEWS =============================

/// Header box: 390w × 140h.
const Size _chatAppBarHeaderBox = Size(390, 140);

/// 1×1 opaque PNG for avatar photo state testing.
final MemoryImage _chatAppBarPeerPhoto = MemoryImage(Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0xDA, 0x63, 0xD0, 0xAB, 0xED, 0xFF,
  0x0F, 0x00, 0x04, 0x51, 0x02, 0x3A, 0x89, 0xCE, 0xFF, 0x6A, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]));

/// JM-025 AC3 dispute action: localized report button.
Widget _chatAppBarDisputeAction() => Builder(
      builder: (BuildContext context) {
        final AppLocalizations l10n = AppLocalizations.of(context);
        return Semantics(
          identifier: 'order_chat_open_dispute',
          button: true,
          label: l10n.escalateTitle,
          child: IconButton(
            icon: const Icon(Icons.report_gmailerrorred_outlined),
            tooltip: l10n.escalateTitle,
            onPressed: () {},
          ),
        );
      },
    );

/// Host the bar in the appBar slot.
Widget _chatAppBarHosted(ChatAppBar appBar) => Scaffold(
      appBar: appBar,
      body: const SizedBox.shrink(),
    );

/// Pre-match: no Jeeber seated yet, order id only.
@JeebPreview(group: 'chat', name: 'Broadcasting (order id, no avatar)', size: _chatAppBarHeaderBox)
Widget chatAppBarBroadcasting() => _chatAppBarHosted(
      const ChatAppBar(title: 'ORD-23748'),
    );

/// Matched with peer photo avatar.
@JeebPreview(group: 'chat', name: 'Matched (photo avatar)', size: _chatAppBarHeaderBox)
Widget chatAppBarMatchedWithPhoto() => _chatAppBarHosted(
      ChatAppBar(
        title: 'Sami Fawaz',
        avatarImage: _chatAppBarPeerPhoto,
        showAvatar: true,
        onAvatarTap: () {},
      ),
    );

/// Matched, no photo, initial fallback.
@JeebPreview(group: 'chat', name: 'Matched (initial fallback)', size: _chatAppBarHeaderBox)
Widget chatAppBarMatchedInitialFallback() => _chatAppBarHosted(
      const ChatAppBar(
        title: 'Layla Haddad',
        showAvatar: true,
        onAvatarTap: null,
      ),
    );

/// Order chat with dispute action.
@JeebPreview(group: 'chat', name: 'Order chat (dispute action)', size: _chatAppBarHeaderBox)
Widget chatAppBarWithDisputeAction() => _chatAppBarHosted(
      ChatAppBar(
        title: 'Kamal Hajj',
        avatarImage: _chatAppBarPeerPhoto,
        showAvatar: true,
        onAvatarTap: () {},
        actions: <Widget>[_chatAppBarDisputeAction()],
      ),
    );

/// Layout ceiling: longest name plus action.
@JeebPreview(group: 'chat', name: 'Longest name + action', size: _chatAppBarHeaderBox)
Widget chatAppBarLongName() => _chatAppBarHosted(
      ChatAppBar(
        title: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        showAvatar: true,
        onAvatarTap: () {},
        actions: <Widget>[_chatAppBarDisputeAction()],
      ),
    );

/// Unresolved counterpart: empty title edge case.
@JeebPreview(group: 'chat', name: 'Unresolved counterpart (empty title)', size: _chatAppBarHeaderBox)
Widget chatAppBarEmptyTitle() => _chatAppBarHosted(
      const ChatAppBar(title: '', showAvatar: true),
    );
