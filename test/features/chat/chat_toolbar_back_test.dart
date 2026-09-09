import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';
import 'chat_header_support.dart' show FakeChatGateway;

enum _ChatStage { resolving, error, customer, jeeber }

const _delegates = <LocalizationsDelegate<dynamic>>[
  SyncAppLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _chat(_ChatStage stage, FakeChatGateway gateway) => switch (stage) {
  _ChatStage.resolving => const ChatDetailScreen(chatId: 'request-test'),
  _ChatStage.error => ChatResolutionErrorView(
    title: 'Test chat',
    failure: const NetworkFailure(),
    onRetry: () {},
  ),
  _ChatStage.customer || _ChatStage.jeeber => ChatScreen(
    deliveryId: 'conversation-test',
    counterpartName: 'Test counterpart',
    gateway: gateway,
    isOrderChat: stage == _ChatStage.customer,
  ),
};

void main() {
  for (final stage in _ChatStage.values) {
    for (final pushed in [false, true]) {
      testWidgets(
        '${stage.name} toolbar Back ${pushed ? 'pops to caller' : 'leaves go-replaced root'}',
        (tester) async {
          useReduceMotion(tester);
          final gateway = FakeChatGateway(phase: ConversationPhase.accepted);
          addTearDown(gateway.dispose);

          if (stage == _ChatStage.resolving) {
            // Hold the real resolving frame without making a network request.
            final dio = Dio();
            dio.interceptors.add(InterceptorsWrapper(onRequest: (_, _) {}));
            GetIt.instance.registerSingleton<Dio>(dio);
            addTearDown(() async {
              await GetIt.instance.unregister<Dio>();
              dio.close(force: true);
            });
          }

          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('HOME')),
              ),
              GoRoute(
                path: '/caller',
                builder: (_, _) => const Scaffold(body: Text('CALLER')),
              ),
              GoRoute(
                path: '/chat/:id',
                name: 'chat-detail',
                builder: (_, _) => _chat(stage, gateway),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: _delegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          );
          await tester.pump();

          if (pushed) {
            router.go('/caller');
            await tester.pumpAndSettle();
            router.pushNamed<void>(
              'chat-detail',
              pathParameters: {'id': 'request-test'},
            );
          } else {
            // The accept sheet uses goNamed, so there is no page to pop.
            router.goNamed(
              'chat-detail',
              pathParameters: {'id': 'request-test'},
            );
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(router.canPop(), pushed);
          final back = find.bySemanticsIdentifier('chat_detail_back_button');
          expect(back, findsOneWidget);
          expect(tester.getSize(back).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
          switch (stage) {
            case _ChatStage.resolving:
              expect(find.byType(ChatScreen), findsNothing);
              expect(find.byType(ChatResolutionErrorView), findsNothing);
            case _ChatStage.error:
              expect(find.byType(ChatResolutionErrorView), findsOneWidget);
            case _ChatStage.customer:
              expect(
                find.bySemanticsIdentifier('order_chat_root'),
                findsOneWidget,
              );
            case _ChatStage.jeeber:
              expect(
                find.bySemanticsIdentifier('chat_detail_root'),
                findsOneWidget,
              );
          }

          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(
            router.routerDelegate.currentConfiguration.uri.path,
            pushed ? '/caller' : '/',
          );
          expect(find.text(pushed ? 'CALLER' : 'HOME'), findsOneWidget);
          expect(find.byType(ChatAppBar), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }

  testWidgets('router-less header keeps the shared guarded Navigator default', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: _delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          appBar: ChatAppBar(title: 'Root chat'),
          body: Text('ROOT'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('chat_detail_back_button'));
    await tester.pumpAndSettle();
    expect(find.text('ROOT'), findsOneWidget);

    navigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            const Scaffold(appBar: ChatAppBar(title: 'Pushed chat')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('chat_detail_back_button'));
    await tester.pumpAndSettle();
    expect(find.text('ROOT'), findsOneWidget);
    expect(find.text('Pushed chat'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
