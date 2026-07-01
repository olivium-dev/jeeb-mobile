// BUG-17 fix (a2) — the tracking screen's pinned-summary "Open chat" routes by
// the REQUEST id (== correlationKey), NEVER a conversationId.
//
// `ChatDetailScreen` resolves the order thread via
// `GET /v1/conversations?correlationKey={requestId}`, so routing
// `order_summary_open_chat` with `info.conversationId` 404s that first lookup
// (the physical-run14 chat-load 404). The header must prefer `info.requestId`
// (falling back to the delivery id), never the conversationId.
//
// Drives the real LiveTrackingScreen + LiveTrackingCubit to a ready state with
// a summary-bearing delivery row over a real GoRouter, taps the open-chat CTA,
// and asserts the resolved `chat-detail` id.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _MockRepo extends Mock implements LiveTrackingRepository {}

String? _navigatedId;

GoRouter _router(LiveTrackingCubit cubit) => GoRouter(
      initialLocation: '/track',
      routes: [
        GoRoute(
          path: '/track',
          builder: (_, _) => BlocProvider<LiveTrackingCubit>.value(
            value: cubit,
            child: const LiveTrackingScreen(
              deliveryId: 'delivery-777',
              useLiveMap: false,
            ),
          ),
        ),
        GoRoute(
          path: '/chat/:id',
          name: 'chat-detail',
          builder: (_, state) {
            _navigatedId = state.pathParameters['id'];
            return const Scaffold(body: Text('chat'));
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
    );

void main() {
  setUp(() => _navigatedId = null);

  testWidgets(
    'order_summary_open_chat routes chat by the request id (== correlationKey) '
    '— NEVER the conversationId that 404s the resolve (BUG-17)',
    (tester) async {
      // A summary-bearing delivery row (price + jeeberName ⇒ hasSummary) that
      // carries BOTH a requestId and a phantom conversationId. `picked` avoids
      // the "on the way" snackbar / delivered auto-advance.
      const info = DeliveryTrackingInfo(
        deliveryId: 'delivery-777',
        currentStage: TrackingStage.picked,
        stageTimestamps: <TrackingStage, DateTime>{},
        price: 12.5,
        currency: 'USD',
        jeeberName: 'Sami',
        requestId: 'req-track-1',
        conversationId: 'conv-should-not-be-used',
      );

      final repo = _MockRepo();
      when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => info);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'delivery-777',
        pollInterval: const Duration(days: 1),
      );

      await tester.pumpWidget(_app(_router(cubit)));
      await tester.pumpAndSettle();

      // The pinned header + its open-chat CTA render.
      final handle = tester.ensureSemantics();
      final openChat = find.bySemanticsIdentifier('order_summary_open_chat');
      expect(openChat, findsOneWidget);
      await tester.tap(openChat);
      await tester.pumpAndSettle();
      handle.dispose();

      // THE FIX: chat opens on the REQUEST id, never the phantom conversationId.
      expect(_navigatedId, 'req-track-1');
      expect(_navigatedId, isNot('conv-should-not-be-used'));

      // Cancel the cubit's poll timer before the tree-disposed invariant check.
      await cubit.close();
    },
  );
}
