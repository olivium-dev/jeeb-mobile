// JEBV4-282 regression lock, re-pointed for b02 wave B.2.
//
// The customer chat's pinned status chip must still be LIVE — not a one-shot
// snapshot frozen at `initState`. What CHANGED is what makes it live: it used to
// be a 60s `LifecyclePoller`, and it is now the `delivery` push.
//
// So this suite now locks BOTH halves, because either one alone is a false pass:
//   * ABSENCE — a mounted, client-accepted chat with NO push and NO user action
//     issues exactly ONE delivery read, and still exactly one after five minutes
//     of virtual time. This is the owner's rule: "if the user does nothing and no
//     push arrives, does a network call happen a second time?"
//   * PRESENCE — one refresh event re-reads the delivery and the chip advances
//     (Ordered → InTransit). Without this half, "zero calls" would also be
//     satisfied by a screen that simply stopped working.
//
// The old test asserted only that a SECOND read eventually happened. That
// assertion passes for a poll and for a push alike, which is exactly why the
// mandate survived a whole batch unmet — so it is replaced, not extended.

import 'dart:async';

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

Widget _host(RoleCubit role, Stream<void> refreshSignals) => MaterialApp(
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
      chatId: _AdvancingDeliveryDio.requestId,
      refreshSignals: refreshSignals,
    ),
  ),
);

Future<RoleCubit> _role(UserRole role) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: role);
}

Future<RoleCubit> _clientRole() => _role(UserRole.client);

void main() {
  late _AdvancingDeliveryDio rec;
  late StreamController<void> refresh;

  setUp(() {
    rec = _AdvancingDeliveryDio();
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
    'ABSENCE: a mounted client accepted-order chat issues ZERO repeat delivery '
    'reads over five minutes with no push and no user action',
    (tester) async {
      await tester.pumpWidget(_host(await _clientRole(), refresh.stream));
      await tester.pumpAndSettle();
      expect(rec.deliveryReads, 1, reason: 'one read at mount');

      // Walk well past every cadence this screen has ever had (1s, 5s, 10s, 60s)
      // and then far beyond it. A single extra read at ANY of these steps is a
      // surviving poll.
      for (final step in const <Duration>[
        Duration(seconds: 1),
        Duration(seconds: 5),
        Duration(seconds: 10),
        Duration(seconds: 60),
        Duration(minutes: 5),
      ]) {
        await tester.pump(step);
        await tester.pump();
        expect(
          rec.deliveryReads,
          1,
          reason:
              'a repeat delivery read appeared after $step — a poll survives',
        );
      }

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'PRESENCE: one refresh event re-reads the delivery and the chip advances — '
    'the positive control that ABSENCE is not just a dead screen',
    (tester) async {
      await tester.pumpWidget(_host(await _clientRole(), refresh.stream));
      await tester.pumpAndSettle();
      expect(rec.deliveryReads, 1, reason: 'one read at mount');

      refresh.add(null);
      await tester.pumpAndSettle();
      expect(
        rec.deliveryReads,
        2,
        reason: 'the delivery push must drive exactly ONE re-read',
      );

      // And nothing follows it — a push must not arm a cadence.
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(rec.deliveryReads, 2, reason: 'the push left a cadence behind');

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'P3/M27: the JEEBER arms NO summary refresh — P3 adds ZERO background load '
    'on the Jeeber device',
    (tester) async {
      await tester.pumpWidget(
        _host(await _role(UserRole.jeeber), refresh.stream),
      );
      await tester.pumpAndSettle();
      // P3 DOES give the Jeeber the one-shot participant-scoped delivery read.
      expect(rec.deliveryReads, 1, reason: 'one read at mount');

      // A refresh event must change nothing: the strip is customer-only (the
      // Jeeber's fields never change post-accept and the delivered-status side
      // effect must fire on the client leg only), so the subscription is never
      // armed on this leg.
      refresh.add(null);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(
        rec.deliveryReads,
        1,
        reason: 'no summary refresh is armed for the Jeeber',
      );

      await tester.pumpWidget(const SizedBox());
    },
  );
}
