// b02 fg-suppression — proves the "currently open chat thread" mechanism is
// actually WIRED, not just implementable.
//
// The pure predicate tests take `openChatThreadIds` as an argument, so they
// would all pass even if no screen ever populated it — the exact "publisher
// with no subscriber" shape that let the newRequest push arrive and drive
// nothing all through b01. This file closes that hole from the other side:
// mount the real `ChatDetailScreen` under the real `appRouteObserver` and read
// the real registry.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/core/notifications/domain/active_chat_thread.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/router/app_route_observer.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

const _conversationId = 'conv-1';
const _requestId = 'req-1';

/// Resolves `/chat/req-1` the way the live gateway does: the route param is the
/// REQUEST id, and `GET /v1/conversations?correlationKey=` yields a DIFFERENT
/// conversation id. That asymmetry is the whole reason the registry holds a set.
Dio _resolvingDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        Object? body = const <String, dynamic>{};
        if (path == '/v1/conversations') {
          body = <String, dynamic>{
            'id': _conversationId,
            'phase': 'accepted',
            'requestId': _requestId,
            'winnerJeeberId': 'jeeber-1',
          };
        } else if (path == '/v1/conversations/$_conversationId/messages') {
          body = const <dynamic>[];
        } else if (path == '/v1/deliveries/$_requestId') {
          body = <String, dynamic>{
            'id': _requestId,
            'requestId': _requestId,
            'status': 'Ordered',
            'amount': <String, dynamic>{'value': 9, 'currency': 'USD'},
          };
        } else if (path == '/v1/offers') {
          body = const <String, dynamic>{'items': <dynamic>[]};
        }
        handler.resolve(
          Response(data: body, statusCode: 200, requestOptions: options),
        );
      },
    ),
  );
  return dio;
}

Widget _host(RoleCubit role, GlobalKey<NavigatorState> navKey) => MaterialApp(
      navigatorKey: navKey,
      navigatorObservers: <NavigatorObserver>[appRouteObserver],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<RoleCubit>.value(
        value: role,
        // `summaryPollInterval: null` disables the JEBV4-282 safety-net poll so
        // no timer is pending at teardown.
        child: const ChatDetailScreen(
          chatId: _requestId,
          summaryPollInterval: null,
        ),
      ),
    );

Future<RoleCubit> _clientRole() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: UserRole.client);
}

void main() {
  setUp(() {
    ActiveChatThread.instance.resetForTest();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
    sl.registerSingleton<Dio>(_resolvingDio());
  });

  tearDown(() {
    ActiveChatThread.instance.resetForTest();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
  });

  testWidgets(
    'an open chat registers BOTH its route param and its resolved '
    'conversation id',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_host(await _clientRole(), navKey));
      await tester.pumpAndSettle();

      final registry = ActiveChatThread.instance;
      expect(
        registry.isOpen(const <String>[_requestId]),
        isTrue,
        reason: 'the route param',
      );
      expect(
        registry.isOpen(const <String>[_conversationId]),
        isTrue,
        reason: 'the id resolved by correlationKey — a chat push stamped with '
            'the conversation id must match the same thread',
      );
      expect(registry.isOpen(const <String>['conv-other']), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'pushing another route ON TOP deregisters the thread — mounted is not the '
    'same as visible',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_host(await _clientRole(), navKey));
      await tester.pumpAndSettle();
      expect(ActiveChatThread.instance.isOpen(const <String>[_requestId]),
          isTrue);

      // The chat screen's own CTAs push exactly this way (order summary,
      // dispute evidence). The State stays mounted; the conversation does not.
      unawaited(navKey.currentState!.push<void>(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      ));
      await tester.pumpAndSettle();
      expect(
        ActiveChatThread.instance.openIds,
        isEmpty,
        reason: 'covered by another route ⇒ a chat push must reach the shade',
      );

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        ActiveChatThread.instance.isOpen(const <String>[_requestId]),
        isTrue,
        reason: 'back on top ⇒ suppression resumes',
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('disposing the chat screen clears the registration',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_host(await _clientRole(), navKey));
    await tester.pumpAndSettle();
    expect(ActiveChatThread.instance.openIds, isNotEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(ActiveChatThread.instance.openIds, isEmpty);
  });
}
