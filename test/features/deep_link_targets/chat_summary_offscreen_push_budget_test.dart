// READ ECONOMICS — the buried chat thread must not pay three reads for a chip
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/router/app_route_observer.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// The accepted-conversation wire, counting the three reads a summary refresh
/// makes. Same fixture shape as `chat_poll_cadence_test.dart`.
class _SummaryRecordingDio {
  _SummaryRecordingDio() {
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

  static const conversationId = 'conv-summary-1';
  static const requestId = 'req-summary-1';

  late final Dio dio;
  int deliveryReads = 0;
  int requestReads = 0;
  int offerReads = 0;

  /// Wire reads attributable to one `_refreshSummary` (three on this leg).
  int get summaryReads => deliveryReads + requestReads + offerReads;

  void clear() {
    deliveryReads = 0;
    requestReads = 0;
    offerReads = 0;
  }
}

Widget _host(RoleCubit role, Stream<void> refreshSignals) => MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  // The PRODUCTION observer the screen's own RouteAware subscribes to — the
  navigatorObservers: <NavigatorObserver>[appRouteObserver],
  home: BlocProvider<RoleCubit>.value(
    value: role,
    child: ChatDetailScreen(
      chatId: _SummaryRecordingDio.requestId,
      refreshSignals: refreshSignals,
    ),
  ),
);

Future<RoleCubit> _clientRole() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: UserRole.client);
}

/// Pushes a plain route ON TOP of the chat thread, the way the order summary /
/// dispute / delivery-detail routes do in the app.
Future<void> _pushOnTop(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  unawaited(
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('on top')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _popBack(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
}

void main() {
  late _SummaryRecordingDio wire;
  late StreamController<void> bus;
  late RoleCubit role;

  setUp(() async {
    wire = _SummaryRecordingDio();
    bus = StreamController<void>.broadcast();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
    sl.registerSingleton<Dio>(wire.dio);
    role = await _clientRole();
  });

  tearDown(() async {
    await bus.close();
    await role.close();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
  });

  Future<int> pumpResolved(WidgetTester tester) async {
    await tester.pumpWidget(_host(role, bus.stream));
    await tester.pumpAndSettle();
    final coldSummaryReads = wire.summaryReads;
    expect(
      coldSummaryReads,
      greaterThanOrEqualTo(3),
      reason: 'the fixture must actually resolve a client-accepted summary',
    );
    wire.clear();
    return coldSummaryReads;
  }

  testWidgets(
    'CONTROL — thread on screen: one order push costs ONE summary read',
    (tester) async {
      final perSummary = await pumpResolved(tester);

      bus.add(null);
      await tester.pumpAndSettle();

      expect(wire.summaryReads, perSummary);
    },
  );

  testWidgets('buried under another route: ONE push costs ZERO reads', (
    tester,
  ) async {
    await pumpResolved(tester);
    await _pushOnTop(tester);
    wire.clear();

    bus.add(null);
    await tester.pumpAndSettle();

    expect(
      wire.summaryReads,
      0,
      reason:
          'deliveries=${wire.deliveryReads} requests=${wire.requestReads} '
          'offers=${wire.offerReads}',
    );
  });

  testWidgets('buried: a BURST of four pushes still costs ZERO reads', (
    tester,
  ) async {
    await pumpResolved(tester);
    await _pushOnTop(tester);
    wire.clear();

    for (var i = 0; i < 4; i++) {
      bus.add(null);
    }
    await tester.pumpAndSettle();

    expect(wire.summaryReads, 0);
  });

  testWidgets(
    'back on top: four buried pushes are paid with ONE summary read, not four',
    (tester) async {
      final perSummary = await pumpResolved(tester);
      await _pushOnTop(tester);
      for (var i = 0; i < 4; i++) {
        bus.add(null);
      }
      await tester.pumpAndSettle();
      wire.clear();

      await _popBack(tester);

      expect(
        wire.summaryReads,
        perSummary,
        reason:
            'exactly one catch-up summary read — the deferred push debt and the '
            'route-return read collapse through the single-flight latch',
      );
    },
  );
}
