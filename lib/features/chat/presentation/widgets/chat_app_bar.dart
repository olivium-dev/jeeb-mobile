import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Chat header composed from OMDS primitives.
///
/// Renders a back affordance, an optional counterpart [avatarUrl] (Figma 03
/// "Kamal Hajj" header, node 56546:2382), and a centered [title] (the
/// counterpart name post-approval, or the order id during broadcasting —
/// Figma 02 "ORD-23748", node 56535:6659). The avatar slot is omitted when no
/// counterpart is resolved yet so the broadcasting header stays title-only.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.title,
    this.avatarUrl,
    this.showAvatar = false,
  });

  /// Header title — counterpart display name or order/request id.
  final String title;

  /// Counterpart avatar URL (CDN-hosted via cdn-service). Falls back to the
  /// title initial inside [OmdsProfileAvatar] when null.
  final String? avatarUrl;

  /// Whether to render the leading avatar (post-approval state only).
  final bool showAvatar;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return OMDSAppBar(
      title: title,
      showBackButton: !showAvatar,
      leading: showAvatar ? _ChatHeaderLeading(title: title, url: avatarUrl) : null,
      leadingWidth: showAvatar ? Sizes.fiveXLarge * 2 : null,
    );
  }
}

/// Back chevron + counterpart avatar packed into the app-bar leading slot.
class _ChatHeaderLeading extends StatelessWidget {
  const _ChatHeaderLeading({required this.title, required this.url});

  final String title;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'chat_detail_back_button',
          button: true,
          label: l10n.chatBackA11y,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Semantics(
          identifier: 'chat_detail_avatar',
          label: l10n.chatAvatarA11y,
          child: OmdsProfileAvatar(
            initial: title.isEmpty ? 'J' : title.characters.first,
            profilePicUrl: url,
            size: Sizes.fourXLarge,
            backgroundColor: colorScheme.surfaceContainer,
            initialColor: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
