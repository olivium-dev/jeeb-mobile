/// Widget previews for [SystemMessageBubble] — run with
/// `flutter widget-preview start`.
///
/// The bubble is a pure-props widget: one [DeliveryChatMessage] in, one centred
/// pill out. No cubit, no gateway, no DI — so these previews are network-free by
/// construction rather than by the guard in [jeebPreviewHost]. Every fixture
/// below is a plain value object built in-process.
///
/// What actually varies is the SOURCE OF THE COPY, and the three sources behave
/// differently enough that they need separate cards:
///
///   * `offerAccepted` / `offerRejected` → ARB template + `payload.jeeberName`.
///     Localized; length swings with locale AND with the name.
///   * `system` → `message.text`, i.e. whatever the chat-service put on the wire,
///     rendered VERBATIM. Not localized, and not direction-detected.
///   * anything else → `''` → [SizedBox.shrink]. The row disappears.
///
/// Every preview renders the bubble inside a full-width stretched column,
/// because a lone pill in an 800 dp test viewport tells you nothing about the
/// two things that break: whether the pill centres, and whether long copy wraps
/// inside it instead of running past the 16 dp gutters.
///
/// Fixture names ('Kamal Hajj', 'Rana') are the ones the existing chat widget
/// tests already use (`test/features/chat/chat_screen_m1plus_widget_test.dart`,
/// `test/features/chat/order_chat_jm025_test.dart`); each state gets its own so
/// a preview cannot silently render a neighbour's fixture.
library;

import 'package:flutter/material.dart';

import '../../features/chat/domain/delivery_chat_message.dart';
import '../../features/chat/presentation/widgets/system_message_bubble.dart';
import '../harness/jeeb_preview.dart';

/// One frozen instant for every fixture. The bubble paints no clock, but the
/// timeline around it does, and a fixed value keeps a canvas diff a layout
/// change rather than a passing minute.
final DateTime _frozenAt = DateTime(2026, 6, 18, 9, 25);

DeliveryChatMessage _accepted(String id, String jeeberName) =>
    DeliveryChatMessage.offerAccepted(
      id: id,
      sentAt: _frozenAt,
      payload: SystemOfferPayload(
        offerId: 'offer-$id',
        jeeberId: 'j-$id',
        jeeberName: jeeberName,
      ),
    );

DeliveryChatMessage _rejected(String id, String jeeberName) =>
    DeliveryChatMessage.offerRejected(
      id: id,
      sentAt: _frozenAt,
      payload: SystemOfferPayload(
        offerId: 'offer-$id',
        jeeberId: 'j-$id',
        jeeberName: jeeberName,
      ),
    );

DeliveryChatMessage _system(String id, String text) =>
    DeliveryChatMessage.system(id: id, sentAt: _frozenAt, text: text);

/// Full-width host: the bubble centres itself inside whatever box it is given,
/// so the column has to stretch or "is it centred?" becomes unanswerable.
///
/// [width] clamps the stack to a device width. The canvas box alone cannot do
/// that in the render tests — `pumpPreview` uses the default 800x600 viewport
/// and ignores [JeebPreview.size] — so any preview that wants to prove something
/// about phone-width wrapping has to clamp itself.
Widget _hosted(List<DeliveryChatMessage> messages, {double? width}) {
  final Widget body = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final DeliveryChatMessage message in messages)
        SystemMessageBubble(message: message),
    ],
  );
  if (width == null) return body;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: width, child: body),
  );
}

/// The happy path: the notice the accept saga drops between the offer cards and
/// the 1:1 timeline.
///
/// This is the matrix card for the common case. The pill itself is
/// direction-symmetric (a [Center] with symmetric padding), so RTL cannot
/// mirror it wrongly — what the AR rendering is really for here is the COPY:
/// "{name}'s offer was accepted" is one line at 390 dp in English and
/// "تم قبول عرض {name}" is a different length, and the dark rendering is the
/// only place the `surfaceContainer` pill is checked against a dark surface at
/// all. The 200% rendering is where a one-line pill becomes a two-line block and
/// the vertical rhythm of the thread changes.
@JeebPreview(
  group: 'chat',
  name: 'Offer accepted · named',
  size: Size(390, 120),
  matrix: true,
)
Widget systemMessageBubbleAccepted() =>
    _hosted(<DeliveryChatMessage>[_accepted('sys-accepted-1', 'Kamal Hajj')]);

/// The reachable degradation, and it is not the one the widget guards against.
///
/// `_copyFor` falls back to the generic ARB copy when `systemOfferPayload` is
/// null — but NOTHING can hand it a null. `DeliveryChatMessage.offerAccepted`
/// takes a required payload, and the only decoder
/// (`chat_message_codec.dart:216`) builds it with `SystemOfferPayload.fromWire`,
/// which resolves a missing `winnerJeeberName`/`jeeberName` to the EMPTY STRING,
/// never to null. So the generic branch is dead on every wire path, and a notice
/// whose payload lost its name takes the NAMED branch with `name: ''`.
///
/// The template is substituted with `replaceFirst('{name}', '')`, so this card
/// renders the possessive with nothing in front of it — "'s offer was accepted"
/// in English, and a trailing-space "تم قبول عرض " in Arabic. That is a real
/// string a partially-populated gateway row produces today, and it is what this
/// preview exists to show. If the fallback is ever fixed to key off an empty
/// name rather than a null payload, this card is where it turns into
/// "Offer accepted".
@JeebPreview(
  group: 'chat',
  name: 'Offer accepted · nameless payload',
  size: Size(390, 90),
)
Widget systemMessageBubbleAcceptedNameless() =>
    _hosted(<DeliveryChatMessage>[_accepted('sys-accepted-2', '')]);

