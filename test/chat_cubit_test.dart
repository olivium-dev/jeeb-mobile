import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_state.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_compressor.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';

/// Test double for [ChatGateway] that returns canned acks and lets the test
/// push inbound events from outside the cubit. The InMemory variant ships
/// real timers and is great for screens; for cubit unit tests we want full
/// control over event timing.
class _TestChatGateway extends ChatGateway {
  _TestChatGateway({
    this.history = const <DeliveryChatMessage>[],
    this.failSend = false,
  });

  final List<DeliveryChatMessage> history;
  bool failSend;

  final _controller = StreamController<ChatEvent>.broadcast();
  final List<DeliveryChatMessage> sentMessages = [];

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String deliveryId) async =>
      List<DeliveryChatMessage>.from(history);

  @override
  Future<DeliveryChatMessage> send(String deliveryId, DeliveryChatMessage message) async {
    sentMessages.add(message);
    if (failSend) {
      throw StateError('send failed');
    }
    return message.copyWith(status: MessageStatus.sent);
  }

  @override
  Stream<ChatEvent> subscribe(String deliveryId) => _controller.stream;

  void push(ChatEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}

/// Compressor that just returns the input bytes — keeps photo tests fast and
/// deterministic.
class _NoopCompressor implements PhotoCompressor {
  const _NoopCompressor();

  @override
  Future<Uint8List> compress(Uint8List bytes) async => bytes;
}

