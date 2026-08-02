import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../domain/delivery_chat_message.dart';
import '../chat_screen.dart' show kChatHeaderMaxViewportFraction;
import 'chat_fee_banner.dart';
import 'chat_message_bubble.dart';
import '../../../../core/previews/jeeb_preview.dart';

/// Read-only notice displayed when the local Jeeber's offer was not accepted.
///
/// Shown in the `closed` phase when the conversation phase is resolved as
/// the Jeeber being the loser. The composer is hidden by [ChatState.isComposerVisible]
/// returning false when phase == closed. This banner provides additional
/// clarity by naming the reason: another Jeeber was picked.
///
/// Rendered above the (frozen) message list as a full-width warning strip.
class JeeberRemovedBanner extends StatelessWidget {
  const JeeberRemovedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('jeeber-removed-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      color: colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.onErrorContainer,
            size: Sizes.large,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              l10n.chatJeeberRemovedMessage,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
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
// Render tests: test/previews/chat/jeeber_removed_banner_preview_test.dart
// ===========================================================================

// Widget previews for [JeeberRemovedBanner] — run with
// `flutter widget-preview start`.
//
// The banner takes no arguments. It is one localized sentence on a
// `colorScheme.errorContainer` band — `Row(Icon, gap, Expanded(Text))` — so
// there is no data state to vary. Every preview below therefore varies the
// only things that can actually break it: the WIDTH it is handed, the chrome
// it is stacked against, and the bounded slot it has to live inside.
//
// Production placement is `chat_screen.dart` (`_ChatBody.header`), gated on
// `phase == closed && messages.any((m) => m.kind == offerRejected)` — the
// losing Jeeber's view of a request that went to somebody else. Each preview
// carries the frozen `offerRejected` notice that gates it, so the canvas shows
// a state the app can really reach rather than a banner floating in a void.
// The composer is deliberately absent: `ChatState.isComposerVisible` returns
// false in the `closed` phase, which is why this banner exists at all.
//
// Network-free by construction: no cubit, no repository, no gateway. The
// fixtures are plain [DeliveryChatMessage] values, and the Jeeber names
// ('Rana', 'Kamal Hajj') are the ones
// `test/features/chat/chat_screen_m1plus_widget_test.dart` already uses for
// this exact gate.

/// Frozen instant for every fixture, so the bubble clocks never drift between
/// runs of the canvas.
final DateTime _jeeberRemovedBannerFrozenAt = DateTime(2026, 6, 1, 12, 30);

/// The system notice that GATES the banner in production. Without an
/// `offerRejected` message in the thread, `showRemovedBanner` is false and this
/// widget never renders — so no preview omits it.
DeliveryChatMessage _jeeberRemovedBannerRejectedNotice(String jeeberName) =>
    DeliveryChatMessage.offerRejected(
      id: 'sys-rejected-$jeeberName',
      sentAt: _jeeberRemovedBannerFrozenAt,
      payload: SystemOfferPayload(
        offerId: 'offer-$jeeberName',
        jeeberId: 'j-$jeeberName',
        jeeberName: jeeberName,
      ),
    );

DeliveryChatMessage _jeeberRemovedBannerText(String id, ChatAuthor author, String body) =>
    DeliveryChatMessage.text(
      id: id,
      author: author,
      sentAt: _jeeberRemovedBannerFrozenAt,
      status: MessageStatus.read,
      text: body,
    );

/// The banner in its production stacking order: chrome above, frozen thread
/// below, no composer.
///
/// [width] constrains the whole body to a device width — the canvas box alone
/// cannot do that, because the harness stretches the widget to the host.
Widget _jeeberRemovedBannerHosted({
  List<Widget> chrome = const <Widget>[],
  List<DeliveryChatMessage> thread = const <DeliveryChatMessage>[],
  double? width,
}) {
  final Widget body = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      ...chrome,
      const JeeberRemovedBanner(),
      for (final DeliveryChatMessage message in thread)
        ChatMessageBubble(message: message),
    ],
  );
  if (width == null) return body;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: width, child: body),
  );
}

