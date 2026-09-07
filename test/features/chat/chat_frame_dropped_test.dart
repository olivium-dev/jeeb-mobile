// F34 — an inbound frame that fails to parse was dropped in total silence, so
// the thread was missing a message no retry would ever fetch.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_state.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _Gateway extends ChatGateway {
  _Gateway();

  final _events = StreamController<ChatEvent>.broadcast();
  int historyReads = 0;

  void dropFrame() => _events.add(const MessageDropped('parse'));

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async {
    historyReads++;
    return <DeliveryChatMessage>[
      DeliveryChatMessage.text(
        id: 'srv-1',
        author: ChatAuthor.them,
        sentAt: DateTime.utc(2026, 8, 1, 12),
        status: MessageStatus.delivered,
        text: 'On my way with your order',
      ),
    ];
  }

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.accepted;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

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
  late List<String> lines;

  setUp(() {
    lines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = lines.add;
  });

  tearDown(Diag.resetForTest);

  test('a dropped frame raises messageDropped and is recorded', () async {
    final gateway = _Gateway();
    addTearDown(gateway.dispose);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);

    await cubit.load();
    gateway.dropFrame();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.error, ChatError.messageDropped);
    // Not silently swallowed.
    expect(lines.where((l) => l.contains('chat_frame_dropped')), hasLength(1));
    // The rendered thread is untouched — the frame is missing, not the thread.
    expect(cubit.state.messages, hasLength(1));
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · the screen surfaces it, with a retry',
        (tester) async {
      useReduceMotion(tester);
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
      await tester.pumpAndSettle();
      expect(gateway.historyReads, 1);

      gateway.dropFrame();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(
        find.bySemanticsIdentifier('chat_screen_error_snack'),
        findsOneWidget,
      );

      // The action is the only thing that can fetch the missed message.
      // SnackBar.action cannot carry a Semantics identifier (kit note), so the
      // key is the handle and the callback is invoked through the widget.
      final SnackBarAction action = tester.widget<SnackBarAction>(
        find.byKey(const Key('chat_screen_error_snack_retry_cta')),
      );
      action.onPressed();
      await tester.pumpAndSettle();

      expect(gateway.historyReads, 2);
    });
  }
}