ChatCubit _build({
  _TestChatGateway? gateway,
  PhotoPickerService? picker,
  DateTime? clock,
}) {
  final cubit = ChatCubit(
    deliveryId: 'd1',
    gateway: gateway ?? _TestChatGateway(),
    pickerService: picker ?? StubPhotoPickerService(),
    compressor: const _NoopCompressor(),
    clock: () => clock ?? DateTime(2026, 5, 17, 10, 30),
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('ChatCubit — sending text', () {
    test('initial state has no messages and an empty composer', () {
      final cubit = _build();
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.composerText, isEmpty);
      expect(cubit.state.canSendText, isFalse);
    });

    test('sendText is a no-op when the composer is blank', () async {
      final gateway = _TestChatGateway();
      final cubit = _build(gateway: gateway);
      await cubit.load();
      await cubit.sendText();
      expect(gateway.sentMessages, isEmpty);
      expect(cubit.state.messages, isEmpty);
    });

    test('sendText appends an optimistic message, ack promotes to sent, '
        'and clears the composer', () async {
      final gateway = _TestChatGateway();
      final cubit = _build(gateway: gateway);
      await cubit.load();
      cubit.composerChanged('Hello!');
      expect(cubit.state.canSendText, isTrue);

      await cubit.sendText();

      expect(cubit.state.composerText, isEmpty);
      expect(cubit.state.messages, hasLength(1));
      final m = cubit.state.messages.single;
      expect(m.author, ChatAuthor.me);
      expect(m.text, 'Hello!');
      expect(m.status, MessageStatus.sent);
      expect(gateway.sentMessages.single.text, 'Hello!');
    });

    test('a failed send marks the optimistic entry as failed', () async {
      final gateway = _TestChatGateway(failSend: true);
      final cubit = _build(gateway: gateway);
      await cubit.load();
      cubit.composerChanged('boom');
      await cubit.sendText();
      expect(cubit.state.messages.single.status, MessageStatus.failed);
      expect(cubit.state.error, ChatError.sendFailed);
    });
  });

  group('ChatCubit — receipts (single tick / double tick / read)', () {
    test('a delivery receipt promotes sent → delivered', () async {
      final gateway = _TestChatGateway();
      final cubit = _build(gateway: gateway);
      await cubit.load();
      cubit.composerChanged('ping');
      await cubit.sendText();
      final id = cubit.state.messages.single.id;
      expect(cubit.state.messages.single.status, MessageStatus.sent);

      gateway.push(DeliveryReceipt(id));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.messages.single.status, MessageStatus.delivered);
    });

    test(
      'a read receipt promotes everything up to that message to read',
      () async {
        final gateway = _TestChatGateway();
        final cubit = _build(gateway: gateway);
        await cubit.load();
        cubit.composerChanged('one');
        await cubit.sendText();
        cubit.composerChanged('two');
        await cubit.sendText();
        cubit.composerChanged('three');
        await cubit.sendText();

        final secondId = cubit.state.messages[1].id;
        gateway.push(ReadReceipt(secondId));
        await Future<void>.delayed(Duration.zero);

        expect(
          cubit.state.messages[0].status,
          MessageStatus.read,
          reason:
              'all messages up to and including the read-through id are read',
        );
        expect(cubit.state.messages[1].status, MessageStatus.read);
        expect(
          cubit.state.messages[2].status,
          MessageStatus.sent,
          reason:
              'messages after the read-through id stay at their prior status',
        );
      },
    );

    test('a read receipt does not touch incoming messages', () async {
      final gateway = _TestChatGateway();
      final cubit = _build(gateway: gateway);
      await cubit.load();
      // Inbound message from the counterpart — should not be promoted by a
      // read receipt destined for the local outgoing queue.
      final inbound = DeliveryChatMessage.text(
        id: 'in-1',
        author: ChatAuthor.them,
        sentAt: DateTime(2026, 5, 17, 10, 25),
        status: MessageStatus.delivered,
        text: 'hi',
      );
      gateway.push(IncomingMessage(inbound));
      await Future<void>.delayed(Duration.zero);

      cubit.composerChanged('hello back');
      await cubit.sendText();
      final outId = cubit.state.messages.last.id;
      gateway.push(ReadReceipt(outId));
      await Future<void>.delayed(Duration.zero);

      final them = cubit.state.messages
          .where((m) => m.author == ChatAuthor.them)
          .single;
      expect(
        them.status,
        MessageStatus.delivered,
        reason: 'incoming messages keep their own status',
      );
    });
  });

  group('ChatCubit — incoming messages', () {
    test(
      'an incoming message is appended without affecting the composer',
      () async {
        final gateway = _TestChatGateway();
        final cubit = _build(gateway: gateway);
        await cubit.load();
        cubit.composerChanged('draft in flight');

        final inbound = DeliveryChatMessage.text(
          id: 'in-99',
          author: ChatAuthor.them,
          sentAt: DateTime(2026, 5, 17, 10, 31),
          status: MessageStatus.delivered,
          text: 'salam',
        );
        gateway.push(IncomingMessage(inbound));
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.messages.single.author, ChatAuthor.them);
        expect(
          cubit.state.composerText,
          'draft in flight',
          reason: 'incoming messages must not disturb the composer',
        );
      },
    );

    test('mixed RTL/LTR content is preserved verbatim (the cubit does not '
        'normalise direction)', () async {
      final gateway = _TestChatGateway();
      final cubit = _build(gateway: gateway);
      await cubit.load();

      // Sender writes Arabic.
      cubit.composerChanged('مرحباً');
      await cubit.sendText();
      // Counterpart replies in English.
      gateway.push(
        IncomingMessage(
          DeliveryChatMessage.text(
            id: 'in-200',
            author: ChatAuthor.them,
            sentAt: DateTime(2026, 5, 17, 10, 32),
            status: MessageStatus.delivered,
            text: 'On my way!',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      // Sender follows up with mixed content.
      cubit.composerChanged('OK شكراً');
      await cubit.sendText();

      expect(cubit.state.messages.map((m) => m.text).toList(), [
        'مرحباً',
        'On my way!',
        'OK شكراً',
      ]);
    });
  });

  group('ChatCubit — photo attachments', () {
    test(
      'sendPhotoFromCamera appends a photo message and clears isAttaching',
      () async {
        final gateway = _TestChatGateway();
        final picker = StubPhotoPickerService(
          cameraPayload: Uint8List.fromList(List<int>.filled(16, 0x42)),
        );
        final cubit = _build(gateway: gateway, picker: picker);
        await cubit.load();

        await cubit.sendPhotoFromCamera();

        expect(cubit.state.isAttaching, isFalse);
        expect(cubit.state.messages, hasLength(1));
        final m = cubit.state.messages.single;
        expect(m.kind, MessageKind.photo);
        expect(m.author, ChatAuthor.me);
        expect(m.photoBytes, isNotNull);
        expect(m.photoSource, PhotoSource.camera);
        expect(m.status, MessageStatus.sent);
      },
    );

    test(
      'sendPhotoFromGallery routes through the gallery side of the picker',
      () async {
        final gateway = _TestChatGateway();
        final picker = StubPhotoPickerService(
          galleryPayload: Uint8List.fromList(List<int>.filled(32, 0xAB)),
        );
        final cubit = _build(gateway: gateway, picker: picker);
        await cubit.load();

        await cubit.sendPhotoFromGallery();

        expect(cubit.state.messages.single.photoSource, PhotoSource.gallery);
      },
    );

    test('a denied permission surfaces ChatError.permissionDenied', () async {
      final picker = StubPhotoPickerService(
        cameraFailure: PhotoPickFailure.permissionDenied,
      );
      final cubit = _build(picker: picker);
      await cubit.load();

      await cubit.sendPhotoFromCamera();

      expect(cubit.state.error, ChatError.permissionDenied);
      expect(cubit.state.messages, isEmpty);
    });

    test('a cancelled pick is silent (no snackbar-worthy error)', () async {
      final picker = StubPhotoPickerService(
        cameraFailure: PhotoPickFailure.cancelled,
      );
      final cubit = _build(picker: picker);
      await cubit.load();

      await cubit.sendPhotoFromCamera();

      expect(cubit.state.error, ChatError.pickCancelled);
      expect(cubit.state.messages, isEmpty);
    });
  });

  group('ChatCubit — lifecycle', () {
    test('load surfaces history from the gateway', () async {
      final history = [
        DeliveryChatMessage.text(
          id: 'h1',
          author: ChatAuthor.them,
          sentAt: DateTime(2026, 5, 17, 10, 0),
          status: MessageStatus.delivered,
          text: 'earlier',
        ),
      ];
      final gateway = _TestChatGateway(history: history);
      final cubit = _build(gateway: gateway);

      await cubit.load();

      expect(cubit.state.isLoadingHistory, isFalse);
      expect(cubit.state.messages, history);
    });

    test('acknowledgeError clears the one-shot error flag', () async {
      final picker = StubPhotoPickerService(
        cameraFailure: PhotoPickFailure.permissionDenied,
      );
      final cubit = _build(picker: picker);
      await cubit.load();
      await cubit.sendPhotoFromCamera();
      expect(cubit.state.error, isNotNull);
      cubit.acknowledgeError();
      expect(cubit.state.error, isNull);
    });
  });
}
