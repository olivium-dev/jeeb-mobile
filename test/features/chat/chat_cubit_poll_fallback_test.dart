// Sprint-7 chat step, re-based on N4 (b02 polling→push): the WS-INDEPENDENT
// history re-pull in [ChatCubit].
//
// The live transport is the WS subscription, but against the mock backend (and
// any flaky / unauthorized socket) the stream may never emit. There used to be
// a 60 s poll behind it; a PUSH on `PushRefreshSignals` is now what re-pulls
// history and merges inbound (counterpart/system) messages the socket missed —
// so "live receive" still works with zero frames, and it works FASTER than the
// clock it replaced.
//
// EVERY MERGE ASSERTION BELOW IS UNCHANGED. That is the point: the trigger
// moved, the fold did not. `_reconciledWithHistory` is still the single merge
// rule shared by the mount path, the resume path, the accept path and this one,
// so these nine cases keep their full value — only `_drivePull` replaced "wait
// for the next tick".
//
// These tests use a fake gateway whose `subscribe` stream NEVER emits (a dead
// WS), then assert the cubit surfaces a new counterpart message on a push,
// RECONCILES the server echo of an own message onto its optimistic bubble (it
// used to drop own rows outright, which is what left own bubbles pinned to the
// local clock above the counterpart's traffic), and dedupes against a message
// already delivered over the (test-pushed) stream.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

/// Gateway whose history is mutable (so the test can "land" a server message)
/// and whose subscribe stream is controllable (defaults to a dead WS — never
/// emits — so the poll is the ONLY inbound path under test).
class _PollGateway extends ChatGateway {
  _PollGateway(this.history);

  List<DeliveryChatMessage> history;
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      List<DeliveryChatMessage>.from(history);

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _controller.stream;

  /// Serves bytes for a peer image ref exactly once per ref, and counts the
  /// reads — the cubit never re-fetches a ref it has already resolved, so a
  /// merge that drops the bytes drops them for good.
  @override
  Future<Uint8List> fetchImageBytes(String objectRef) async {
    imageFetches.add(objectRef);
    return Uint8List.fromList(<int>[1, 2, 3, 4]);
  }

  final List<String> imageFetches = <String>[];

  // Opt into the poll fallback — this stands in for the real network gateway.
  @override
  bool get supportsPolling => true;

  void push(ChatEvent event) => _controller.add(event);
}

DeliveryChatMessage _them(String id, String text) => DeliveryChatMessage.text(
      id: id,
      author: ChatAuthor.them,
      sentAt: DateTime(2026, 6, 26, 10, 30),
      status: MessageStatus.delivered,
      text: text,
    );

DeliveryChatMessage _me(String id, String text) => DeliveryChatMessage.text(
      id: id,
      author: ChatAuthor.me,
      sentAt: DateTime(2026, 6, 26, 10, 31),
      status: MessageStatus.sent,
      text: text,
    );

/// The push bus the cubit under test is subscribed to. One per case, closed by
/// `addTearDown`.
late StreamController<void> _bus;

ChatCubit _build(_PollGateway gateway) {
  _bus = StreamController<void>.broadcast();
  addTearDown(_bus.close);
  final cubit = ChatCubit(
    deliveryId: 'conv-1',
    gateway: gateway,
    pickerService: StubPhotoPickerService(),
    refreshSignals: _bus.stream,
  );
  addTearDown(cubit.close);
  return cubit;
}

