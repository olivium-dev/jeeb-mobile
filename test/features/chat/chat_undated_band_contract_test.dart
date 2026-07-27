// THE UNDATED-BAND CONTRACT — what `ChatCubit` actually guarantees about the
// order of rows the server did not date.
//
// WHY THIS FILE EXISTS. `_reconciledWithHistory`'s doc used to say the rendered
// order for undated rows "is the server's array order". `_withRebasedAnchors`
// does something narrower: it collects EVERY undated row into ONE CONTIGUOUS
// BAND immediately below the earliest DATED row, whatever position those rows
// held in the server's array. A server array that interleaves dated and undated
// rows therefore does NOT render as that array. Two readers of the same file
// could not both be right, and the one who believed the doc would ship an
// ordering bug.
//
// THIS IS A CHARACTERIZATION SUITE, NOT A REGRESSION SUITE. Every assertion
// below passed BEFORE the doc was corrected and passes after — that is the
// point: the code was never the thing that changed. What was RED before is the
// DOC, and a doc cannot be run. Stating that plainly matters, because this batch
// has already shipped a test whose green was mistaken for proof of a fix.
//
// WHY THE DOC WAS CORRECTED RATHER THAN THE CODE. Honouring "the server's array
// order" literally means dropping the chronological sort (S0-CHAT-04), which
// exists because the backend may return rows unsorted, may page them
// newest-first, and may append a system row out of band. Trading a real ordering
// guarantee for a doc sentence is a worse deal than fixing the sentence.
//
// PRODUCTION REACHABILITY, stated honestly: after jeeb-gateway #326 every row on
// the live wire carries `created_at`, and chat-service's own
// `ChatService.Persistence/BaseModel.cs` initialises it to `DateTime.UtcNow`, so
// a mixed dated/undated array is not currently known to be producible in
// production. It is producible on the LEGACY wire (a pre-#326 gateway, a paged
// read that predates it, a projection that omits the field), which is why the
// behaviour is pinned rather than assumed away.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

const _conversationId = 'conv-band';

DeliveryChatMessage _dated(String id, String text, DateTime at,
        {ChatAuthor author = ChatAuthor.them}) =>
    DeliveryChatMessage.text(
      id: id,
      author: author,
      sentAt: at,
      status: MessageStatus.delivered,
      text: text,
    );

/// A row the server returned with no usable timestamp: the decoder hands it a
/// PROVISIONAL anchor and flags it, exactly as `DioChatGateway` does.
DeliveryChatMessage _undated(String id, String text, int arrayPosition,
        {ChatAuthor author = ChatAuthor.them}) =>
    DeliveryChatMessage.text(
      id: id,
      author: author,
      sentAt: DateTime.utc(1970).add(Duration(microseconds: arrayPosition)),
      status: MessageStatus.delivered,
      text: text,
      hasServerTimestamp: false,
    );

/// Serves a fixed history. Polling stays OFF (the `supportsPolling` default) so
/// nothing ticks behind the assertions.
class _FixedHistoryGateway extends ChatGateway {
  _FixedHistoryGateway(this.history);

  final List<DeliveryChatMessage> history;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      history;

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.accepted;

  @override
  Stream<ChatEvent> subscribe(String conversationId) => const Stream.empty();

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message;
}

List<String> _texts(ChatCubit cubit) =>
    cubit.state.messages.map((m) => m.text).toList(growable: false);

ChatCubit _cubit(List<DeliveryChatMessage> history) {
  final cubit = ChatCubit(
    deliveryId: _conversationId,
    gateway: _FixedHistoryGateway(history),
    pickerService: StubPhotoPickerService(),
    clock: () => DateTime.utc(2026, 7, 27, 12, 30),
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('the undated band is CONTIGUOUS and sits below the earliest dated row',
      () {
    test(
      'a server array of [dated 12:00, undated, dated 12:02] renders as '
      '[undated, dated 12:00, dated 12:02] — NOT as the array',
      () async {
        final cubit = _cubit(<DeliveryChatMessage>[
          _dated('a', 'dated 12:00', DateTime.utc(2026, 7, 27, 12, 0)),
          _undated('b', 'undated middle', 1),
          _dated('c', 'dated 12:02', DateTime.utc(2026, 7, 27, 12, 2)),
        ]);

        await cubit.load();

        expect(
          _texts(cubit),
          <String>['undated middle', 'dated 12:00', 'dated 12:02'],
          reason: 'the undated row sat BETWEEN two dated rows in the server '
              'array and is rendered BEFORE both. This is the guarantee the '
              'code makes; the doc that claimed "the server\'s array order" '
              'described something the code has never done',
        );
      },
    );

    test(
      'a counterpart row the server did not date sinks below MY dated row, even '
      'though the server put theirs first',
      () async {
        // The user-visible shape of the same rule, and the reason it is worth
        // pinning rather than shrugging at: on a legacy wire this is how their
        // opening message ends up underneath the reply to it.
        final cubit = _cubit(<DeliveryChatMessage>[
          _dated('a', 'them dated 12:00', DateTime.utc(2026, 7, 27, 12, 0)),
          _undated('b', 'me undated', 1, author: ChatAuthor.me),
          _undated('c', 'them undated', 2),
        ]);

        await cubit.load();

        expect(
          _texts(cubit),
          <String>['me undated', 'them undated', 'them dated 12:00'],
          reason: 'the two undated rows keep their RELATIVE array order but the '
              'whole band sits below the dated row that preceded them',
        );
      },
    );

    test(
      'RELATIVE ORDER INSIDE THE BAND is the server array order — the part of '
      'the old doc that WAS true',
      () async {
        final cubit = _cubit(<DeliveryChatMessage>[
          _undated('a', 'first', 1),
          _undated('b', 'second', 2),
          _undated('c', 'third', 3),
          _dated('d', 'dated', DateTime.utc(2026, 7, 27, 12, 0)),
        ]);

        await cubit.load();

        expect(
          _texts(cubit),
          <String>['first', 'second', 'third', 'dated'],
          reason: 'array position is the ONLY ordering information an undated '
              'row carries, and it is preserved within the band',
        );
      },
    );

    test(
      'an all-undated thread renders in server array order — the band IS the '
      'thread, so the two rules coincide and nothing is observably reordered',
      () async {
        final cubit = _cubit(<DeliveryChatMessage>[
          _undated('a', 'one', 1),
          _undated('b', 'two', 2),
          _undated('c', 'three', 3),
        ]);

        await cubit.load();

        expect(_texts(cubit), <String>['one', 'two', 'three']);
        expect(
          cubit.state.messages.every((m) => !m.hasServerTimestamp), isTrue,
          reason: 'no surface may read these anchors as clocks',
        );
      },
    );

    test(
      'CONTROL — an ALL-DATED thread is sorted by the server clock, so a wire '
      'that pages newest-first still renders oldest-first',
      () async {
        // Proves the chronological sort the doc fix declines to remove is doing
        // real work: without it this array would render backwards.
        final cubit = _cubit(<DeliveryChatMessage>[
          _dated('c', 'newest', DateTime.utc(2026, 7, 27, 12, 2)),
          _dated('b', 'middle', DateTime.utc(2026, 7, 27, 12, 1)),
          _dated('a', 'oldest', DateTime.utc(2026, 7, 27, 12, 0)),
        ]);

        await cubit.load();

        expect(_texts(cubit), <String>['oldest', 'middle', 'newest']);
      },
    );
  });
}
