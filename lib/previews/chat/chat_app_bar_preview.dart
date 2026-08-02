/// Widget previews for [ChatAppBar] — run with `flutter widget-preview start`.
///
/// [ChatAppBar] is a pure-props [PreferredSizeWidget]: everything it paints
/// comes from its constructor arguments, so no cubit, repository or DI graph is
/// involved and these previews are network-free by construction rather than by
/// the guard in [jeebPreviewHost].
///
/// One deliberate omission: no preview passes [ChatAppBar.avatarUrl]. That path
/// hands the URL to `OmdsProfileAvatar` → `OmdsCachedImage`, which is a real
/// network fetch. The photo state is driven through [ChatAppBar.avatarImage]
/// with an in-memory PNG instead — the same substitution
/// `test/chat_dm_header_parity_test.dart` makes (see [_peerPhoto] for why the
/// bytes are not the same ones), and it exercises the identical circular
/// treatment.
///
/// Because the widget IS an app bar, each preview hosts it in the appBar slot of
/// a bare [Scaffold]. Rendering it in a body would give it an unconstrained box
/// and hide exactly the leading/title/actions squeeze these previews exist to
/// show.
///
/// The states mirror the regression pins in `test/chat_dm_header_parity_test.dart`
/// (D1 circular avatar, D2 mirrored chevron) plus the two header shapes the
/// hosts actually build — `chat_screen.dart` (counterpart name + JM-025 AC3
/// dispute action) and `chat_detail_screen.dart` (title-only, order reference).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../features/chat/presentation/widgets/chat_app_bar.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// Phone width, and just enough height for the 56 dp bar plus the sliver of
/// body that shows where the header ends.
const Size _headerBox = Size(390, 140);

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
final MemoryImage _peerPhoto = MemoryImage(Uint8List.fromList(const [
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
Widget _disputeAction() => Builder(
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
Widget _hosted(ChatAppBar appBar) => Scaffold(
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
@JeebPreview(name: 'Broadcasting (order id, no avatar)', size: _headerBox)
Widget chatAppBarBroadcasting() => _hosted(
      const ChatAppBar(title: 'ORD-23748'),
    );

/// Post-approval happy path (Figma 56560:1605): chevron → circular peer photo →
/// name, with the avatar wired to the counterpart's public profile (D-P1).
///
/// This is the D1 pin made visible — the photo must render as a CIRCLE, never a
/// square crop and never a bare glyph floating in the bar.
@JeebPreview(name: 'Matched (photo avatar)', size: _headerBox)
Widget chatAppBarMatchedWithPhoto() => _hosted(
      ChatAppBar(
        title: 'Sami Fawaz',
        avatarImage: _peerPhoto,
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
@JeebPreview(name: 'Matched (initial fallback)', size: _headerBox)
Widget chatAppBarMatchedInitialFallback() => _hosted(
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
@JeebPreview(name: 'Order chat (dispute action)', size: _headerBox)
Widget chatAppBarWithDisputeAction() => _hosted(
      ChatAppBar(
        title: 'Kamal Hajj',
        avatarImage: _peerPhoto,
        showAvatar: true,
        onAvatarTap: () {},
        actions: <Widget>[_disputeAction()],
      ),
    );

/// The layout ceiling: the longest plausible name, the avatar cluster AND the
/// dispute action, all competing for one 56 dp row.
///
/// The title must ellipsize; it must never push the report button off the
/// trailing edge or wrap the bar into an overflow stripe. The AR RTL and
/// 200%-text renderings are the ones that matter here — the EN light rendering
/// keeps looking fine long after the other two have broken.
@JeebPreview(name: 'Longest name + action', size: _headerBox)
Widget chatAppBarLongName() => _hosted(
      ChatAppBar(
        title: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        showAvatar: true,
        onAvatarTap: () {},
        actions: <Widget>[_disputeAction()],
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
@JeebPreview(name: 'Unresolved counterpart (empty title)', size: _headerBox)
Widget chatAppBarEmptyTitle() => _hosted(
      const ChatAppBar(title: '', showAvatar: true),
    );
