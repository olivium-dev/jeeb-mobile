// ignore_for_file: avoid_dynamic_calls
//
// `ChatDetailScreen`'s State class is PRIVATE (`_ChatDetailScreenState`), so
// `tester.state(find.byType(ChatDetailScreen))` can only be typed as `dynamic`
// from a test. The alternative — widening the State class or adding a public
// accessor to production code purely so a test can name it — is worse than the
// lint. Scoped to this file, and only for that one call.

// b02 wave D — the measured resume fan-out, pinned.
//
// A device capture of ONE foreground resume on the customer order-chat produced
// 4x `GET /v1/deliveries/{id}` + 2x `GET /v1/offers`, against
// `ChatDetailScreen._refreshSummary`'s own documented claim of "ONE summary
// re-read". The arithmetic decomposes exactly:
//
//   * `ChatDetailScreen` fired `_refreshSummary` TWICE — once from
//     `didChangeAppLifecycleState(resumed)`, once from the `delivery` push the
//     OS delivered on the way back to the foreground. Each call is a
//     `fetchSummary`, and on the owner-scoped (customer) leg that is THREE
//     gateway reads: deliveries + requests + offers. → 2 deliveries, 2 offers.
//   * `DeliveryDetailScreen`, sitting BELOW the chat route in the stack for the
//     whole conversation, fired `_loadStatus` twice for the same two reasons.
//     Its repository is participant-scoped, so one read each. → 2 deliveries.
//
//   4 deliveries, 2 offers. No timer involved: three individually-correct
//   one-shot triggers, none of which knew about the others.
//
// Two independent fixes, both asserted here:
//   1. SINGLE FLIGHT on each screen — a trigger that lands while a read is on
//      the wire is DROPPED, not stacked. Beyond the wasted reads, the stacked
//      calls could complete out of order and repaint the chip from the OLDER
//      snapshot.
//   2. TOPIC ROUTING — neither screen subscribes to `chat` any more, so an
//      inbound message stops contributing to this at all. Covered in
//      `test/core/notifications/push_refresh_topic_routing_test.dart`.
//
// The counters are deliberately a PAIR: `debugSummaryRefetchCount` counts
// ATTEMPTS and `debugSummaryFetchCount` counts reads that reached the wire. A
// test that saw only "one read" could not tell a working latch from a
// subscription that never fired.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// Recording Dio whose DELIVERY read can be held open, so a second trigger
/// lands while the first read is genuinely in flight — which is the only state
/// in which a single-flight latch means anything.
class _GatedDio {
  _GatedDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
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
            final gate = hold;
            if (gate != null) await gate.future;
            body = <String, dynamic>{
              'id': requestId,
              'requestId': requestId,
              'status': 'InTransit',
              'amount': <String, dynamic>{'value': 9, 'currency': 'USD'},
            };
          } else if (path == '/v1/requests/$requestId') {
            requestReads++;
            body = <String, dynamic>{
              'displayId': 'ORD-1',
              'title': 'Deliver a parcel',
            };
          } else if (path == '/v1/offers') {
            offerReads++;
            body = const <String, dynamic>{'items': <dynamic>[]};
          }
          handler.resolve(
            Response<dynamic>(
              data: body,
              statusCode: 200,
              requestOptions: options,
            ),
          );
        },
      ),
    );
  }

  static const conversationId = 'conv-1';
  static const requestId = 'req-1';

  late final Dio dio;
  int deliveryReads = 0;
  int requestReads = 0;
  int offerReads = 0;

  /// Non-null holds every delivery read open until completed.
  Completer<void>? hold;
}

Widget _chatHost(RoleCubit role, Stream<void> refreshSignals) => MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<RoleCubit>.value(
    value: role,
    child: ChatDetailScreen(
      chatId: _GatedDio.requestId,
      refreshSignals: refreshSignals,
    ),
  ),
);

