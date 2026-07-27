// b02 fg-suppression — proves the "currently open chat thread" mechanism is
// actually WIRED, not just implementable.
//
// The pure predicate tests take `openChatThreadIds` as an argument, so they
// would all pass even if no screen ever populated it — the exact "publisher
// with no subscriber" shape that let the newRequest push arrive and drive
// nothing all through b01. This file closes that hole from the other side:
// mount the real `ChatDetailScreen` under the real `appRouteObserver` and read
// the real registry.
//
// ## Why every case here is mounted under a real GoRouter
//
// The first version of this file used `MaterialApp(home: ChatDetailScreen(...))`.
// That harness cannot see the two defects hardware found, because it is not how
// the app mounts this screen:
//
//  * `go_router` keys its pages on the ROUTE OBJECT, not the location
//    (`go_router-13.2.5/lib/src/match.dart:178` —
//    `pageKey: ValueKey<String>(route.hashCode.toString())`), so
//    `context.go('/chat/B')` from `/chat/A` matches the SAME `/chat/:id` route,
//    reuses the page, and — without a widget key — reuses the `State`. No
//    `didPush`/`didPop` fires. A `home:`-mounted screen never navigates, so the
//    old harness could not express the case at all.
//  * `home:` also pushes exactly one route ever, so it cannot distinguish
//    "registered because the mechanism works" from "registered because
//    `subscribe()` happens to fire `didPush`".
//
// The router built below mirrors `AppRouter.create`'s `/chat/:id` entry
// verbatim, INCLUDING its `ValueKey(id)`; `_unkeyedRouter` drops the key so the
// key itself is proven load-bearing rather than assumed.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/notifications/domain/active_chat_thread.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/router/app_route_observer.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

const _requestIdA = 'req-1';
const _conversationIdA = 'conv-1';
const _requestIdB = 'req-2';
const _conversationIdB = 'conv-2';

/// Resolves `/chat/req-N` the way the live gateway does: the route param is the
/// REQUEST id, and `GET /v1/conversations?correlationKey=` yields a DIFFERENT
/// conversation id (`req-1` → `conv-1`). That asymmetry is the whole reason the
/// registry holds a set — and the reason a snapshot registry that misses the
/// resolution moment lets a conversation-id-stamped push through to the shade.
Dio _resolvingDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        Object? body = const <String, dynamic>{};
        if (path == '/v1/conversations') {
          final key = options.queryParameters['correlationKey'] as String? ?? '';
          final suffix = key.split('-').last;
          body = <String, dynamic>{
            'id': 'conv-$suffix',
            'phase': 'accepted',
            'requestId': key,
            'winnerJeeberId': 'jeeber-1',
          };
        } else if (path.startsWith('/v1/deliveries/')) {
          body = <String, dynamic>{
            'id': path.split('/').last,
            'status': 'Ordered',
            'amount': <String, dynamic>{'value': 9, 'currency': 'USD'},
          };
        } else if (path == '/v1/offers') {
          body = const <String, dynamic>{'items': <dynamic>[]};
        } else if (path.endsWith('/messages')) {
          body = const <dynamic>[];
        }
        handler.resolve(
          Response(data: body, statusCode: 200, requestOptions: options),
        );
      },
    ),
  );
  return dio;
}

/// PRODUCTION factory — the exact child `AppRouter.create`'s `/chat/:id` route
/// builds (`core/router/app_router.dart`). Using it, rather than re-declaring
/// an equivalent route here, is what makes these cases falsifiable against the
/// app: deleting the `ValueKey(id)` in `app_router.dart` reds the
/// `go('/chat/B')` case below. A locally-declared copy would not notice.
Widget _chatProd(String id) => buildChatDetailRouteChild(id);

/// CONTROL — the same screen with the key deliberately removed. Exists only to
/// demonstrate what go_router does without it; never claims to be production.
Widget _chatUnkeyed(String id) =>
    ChatDetailScreen(chatId: id, summaryPollInterval: null);