/// Fire ONE push and let the re-pull it drives complete and merge.
///
/// Replaces the old "sleep past the poll interval" idiom. Deliberately not a
/// direct `cubit.refresh()` call: routing through the real bus keeps these
/// cases exercising the subscription + single-flight latch that now carry the
/// surface, so a regression that silently unsubscribes reds them.
Future<void> _drivePull() async {
  _bus.add(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  group('ChatCubit — push-driven history re-pull (sprint-7, N4)', () {
    test('a counterpart message that lands server-side appears via the poll '
        '(no WS frame)', () async {
      final gateway = _PollGateway(const <DeliveryChatMessage>[]);
      final cubit = _build(gateway);
      await cubit.load();
      expect(cubit.state.messages, isEmpty);

      // The other participant posts; the dead WS never delivers it.
      gateway.history = [_them('srv-1', 'hello from the other side')];

      await _drivePull();

      expect(
        cubit.state.messages.map((m) => m.id),
        contains('srv-1'),
        reason: 'the push-driven re-pull should surface the inbound message',
      );
    });

    test(
      'poll RECONCILES the server echo of an own message onto the optimistic '
      'bubble — exactly one bubble, now carrying the server id',
      () async {
        // This test used to assert the opposite ("poll does NOT merge the local
        // user's own messages"), on the grounds that merging the echo would
        // duplicate the bubble. Dropping it had a worse cost: the echo is the
        // ONLY thing that ties an own message into the server's array, so
        // without it the optimistic bubble kept its LOCAL clock and a
        // counterpart row that arrived afterwards could not sort after it — the
        // thread read "all of theirs, then all of mine" for the whole session.
        // The real invariant is NO DUPLICATE, which reconciliation satisfies.
        final gateway = _PollGateway(const <DeliveryChatMessage>[]);
        final cubit = _build(gateway);
        await cubit.load();
        expect(cubit.state.messages, isEmpty);

        cubit.composerChanged('mine');
        await cubit.sendText();
        expect(cubit.state.messages, hasLength(1));
        final optimisticId = cubit.state.messages.single.id;

        // The server now returns that message under a server-minted id that can
        // never match the optimistic client id.
        gateway.history = [_me('srv-echo', 'mine')];
        await _drivePull();

        expect(
          cubit.state.messages, hasLength(1),
          reason: 'the echo must reconcile onto the bubble, not append a second '
              'copy of the user\'s own message',
        );
        expect(
          cubit.state.messages.single.id, 'srv-echo',
          reason: 'adopting the server id is what lets later delivery/read '
              'receipts (keyed by it) land on this bubble',
        );
        expect(optimisticId, isNot('srv-echo'));
      },
    );

    test(
      'poll surfaces an own message that has NO optimistic bubble to reconcile '
      'onto (sent from another device / a previous session)',
      () async {
        final gateway = _PollGateway(const <DeliveryChatMessage>[]);
        final cubit = _build(gateway);
        await cubit.load();

        gateway.history = [_me('srv-elsewhere', 'sent from my other device')];
        await _drivePull();

        expect(
          cubit.state.messages.map((m) => m.id), contains('srv-elsewhere'),
          reason: 'skipping every own-authored row meant a message the user '
              'really did send was invisible in their own thread',
        );
      },
    );

    test(
      'a repeated poll of the same own echo does not re-reconcile or duplicate',
      () async {
        final gateway = _PollGateway(const <DeliveryChatMessage>[]);
        final cubit = _build(gateway);
        await cubit.load();

        cubit.composerChanged('mine');
        await cubit.sendText();
        gateway.history = [_me('srv-echo', 'mine')];
        await _drivePull();
        // Several more ticks read the identical history.
        await _drivePull();

        expect(cubit.state.messages, hasLength(1));
        expect(cubit.state.messages.single.id, 'srv-echo');
      },
    );

    test(
      'two identical own texts are absorbed one-for-one, not collapsed onto a '
      'single bubble',
      () async {
        final gateway = _PollGateway(const <DeliveryChatMessage>[]);
        final cubit = _build(gateway);
        await cubit.load();

        cubit.composerChanged('same text');
        await cubit.sendText();
        cubit.composerChanged('same text');
        await cubit.sendText();
        expect(cubit.state.messages, hasLength(2));

        gateway.history = [
          _me('srv-echo-1', 'same text'),
          _me('srv-echo-2', 'same text'),
        ];
        await _drivePull();

        expect(
          cubit.state.messages, hasLength(2),
          reason: 'two sends, two server rows, two bubbles — an echo must not '
              'be able to claim a bubble another echo already claimed',
        );
        expect(
          cubit.state.messages.map((m) => m.id),
          containsAll(<String>['srv-echo-1', 'srv-echo-2']),
        );
      },
    );

    test(
      'a poll does NOT demote a bubble the counterpart already read',
      () async {
        // The poll now folds history in through the same reconcile as refresh(),
        // which means a server row can REPLACE the shown copy of the same id.
        // The wire projection knows nothing about receipts, so a naive replace
        // would walk a `read` bubble back to `delivered` every 60 seconds.
        final gateway = _PollGateway(const <DeliveryChatMessage>[]);
        final cubit = _build(gateway);
        await cubit.load();

        cubit.composerChanged('mine');
        await cubit.sendText();
        gateway.history = [_me('srv-echo', 'mine')];
        await _drivePull();
        expect(cubit.state.messages.single.id, 'srv-echo');

        gateway.push(const ReadReceipt('srv-echo'));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.messages.single.status, MessageStatus.read);

        // Several more polls of the identical history.
        await _drivePull();

        expect(
          cubit.state.messages.single.status, MessageStatus.read,
          reason: 'the shown copy knows things the wire row cannot: a receipt '
              'status must never be walked backwards by a re-read',
        );
      },
    );

    test(
      'a poll does not discard peer-image bytes the device already resolved',
      () async {
        final gateway = _PollGateway(<DeliveryChatMessage>[
          DeliveryChatMessage.image(
            id: 'srv-img',
            author: ChatAuthor.them,
            sentAt: DateTime(2026, 6, 26, 10, 30),
            status: MessageStatus.delivered,
            url: 'chat_attachment/peer.jpg',
          ),
        ]);
        final cubit = _build(gateway);
        await cubit.load();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(gateway.imageFetches, hasLength(1));
        expect(cubit.state.messages.single.photoBytes, isNotNull);

        // Several more polls return the same row, bytes-less as always.
        await _drivePull();

        expect(
          cubit.state.messages.single.photoBytes, isNotNull,
          reason: 'the ref is never re-fetched, so a merge that drops the bytes '
              'blanks the image permanently',
        );
        expect(
          gateway.imageFetches, hasLength(1),
          reason: 'and it must not thrash the CDN re-fetching what it dropped',
        );
      },
    );

    test('poll dedupes a message already delivered over the WS stream',
        () async {
      final gateway = _PollGateway(const <DeliveryChatMessage>[]);
      final cubit = _build(gateway);
      await cubit.load();

      // WS delivers srv-2 first...
      gateway.push(IncomingMessage(_them('srv-2', 'live')));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // ...and the same message is also present in the polled history.
      gateway.history = [_them('srv-2', 'live')];

      await _drivePull();

      expect(
        cubit.state.messages.where((m) => m.id == 'srv-2').length,
        1,
        reason: 'the same server id must appear exactly once',
      );
    });

    test('poll timer is cancelled on close (no inbound after dispose)',
        () async {
      final gateway = _PollGateway(const <DeliveryChatMessage>[]);
      final cubit = ChatCubit(
        deliveryId: 'conv-1',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
      );
      await cubit.load();
      await cubit.close();

      // Land a message AFTER close — the cancelled timer must never fire.
      gateway.history = [_them('srv-after-close', 'too late')];
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.messages, isEmpty);
    });
  });
}
