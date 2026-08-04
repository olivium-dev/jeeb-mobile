import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';


// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:ui' as ui show TextDirection;
import '../../../../core/widgets/jeeb/jeeb_chat_bubble.dart';
import '../../../../core/previews/jeeb_preview.dart';

/// Locale-aware "HH:mm" timestamp in chat bubble meta row via DateFormat.Hm.
class ChatBubbleTimestamp extends StatelessWidget {
  const ChatBubbleTimestamp({
    super.key,
    required this.sentAt,
    this.hasServerTimestamp = true,
    this.color,
  });

  final DateTime sentAt;

  // Was re-derived from sentAt value (anchor was "any instant inside 1970"). Message now
  final bool hasServerTimestamp;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Server-returned message with no timestamp carries ordering anchor, not send time.
    if (!hasServerTimestamp) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        DateFormat.Hm(locale).format(sentAt),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color ??
              theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: UIConstants.opacityHigh),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [ChatBubbleTimestamp] — run with

/// Canvas box for one bubble plus its meta row.
const Size _chatBubbleTimestampBubbleBox = Size(390, 160);

/// Taller box for the two matrix states: at 200% the body copy wraps to three
/// lines and the caption to three more, so the card needs the headroom or the
const Size _chatBubbleTimestampMatrixBox = Size(390, 300);

/// Bubbles in the thread are capped at ~70% of a 390 pt phone (design-spec §4).
const double _chatBubbleTimestampBubbleWidth = 260;

/// A stand-in for the chat bubble the timestamp always lives inside.
/// [filled] picks the sender's OUTGOING bubble over the incoming offer card;
/// [caption] labels a state whose whole point is that nothing renders.
///
/// Both fills are read off [JeebChatBubble] rather than restated, so the
/// stand-in can never again misrepresent the bubble that actually ships.
class _ChatBubbleTimestampBubble extends StatelessWidget {
  const _ChatBubbleTimestampBubble({required this.child, this.filled = false, this.caption});

  final Widget child;
  final bool filled;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final JeebChatBubbleSide side = filled
        ? JeebChatBubbleSide.outgoing
        : JeebChatBubbleSide.incoming;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: _chatBubbleTimestampBubbleWidth,
            padding: const EdgeInsets.all(Spacing.small),
            decoration: BoxDecoration(
              color: JeebChatBubble.fillOf(context, side),
              border: Border.all(
                color: JeebChatBubble.borderInkOf(context, side),
              ),
              borderRadius: JeebChatBubble.radiusOf(side),
            ),
            child: child,
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: Spacing.twoXSmall),
            SizedBox(
              width: _chatBubbleTimestampBubbleWidth,
              child: Text(
                caption!,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The offer-card footer: body copy over a start-aligned column, the clock
/// aligning itself to the trailing edge.
Widget _chatBubbleTimestampOfferFooter({
  required DateTime sentAt,
  bool hasServerTimestamp = true,
  String? caption,
}) =>
    _ChatBubbleTimestampBubble(
      caption: caption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Fast delivery guaranteed'),
          const SizedBox(height: Spacing.twoXSmall),
          ChatBubbleTimestamp(
            sentAt: sentAt,
            hasServerTimestamp: hasServerTimestamp,
          ),
        ],
      ),
    );

/// The sender's bubble footer, built the way `chat_message_bubble.dart:563`
/// builds it: a min-width Row of clock → status tick, force-wrapped in
Widget _chatBubbleTimestampSenderFooter({
  required String body,
  required DateTime sentAt,
  bool overrideColour = true,
  String? caption,
}) =>
    _ChatBubbleTimestampBubble(
      filled: true,
      caption: caption,
      child: Builder(
        builder: (BuildContext context) {
          const JeebChatBubbleSide side = JeebChatBubbleSide.outgoing;
          final Color ink = JeebChatBubble.metaInkOf(context, side);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(body, style: JeebChatBubble.bodyStyleOf(context, side)),
              const SizedBox(height: Spacing.twoXSmall),
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    ChatBubbleTimestamp(
                      sentAt: sentAt,
                      color: overrideColour ? ink : null,
                    ),
                    const SizedBox(width: Spacing.twoXSmall),
                    Icon(Icons.done_all, size: Sizes.medium, color: ink),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

/// The reference rendering: an offer that arrived at 12:34, drawn with the
/// widget's default ink on the grey card it was designed for.
@JeebPreview(group: 'chat', name: 'Offer card footer · 12:34', size: _chatBubbleTimestampMatrixBox, matrix: true)
Widget chatBubbleTimestampOfferFooter() =>
    _chatBubbleTimestampOfferFooter(sentAt: DateTime(2026, 6, 1, 12, 34));

/// The other production caller, done correctly: the sender's orange-tinted
/// outgoing bubble with the caller's `color:` override.
@JeebPreview(group: 'chat', name: 'Sender bubble · caller colour', size: _chatBubbleTimestampBubbleBox)
Widget chatBubbleTimestampSenderBubble() => _chatBubbleTimestampSenderFooter(
      body: 'The blue box, please',
      sentAt: DateTime(2026, 6, 11, 9, 41),
    );

/// The same bubble with the `color:` argument dropped — i.e. what any NEW
/// caller gets by default on a filled bubble.
@JeebPreview(group: 'chat', name: 'Sender bubble · default colour', size: _chatBubbleTimestampMatrixBox, matrix: true)
Widget chatBubbleTimestampDefaultInkOnBubble() => _chatBubbleTimestampSenderFooter(
      body: 'Coming down now, one minute',
      sentAt: DateTime(2026, 6, 11, 23, 58),
      overrideColour: false,
      caption: 'no colour override — default surface ink',
    );

/// A history row the gateway returned with no usable `created_at`.
/// `sentAt` here is the epoch ordering anchor `ChatMessageCodec` substitutes,
@JeebPreview(group: 'chat', name: 'Ordering anchor · no clock', size: _chatBubbleTimestampBubbleBox)
Widget chatBubbleTimestampOrderingAnchor() => _chatBubbleTimestampOfferFooter(
      sentAt: DateTime(1970),
      hasServerTimestamp: false,
      caption: 'anchor only — no clock is drawn',
    );

/// The SAME epoch instant with the flag left at its default `true` — the
/// regression this widget's `hasServerTimestamp` parameter exists to prevent.
@JeebPreview(group: 'chat', name: 'Epoch anchor drawn as 00:00', size: _chatBubbleTimestampBubbleBox)
Widget chatBubbleTimestampEpochDrawn() => _chatBubbleTimestampOfferFooter(sentAt: DateTime(1970));

/// A send time that reached the widget as UTC instead of local time.
/// [DateFormat] formats the fields the [DateTime] carries and converts nothing,
@JeebPreview(group: 'chat', name: 'UTC instant, not localized', size: _chatBubbleTimestampBubbleBox)
Widget chatBubbleTimestampUtcInstant() =>
    _chatBubbleTimestampOfferFooter(sentAt: DateTime.utc(2026, 6, 11, 21, 5));
