import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/data/in_memory_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/data/shared_prefs_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _FailureStore extends InMemorySharedPreferencesStore {
  _FailureStore() : super.empty();
  bool failAccount = false;
  bool throwing = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failAccount && key.contains('.account.')) {
      if (throwing) throw StateError('write failed');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

class _RemoveFailureOutbox extends InMemoryChatOutbox {
  bool removeFails = true;

  @override
  Future<void> remove(String clientId) async {
    if (removeFails) throw StateError('remove failed');
    await super.remove(clientId);
  }
}

class _Gateway extends ChatGateway {
  int voiceUploads = 0;
  int imageUploads = 0;
  bool uploadFails = false;
  bool sendFails = false;
  bool historyFails = false;
  Completer<void>? uploadWait;
  final sent = <DeliveryChatMessage>[];
  final history = <DeliveryChatMessage>[];
  final voiceKeys = <String>[];
  final voiceBytes = <List<int>>[];

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async {
    if (historyFails) throw const NetworkFailure(offline: true);
    return history;
  }

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.accepted;

  @override
  Stream<ChatEvent> subscribe(String id) => const Stream.empty();

  @override
  Future<DeliveryChatMessage> send(
    String id,
    DeliveryChatMessage message,
  ) async {
    sent.add(message);
    if (sendFails) throw const NetworkFailure(offline: true);
    return message.copyWith(status: MessageStatus.sent);
  }

  @override
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async {
    voiceUploads++;
    voiceKeys.add(idempotencyKey);
    voiceBytes.add(List.of(audioBytes));
    await uploadWait?.future;
    if (uploadFails) throw const NetworkFailure(offline: true);
    return const VoiceUploadResult(url: 'valid/voice.m4a');
  }

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    imageUploads++;
    await uploadWait?.future;
    if (uploadFails) throw const NetworkFailure(offline: true);
    return 'valid/image.jpg';
  }
}

ChatMessage _row(String sender, {String id = 'draft'}) => ChatMessage(
  clientId: id,
  conversationId: 'conv',
  senderId: sender,
  body: 'Private $sender draft',
  createdAt: DateTime.utc(2026),
  status: ChatMessageStatus.failed,
);

