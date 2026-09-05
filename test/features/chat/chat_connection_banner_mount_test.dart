// EP-11 / OFF-30 — `ChatConnectionBanner` was dead code: the thread had no
// connection indicator at all.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/data/in_memory_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _Gateway extends ChatGateway {
  _Gateway({
    this.historyFails = false,
    this.sendFails = false,
    this.failure = const NetworkFailure(offline: true),
  });

  bool historyFails;
  bool sendFails;
  AppFailure failure;
  int historyReads = 0;
  final _events = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async {
    historyReads++;
    if (historyFails) throw failure;
    return <DeliveryChatMessage>[
      DeliveryChatMessage.text(
        id: 'srv-1',
        author: ChatAuthor.them,
        sentAt: DateTime.utc(2026, 8, 1, 12),
        status: MessageStatus.delivered,
        text: 'On my way',
      ),
    ];
  }

  @override
  Future<ConversationPhase> loadPhase(String id) async {
    if (historyFails) throw failure;
    return ConversationPhase.accepted;
  }

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async {
    if (sendFails) throw const ServerFailure(status: 503);
    return m.copyWith(status: MessageStatus.sent);
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

void main() {
  Future<ChatCubit> mount(
    WidgetTester tester,
    _Gateway gateway, {
    InMemoryChatOutbox? outbox,
    Locale locale = const Locale('en'),
  }) async {
    useReduceMotion(tester);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
      outbox: outbox,
      currentUserId: 'me',
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(wrapForTest(
      ChatScreen(deliveryId: 'conv-1', counterpartName: 'Kamal', cubit: cubit),
      locale: locale,
    ));
    await cubit.load();
    await tester.pumpAndSettle();
    return cubit;
  }

  // A gateway with no realtime transport is a WORKING configuration carried by
  // HTTP, so `realtimeLive == false` alone must NOT raise the strip.
  testWidgets('a healthy thread renders NO connection banner', (tester) async {
    final gateway = _Gateway();
    addTearDown(gateway.dispose);
    final cubit = await mount(tester, gateway);

    expect(cubit.state.realtimeLive, isFalse);
    expect(
      find.bySemanticsIdentifier('chat_connection_banner'),
      findsNothing,
    );
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · a failed read raises the banner '
        'with a reconnect CTA', (tester) async {
      final gateway = _Gateway(historyFails: true);
      addTearDown(gateway.dispose);
      await mount(tester, gateway, locale: locale);

      expect(
        find.bySemanticsIdentifier('chat_connection_banner'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('chat_connection_reconnect'),
        findsOneWidget,
      );
      expect(gateway.historyReads, 1);

      gateway.historyFails = false;
      await tester.tap(find.bySemanticsIdentifier('chat_connection_reconnect'));
      await tester.pumpAndSettle();

      expect(gateway.historyReads, 2);
      expect(
        find.bySemanticsIdentifier('chat_connection_banner'),
        findsNothing,
      );
    });
  }

  // R6 — only Network/Timeout may blame connectivity. A 500 is a server fault
  // and the failure block already carries it; a second, WRONG diagnosis is not
  // a nicer error, it is a lie about the user's network.
  testWidgets('a SERVER failure raises NO connection banner', (tester) async {
    final gateway =
        _Gateway(historyFails: true, failure: const ServerFailure(status: 500));
    addTearDown(gateway.dispose);
    await mount(tester, gateway);

    expect(find.byKey(ChatScreen.historyErrorKey), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('chat_connection_banner'),
      findsNothing,
    );
  });

  testWidgets('an UNAUTHORIZED failure raises NO connection banner',
      (tester) async {
    final gateway =
        _Gateway(historyFails: true, failure: const UnauthorizedFailure());
    addTearDown(gateway.dispose);
    await mount(tester, gateway);

    expect(
      find.bySemanticsIdentifier('chat_connection_banner'),
      findsNothing,
    );
  });

  // The WARM rung: rows are on screen, so the recovery must re-read without
  // blanking them — and one success must retire the strip for good.
  testWidgets('a network refresh failure raises the strip, and a later '
      'success clears it', (tester) async {
    final gateway = _Gateway();
    addTearDown(gateway.dispose);
    final cubit = await mount(tester, gateway);
    expect(
      find.bySemanticsIdentifier('chat_connection_banner'),
      findsNothing,
    );

    gateway.historyFails = true;
    await cubit.refresh();
    await tester.pumpAndSettle();

    expect(cubit.state.historyLoadFailed, isFalse);
    expect(find.text('On my way'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('chat_connection_banner'),
      findsOneWidget,
    );

    gateway.historyFails = false;
    await tester.tap(find.bySemanticsIdentifier('chat_connection_reconnect'));
    await tester.pumpAndSettle();

    expect(cubit.state.refreshFailure, isNull);
    // Stale-beats-blank: the CTA re-read, it never emptied the thread.
    expect(find.text('On my way'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('chat_connection_banner'),
      findsNothing,
    );
  });

  testWidgets('queued sends raise the banner and its pending badge',
      (tester) async {
    final gateway = _Gateway(sendFails: true);
    addTearDown(gateway.dispose);
    final cubit = await mount(tester, gateway, outbox: InMemoryChatOutbox());

    cubit.composerChanged('are you close?');
    await cubit.sendText();
    await tester.pumpAndSettle();

    expect(cubit.state.outboxPending, 1);
    expect(
      find.bySemanticsIdentifier('chat_connection_banner'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat-pending-badge')), findsOneWidget);
  });

  // The banner lives INSIDE the bounded header slot, so it can never re-open
  // the `chat_header_overflow_test` defect.
  testWidgets('the banner sits inside the bounded header slot at 320x480/2.0',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _Gateway(historyFails: true);
    addTearDown(gateway.dispose);
    useReduceMotion(tester);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: const _NoopPicker(),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(wrapForTest(
      Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: ChatScreen(
            deliveryId: 'conv-1',
            counterpartName: 'Kamal',
            cubit: cubit,
          ),
        ),
      ),
    ));
    await cubit.load();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(chatHeaderSlotKey),
        matching: find.bySemanticsIdentifier('chat_connection_banner'),
      ),
      findsOneWidget,
    );
    // The composer stays whole: the header yields, it does not overflow.
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
