import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_location_pin.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_map_viewport.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/map_capture_controller.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

void main() {
  // T-MOB-012: the route injects a live GoogleMap via `mapBuilder`. These
  testWidgets('renders the injected map builder instead of the placeholder',
      (tester) async {
    const injected = Key('injected-map-sentinel');
    await tester.pumpWidget(
      wrapForTest(
        CaptureLocationScreen(
          mapBuilder: (_) => const ColoredBox(
            key: injected,
            color: Color(0xFF00FF00),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(injected), findsOneWidget);
    // The placeholder must NOT be rendered when a builder is injected.
    expect(find.byType(CaptureMapViewport), findsNothing);
    // The fixed centre pin overlay is always present.
    expect(find.byType(CaptureLocationPin), findsOneWidget);
  });

  testWidgets('falls back to the placeholder when no map builder is injected',
      (tester) async {
    await tester.pumpWidget(wrapForTest(const CaptureLocationScreen()));
    await tester.pump();

    expect(find.byType(CaptureMapViewport), findsOneWidget);
    expect(find.byType(CaptureLocationPin), findsOneWidget);
  });

  testWidgets('Confirm drop-off CTA fires onPinned (the route returns the centre)',
      (tester) async {
    var pinned = 0;
    await tester.pumpWidget(
      wrapForTest(
        CaptureLocationScreen(
          mapBuilder: (_) => const SizedBox.expand(),
          onPinned: () => pinned++,
        ),
      ),
    );
    await tester.pump();

    final cta = find.text('Confirm drop-off');
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pump();

    expect(pinned, 1);
  });

  group('CaptureLocationRoute — the pre-idle tap race (JEBV4-176 class)', () {
    // Exercises the real CaptureLocationRoute (app_router.dart), not just the
    // standalone CaptureLocationScreen: `mapBuilderOverride` replaces only the
    // live GoogleMap widget, so the ready-gate + onPinned wiring under test is
    // the production code, driven via the same `markReady` callback
    // `onCameraIdle` would call.
    late MapCaptureController controller;
    Object? popped;
    var poppedCount = 0;

    GoRouter buildRouter() {
      popped = null;
      poppedCount = 0;
      return GoRouter(
        initialLocation: '/from',
        routes: [
          GoRoute(
            path: '/from',
            name: 'from',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result =
                      await context.pushNamed<Object?>('capture-location');
                  popped = result;
                  poppedCount++;
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
          GoRoute(
            path: '/capture-location',
            name: 'capture-location',
            builder: (context, state) => CaptureLocationRoute(
              mapBuilderOverride: (c) {
                controller = c;
                return const SizedBox.expand();
              },
            ),
          ),
        ],
      );
    }

    Future<void> pump(WidgetTester tester) async {
      final router = buildRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
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
      await tester.pump();
      await tester.tap(find.text('OPEN'));
      // MIDNIGHT R11: the capture route's centre pin breathes forever, so this
      // surface never settles — advance it by hand (matches the B35 pattern).
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets(
      'a tap before onCameraIdle cannot silently no-op the pop: the CTA is '
      'disabled and no pop happens',
      (tester) async {
        await pump(tester);

        final cta = tester.widget<OmdsPrimaryButton>(
          find.byType(OmdsPrimaryButton),
        );
        expect(cta.isEnabled, isFalse);

        await tester.tap(
          find.bySemanticsIdentifier('capture_location_pin_cta'),
        );
        await tester.pump();

        expect(poppedCount, 0);
        expect(find.byType(CaptureLocationScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a tap after onCameraIdle (markReady) returns the real pinned '
      'coordinate',
      (tester) async {
        await pump(tester);

        // Simulate the real map's onCameraIdle.
        controller.markReady();
        await tester.pump();

        final cta = tester.widget<OmdsPrimaryButton>(
          find.byType(OmdsPrimaryButton),
        );
        expect(cta.isEnabled, isTrue);

        await tester.tap(
          find.bySemanticsIdentifier('capture_location_pin_cta'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(poppedCount, 1);
        expect(popped, isA<LocationPoint>());
        expect(popped, CaptureLocationRoute.initialCentre);
      },
    );
  });
}
