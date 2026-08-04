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

/// P4/P5: a [ChatGateway] that DOES have a CDN wired — it overrides
/// `uploadImage` / `fetchImageBytes` the way [DioChatGateway] does when a
/// [CdnAssetGateway] is registered. The plain [_TestChatGateway] deliberately
class _CdnChatGateway extends _TestChatGateway {
  _CdnChatGateway({
    this.objectRef = '',
    this.uploadThrows = false,
    this.fetchBytes,
    super.history = const <DeliveryChatMessage>[],
  });

  String objectRef;
  final bool uploadThrows;
  final Uint8List? fetchBytes;

  final List<Uint8List> uploadedBytes = [];
  final List<String> fetchedRefs = [];

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (uploadThrows) throw StateError('cdn upload failed');
    uploadedBytes.add(bytes);
    return objectRef;
  }

  @override
  Future<Uint8List> fetchImageBytes(String objectRef) async {
    fetchedRefs.add(objectRef);
    return fetchBytes ?? Uint8List(0);
  }
}

/// Counts which pick method the cubit actually invoked (double-tap + gallery
/// branch assertions).
class _CountingPicker implements PhotoPickerService {
  int cameraCalls = 0;
  int galleryCalls = 0;

  @override
  Future<RawPhoto> pickFromCamera() async {
    cameraCalls++;
    return RawPhoto(
      bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      source: PhotoSource.camera,
    );
  }

  @override
  Future<RawPhoto> pickFromGallery() async {
    galleryCalls++;
    return RawPhoto(
      bytes: Uint8List.fromList(const <int>[5, 6, 7, 8]),
      source: PhotoSource.gallery,
    );
  }
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

