import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

void main() {
  /// `RequestTypeScreen`/`setPickupPoint` is production-unreachable behind the
  /// redirect-only route but retained for the devtool catalog. Pin this hand-off
  /// so re-wiring or session-reset refactors cannot silently revive JEBV4-176's
  /// "picked pin was dropped" bug class through this seam.
  testWidgets('the Change picker point survives Continue in the compose seam', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await sl.reset();
    addTearDown(sl.reset);
    sl.registerLazySingleton<RequestSubmissionService>(
      FakeRequestSubmissionService.new,
    );
    sl.registerLazySingleton<ComposeRequestController>(
      () => ComposeRequestController(sl<RequestSubmissionService>()),
    );

    const picked = LocationPoint(
      latitude: 33.9001,
      longitude: 35.5002,
      address: 'Rue Monot, Achrafieh',
    );
    final router = GoRouter(
      initialLocation: '/request-type',
      routes: <RouteBase>[
        GoRoute(
          path: '/request-type',
          builder: (context, state) =>
              const RequestTypeScreen(repository: FakeTierRepository()),
        ),
        GoRoute(
          path: '/capture-location',
          name: 'capture-location',
          builder: (context, state) => Scaffold(
            body: TextButton(
              key: const Key('return-picked-point'),
              onPressed: () => context.pop(picked),
              child: const Text('PICK POINT'),
            ),
          ),
        ),
        GoRoute(
          path: '/client-location',
          name: 'client-location',
          builder: (context, state) =>
              const Scaffold(body: Text('CLIENT LOCATION')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    final change = find.bySemanticsIdentifier(
      'request_type_change_location_button',
    );
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('return-picked-point')));
    await tester.pumpAndSettle();

    expect(sl<ComposeRequestController>().pickupPoint, isNull);
    await tester.tap(find.bySemanticsIdentifier('request_type_continue_cta'));
    await tester.pumpAndSettle();

    expect(find.text('CLIENT LOCATION'), findsOneWidget);
    expect(sl<ComposeRequestController>().pickupPoint, picked);
  });
}

Widget _harness(GoRouter router) => MaterialApp.router(
  theme: AppTheme.midnight(),
  routerConfig: router,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
);