/// The other half of the offer lifecycle: a Jeeber's offer withdrawn or lost.
///
/// Same pill, different ARB key, and it is the message that gates
/// `JeeberRemovedBanner` upstream (T-MOB-014 AC4). Worth its own card because
/// the two notices are visually identical — the copy is the ONLY thing telling a
/// client that their chosen Jeeber is gone rather than confirmed. If accepted
/// and withdrawn ever render the same string, this pair is where it shows.
@JeebPreview(
  group: 'chat',
  name: 'Offer withdrawn · named',
  size: Size(390, 90),
)
Widget systemMessageBubbleRejected() =>
    _hosted(<DeliveryChatMessage>[_rejected('sys-rejected-1', 'Rana')]);

/// `system` kind: server copy, rendered verbatim.
///
/// Unlike the two offer kinds, this branch does not touch the ARB — it returns
/// `message.text` exactly as the chat-service sent it. Two consequences are
/// visible on this card and both are widget-level, not fixture-level:
///
///   1. The copy does NOT localize. The Arabic rendering of this preview shows
///      the same English sentence, because the mobile has no key to look up.
///      That is inherent to a pass-through channel, but it means every string
///      the gateway puts on this kind ships to Arabic users untranslated.
///   2. The copy does not get first-strong direction detection. Sibling text
///      bubbles wrap their body in [AutoDirectionText]
///      (`chat_message_bubble.dart:192`) so an Arabic line reads RTL inside an
///      English thread; [SystemMessageBubble] uses a bare [Text], so the second
///      row below resolves to `TextDirection.ltr` in the EN rendering (measured,
///      and pinned by the render test) and its sentence-final '.' is laid out on
///      the wrong side of the sentence.
///
/// Both rows are here together so the mismatch is one glance rather than two
/// cards.
@JeebPreview(
  group: 'chat',
  name: 'Server notice · verbatim',
  size: Size(390, 150),
)
Widget systemMessageBubbleServerNotice() => _hosted(<DeliveryChatMessage>[
      _system('sys-note-1', 'Your request expired before a Jeeber accepted it.'),
      _system('sys-note-2', 'انتهت مهلة الطلب قبل أن يقبله أي جيبر.'),
    ]);

/// Layout ceiling, clamped to phone width so the wrap is real.
///
/// The pill has no max-width token and no `maxLines`: it is a [Container] inside
/// a [Center] inside 16 dp symmetric padding, so its only bound is the gutters.
/// A long registered name — the client base runs to three- and four-part Arabic
/// names transliterated in full — turns the notice into a multi-line block, and
/// the pill radius (`OmdsBorderRadius.pill`) was drawn for one line.
///
/// This is the second matrix card, and the one where the 200% rendering matters
/// most. Measured at 390 dp with the bundled font: the copy is 326x48 (three
/// lines, in a 358x56 pill) at 1x and 326x160 (five lines) at 2x. Width is
/// pinned by the gutters in both, so the entire 2x cost is height — a ~3.3x
/// taller row in the middle of a scrolling thread. That is a degradation and
/// not a break: there is no overflow stripe, because nothing clamps the lines.
/// What to look at is whether the result still reads as a CHIP or has become a
/// rounded paragraph that no longer says "this is chrome, not a message".
@JeebPreview(
  group: 'chat',
  name: 'Long name at 390dp',
  size: Size(390, 230),
  matrix: true,
)
Widget systemMessageBubbleLongName() => _hosted(
      <DeliveryChatMessage>[
        _accepted('sys-accepted-3', 'Abdulrahman Al-Muhandis Al-Trabulsi'),
      ],
      width: 390,
    );

/// The collapse path: rows that must occupy ZERO height.
///
/// Three messages go in, one pill comes out. The first is a `system` row whose
/// text came back empty — the shape `ChatCubit._missing` and `ChatState._never`
/// both use as their not-found sentinels, and the shape the codec produces from
/// `{"kind":"system"}` with no `text` field. The second is a `text` message
/// routed here directly, which hits `_copyFor`'s `default` arm. Both return `''`
/// and must degrade to [SizedBox.shrink], not to an empty pill floating in the
/// thread with 24 dp of padding around nothing.
///
/// The third row is a real notice, and it is load-bearing: it proves the column
/// still paints, so a reviewer can tell "correctly collapsed" apart from
/// "the whole preview failed to build".
///
/// Note the collapse drops the `chat-system-<id>` key with the widget — an
/// empty row is not addressable by key, which is why the render test asserts
/// its absence by key rather than by text.
@JeebPreview(
  group: 'chat',
  name: 'Empty + unsupported collapse',
  size: Size(390, 100),
)
Widget systemMessageBubbleCollapsed() => _hosted(<DeliveryChatMessage>[
      _system('sys-empty', ''),
      DeliveryChatMessage.text(
        id: 'sys-wrong-kind',
        author: ChatAuthor.them,
        sentAt: _frozenAt,
        status: MessageStatus.delivered,
        text: 'a text message must never paint as a system chip',
      ),
      _accepted('sys-accepted-4', 'Ziad'),
    ]);
