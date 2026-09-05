// OFF-05 / F36 — `chatErrorSendFailed` promised "Tap the bubble to retry" and
// nothing was tappable; a failed image tile had no way back at all.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _Gateway extends ChatGateway {
  _Gateway({this.history = const <DeliveryChatMessage>[]});

  final List<DeliveryChatMessage> history;
  bool sendFails = true;
  bool imageFails = true;
  int sends = 0;
  int imageReads = 0;
  final _events = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => history;

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
  Future<Uint8List> fetchImageBytes(String objectRef) async {
    imageReads++;
    if (imageFails) throw StateError('HTTP 503');
    return Uint8List.fromList(<int>[1, 2, 3, 4]);
  }

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

DeliveryChatMessage _theirImage() => DeliveryChatMessage.image(
      id: 'img-1',
      author: ChatAuthor.them,
      sentAt: DateTime.utc(2026, 8, 1, 12),
      status: MessageStatus.delivered,
      url: 'chat_attachment/abc.jpg',
    );

DeliveryChatMessage _theirText() => DeliveryChatMessage.text(
      id: 'srv-1',
      author: ChatAuthor.them,
      sentAt: DateTime.utc(2026, 8, 1, 12),
      status: MessageStatus.delivered,
      text: 'On my way',
    );

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('$tag · a failed OWN bubble is tappable and re-dispatches',
        (tester) async {
      useReduceMotion(tester);
      final gateway = _Gateway();
      addTearDown(gateway.dispose);
      final cubit = ChatCubit(
        deliveryId: 'conv-1',
        gateway: gateway,
        pickerService: const _NoopPicker(),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(wrapForTest(
        ChatScreen(
          deliveryId: 'conv-1',
          counterpartName: 'Kamal',
          cubit: cubit,
        ),
        locale: locale,
      ));
      await cubit.load();
      cubit.composerChanged('are you close?');
      await cubit.sendText();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('chat_detail_message_retry'),
        findsOneWidget,
      );
      // The frozen status glyph is untouched: the retry is a NEW id.
      expect(
        find.bySemanticsIdentifier('chat_detail_message_failed'),
        findsOneWidget,
      );

      gateway.sendFails = false;
      await tester.tap(find.bySemanticsIdentifier('chat_detail_message_retry'));
      await tester.pumpAndSettle();

      expect(gateway.sends, 2);
      expect(cubit.state.messages.single.status, MessageStatus.sent);
      expect(
        find.bySemanticsIdentifier('chat_detail_message_retry'),
        findsNothing,
      );
    });
  }

  testWidgets('a counterpart bubble exposes no retry node', (tester) async {
    useReduceMotion(tester);
    final gateway = _Gateway(history: <DeliveryChatMessage>[_theirText()]);
    addTearDown(gateway.dispose);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(wrapForTest(
      ChatScreen(deliveryId: 'conv-1', counterpartName: 'Kamal', cubit: cubit),
    ));
    await cubit.load();
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('chat_detail_message_retry'),
      findsNothing,
    );
  });

  test('retryMessage is a no-op for a message that did not fail', () async {
    final gateway = _Gateway(history: <DeliveryChatMessage>[_theirText()]);
    addTearDown(gateway.dispose);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.retryMessage('srv-1');

    expect(gateway.sends, 0);
  });

  // F36 — the placeholder used to be permanent: the poll tick its comment
  // relied on was deleted in N4.
  test('an image whose fetch throws is MARKED, and retryImage re-enters',
      () async {
    final gateway = _Gateway(history: <DeliveryChatMessage>[_theirImage()]);
    addTearDown(gateway.dispose);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(gateway.imageReads, 1);
    expect(cubit.state.messages.single.imageLoadFailed, isTrue);

    gateway.imageFails = false;
    await cubit.retryImage('img-1');

    expect(gateway.imageReads, 2);
    expect(cubit.state.messages.single.imageLoadFailed, isFalse);
    expect(cubit.state.messages.single.photoBytes, isNotNull);
  });

  testWidgets('the failed image tile exposes its reload affordance',
      (tester) async {
    useReduceMotion(tester);
    final gateway = _Gateway(history: <DeliveryChatMessage>[_theirImage()]);
    addTearDown(gateway.dispose);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(wrapForTest(
      ChatScreen(deliveryId: 'conv-1', counterpartName: 'Kamal', cubit: cubit),
    ));
    await cubit.load();
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('chat_detail_image_retry'),
      findsOneWidget,
    );

    gateway.imageFails = false;
    await tester.tap(find.bySemanticsIdentifier('chat_detail_image_retry'));
    await tester.pumpAndSettle();

    expect(gateway.imageReads, 2);
    expect(
      find.bySemanticsIdentifier('chat_detail_image_retry'),
      findsNothing,
    );
  });
}
