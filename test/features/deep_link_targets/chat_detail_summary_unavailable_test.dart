// F44 — a failed summary read used to make the pinned strip VANISH: the user
// silently lost price, status and the track affordance, with no explanation.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/chat_screen_fixtures.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/order_chat_summary_unavailable_strip.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _Gateway extends ChatGateway {
  _Gateway();

  final _events = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async =>
      <DeliveryChatMessage>[
        DeliveryChatMessage.text(
          id: 'srv-1',
          author: ChatAuthor.them,
          sentAt: DateTime.utc(2026, 8, 1, 12),
          status: MessageStatus.delivered,
          text: 'On my way',
        ),
      ];

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

const OrderChatSummary _summary = OrderChatSummary(
  deliveryId: 'del-1',
  requestId: 'req-1',
  priceLabel: r'$9.00',
  jeeberName: 'Kamal',
  statusId: 'InTransit',
);

Future<ChatCubit> _mount(
  WidgetTester tester, {
  required OrderChatSummary? summary,
  required Widget? fallback,
  Locale locale = const Locale('en'),
}) async {
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
      pinnedSummary: summary,
      pinnedSummaryFallback: fallback,
    ),
    locale: locale,
  ));
  await cubit.load();
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · the unavailable strip takes the '
        'slot instead of nothing', (tester) async {
      int retries = 0;
      await _mount(
        tester,
        summary: null,
        fallback: OrderChatSummaryUnavailableStrip(
          failure: const ServerFailure(status: 503),
          onRetry: () => retries++,
        ),
        locale: locale,
      );

      expect(
        find.bySemanticsIdentifier('order_chat_summary_unavailable'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('order_chat_summary_retry'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_retry'));
      await tester.pump();

      expect(retries, 1);
    });
  }

  testWidgets('a resolved summary wins the slot; the stand-in stands down',
      (tester) async {
    await _mount(
      tester,
      summary: _summary,
      fallback: OrderChatSummaryUnavailableStrip(
        failure: const ServerFailure(status: 503),
        onRetry: () {},
      ),
    );

    expect(
      find.bySemanticsIdentifier('order_chat_summary_unavailable'),
      findsNothing,
    );
  });

  testWidgets('no summary and no failure leaves the slot empty', (tester) async {
    await _mount(tester, summary: null, fallback: null);

    expect(
      find.bySemanticsIdentifier('order_chat_summary_unavailable'),
      findsNothing,
    );
  });

  // R6: an unrecoverable failure gets no Retry the user cannot win.
  testWidgets('a 403 renders the strip with no retry', (tester) async {
    await _mount(
      tester,
      summary: null,
      fallback: const OrderChatSummaryUnavailableStrip(
        failure: ForbiddenFailure(),
      ),
    );

    expect(
      find.bySemanticsIdentifier('order_chat_summary_unavailable'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('order_chat_summary_retry'),
      findsNothing,
    );
  });

  // The PRODUCTION wiring, not just the strip: `chat_detail_screen` is what
  // decides whether the slot says "unavailable" or silently vanishes.
  group('ChatDetailScreen wires the stand-in', () {
    Future<void> mountDetail(
      WidgetTester tester, {
      required AppFailure? failure,
      OrderChatSummary? summary,
      Locale locale = const Locale('en'),
    }) async {
      useReduceMotion(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final role = RoleCubit(prefs: prefs, initialRole: UserRole.client);
      addTearDown(role.close);
      await tester.pumpWidget(wrapForTest(
        BlocProvider<RoleCubit>.value(
          value: role,
          child: ChatDetailScreen(
            chatId: 'conv-1',
            debugGateway: ChatScreenPreviewFixtures.emptyAccepted(),
            debugPhase: ConversationPhase.accepted,
            debugHasWinner: true,
            debugSummary: summary,
            debugSummaryFailure: failure,
          ),
        ),
        locale: locale,
      ));
      await tester.pumpAndSettle();
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('${locale.languageCode} · a failed summary read renders the '
          'stand-in in the real header slot', (tester) async {
        await mountDetail(
          tester,
          failure: const ServerFailure(status: 503),
          locale: locale,
        );

        expect(
          find.bySemanticsIdentifier('order_chat_summary_unavailable'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('order_chat_summary_retry'),
          findsOneWidget,
        );
      });
    }

    testWidgets('a resolved summary suppresses the stand-in', (tester) async {
      await mountDetail(
        tester,
        failure: const ServerFailure(status: 503),
        summary: _summary,
      );

      expect(
        find.bySemanticsIdentifier('order_chat_summary_unavailable'),
        findsNothing,
      );
    });

    testWidgets('no failure leaves the slot empty', (tester) async {
      await mountDetail(tester, failure: null);

      expect(
        find.bySemanticsIdentifier('order_chat_summary_unavailable'),
        findsNothing,
      );
    });
  });
}