GoRouter _router({bool keyed = true, String initialLocation = '/'}) => GoRouter(
      initialLocation: initialLocation,
      // The production registration: `AppRouter.create`'s `observers:` list
      // calls `newAppRouteObserver()`, which mints and publishes the instance.
      observers: <NavigatorObserver>[newAppRouteObserver()],
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return keyed ? _chatProd(id) : _chatUnkeyed(id);
          },
        ),
        GoRoute(
          path: '/on-top',
          builder: (_, __) => const Scaffold(body: Text('on top')),
        ),
      ],
    );

Widget _host(RoleCubit role, GoRouter router) => BlocProvider<RoleCubit>.value(
      value: role,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

Future<RoleCubit> _clientRole() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: UserRole.client);
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
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
      final router = _router();
      await tester.pumpWidget(_host(await _clientRole(), router));
      await tester.pumpAndSettle();

      router.go('/chat/$_requestIdA');
      await tester.pumpAndSettle();

      final registry = ActiveChatThread.instance;
      expect(
        registry.isOpen(const <String>[_requestIdA]),
        isTrue,
        reason: 'the route param',
      );
      expect(
        registry.isOpen(const <String>[_conversationIdA]),
        isTrue,
        reason: 'the id resolved by correlationKey — a chat push stamped with '
            'the conversation id must match the same thread',
      );
      expect(registry.isOpen(const <String>['conv-other']), isFalse);

      await _teardown(tester);
    },
  );

  testWidgets(
    'the resolved conversation id lands AFTER registration and needs NO '
    'republish — the reader mechanism, not a publish moment',
    (tester) async {
      // This is the assertion that was TRUE in the old harness and FALSE on
      // hardware. It is pinned to the ORDER, not just the end state: read the
      // registry at the instant the screen registers (before the async
      // `?correlationKey=` resolution can have completed), then read it again
      // after, with nothing in between calling `enter`.
      final router = _router();
      await tester.pumpWidget(_host(await _clientRole(), router));
      await tester.pumpAndSettle();

      router.go('/chat/$_requestIdA');
      await tester.pump(); // build + didPush; resolution still in flight

      final registry = ActiveChatThread.instance;
      expect(
        registry.isOpen(const <String>[_requestIdA]),
        isTrue,
        reason: 'registered on didPush, from the route param alone',
      );
      expect(
        registry.isOpen(const <String>[_conversationIdA]),
        isFalse,
        reason: 'positive control: the conversation id is genuinely not known '
            'yet, so the next expect cannot pass vacuously',
      );

      await tester.pumpAndSettle(); // resolution lands

      expect(
        registry.isOpen(const <String>[_conversationIdA]),
        isTrue,
        reason: 'a snapshot registry returns false here unless someone '
            'remembered to republish; the reader has nothing to remember',
      );

      await _teardown(tester);
    },
  );

  testWidgets(
    "go('/chat/B') while /chat/A is on screen re-registers B and DROPS A — "
    'go_router reuses the page, so no didPush fires',
    (tester) async {
      final router = _router();
      await tester.pumpWidget(_host(await _clientRole(), router));
      await tester.pumpAndSettle();

      router.go('/chat/$_requestIdA');
      await tester.pumpAndSettle();
      final stateA = tester.state(find.byType(ChatDetailScreen));
      expect(
        ActiveChatThread.instance.openIds,
        <String>{_requestIdA, _conversationIdA},
      );

      // The notification-tap path: `app/app.dart:613` does exactly this.
      router.go('/chat/$_requestIdB');
      await tester.pumpAndSettle();

      expect(
        identical(stateA, tester.state(find.byType(ChatDetailScreen))),
        isFalse,
        reason: 'the ValueKey(id) on the /chat/:id builder must force a fresh '
            'State; without it go_router reuses this one and the screen shows '
            "chat A's messages under chat B's route",
      );
      expect(
        tester.widget<ChatDetailScreen>(find.byType(ChatDetailScreen)).chatId,
        _requestIdB,
      );
      expect(
        ActiveChatThread.instance.isOpen(const <String>[_requestIdB]),
        isTrue,
      );
      expect(
        ActiveChatThread.instance.isOpen(const <String>[_conversationIdB]),
        isTrue,
        reason: 'B re-resolved, so a push stamped with conv-2 is the open one',
      );
      expect(
        ActiveChatThread.instance.isOpen(
          const <String>[_requestIdA, _conversationIdA],
        ),
        isFalse,
        reason: "A is gone — a push for A must reach the shade. This is the "
            'assertion that fails without the key: the reused State keeps '
            "A's ids and swallows the very notification the user tapped away "
            'from.',
      );

      await _teardown(tester);
    },
  );

  testWidgets(
    'UNKEYED host: a State reused across a chatId change DEREGISTERS rather '
    'than lying about which thread is on screen',
    (tester) async {
      // Proves both halves of the didUpdateWidget fail-safe: that a reused
      // State really is what an unkeyed mount produces (so the ValueKey above
      // is load-bearing, not decoration), and that the registry refuses to
      // claim a thread when the route param and the resolved ids disagree.
      final router = _router(keyed: false);
      await tester.pumpWidget(_host(await _clientRole(), router));
      await tester.pumpAndSettle();

      router.go('/chat/$_requestIdA');
      await tester.pumpAndSettle();
      final stateA = tester.state(find.byType(ChatDetailScreen));
      expect(ActiveChatThread.instance.openIds, isNotEmpty);

      router.go('/chat/$_requestIdB');
      await tester.pumpAndSettle();

      expect(
        identical(stateA, tester.state(find.byType(ChatDetailScreen))),
        isTrue,
        reason: 'unkeyed ⇒ go_router reuses the State (match.dart:178)',
      );
      expect(
        ActiveChatThread.instance.openIds,
        isEmpty,
        reason: 'fail OPEN: every chat push shows, none is swallowed',
      );

      await _teardown(tester);
    },
  );

  testWidgets(
    'pushing another route ON TOP deregisters the thread — mounted is not the '
    'same as visible',
    (tester) async {
      final router = _router();
      await tester.pumpWidget(_host(await _clientRole(), router));
      await tester.pumpAndSettle();
      router.go('/chat/$_requestIdA');
      await tester.pumpAndSettle();
      expect(
        ActiveChatThread.instance.isOpen(const <String>[_requestIdA]),
        isTrue,
      );

      // The chat screen's own CTAs push exactly this way (order summary,
      // dispute evidence). The State stays mounted; the conversation does not.
      unawaited(router.push<void>('/on-top'));
      await tester.pumpAndSettle();
      expect(
        ActiveChatThread.instance.openIds,
        isEmpty,
        reason: 'covered by another route ⇒ a chat push must reach the shade',
      );

      router.pop();
      await tester.pumpAndSettle();
      expect(
        ActiveChatThread.instance.isOpen(
          const <String>[_requestIdA, _conversationIdA],
        ),
        isTrue,
        reason: 'back on top ⇒ suppression resumes, resolved ids included',
      );

      await _teardown(tester);
    },
  );

  testWidgets('disposing the chat screen clears the registration',
      (tester) async {
    final router = _router();
    await tester.pumpWidget(_host(await _clientRole(), router));
    await tester.pumpAndSettle();
    router.go('/chat/$_requestIdA');
    await tester.pumpAndSettle();
    expect(ActiveChatThread.instance.openIds, isNotEmpty);

    await _teardown(tester);
    expect(ActiveChatThread.instance.openIds, isEmpty);
  });

  testWidgets('a chat cold-landed as the INITIAL location still registers',
      (tester) async {
    // The push-tap-from-cold path lands here rather than on a `go` from `/`.
    final router = _router(initialLocation: '/chat/$_requestIdA');
    await tester.pumpWidget(_host(await _clientRole(), router));
    await tester.pumpAndSettle();
    expect(
      ActiveChatThread.instance.openIds,
      <String>{_requestIdA, _conversationIdA},
    );
    await _teardown(tester);
  });
}