/// `DeliveryDetailScreen` wraps its body in `RootAwareBackScope`, which needs a
/// real `Router` above it, so this host is `MaterialApp.router` rather than a
/// bare `home:`.
Widget _deliveryHost(Stream<void> refreshSignals) {
  final router = GoRouter(
    initialLocation: '/orders/${_GatedDio.requestId}',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => DeliveryDetailScreen(
          deliveryId: state.pathParameters['id']!,
          refreshSignals: refreshSignals,
        ),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

Future<RoleCubit> _clientRole() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: UserRole.client);
}

dynamic _chatState(WidgetTester tester) =>
    tester.state(find.byType(ChatDetailScreen));

void main() {
  // b02 P0: the resume bus is a process-wide singleton with a 2 s coalescing
  // floor. Without a per-test reset the floor bleeds across cases in this file
  // (they run milliseconds apart) and a genuine resume in test N is silently
  // folded into test N-1's window.
  setUp(() async => AppResumeSignals.debugReset());

  late _GatedDio rec;
  late StreamController<void> refresh;

  setUp(() {
    rec = _GatedDio();
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
    'ChatDetailScreen: a resume and a push inside one round trip are TWO '
    'triggers and ONE summary read',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(_chatHost(await _clientRole(), refresh.stream));
      await tester.pumpAndSettle();

      final state = _chatState(tester);
      expect(state.debugSummaryRefreshArmed, isTrue);
      final deliveriesAtMount = rec.deliveryReads;
      final offersAtMount = rec.offerReads;

      // Hold the next delivery read open so the second trigger is guaranteed to
      // land mid-flight. Without the gate the first read completes inside the
      // same microtask drain and the test proves nothing.
      final gate = Completer<void>();
      rec.hold = gate;

      // Trigger 1: the app returns to the foreground.
      // b02 P0: `paused`, not `inactive` — a bare focus loss is no longer a
      // resume, so this must model a real background trip to fire the hook.
      for (final s in const <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();

      // Trigger 2: the `delivery` push the OS queued while backgrounded.
      refresh.add(null);
      await tester.pump();

      expect(
        state.debugSummaryRefetchCount,
        2,
        reason: 'both triggers must genuinely have fired — otherwise the read '
            'count below is low for the wrong reason',
      );
      expect(state.debugSummaryFetchCount, 1);

      gate.complete();
      rec.hold = null;
      await tester.pumpAndSettle();

      expect(
        rec.deliveryReads - deliveriesAtMount,
        1,
        reason: 'the measured capture had 2 from this screen alone',
      );
      expect(
        rec.offerReads - offersAtMount,
        1,
        reason: 'the measured capture had 2 offers reads',
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ChatDetailScreen: the latch RELEASES — a trigger after the read completes '
    'still re-reads',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(_chatHost(await _clientRole(), refresh.stream));
      await tester.pumpAndSettle();

      final state = _chatState(tester);
      final baseline = rec.deliveryReads;

      refresh.add(null);
      await tester.pumpAndSettle();
      expect(state.debugSummaryFetchCount, 1);
      expect(rec.deliveryReads - baseline, 1);

      refresh.add(null);
      await tester.pumpAndSettle();
      expect(
        state.debugSummaryFetchCount,
        2,
        reason: 'a latch that never released would freeze the chip forever',
      );
      expect(rec.deliveryReads - baseline, 2);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'DeliveryDetailScreen: a resume and a push inside one round trip produce '
    'ONE status read',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(_deliveryHost(refresh.stream));
      await tester.pumpAndSettle();

      final atMount = rec.deliveryReads;
      expect(atMount, 1, reason: 'one read at mount');

      final gate = Completer<void>();
      rec.hold = gate;

      // b02 P0: `paused`, not `inactive` — a bare focus loss is no longer a
      // resume, so this must model a real background trip to fire the hook.
      for (final s in const <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      refresh.add(null);
      await tester.pump();

      gate.complete();
      rec.hold = null;
      await tester.pumpAndSettle();

      expect(
        rec.deliveryReads - atMount,
        1,
        reason: 'the measured capture had 2 from this screen',
      );

      // And the latch releases.
      refresh.add(null);
      await tester.pumpAndSettle();
      expect(rec.deliveryReads - atMount, 2);

      await tester.pumpWidget(const SizedBox());
    },
  );
}
