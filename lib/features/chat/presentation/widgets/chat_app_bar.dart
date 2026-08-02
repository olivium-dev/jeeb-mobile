import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:typed_data';
import '../../../../core/previews/jeeb_preview.dart';

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
    this.actions,
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

  /// Trailing app-bar actions. JM-025 AC3 injects the `order_chat_open_dispute`
  /// affordance here on the accepted/active order-chat; the legacy 1:1 chat
  /// leaves it null (no actions). Additive — existing callers are unchanged.
  final List<Widget>? actions;

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
      actions: actions ?? const <Widget>[],
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/chat_app_bar_preview_test.dart
// ===========================================================================

// Widget previews for [ChatAppBar] — run with `flutter widget-preview start`.
//
// [ChatAppBar] is a pure-props [PreferredSizeWidget]: everything it paints
// comes from its constructor arguments, so no cubit, repository or DI graph is
// involved and these previews are network-free by construction rather than by
// the guard in [jeebPreviewHost].
//
// One deliberate omission: no preview passes [ChatAppBar.avatarUrl]. That path
// hands the URL to `OmdsProfileAvatar` → `OmdsCachedImage`, which is a real
// network fetch. The photo state is driven through [ChatAppBar.avatarImage]
// with an in-memory PNG instead — the same substitution
// `test/chat_dm_header_parity_test.dart` makes (see [_peerPhoto] for why the
// bytes are not the same ones), and it exercises the identical circular
// treatment.
//
// Because the widget IS an app bar, each preview hosts it in the appBar slot of
// a bare [Scaffold]. Rendering it in a body would give it an unconstrained box
// and hide exactly the leading/title/actions squeeze these previews exist to
// show.
//
// The states mirror the regression pins in `test/chat_dm_header_parity_test.dart`
// (D1 circular avatar, D2 mirrored chevron) plus the two header shapes the
// hosts actually build — `chat_screen.dart` (counterpart name + JM-025 AC3
// dispute action) and `chat_detail_screen.dart` (title-only, order reference).

/// Phone width, and just enough height for the 56 dp bar plus the sliver of
/// body that shows where the header ends.
const Size _chatAppBarHeaderBox = Size(390, 140);

/// A 1×1 opaque PNG — an [ImageProvider] with no network and no bundled asset
/// behind it, stretched over the 48 dp disc by `BoxFit.cover` so the photo
/// state shows a filled circle instead of a hole.
///
/// Deliberately NOT the byte array in `test/chat_dm_header_parity_test.dart`.
/// That one is a canonical 1×1 PNG whose IDAT length field reads `0x0D` while
/// only ten bytes of deflate data follow, so it never decodes; the test gets
/// away with it because it asserts widget types after a single `pump()`, before
/// the decode fails. A preview has to survive `pumpAndSettle` and a real canvas,
/// so these bytes are a re-encoded, CRC-correct pixel.
final MemoryImage _chatAppBarPeerPhoto = MemoryImage(Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0xDA, 0x63, 0xD0, 0xAB, 0xED, 0xFF,
  0x0F, 0x00, 0x04, 0x51, 0x02, 0x3A, 0x89, 0xCE, 0xFF, 0x6A, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]));

/// The JM-025 AC3 trailing affordance, rebuilt exactly as `chat_screen.dart`
/// injects it: a localized, semantically-identified report button.
///
/// It is wrapped in a [Builder] because the label comes from
/// [AppLocalizations], which needs a context below the canvas's `Localizations`
/// scope — a preview function has none of its own.
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

/// Hosts the bar in the one slot it is designed for.
Widget _chatAppBarHosted(ChatAppBar appBar) => Scaffold(
      appBar: appBar,
      body: const SizedBox.shrink(),
    );

/// Pre-match (JM-025 AC1 compose / broadcasting): no Jeeber has been seated, so
/// there is no counterpart to name or picture.
///
/// The header degrades to the order reference — Figma 02 "ORD-23748", node
/// 56535:6659 — and `showAvatar: false` drops the whole leading cluster back to
/// `OMDSAppBar`'s own back button. The avatar slot must NOT appear here: a
/// circle with a "O" in it would assert a counterpart that does not exist yet.
@JeebPreview(group: 'chat', name: 'Broadcasting (order id, no avatar)', size: _chatAppBarHeaderBox)
Widget chatAppBarBroadcasting() => _chatAppBarHosted(
      const ChatAppBar(title: 'ORD-23748'),
    );

/// Post-approval happy path (Figma 56560:1605): chevron → circular peer photo →
/// name, with the avatar wired to the counterpart's public profile (D-P1).
///
/// This is the D1 pin made visible — the photo must render as a CIRCLE, never a
/// square crop and never a bare glyph floating in the bar.
@JeebPreview(group: 'chat', name: 'Matched (photo avatar)', size: _chatAppBarHeaderBox)
Widget chatAppBarMatchedWithPhoto() => _chatAppBarHosted(
      ChatAppBar(
        title: 'Sami Fawaz',
        avatarImage: _chatAppBarPeerPhoto,
        showAvatar: true,
        onAvatarTap: () {},
      ),
    );

/// Matched, but the counterpart has no picture on file — the overwhelmingly
/// common case for phone-only accounts.
///
/// The D1 fix says the fallback is an INITIAL INSIDE A VISIBLE CIRCLE, so the
/// leading cluster keeps the same shape and width whether or not a photo
/// resolved. A bare "L" with no disc behind it is the regression.
@JeebPreview(group: 'chat', name: 'Matched (initial fallback)', size: _chatAppBarHeaderBox)
Widget chatAppBarMatchedInitialFallback() => _chatAppBarHosted(
      const ChatAppBar(
        title: 'Layla Haddad',
        showAvatar: true,
        onAvatarTap: null,
      ),
    );

/// The order chat on an accepted/active delivery (JM-025 AC3): the same matched
/// header plus the `order_chat_open_dispute` action in the trailing slot.
///
/// Worth its own state because it is the first configuration where BOTH ends of
/// the bar are occupied — 104 dp of leading cluster on one side, an icon button
/// plus `OMDSAppBar`'s hardcoded 16 dp trailing spacer on the other — leaving
/// the title the narrowest box it ever gets.
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

/// The layout ceiling: the longest plausible name, the avatar cluster AND the
/// dispute action, all competing for one 56 dp row.
///
/// The title must ellipsize; it must never push the report button off the
/// trailing edge or wrap the bar into an overflow stripe. The AR RTL and
/// 200%-text renderings are the ones that matter here — the EN light rendering
/// keeps looking fine long after the other two have broken.
@JeebPreview(group: 'chat', name: 'Longest name + action', size: _chatAppBarHeaderBox)
Widget chatAppBarLongName() => _chatAppBarHosted(
      ChatAppBar(
        title: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        showAvatar: true,
        onAvatarTap: () {},
        actions: <Widget>[_chatAppBarDisputeAction()],
      ),
    );

/// Degenerate but reachable: `ChatScreen.counterpartName` defaults to `''`
/// (chat_screen.dart:650), so a host that opens the thread before the
/// counterpart resolves hands the bar an empty title while
/// `showsCounterpartHeader` is already true.
///
/// The guard in `_UrlOrInitialAvatar` covers it — an empty title yields the
/// house "J" initial rather than an `initial[0]` range error or an empty disc.
/// If this preview ever throws instead of rendering, that guard is gone.
@JeebPreview(group: 'chat', name: 'Unresolved counterpart (empty title)', size: _chatAppBarHeaderBox)
Widget chatAppBarEmptyTitle() => _chatAppBarHosted(
      const ChatAppBar(title: '', showAvatar: true),
    );