  group('ChatCubit — own-message WS echo dedupe (T-APP-2)', () {
    test(
      "the sender's own message echoed back over the WS with a different "
      'SERVER id is NOT shown twice — it reconciles onto the optimistic bubble',
      () async {
        final gateway = _TestChatGateway();
        final cubit = _build(gateway: gateway);
        await cubit.load();

        cubit.composerChanged('on my way');
        await cubit.sendText();
        expect(cubit.state.messages, hasLength(1));
        final optimisticId = cubit.state.messages.single.id;
        expect(cubit.state.messages.single.author, ChatAuthor.me);

        // The mock fans the sender's OWN message back out over the WS with the
        gateway.push(
          IncomingMessage(
            DeliveryChatMessage.text(
              id: 'srv-msg-7',
              author: ChatAuthor.me,
              sentAt: DateTime(2026, 5, 17, 10, 30, 1),
              status: MessageStatus.delivered,
              text: 'on my way',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          cubit.state.messages,
          hasLength(1),
          reason: "own-message echo must not duplicate the sender's bubble",
        );
        final reconciled = cubit.state.messages.single;
        expect(reconciled.text, 'on my way');
        expect(reconciled.author, ChatAuthor.me);
        expect(reconciled.id, 'srv-msg-7');
        expect(reconciled.id, isNot(optimisticId));
        expect(reconciled.status, MessageStatus.delivered);
      },
    );

    test(
      'a delivery receipt keyed by the reconciled SERVER id promotes the '
      'own bubble (proves the id was adopted from the echo)',
      () async {
        final gateway = _TestChatGateway();
        final cubit = _build(gateway: gateway);
        await cubit.load();

        cubit.composerChanged('ping');
        await cubit.sendText();
        gateway.push(
          IncomingMessage(
            DeliveryChatMessage.text(
              id: 'srv-ping-1',
              author: ChatAuthor.me,
              sentAt: DateTime(2026, 5, 17, 10, 30, 2),
              status: MessageStatus.sent,
              text: 'ping',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        gateway.push(const ReadReceipt('srv-ping-1'));
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.messages, hasLength(1));
        expect(cubit.state.messages.single.status, MessageStatus.read);
      },
    );

    test(
      'a repeated identical echo (same SERVER id) is an idempotent no-op',
      () async {
        final gateway = _TestChatGateway();
        final cubit = _build(gateway: gateway);
        await cubit.load();

        cubit.composerChanged('hi');
        await cubit.sendText();
        final echo = IncomingMessage(
          DeliveryChatMessage.text(
            id: 'srv-hi-1',
            author: ChatAuthor.me,
            sentAt: DateTime(2026, 5, 17, 10, 30, 3),
            status: MessageStatus.delivered,
            text: 'hi',
          ),
        );
        gateway
          ..push(echo)
          ..push(echo);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.messages, hasLength(1));
      },
    );

    test(
      'a genuine counterpart message is always appended (never collapsed by '
      'the own-echo path)',
      () async {
        final gateway = _TestChatGateway();
        final cubit = _build(gateway: gateway);
        await cubit.load();

        cubit.composerChanged('same words');
        await cubit.sendText();
        // The counterpart happens to send the IDENTICAL text — it must still
        gateway.push(
          IncomingMessage(
            DeliveryChatMessage.text(
              id: 'srv-them-1',
              author: ChatAuthor.them,
              sentAt: DateTime(2026, 5, 17, 10, 30, 4),
              status: MessageStatus.delivered,
              text: 'same words',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.messages, hasLength(2));
        expect(
          cubit.state.messages.where((m) => m.author == ChatAuthor.them),
          hasLength(1),
        );
      },
    );

    test(
      'a distinct own message (different text) is NOT collapsed into a prior '
      'own bubble',
      () async {
        final gateway = _TestChatGateway();
        final cubit = _build(gateway: gateway);
        await cubit.load();

        cubit.composerChanged('first');
        await cubit.sendText();
        // A genuinely different own message arriving over the WS (not an echo
        gateway.push(
          IncomingMessage(
            DeliveryChatMessage.text(
              id: 'srv-second-1',
              author: ChatAuthor.me,
              sentAt: DateTime(2026, 5, 17, 10, 30, 5),
              status: MessageStatus.delivered,
              text: 'second',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.messages, hasLength(2));
        expect(
          cubit.state.messages.map((m) => m.text).toList(),
          ['first', 'second'],
        );
      },
    );
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

  group('ChatCubit — P4/P5 CDN image attachments', () {
    ChatCubit buildWithCdn({
      required _CdnChatGateway gateway,
      PhotoPickerService? picker,
    }) {
      final cubit = ChatCubit(
        deliveryId: 'd1',
        gateway: gateway,
        pickerService: picker ??
            StubPhotoPickerService(
              cameraPayload: Uint8List.fromList(List<int>.filled(16, 0x42)),
              galleryPayload: Uint8List.fromList(List<int>.filled(32, 0xAB)),
            ),
        compressor: const _NoopCompressor(),
        clock: () => DateTime(2026, 5, 17, 10, 30),
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('camera send uploads to the CDN then posts an `image`', () async {
      final gateway = _CdnChatGateway(objectRef: 'chat_attachment/aa.jpg');
      final cubit = buildWithCdn(gateway: gateway);
      await cubit.load();

      await cubit.sendPhotoFromCamera();

      expect(gateway.uploadedBytes, hasLength(1));
      expect(gateway.uploadedBytes.single, Uint8List.fromList(List<int>.filled(16, 0x42)));
      final m = cubit.state.messages.single;
      expect(m.kind, MessageKind.image, reason: 'the wire kind must be `image`');
      expect(m.imageUrl, 'chat_attachment/aa.jpg');
      expect(
        m.photoBytes,
        isNotNull,
        reason: 'the sender keeps the local preview so the bubble never blinks',
      );
      expect(m.status, MessageStatus.sent);
      expect(cubit.state.isAttaching, isFalse);
      expect(gateway.sentMessages.single.kind, MessageKind.image);
      expect(gateway.sentMessages.single.imageUrl, 'chat_attachment/aa.jpg');
    });

    test('gallery send does the same through the gallery branch', () async {
      final gateway = _CdnChatGateway(objectRef: 'chat_attachment/bb.jpg');
      final picker = _CountingPicker();
      final cubit = buildWithCdn(gateway: gateway, picker: picker);
      await cubit.load();

      await cubit.sendPhotoFromGallery();

      expect(picker.galleryCalls, 1);
      expect(picker.cameraCalls, 0);
      expect(gateway.uploadedBytes, hasLength(1));
      final m = cubit.state.messages.single;
      expect(m.kind, MessageKind.image);
      expect(m.imageUrl, 'chat_attachment/bb.jpg');
    });

    test('an upload failure is honest — failed bubble, error, NOTHING posted',
        () async {
      final gateway = _CdnChatGateway(uploadThrows: true);
      final cubit = buildWithCdn(gateway: gateway);
      await cubit.load();

      await cubit.sendPhotoFromCamera();

      expect(cubit.state.messages.single.status, MessageStatus.failed);
      expect(cubit.state.error, ChatError.attachmentUploadFailed);
      expect(
        gateway.sentMessages,
        isEmpty,
        reason: 'a failed upload must never post a phantom message',
      );
    });

    test('no CDN wired ⇒ unchanged legacy `photo` behaviour', () async {
      final gateway = _TestChatGateway();
      final cubit = _build(
        gateway: gateway,
        picker: StubPhotoPickerService(
          cameraPayload: Uint8List.fromList(List<int>.filled(16, 0x42)),
        ),
      );
      await cubit.load();

      await cubit.sendPhotoFromCamera();

      final m = cubit.state.messages.single;
      expect(m.kind, MessageKind.photo);
      expect(m.photoBytes, isNotNull);
      expect(gateway.sentMessages.single.kind, MessageKind.photo);
    });

    test('an oversize pick is rejected before any upload', () async {
      final gateway = _CdnChatGateway(objectRef: 'chat_attachment/cc.jpg');
      final cubit = buildWithCdn(
        gateway: gateway,
        picker: StubPhotoPickerService(
          cameraPayload: Uint8List(12 * 1024 * 1024),
        ),
      );
      await cubit.load();

      await cubit.sendPhotoFromCamera();

      expect(cubit.state.messages, isEmpty, reason: 'no bubble is appended');
      expect(cubit.state.error, ChatError.attachmentUploadFailed);
      expect(gateway.uploadedBytes, isEmpty);
      expect(cubit.state.isAttaching, isFalse);
    });

    test('cancel and permission-denied behave exactly as before', () async {
      final cancelled = buildWithCdn(
        gateway: _CdnChatGateway(objectRef: 'x'),
        picker: StubPhotoPickerService(
          cameraFailure: PhotoPickFailure.cancelled,
        ),
      );
      await cancelled.load();
      await cancelled.sendPhotoFromCamera();
      expect(cancelled.state.error, ChatError.pickCancelled);
      expect(cancelled.state.messages, isEmpty);
      expect(cancelled.state.isAttaching, isFalse);

      final denied = buildWithCdn(
        gateway: _CdnChatGateway(objectRef: 'x'),
        picker: StubPhotoPickerService(
          cameraFailure: PhotoPickFailure.permissionDenied,
        ),
      );
      await denied.load();
      await denied.sendPhotoFromCamera();
      expect(denied.state.error, ChatError.permissionDenied);
      expect(denied.state.messages, isEmpty);
    });

    test('a double tap picks and uploads exactly once', () async {
      final gateway = _CdnChatGateway(objectRef: 'chat_attachment/dd.jpg');
      final picker = _CountingPicker();
      final cubit = buildWithCdn(gateway: gateway, picker: picker);
      await cubit.load();

      await Future.wait([
        cubit.sendPhotoFromCamera(),
        cubit.sendPhotoFromCamera(),
      ]);

      expect(picker.cameraCalls, 1);
      expect(gateway.uploadedBytes, hasLength(1));
      expect(cubit.state.messages, hasLength(1));
    });

    test('inbound image bytes are resolved once and then deduped', () async {
      final inbound = DeliveryChatMessage.image(
        id: 'srv-1',
        author: ChatAuthor.them,
        sentAt: DateTime(2026, 5, 17, 10, 0),
        status: MessageStatus.delivered,
        url: 'chat_attachment/bb.jpg',
      );
      final known = Uint8List.fromList(const <int>[9, 8, 7, 6, 5, 4, 3, 2]);
      final gateway = _CdnChatGateway(
        objectRef: 'unused',
        history: [inbound],
        fetchBytes: known,
      );
      final cubit = buildWithCdn(gateway: gateway);

      await cubit.load();
      // The fetch is fire-and-forget; drain the microtask queue.
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.messages.single.photoBytes, known);
      expect(gateway.fetchedRefs, ['chat_attachment/bb.jpg']);

      // A later poll tick returning the SAME message must not re-download it.
      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.fetchedRefs, hasLength(1));
    });

    test('two captionless images with distinct refs do NOT collapse', () async {
      final gateway = _CdnChatGateway(objectRef: 'chat_attachment/e1.jpg');
      final cubit = buildWithCdn(gateway: gateway);
      await cubit.load();

      await cubit.sendPhotoFromCamera();
      gateway.objectRef = 'chat_attachment/e2.jpg';
      await cubit.sendPhotoFromCamera();
      expect(cubit.state.messages, hasLength(2));

      // The server fans BOTH back out with server ids and distinct urls.
      gateway.push(IncomingMessage(DeliveryChatMessage.image(
        id: 'srv-e1',
        author: ChatAuthor.me,
        sentAt: DateTime(2026, 5, 17, 10, 30),
        status: MessageStatus.delivered,
        url: 'chat_attachment/e1.jpg',
      )));
      gateway.push(IncomingMessage(DeliveryChatMessage.image(
        id: 'srv-e2',
        author: ChatAuthor.me,
        sentAt: DateTime(2026, 5, 17, 10, 31),
        status: MessageStatus.delivered,
        url: 'chat_attachment/e2.jpg',
      )));
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state.messages,
        hasLength(2),
        reason: 'keying the echo on the CDN ref keeps two different images '
            'with empty captions from collapsing onto one bubble',
      );
      expect(
        cubit.state.messages.map((m) => m.imageUrl).toSet(),
        {'chat_attachment/e1.jpg', 'chat_attachment/e2.jpg'},
      );
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
