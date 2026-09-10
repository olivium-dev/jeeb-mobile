import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_map_surface.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/handover_code_store.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _id = 'synthetic-terminal-delivery';

DeliveryTrackingInfo _status(String value) =>
    DeliveryTrackingInfo.fromDeliveryJson(_id, {'id': _id, 'status': value});

class _Repository implements LiveTrackingRepository {
  DeliveryTrackingInfo info = _status('Done');

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async => info;
}

class _CodeStore implements HandoverCodeStore {
  final result = Completer<String?>();

  @override
  Future<String?> read({required String deliveryId}) => result.future;

  @override
  Future<void> save({required String deliveryId, required String code}) async =>
      fail('no code writes in a tracking view');

  @override
  Future<void> clear({required String deliveryId}) async =>
      fail('no persistent changes in a tracking view');
}

GoRouter _router(LiveTrackingCubit cubit, {VoidCallback? onReceipt}) =>
    GoRouter(
      initialLocation: '/orders/$_id/tracking',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Home')),
        GoRoute(
          path: '/orders/:id/tracking',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const LiveTrackingScreen(deliveryId: _id, useLiveMap: false),
          ),
        ),
        GoRoute(
          path: '/orders/:id/delivered-receipt',
          name: 'delivered-receipt',
          builder: (_, state) {
            onReceipt?.call();
            return Text('Receipt:${state.pathParameters['id']}');
          },
        ),
      ],
    );

Widget _app(GoRouter router) => MaterialApp.router(
  routerConfig: router,
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
);

void _expectNoLiveControls() {
  expect(find.byType(TrackingMapSurface), findsNothing);
  expect(find.byType(DeliveryTrackingPanel), findsNothing);
  for (final identifier in [
    'tracking_eta_label',
    'tracking_distance_label',
    'tracking_handover_code_row',
    'tracking_at_door_code',
    'tracking_stepper',
    'tracking_stream_retry_cta',
    'tracking_noshow_cta',
  ]) {
    expect(find.bySemanticsIdentifier(identifier), findsNothing);
  }
}

void main() {
  for (final cachedCode in [false, true]) {
    testWidgets(
      'pre-resolved Done is terminal with ${cachedCode ? 'cached' : 'late'} code',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final store = _CodeStore();
        if (cachedCode) store.result.complete('1234');
        // Resolve Done BEFORE BlocConsumer mounts: initial state does not replay
        // a one-shot navigation event, so this exercises the real fallback body.
        final cubit = LiveTrackingCubit(
          repository: _Repository(),
          deliveryId: _id,
          handoverCodeStore: store,
        );
        addTearDown(cubit.close);
        await tester.runAsync(() async => pumpEventQueue());
        expect(cubit.state.trackingInfo!.isDelivered, isTrue);
        final router = _router(cubit);
        addTearDown(router.dispose);
        await tester.pumpWidget(_app(router));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('live-tracking-delivered-state')),
          findsOneWidget,
        );
        expect(find.text('Delivered successfully'), findsOneWidget);
        expect(find.text('This delivery is complete.'), findsOneWidget);
        expect(find.bySemanticsIdentifier('tracking_back'), findsOneWidget);
        expect(cubit.state.handoverCode, isNull);
        _expectNoLiveControls();
        if (!cachedCode) {
          store.result.complete('1234');
          await tester.pumpAndSettle();
          expect(cubit.state.handoverCode, isNull);
          _expectNoLiveControls();
          expect(
            find.byKey(const Key('live-tracking-delivered-state')),
            findsOneWidget,
          );
        }

        await tester.tap(
          find.byKey(const Key('tracking-delivered-receipt-cta')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Receipt:$_id'), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/orders/$_id/delivered-receipt',
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'active → Done auto-advances once; late code cannot navigate again',
    (tester) async {
      final store = _CodeStore();
      final repository = _Repository()..info = _status('InTransit');
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: _id,
        handoverCodeStore: store,
      );
      addTearDown(cubit.close);
      await tester.runAsync(() async => pumpEventQueue());
      var receiptBuilds = 0;
      final router = _router(cubit, onReceipt: () => receiptBuilds++);
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      expect(find.byType(TrackingMapSurface), findsOneWidget);

      repository.info = _status('Done');
      await cubit.refreshNow();
      await tester.pumpAndSettle();
      expect(find.text('Receipt:$_id'), findsOneWidget);
      expect(receiptBuilds, 1);
      _expectNoLiveControls();

      store.result.complete('1234');
      await tester.pumpAndSettle();
      await cubit.refreshNow();
      cubit.retry();
      await tester.pumpAndSettle();
      expect(receiptBuilds, 1);
      expect(cubit.state.handoverCode, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
