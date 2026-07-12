// JEBV4-282 regression lock: the customer chat pinned status chip must be LIVE,
// not a one-shot snapshot taken once in initState.
//
// ChatDetailScreen resolves the accepted-order summary once at mount. This test
// proves the screen now RE-POLLS the delivery (`GET /v1/deliveries/{id}`) on the
// configured cadence so the chip advances (Ordered → InTransit → …) without the
// user leaving and reopening the chat. The poll is gated to the client-accepted
// surface (the only place the strip renders) and stops at a terminal status.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// Recording Dio: resolves an accepted client conversation and serves a delivery
/// whose status ADVANCES on the second read, counting delivery reads.
class _AdvancingDeliveryDio {
  _AdvancingDeliveryDio() {
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
              // First read is Ordered; every read after the first is InTransit —
              // proving the chip is re-sourced, not frozen at the mount value.
              'status': deliveryReads <= 1 ? 'Ordered' : 'InTransit',
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

Widget _host(RoleCubit role) => MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<RoleCubit>.value(
    value: role,
    child: const ChatDetailScreen(
      chatId: _AdvancingDeliveryDio.requestId,
      summaryPollInterval: Duration(seconds: 1),
    ),
  ),
);

Future<RoleCubit> _clientRole() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: UserRole.client);
}

void main() {
  late _AdvancingDeliveryDio rec;

  setUp(() {
    rec = _AdvancingDeliveryDio();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
    sl.registerSingleton<Dio>(rec.dio);
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
  });

  testWidgets(
    'client accepted-order summary re-polls the delivery so the chip is live',
    (tester) async {
      await tester.pumpWidget(_host(await _clientRole()));
      // Initial mount resolution reads the delivery exactly once (the snapshot).
      await tester.pumpAndSettle();
      expect(rec.deliveryReads, 1, reason: 'one read at mount');

      // Advance past the poll interval: the screen must re-fetch the delivery
      // (the JEBV4-282 fix) rather than sit on the mount-time snapshot.
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(
        rec.deliveryReads,
        greaterThanOrEqualTo(2),
        reason: 'the pinned status chip re-polled the delivery',
      );

      // Dispose the screen so the periodic poll timer is cancelled (no pending
      // timer at teardown).
      await tester.pumpWidget(const SizedBox());
    },
  );
}
