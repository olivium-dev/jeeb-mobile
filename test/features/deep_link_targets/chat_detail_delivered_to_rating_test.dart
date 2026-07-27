// Gap fix (fix/chat-delivered-to-rating): when the delivery a client is chatting
// about reaches a delivered-class terminal (Done) WHILE the client sits on the
// order-chat, the chat surface must auto-advance to the MANDATORY blind
// mutual-rating screen — the SAME canonical `/orders/:id/mutual-rate` route the
// OTP-handover and jeeber active-delivery completions use. Before this fix the
// summary poll advanced the status chip and then stopped, stranding the client
// on a finished chat with no forward path to rating.
//
// This locks two behaviours:
//   * in-transit (InTransit) → NO navigation (the client keeps chatting);
//   * delivered (Done)       → navigate to `/orders/:id/mutual-rate` (client leg,
//                              no `?mode=jeeber`, since RoleCubit is client).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// Recording Dio: resolves an accepted CLIENT conversation and serves a delivery
/// whose status advances Ordered → InTransit → Done across successive reads, so
/// the summary poll observes the completion transition live.
class _CompletingDeliveryDio {
  _CompletingDeliveryDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          Object? body = const <String, dynamic>{};
          if (path == '/v1/conversations') {
            body = <String, dynamic>{
              'id': conversationId,
              'phase': 'accepted',
              'requestId': requestId,
              'winnerJeeberId': 'jeeber-1',
            };
          } else if (path == '/v1/conversations/$conversationId/messages') {
            body = const <dynamic>[];
          } else if (path == '/v1/deliveries/$requestId') {
            deliveryReads++;
            // read 1 (mount) = Ordered, read 2 = InTransit, read 3+ = Done.
            final status = deliveryReads <= 1
                ? 'Ordered'
                : deliveryReads == 2
                    ? 'InTransit'
                    : 'Done';
            body = <String, dynamic>{
              'id': requestId,
              'requestId': requestId,
              'status': status,
              'amount': <String, dynamic>{'value': 9, 'currency': 'USD'},
            };
          } else if (path == '/v1/requests/$requestId') {
            body = <String, dynamic>{
              'displayId': 'ORD-1',
              'title': 'Deliver a parcel',
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
  }

  static const conversationId = 'conv-1';
  static const requestId = 'req-1';

  late final Dio dio;
  int deliveryReads = 0;
}

const _ratingText = 'RATING_SCREEN';

Widget _host(RoleCubit role, Stream<void> refreshSignals) {
  final router = GoRouter(
    initialLocation: '/chat/${_CompletingDeliveryDio.requestId}',
    routes: <RouteBase>[
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ChatDetailScreen(
          chatId: state.pathParameters['id']!,
          refreshSignals: refreshSignals,
        ),
      ),
      // Stub stand-in for the real MutualRatingScreen so the test asserts the
      // ROUTE the chat navigates to (and its `mode` leg) without pulling the
      // rating feature's DI graph.
      GoRoute(
        path: '/orders/:id/mutual-rate',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'client';
          return Scaffold(
            body: Center(
              child: Text(
                '$_ratingText ${state.pathParameters['id']} mode=$mode',
              ),
            ),
          );
        },
      ),
    ],
  );
  return BlocProvider<RoleCubit>.value(
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
}

Future<RoleCubit> _clientRole() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: UserRole.client);
}

void main() {
  late _CompletingDeliveryDio rec;
  late StreamController<void> refresh;

  setUp(() {
    rec = _CompletingDeliveryDio();
    refresh = StreamController<void>.broadcast();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
    sl.registerSingleton<Dio>(rec.dio);
  });

  tearDown(() async {
    await refresh.close();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
  });

  testWidgets(
    'client order-chat auto-navigates to mutual-rate when delivery reaches Done',
    (tester) async {
      await tester.pumpWidget(_host(await _clientRole(), refresh.stream));

      // Mount resolution: status is Ordered — the client stays on the chat, no
      // rating navigation yet.
      await tester.pumpAndSettle();
      expect(rec.deliveryReads, 1, reason: 'one delivery read at mount');
      expect(find.textContaining(_ratingText), findsNothing);

      // ⚠️ THE POINT OF THIS TEST AFTER b02 WAVE B.2. The rating hand-off used to
      // hang off the 60s summary POLL; deleting that poll without re-hosting the
      // hand-off would have stranded the customer on a finished chat with no
      // forward path, and no instrument we have would have shown it — the chip
      // simply never advances and nothing throws. So the hand-off is now driven
      // by the `delivery` push, and this suite is what holds that.
      //
      // `delivery` push #1: status advances to InTransit. Still in flight — the
      // chat MUST NOT navigate to rating.
      refresh.add(null);
      await tester.pumpAndSettle();
      expect(rec.deliveryReads, 2);
      expect(
        find.textContaining(_ratingText),
        findsNothing,
        reason: 'no rating navigation while the delivery is still in transit',
      );

      // `delivery` push #2: status reaches Done — the delivery completed while
      // the client is on the chat, so the screen navigates to the mutual-rating
      // route, client leg (no ?mode=jeeber).
      refresh.add(null);
      await tester.pumpAndSettle();
      expect(
        find.text('$_ratingText ${_CompletingDeliveryDio.requestId} mode=client'),
        findsOneWidget,
        reason: 'delivered → mandatory blind mutual-rating, client leg',
      );
    },
  );
}
