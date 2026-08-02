/// Widget previews for [ChatMessageBubble] — run with
/// `flutter widget-preview start`.
///
/// The bubble takes a single [DeliveryChatMessage] and nothing else: no cubit,
/// no repository, no DI. So these previews are network-free by construction —
/// every state below is a plain value object built in-process, and the CDN
/// refs in them are deliberately non-fetchable (see [chatMessageBubbleImageNoBytes]).
///
/// Each preview renders the bubble inside a full-width column, because the one
/// thing a lone centred bubble cannot show is the thing that broke first:
/// alignment. The bubble hugs the *trailing* edge for the local user and the
/// *leading* edge for the counterpart (`AlignmentDirectional`), so the whole
/// row mirrors in Arabic — self moves LEFT, incoming moves RIGHT — per Figma
/// `design-spec.md` §4/§7-10. Round 1 shipped `Alignment.centerRight`, which
/// pinned self to the physical right in every locale; the AR RTL rendering of
/// the matrix is where that class of regression shows up without being asked.
///
/// The states mirror the contracts asserted in
/// `test/chat_message_bubble_rtl_test.dart` and
/// `test/features/chat/chat_image_bubble_source_test.dart`; the previews exist
/// so the *visual* half (wrap, tick glyphs, placeholder, large text) is
/// reviewable without booting the app and opening a live thread.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/chat/domain/delivery_chat_message.dart';
import '../../features/chat/presentation/widgets/chat_message_bubble.dart';

/// One fixed instant for every fixture, so the rendered clock is stable and a
/// diff in the canvas is always a layout change, never a passing minute.
final DateTime _sentAt = DateTime(2026, 6, 11, 9, 41);

/// Full-width host: the bubble aligns itself inside whatever box it is given,
/// so the column must stretch or every bubble renders centred and the
/// leading/trailing contract becomes invisible.
Widget _hosted(List<DeliveryChatMessage> messages) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final DeliveryChatMessage message in messages)
          ChatMessageBubble(message: message),
      ],
    );

DeliveryChatMessage _text(
  String id,
  ChatAuthor author,
  String body, {
  MessageStatus status = MessageStatus.read,
  bool hasServerTimestamp = true,
}) =>
    DeliveryChatMessage.text(
      id: id,
      author: author,
      sentAt: _sentAt,
      status: status,
      text: body,
      hasServerTimestamp: hasServerTimestamp,
    );

/// The directional contract, in one card: an incoming message followed by the
/// reply to it.
///
/// Two things to check here, and both are edge-dependent rather than
/// content-dependent — which is why they need the AR RTL rendering:
///
/// 1. The counterpart bubble sits on the LEADING edge and the local user's on
///    the TRAILING edge, so the pair swaps sides in Arabic.
/// 2. Only the sender's bubble carries the "time → ticks" meta row (D3 fix,
///    Figma node 56560:1605 leaves the incoming timestamp slot empty). If the
///    incoming bubble here ever grows a clock, that suppression has broken.
@JeebPreview(name: 'Incoming + reply', size: Size(390, 200))
Widget chatMessageBubblePair() => _hosted(<DeliveryChatMessage>[
      _text('them-1', ChatAuthor.them, "I'm at the pharmacy now — which brand?"),
      _text('me-1', ChatAuthor.me, 'The blue box, please'),
    ]);

/// Every send state stacked, because the tick glyph is the only difference
/// between "it went" and "it silently did not".
///
/// The bodies are labels rather than chat lines on purpose: a reviewer has to
/// be able to tell which glyph belongs to which status without counting rows.
///
/// LOOK AT THE DARK RENDERING. Two glyphs here are drawn in colours that do not
/// track the bubble they sit on, and both were measured against this preview:
///
///   * `failed` uses `colorScheme.error` on a `colorScheme.primary` bubble —
///     1.01:1 in dark (2.34:1 in light). The single most important glyph in the
///     thread is invisible on the sender's own bubble in dark mode.
///   * `read` uses `omdsColorTokens.infoColor`, a fixed brand blue that does not
///     flip with brightness, on the same bubble — 1.83:1 in dark, under the 3:1
///     floor for non-text contrast.
///
/// Both are widget defects, not preview defects; this card is where they show.
@JeebPreview(name: 'Status ladder', size: Size(390, 540))
Widget chatMessageBubbleStatusLadder() => _hosted(<DeliveryChatMessage>[
      _text('st-1', ChatAuthor.me, 'sending — still on this phone',
          status: MessageStatus.sending),
      _text('st-2', ChatAuthor.me, 'sent — the server has it',
          status: MessageStatus.sent),
      _text('st-3', ChatAuthor.me, 'delivered — on their device',
          status: MessageStatus.delivered),
      _text('st-4', ChatAuthor.me, 'read — they opened the thread',
          status: MessageStatus.read),
      _text('st-5', ChatAuthor.me, 'failed — this one never left',
          status: MessageStatus.failed),
    ]);

