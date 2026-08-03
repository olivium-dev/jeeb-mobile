import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

/// Gateway whose history is mutable (so the test can "land" a server message)
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
  @override
  Future<Uint8List> fetchImageBytes(String objectRef) async {
    imageFetches.add(objectRef);
    return Uint8List.fromList(<int>[1, 2, 3, 4]);
  }

  final List<String> imageFetches = <String>[];

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
        final gateway = _PollGateway(const <DeliveryChatMessage>[]);
        final cubit = _build(gateway);
        await cubit.load();
        expect(cubit.state.messages, isEmpty);

        cubit.composerChanged('mine');
        await cubit.sendText();
        expect(cubit.state.messages, hasLength(1));
        final optimisticId = cubit.state.messages.single.id;

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

      gateway.push(IncomingMessage(_them('srv-2', 'live')));
      await Future<void>.delayed(const Duration(milliseconds: 5));
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

      gateway.history = [_them('srv-after-close', 'too late')];
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.messages, isEmpty);
    });
  });
}