/// The bare strip, exactly as `chat_screen.dart:718` emits it —
/// `const JeeberRemovedBanner()` with nothing around it.
///
/// This is the reading that has to survive the 200% rendering of the matrix:
/// the band has no fixed height, so the sentence must be allowed to wrap and
/// push the band taller instead of clipping. Measured: 44 dp on one line,
/// growing several times that once the sentence wraps — hence the tall box.
@JeebPreview(group: 'chat', name: 'Strip alone', size: Size(390, 200))
Widget jeeberRemovedBannerStrip() => _jeeberRemovedBannerHosted();

/// Small-phone width (320 dp), the narrowest width the app ships to and the
/// first width at which the sentence wraps.
///
/// This is the state that shows the `Row`'s default
/// `crossAxisAlignment: center`: once the text wraps, the info icon floats to
/// the vertical middle of the text block instead of sitting on the first line
/// (measured — icon top 32 dp against a text block starting at 12 dp). It is
/// also the width at which the AR RTL rendering has to prove the icon and the
/// padding really mirror; they do — the icon keeps the LEADING edge, which is
/// the right-hand side in AR, and the text flows away from it.
@JeebPreview(group: 'chat', name: 'Small phone 320dp', size: Size(320, 320))
Widget jeeberRemovedBannerSmallPhone() => _jeeberRemovedBannerHosted(
      width: 320,
      thread: <DeliveryChatMessage>[_jeeberRemovedBannerRejectedNotice('Rana')],
    );

/// The real composition: the banner pinned above a thread that is now frozen.
///
/// The last two messages are the ones the Jeeber will never get a reply to, so
/// the band has to read as an explanation of the silence below it, not as a
/// transient error toast. Mixed-script content is deliberate — the bubbles pick
/// their own direction from the first strong character, the band does not.
@JeebPreview(group: 'chat', name: 'Above frozen thread', size: Size(390, 560))
Widget jeeberRemovedBannerAboveFrozenThread() => _jeeberRemovedBannerHosted(
      thread: <DeliveryChatMessage>[
        _jeeberRemovedBannerText('m-1', ChatAuthor.them, 'Can you pick it up from Hamra before 6?'),
        _jeeberRemovedBannerText('m-2', ChatAuthor.me, 'I can be at the pickup in 10 minutes.'),
        _jeeberRemovedBannerRejectedNotice('Kamal Hajj'),
      ],
    );

/// Two full-bleed bands touching, which is reachable for a Jeeber viewer: the
/// fee notice (`secondaryContainer`, navy) sits directly on top of this banner
/// (`errorContainer`).
///
/// Worth looking at because the two bands share an edge with no divider and no
/// gap — the seam is the only thing separating a neutral notice from an error
/// notice, and both bands wrap independently at 200%.
@JeebPreview(group: 'chat', name: 'Under fee notice', size: Size(390, 360))
Widget jeeberRemovedBannerUnderFeeNotice() => _jeeberRemovedBannerHosted(
      chrome: const <Widget>[ChatFeeBanner(amount: r'$0.50')],
      thread: <DeliveryChatMessage>[_jeeberRemovedBannerRejectedNotice('Nour')],
    );

/// The b02 regression, made visible: this banner is one of the NON-FLEXIBLE
/// chrome children that overflowed `_ChatBody`'s Column ("BOTTOM OVERFLOWED BY
/// 16 PIXELS").
///
/// The fix bounded the chrome at [kChatHeaderMaxViewportFraction] of the body
/// height and made it scroll; this preview reproduces that bound with the real
/// constant, at a body height a small phone has once the keyboard is up (300
/// dp → a 120 dp slot). At the 200% rendering the fee band plus this banner
/// exceed the slot, and the correct degradation is a SCROLL. If the canvas ever
/// shows a clipped band or an overflow stripe here instead, the bound has
/// regressed.
@JeebPreview(group: 'chat', name: 'Bounded header slot', size: Size(390, 340))
Widget jeeberRemovedBannerBoundedHeaderSlot() => SizedBox(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 300 * kChatHeaderMaxViewportFraction,
            ),
            child: const SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ChatFeeBanner(amount: r'$1.25'),
                  JeeberRemovedBanner(),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: <Widget>[
                ChatMessageBubble(
                  message: _jeeberRemovedBannerText('m-3', ChatAuthor.me, 'On my way, 5 min.'),
                ),
                ChatMessageBubble(message: _jeeberRemovedBannerRejectedNotice('Ziad')),
              ],
            ),
          ),
        ],
      ),
    );