/// Layout ceiling: the longest message a client plausibly types.
///
/// The bubble is capped at ~70% of the available width (design-spec §4) with
/// no OMDS fractional-width token behind it (flag F-CHAT-3), so this is the
/// state that proves the cap actually wraps instead of overflowing — and the
/// EN 200% rendering is the real test, since the light EN rendering looks fine
/// long after the accessible one has stopped fitting.
@JeebPreview(name: 'Longest plausible message', size: Size(390, 470))
Widget chatMessageBubbleLongText() => _hosted(<DeliveryChatMessage>[
      _text(
        'long-1',
        ChatAuthor.me,
        'Hi! Please pick up the two large bags of ice, a pack of paper cups, '
        'and the birthday cake reserved under the name Fawaz — the counter '
        'staff already have it boxed and paid for, so you only need to show '
        'them this message.',
      ),
    ]);

/// Mixed-script thread: the bubble edge and the text direction are decided
/// SEPARATELY, and this is the only state that proves it.
///
/// Both messages below are the local user's, so both bubbles stay on the same
/// (trailing) edge — but [AutoDirectionText] gives the Arabic one an RTL
/// paragraph from its first strong character while the English one stays LTR.
/// That is the WhatsApp behaviour the ticket asks for. If the Arabic line ever
/// renders left-aligned-with-trailing-punctuation, the first-strong detection
/// has stopped running and the ambient direction is leaking through.
@JeebPreview(name: 'Arabic message in an EN thread', size: Size(390, 230))
Widget chatMessageBubbleMixedScript() => _hosted(<DeliveryChatMessage>[
      _text('bidi-1', ChatAuthor.me, 'وصلت للبناية، أنا عند المصعد'),
      _text('bidi-2', ChatAuthor.me, 'Coming down now, one minute'),
    ]);

/// P4/P5 regression, made visible: an image row whose only source is a CDN
/// `object_ref`.
///
/// `chat_attachment/<guid>.jpg` is NOT a fetchable URL — handing it to
/// `OmdsCachedImage` issues a doomed unauthenticated GET, and the pre-fix
/// `photoBytes!` dereference threw outright on a bytes-less row. Both now
/// degrade to the grey placeholder. This preview must show a placeholder plus
/// its caption, never a spinner, a broken-image glyph, or a red `ErrorWidget`
/// inside the thread. It is also the state that guarantees these previews make
/// no network call even if the guard were removed.
///
/// The AR rendering additionally exposes an unrelated leak: `_ImageBubble`
/// builds its accessibility label from a Dart literal `'You'`/`'Jeeber'` and
/// feeds it to the localized template, so an Arabic screen reader announces
/// "صورة من You". The visible bubble is fully localized; only the spoken label
/// is not.
@JeebPreview(name: 'Image with no local bytes', size: Size(390, 210))
Widget chatMessageBubbleImageNoBytes() => _hosted(<DeliveryChatMessage>[
      DeliveryChatMessage.image(
        id: 'img-1',
        author: ChatAuthor.me,
        sentAt: _sentAt,
        status: MessageStatus.sent,
        url: 'chat_attachment/9f2c41e8-3d55-4f0a-b1c7-0a2e6f8d1b44.jpg',
        caption: 'Left it with the concierge',
      ),
    ]);

/// A history row the server returned with no usable `created_at`.
///
/// Such a row is a REAL message — it renders — but its `sentAt` is an ORDERING
/// ANCHOR, not a send time, so no surface may draw it as a clock. The undated
/// bubble below must show its ticks and NO time; the dated one beneath it must
/// show both. If the undated one ever renders `00:00` (or a 1970 date divider
/// in the thread around it), the `hasServerTimestamp` check in
/// [ChatBubbleTimestamp] has been bypassed and the whole class of 56-years-ago
/// bugs is back.
@JeebPreview(name: 'Undated history row', size: Size(390, 250))
Widget chatMessageBubbleUndated() => _hosted(<DeliveryChatMessage>[
      _text('undated-1', ChatAuthor.me, 'No created_at came back for this row',
          hasServerTimestamp: false),
      _text('dated-1', ChatAuthor.me, 'This one carries a real send time'),
    ]);
