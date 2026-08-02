import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../domain/delivery_chat_message.dart';
import '../chat_screen.dart' show kChatHeaderMaxViewportFraction;
import 'chat_fee_banner.dart';
import 'chat_message_bubble.dart';
import '../../../../core/previews/jeeb_preview.dart';

/// Read-only notice: another Jeeber was picked (closed phase). Composer hidden by isComposerVisible=false.
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
// DEV-ONLY, NOT SHIPPED.

// Widget previews for [JeeberRemovedBanner] — run with

/// Frozen instant for every fixture, so the bubble clocks never drift between
/// runs of the canvas.
final DateTime _jeeberRemovedBannerFrozenAt = DateTime(2026, 6, 1, 12, 30);

/// The system notice that GATES the banner in production. Without an
/// `offerRejected` message in the thread, `showRemovedBanner` is false and this
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

@JeebPreview(group: 'chat', name: 'Strip alone', size: Size(390, 200))
Widget jeeberRemovedBannerStrip() => _jeeberRemovedBannerHosted();

@JeebPreview(group: 'chat', name: 'Small phone 320dp', size: Size(320, 320))
Widget jeeberRemovedBannerSmallPhone() => _jeeberRemovedBannerHosted(
      width: 320,
      thread: <DeliveryChatMessage>[_jeeberRemovedBannerRejectedNotice('Rana')],
    );

@JeebPreview(group: 'chat', name: 'Above frozen thread', size: Size(390, 560))
Widget jeeberRemovedBannerAboveFrozenThread() => _jeeberRemovedBannerHosted(
      thread: <DeliveryChatMessage>[
        _jeeberRemovedBannerText('m-1', ChatAuthor.them, 'Can you pick it up from Hamra before 6?'),
        _jeeberRemovedBannerText('m-2', ChatAuthor.me, 'I can be at the pickup in 10 minutes.'),
        _jeeberRemovedBannerRejectedNotice('Kamal Hajj'),
      ],
    );

@JeebPreview(group: 'chat', name: 'Under fee notice', size: Size(390, 360))
Widget jeeberRemovedBannerUnderFeeNotice() => _jeeberRemovedBannerHosted(
      chrome: const <Widget>[ChatFeeBanner(amount: r'$0.50')],
      thread: <DeliveryChatMessage>[_jeeberRemovedBannerRejectedNotice('Nour')],
    );

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