Future<void> _drain() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'a voice draft without upload inputs cannot dispatch an empty URL',
    () async {
      final gateway = _Gateway();
      gateway.history.add(
        DeliveryChatMessage.voice(
          id: 'orphaned-voice',
          author: ChatAuthor.me,
          sentAt: DateTime.utc(2026),
          status: MessageStatus.failed,
          url: '',
          durationMs: 1000,
        ),
      );
      final cubit = ChatCubit(
        deliveryId: 'conv',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.retryMessage('orphaned-voice');
      expect(gateway.sent, isEmpty);
      expect(cubit.state.messages.single.status, MessageStatus.failed);
    },
  );

  test(
    'new draft IDs cannot overwrite restored or previous-session sends',
    () async {
      final outbox = InMemoryChatOutbox([_row('alice', id: 'msg-conv-0')]);
      final gateway = _Gateway()..sendFails = true;
      ChatCubit build() => ChatCubit(
        deliveryId: 'conv',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
        outbox: outbox,
        currentUserId: 'alice',
        clock: () => DateTime.utc(2026),
      );
      final first = build();
      await first.load();
      await first.sendQuickReply('New draft');
      await first.close();
      final second = build();
      addTearDown(second.close);
      await second.load();
      await second.sendQuickReply('Another new draft');
      final rows = await outbox.load();
      expect(rows.map((row) => row.clientId).toSet(), hasLength(3));
      expect(rows.map((row) => row.body), [
        'Private alice draft',
        'New draft',
        'Another new draft',
      ]);
    },
  );

  for (final throwing in [false, true]) {
    test(
      'migration preserves durable source when copy fails: throws=$throwing',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = _FailureStore()..throwing = throwing;
        SharedPreferencesStorePlatform.instance = store;
        final prefs = await SharedPreferences.getInstance();
        final root = SharedPrefsChatOutbox(prefs: prefs);
        await root.enqueue(_row('alice'));
        store.failAccount = true;
        final account = root.forAccount('alice');
        await expectLater(account.load(), throwsStateError);
        expect((await root.load()).single.senderId, 'alice');
        store.failAccount = false;
        expect((await account.load()).single.senderId, 'alice');
        final stored = await store.getAll();
        final durableRows = stored.values.whereType<String>().expand(
          (value) => (jsonDecode(value) as List).cast<Map<String, Object?>>(),
        );
        expect(
          durableRows.where((row) => row['body'] == 'Private alice draft'),
          hasLength(1),
        );
      },
    );
  }

  test(
    'failed cleanup is contained and retried without resending the acked row',
    () async {
      final outbox = _RemoveFailureOutbox();
      final gateway = _Gateway()..sendFails = true;
      final reconnect = StreamController<void>.broadcast(sync: true);
      final cubit = ChatCubit(
        deliveryId: 'conv',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
        outbox: outbox,
        currentUserId: 'alice',
        reconnectSignals: reconnect.stream,
      );
      addTearDown(cubit.close);
      addTearDown(reconnect.close);
      await cubit.load();
      await cubit.sendQuickReply('Keep me until acknowledged');
      gateway.sendFails = false;
      reconnect.add(null);
      await _drain();
      expect(gateway.sent, hasLength(2));
      expect(cubit.state.messages.single.status, MessageStatus.sent);
      expect(cubit.state.outboxPending, 1);
      outbox.removeFails = false;
      reconnect.add(null);
      await _drain();
      expect(gateway.sent, hasLength(2));
      expect(await outbox.load(), isEmpty);
      expect(cubit.state.outboxPending, 0);
    },
  );

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets(
      'account change disposes old chat state (${locale.languageCode})',
      (tester) async {
        useReduceMotion(tester);
        final gateway = _Gateway();
        final outbox = InMemoryChatOutbox([_row('alice')]);
        Future<void> mount(String userId) async {
          await tester.pumpWidget(
            wrapForTest(
              ChatScreen(
                deliveryId: 'conv',
                counterpartName: 'Counterpart',
                gateway: gateway,
                outbox: outbox,
                currentUserId: userId,
                pickerService: StubPhotoPickerService(),
              ),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
        }

        await mount('alice');
        final first = tester
            .element(find.byType(ChatComposer))
            .read<ChatCubit>();
        expect(first.state.outboxPending, 1);
        await mount('bob');
        final second = tester
            .element(find.byType(ChatComposer))
            .read<ChatCubit>();
        expect(identical(first, second), false);
        await tester.runAsync(_drain);
        await tester.pump();
        expect(first.isClosed, true);
        expect(second.state.outboxPending, 0);
        expect(second.state.messages, isEmpty);
        await second.refresh();
        await tester.pumpAndSettle();
        expect(gateway.sent, isEmpty);
        expect(
          find.bySemanticsIdentifier('chat_connection_banner'),
          findsNothing,
        );
      },
    );
  }

  test('another account cannot see, count, or flush a legacy draft', () async {
    final outbox = InMemoryChatOutbox([_row('alice')]);
    final gateway = _Gateway();
    final reconnect = StreamController<void>.broadcast(sync: true);
    final cubit = ChatCubit(
      deliveryId: 'conv',
      gateway: gateway,
      pickerService: StubPhotoPickerService(),
      outbox: outbox,
      currentUserId: 'bob',
      reconnectSignals: reconnect.stream,
    );
    addTearDown(cubit.close);
    addTearDown(reconnect.close);
    await cubit.load();
    reconnect.add(null);
    await _drain();
    expect(cubit.state.messages, isEmpty);
    expect(cubit.state.outboxPending, 0);
    expect(gateway.sent, isEmpty);
    expect((await outbox.load()).single.senderId, 'alice');
  });

  test('unknown identity neither restores nor persists drafts', () async {
    final outbox = InMemoryChatOutbox([_row('')]);
    final gateway = _Gateway()..sendFails = true;
    final cubit = ChatCubit(
      deliveryId: 'conv',
      gateway: gateway,
      pickerService: StubPhotoPickerService(),
      outbox: outbox,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.messages, isEmpty);
    await cubit.sendQuickReply('Unidentified draft');
    expect(await outbox.load(), hasLength(1));
    expect(cubit.state.outboxPending, 0);
  });

  test(
    'account stores migrate concurrently without deleting another owner',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final legacy = SharedPrefsChatOutbox(prefs: prefs);
      await legacy.enqueue(_row('alice'));
      await legacy.enqueue(_row('bob'));
      await legacy.enqueue(_row('', id: 'unowned'));
      final alice = legacy.forAccount('alice');
      final bob = legacy.forAccount('bob');
      final rows = await Future.wait([alice.load(), bob.load()]);
      expect(rows[0].single.senderId, 'alice');
      expect(rows[1].single.senderId, 'bob');
      expect((await legacy.load()).single.senderId, '');
      await bob.remove('draft');
      await bob.enqueue(_row('alice', id: 'foreign'));
      expect(await bob.load(), isEmpty);
      final reloaded = SharedPrefsChatOutbox(prefs: prefs);
      expect(
        (await reloaded.forAccount('alice').load()).single.senderId,
        'alice',
      );
      expect(await reloaded.forAccount('bob').load(), isEmpty);
      expect(
        prefs.getKeys().where((key) => key.contains('.account.')),
        hasLength(2),
      );
    },
  );

  test(
    'successful refresh retires the cold offline failure and retry timer',
    () async {
      final gateway = _Gateway()..historyFails = true;
      final cubit = ChatCubit(
        deliveryId: 'conv',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.historyFailure, isA<NetworkFailure>());
      gateway.historyFails = false;
      await cubit.refresh();
      expect(cubit.state.historyLoadFailed, false);
      expect(cubit.state.refreshFailure, isNull);
      expect(cubit.state.historyFailure, isNull);
      expect(cubit.debugHistoryRetryArmed, false);
      await cubit.refresh();
      expect(cubit.state.historyFailure, isNull);
    },
  );

  for (final voice in [true, false]) {
    final kind = voice ? 'voice' : 'photo';
    Future<void> send(ChatCubit cubit) => voice
        ? cubit.sendVoiceNote(
            audioBytes: [1, 2, 3],
            mimeType: 'audio/mp4',
            durationMs: 1000,
          )
        : cubit.sendPhotoFromCamera();

    test(
      '$kind retry resumes upload with the same draft before dispatch',
      () async {
        final gateway = _Gateway()..uploadFails = true;
        final cubit = ChatCubit(
          deliveryId: 'conv',
          gateway: gateway,
          pickerService: StubPhotoPickerService(),
        );
        addTearDown(cubit.close);
        await send(cubit);
        final id = cubit.state.messages.single.id;
        expect(cubit.state.messages.single.status, MessageStatus.failed);
        expect(gateway.sent, isEmpty);
        gateway.uploadFails = false;
        gateway.uploadWait = Completer<void>();
        final retry = cubit.retryMessage(id);
        await _drain();
        await cubit.retryMessage(id);
        expect(gateway.sent, isEmpty);
        expect(voice ? gateway.voiceUploads : gateway.imageUploads, 2);
        gateway.uploadWait!.complete();
        await retry;
        expect(gateway.sent, hasLength(1));
        expect(gateway.sent.single.id, id);
        expect(
          voice ? gateway.sent.single.voiceUrl : gateway.sent.single.imageUrl,
          voice ? 'valid/voice.m4a' : 'valid/image.jpg',
        );
        expect(cubit.state.messages.single.status, MessageStatus.sent);
        if (voice) {
          expect(gateway.voiceKeys, [id, id]);
          expect(gateway.voiceBytes, [
            [1, 2, 3],
            [1, 2, 3],
          ]);
        }
      },
    );

    test('$kind dispatch retry reuses the already uploaded ref', () async {
      final gateway = _Gateway()..sendFails = true;
      final cubit = ChatCubit(
        deliveryId: 'conv',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
      );
      addTearDown(cubit.close);
      await send(cubit);
      expect(cubit.state.messages.single.status, MessageStatus.failed);
      gateway.sendFails = false;
      await cubit.retryMessage(cubit.state.messages.single.id);
      expect(voice ? gateway.voiceUploads : gateway.imageUploads, 1);
      expect(gateway.sent, hasLength(2));
      expect(cubit.state.messages.single.status, MessageStatus.sent);
    });

    test('$kind upload finishing after disposal never dispatches', () async {
      final gateway = _Gateway()..uploadWait = Completer<void>();
      final cubit = ChatCubit(
        deliveryId: 'conv',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
      );
      final sending = send(cubit);
      await _drain();
      await cubit.close();
      gateway.uploadWait!.complete();
      await sending;
      expect(gateway.sent, isEmpty);
    });
  }
}
