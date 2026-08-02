import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/router/app_router.dart'
    show resolveTrackingDeliveryId;
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/in_progress_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Captures the id the live-tracking route resolved, so a nav test can assert
/// the CTA handed the delivery id (not the request id) to the tracking surface.
class _TrackingProbe extends StatelessWidget {
  const _TrackingProbe({required this.resolvedId});
  final String resolvedId;
  @override
  Widget build(BuildContext context) =>
      Center(child: Text('tracking:$resolvedId', key: const Key('probe')));
}

GoRouter _router(ClientHomeRepository repo) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: BlocProvider(
            create: (_) => ClientHomeCubit(
              repository: repo,
              greetingNameProvider: () => 'Sami',
            )..load(),
            // No onTrack override → exercises the REAL GoRouter nav path.
            child: const InProgressTab(),
          ),
        ),
      ),
      GoRoute(
        path: '/orders/:id/tracking',
        name: 'live-tracking',
        builder: (context, state) => _TrackingProbe(
          // Same precedence rule the production route applies.
          resolvedId: resolveTrackingDeliveryId(
            routeId: state.pathParameters['id'],
            queryDeliveryId: state.uri.queryParameters['deliveryId'],
          ),
        ),
      ),
    ],
  );
}

Widget _app(GoRouter router) => MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [SyncAppLocalizationsDelegate()],
    );

ClientHomeRequest _activeRequest({
  required String id,
  String? deliveryId,
}) =>
    ClientHomeRequest(
      id: id,
      deliveryId: deliveryId,
      title: 'Pharmacy run',
      status: ClientRequestStatus.enRoute,
      destinationLabel: 'Ashrafieh, Beirut',
      progressStep: 2,
      tier: ClientRequestTier.flash,
    );

void main() {
  group('resolveTrackingDeliveryId (pure)', () {
    test('prefers the server deliveryId query param over the path id', () {
      expect(
        resolveTrackingDeliveryId(
          routeId: 'req-123',
          queryDeliveryId: 'delivery-offer-9',
        ),
        'delivery-offer-9',
      );
    });

    test('falls back to the path id when no query deliveryId', () {
      expect(
        resolveTrackingDeliveryId(routeId: 'delivery-7', queryDeliveryId: null),
        'delivery-7',
      );
      expect(
        resolveTrackingDeliveryId(routeId: 'delivery-7', queryDeliveryId: ''),
        'delivery-7',
      );
    });

    test('empty/null route id resolves to empty (screen defends it)', () {
      expect(resolveTrackingDeliveryId(routeId: null, queryDeliveryId: null),
          '');
    });
  });

  group('In-Progress "Track my order" CTA — delivery id, not request id', () {
    testWidgets(
        'navigates with the SERVER delivery id (delivery-<offerId>) when the '
        'card carries one — the request id is NOT used as the tracking id',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          inProgress: [
            _activeRequest(id: 'req-abc', deliveryId: 'delivery-offer-42'),
          ],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_app(_router(repo)));
      await tester.pumpAndSettle();

      // CTA key is coined on the REQUEST id (the card's id).
      await tester.tap(find.byKey(const Key('active-track-order-req-abc')));
      await tester.pumpAndSettle();

      // The tracking surface resolved the SERVER delivery id — proving the CTA
      expect(find.text('tracking:delivery-offer-42'), findsOneWidget);
      expect(find.text('tracking:req-abc'), findsNothing);
    });

    testWidgets(
        'falls back to the request id only when no delivery id is available '
        '(documented backend-gap path)', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          inProgress: [_activeRequest(id: 'order-xyz')],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_app(_router(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('active-track-order-order-xyz')));
      await tester.pumpAndSettle();

      expect(find.text('tracking:order-xyz'), findsOneWidget);
    });
  });
}
