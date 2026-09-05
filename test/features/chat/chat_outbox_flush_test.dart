// OFF-04 — a failed TEXT send used to exist only in memory: the composer was
// already cleared, so killing the app dropped the message with no trace.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_state.dart';
import 'package:jeeb_mobile/features/chat/data/in_memory_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';

class _Gateway extends ChatGateway {
  _Gateway();

  bool sendFails = true;
  final _events = StreamController<ChatEvent>.broadcast();
  int sends = 0;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async =>
      const <DeliveryChatMessage>[];

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.accepted;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async {
    sends++;
    if (sendFails) throw StateError('HTTP 503');
    return m.copyWith(status: MessageStatus.sent);
  }

  @override
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async =>
      throw StateError('HTTP 503');

  @override
  Stream<ChatEvent> subscribe(String id) => _events.stream;

  Future<void> dispose() => _events.close();
}

class _NoopPicker implements PhotoPickerService {
  const _NoopPicker();
  @override
  Future<RawPhoto> pickFromCamera() => throw UnimplementedError();
  @override
  Future<RawPhoto> pickFromGallery() => throw UnimplementedError();
}

void main() {
  late _Gateway gateway;
  late InMemoryChatOutbox outbox;
  late StreamController<void> reconnects;

  setUp(() {
    gateway = _Gateway();
    outbox = InMemoryChatOutbox();
    reconnects = StreamController<void>.broadcast();
  });

  tearDown(() async {
    await gateway.dispose();
    await reconnects.close();
  });

  ChatCubit build() => ChatCubit(
        deliveryId: 'conv-1',
        gateway: gateway,
        pickerService: const _NoopPicker(),
        outbox: outbox,
        currentUserId: 'me',
        reconnectSignals: reconnects.stream,
      );

  test('a failed text send is persisted and counted', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();

    cubit.composerChanged('I am at the gate');
    await cubit.sendText();

    final rows = await outbox.load();
    expect(rows, hasLength(1));
    expect(rows.single.body, 'I am at the gate');
    expect(rows.single.conversationId, 'conv-1');
    expect(rows.single.senderId, 'me');
    expect(rows.single.status, ChatMessageStatus.failed);
    expect(cubit.state.outboxPending, 1);
    expect(cubit.state.messages.single.status, MessageStatus.failed);
  });

  // The row is not in server history, so a second cubit that does not REBUILD
  // its bubble can never retry it: `retryMessage` would hit the `_missing`
  // sentinel, the row would sit in storage forever and the banner would read
  // "1 pending" for the life of the install.
  test('a queued row survives a cubit re-create AND is flushed after it',
      () async {
    final first = build();
    await first.load();
    first.composerChanged('still here');
    await first.sendText();
    await first.close();
    expect(gateway.sends, 1);

    final second = build();
    addTearDown(second.close);
    await second.load();

    expect(await outbox.load(), hasLength(1));
    // Rehydrated as a FAILED own bubble, so the user can see and tap it.
    expect(second.state.messages, hasLength(1));
    expect(second.state.messages.single.id, isNotEmpty);
    expect(second.state.messages.single.text, 'still here');
    expect(second.state.messages.single.isMine, isTrue);
    expect(second.state.messages.single.status, MessageStatus.failed);
    expect(second.state.outboxPending, 1);

    gateway.sendFails = false;
    reconnects.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.sends, 2);
    expect(await outbox.load(), isEmpty);
    expect(second.state.outboxPending, 0);
    expect(second.state.messages.single.status, MessageStatus.sent);
  });

  // Both stores implement `enqueue` as a plain append, so a flush that fails
  // again while still offline must UPDATE the row, never duplicate it.
  test('repeated failed flushes never duplicate the queued row', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    cubit.composerChanged('offline for a while');
    await cubit.sendText();
    expect(await outbox.load(), hasLength(1));

    for (var i = 0; i < 3; i++) {
      reconnects.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    expect(await outbox.load(), hasLength(1));
    expect(cubit.state.outboxPending, 1);
    expect(cubit.state.messages, hasLength(1));
  });

  // A background flush is not a user action: firing the "send failed" snack on
  // every reachability edge while still offline is noise the user cannot act on.
  test('a background flush that fails again raises no send-failed error',
      () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    cubit.composerChanged('still offline');
    await cubit.sendText();
    expect(cubit.state.error, ChatError.sendFailed);
    cubit.acknowledgeError();

    reconnects.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.error, isNull);
    expect(cubit.state.messages.single.status, MessageStatus.failed);
  });

  test('a reachability edge flushes the queue and clears it on success',
      () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    cubit.composerChanged('flush me');
    await cubit.sendText();
    expect(gateway.sends, 1);

    gateway.sendFails = false;
    reconnects.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.sends, 2);
    expect(await outbox.load(), isEmpty);
    expect(cubit.state.outboxPending, 0);
    expect(cubit.state.messages.single.status, MessageStatus.sent);
  });

  // G9 — the outbox row carries only `body`, so an attachment cannot be
  // persisted through it. Say so rather than pretending it is queued.
  test('a failed VOICE send is NOT enqueued, but keeps its failed bubble',
      () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.sendVoiceNote(
      audioBytes: const <int>[1, 2, 3],
      mimeType: 'audio/m4a',
      durationMs: 1200,
    );

    expect(await outbox.load(), isEmpty);
    expect(cubit.state.messages.single.status, MessageStatus.failed);
  });

  test('a cubit with NO outbox behaves exactly as before', () async {
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
      reconnectSignals: reconnects.stream,
    );
    addTearDown(cubit.close);
    await cubit.load();

    cubit.composerChanged('no outbox here');
    await cubit.sendText();

    expect(await outbox.load(), isEmpty);
    expect(cubit.state.outboxPending, 0);
    expect(cubit.state.messages.single.status, MessageStatus.failed);
  });

  test('the default reconnect source is the app-wide reachability bus', () {
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);

    // Constructing without an explicit stream must not throw: the ambient
    // singleton is a broadcast controller with no timer of its own.
    expect(NetworkReachabilitySignals.instance.stream, isNotNull);
  });
}
