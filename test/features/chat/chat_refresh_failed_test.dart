// F35 — a refresh that fails used to be completely silent: the user read a
// stale thread and never learned the re-read had failed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
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

  bool failing = false;
  final _events = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async {
    if (failing) throw StateError('HTTP 500');
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
  Future<ConversationPhase> loadPhase(String id) async {
    if (failing) throw StateError('HTTP 500');
    return ConversationPhase.accepted;
  }

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
  test('a failed refresh keeps the rows, never flips loading, and SAYS so',
      () async {
    final gateway = _Gateway();
    addTearDown(gateway.dispose);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.messages, hasLength(1));

    gateway.failing = true;
    await cubit.refresh();

    // Stale beats blank...
    expect(cubit.state.messages, hasLength(1));
    // ...but the failure is no longer invisible.
    expect(cubit.state.refreshFailure, isA<UnknownFailure>());
    expect(cubit.state.error, ChatError.refreshFailed);
    // R6: refresh() never flips to loading, and never raises the COLD rung.
    expect(cubit.state.isLoadingHistory, isFalse);
    expect(cubit.state.historyLoadFailed, isFalse);
  });

  test('a later successful refresh clears the warm failure', () async {
    final gateway = _Gateway();
    addTearDown(gateway.dispose);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);

    await cubit.load();
    gateway.failing = true;
    await cubit.refresh();
    expect(cubit.state.refreshFailure, isNotNull);

    gateway.failing = false;
    await cubit.refresh();

    expect(cubit.state.messages, hasLength(1));
    // Without this the warm strip is PERMANENT: one transient failure, and
    // "Reconnecting…" sits over a healthy thread for the rest of the session.
    expect(cubit.state.refreshFailure, isNull);
  });

  test('a cold reload also clears a warm failure', () async {
    final gateway = _Gateway();
    addTearDown(gateway.dispose);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);

    await cubit.load();
    gateway.failing = true;
    await cubit.refresh();
    expect(cubit.state.refreshFailure, isNotNull);

    gateway.failing = false;
    await cubit.load();

    expect(cubit.state.refreshFailure, isNull);
    expect(cubit.state.messages, hasLength(1));
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · the failure fires exactly one snack',
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
      await tester.pumpAndSettle();

      gateway.failing = true;
      await cubit.refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.bySemanticsIdentifier('chat_screen_error_snack'),
        findsOneWidget,
      );
    });
  }

  testWidgets('the rows survive the snack', (tester) async {
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
      ChatScreen(deliveryId: 'conv-1', counterpartName: 'Kamal', cubit: cubit),
    ));
    await cubit.load();
    await tester.pumpAndSettle();

    gateway.failing = true;
    await cubit.refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('On my way with your order'), findsOneWidget);
    expect(find.byKey(ChatScreen.historyErrorKey), findsNothing);
  });
}
