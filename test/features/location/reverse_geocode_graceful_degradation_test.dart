import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/location/application/location_select_cubit.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/domain/reverse_geocoder.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/map_capture_controller.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

typedef _Lookup = Future<String?> Function(double latitude, double longitude);

class _FakeReverseGeocoder implements ReverseGeocoder {
  _FakeReverseGeocoder(this.lookup);

  final _Lookup lookup;
  int calls = 0;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    calls++;
    return lookup(latitude, longitude);
  }
}

const _tier = Tier(
  id: TierId.standard,
  serverId: 'tier-standard',
  priceLow: 1000,
  priceHigh: 2000,
  currency: 'USD',
  vehicleClass: TierVehicleClass.bikeOrScooter,
);

void main() {
  setUp(() async {
    await sl.reset();
  });

  tearDown(() async {
    await sl.reset();
  });

  test(
    'camera moves do not look up addresses and stale results cannot win',
    () async {
      final completions = <Completer<String?>>[];
      final geocoder = _FakeReverseGeocoder((_, _) {
        final completion = Completer<String?>();
        completions.add(completion);
        return completion.future;
      });
      final controller = MapCaptureController(
        initial: const LocationPoint(latitude: 33.8, longitude: 35.4),
        reverseGeocoder: geocoder,
      );
      addTearDown(controller.dispose);

      controller.updateCenter(
        const LocationPoint(latitude: 33.9012, longitude: 35.6033),
      );
      controller.updateCenter(
        const LocationPoint(latitude: 33.9013, longitude: 35.6034),
      );
      expect(geocoder.calls, 0, reason: 'camera moves must not call the OS');

      controller.markReady();
      expect(geocoder.calls, 1);

      controller.updateCenter(
        const LocationPoint(latitude: 33.9020, longitude: 35.6040),
      );
      controller.markReady();
      expect(geocoder.calls, 2);

      completions.first.complete('Stale address');
      await Future<void>.delayed(Duration.zero);
      expect(controller.center.address, isNull);

      completions.last.complete('Latest address');
      await Future<void>.delayed(Duration.zero);
      expect(controller.center.address, 'Latest address');
      expect(controller.center.latitude, 33.9020);
      expect(controller.center.longitude, 35.6040);
    },
  );

  testWidgets(
    'a throwing reverse geocoder never blocks pin confirmation or raw-coordinate submission',
    (tester) async {
      final geocoder = _FakeReverseGeocoder(
        (_, _) async => throw StateError('OS geocoder unavailable'),
      );
      sl.registerSingleton<ReverseGeocoder>(geocoder);

      late MapCaptureController mapController;
      LocationPoint? popped;
      final router = GoRouter(
        initialLocation: '/from',
        routes: [
          GoRoute(
            path: '/from',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await context.pushNamed<LocationPoint>(
                    'capture-location',
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
          GoRoute(
            path: '/capture-location',
            name: 'capture-location',
            builder: (context, state) => CaptureLocationRoute(
              mapBuilderOverride: (controller) {
                mapController = controller;
                return const SizedBox.expand();
              },
            ),
          ),
        ],
      );
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
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      const pin = LocationPoint(latitude: 33.9012, longitude: 35.6033);
      mapController.updateCenter(pin);
      mapController.markReady();
      await tester.pump();

      expect(geocoder.calls, 1);
      expect(mapController.isReady, isTrue);
      expect(mapController.center.address, isNull);
      final cta = tester.widget<OmdsPrimaryButton>(
        find.byType(OmdsPrimaryButton),
      );
      expect(cta.isEnabled, isTrue);

      await tester.tap(find.bySemanticsIdentifier('capture_location_pin_cta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(popped, pin);
      final location = LocationSelectCubit(
        repository: const FakeLocationSelectRepository(),
        userId: 'customer-1',
      );
      addTearDown(location.close);
      location.markPinned(
        latitude: popped!.latitude,
        longitude: popped!.longitude,
        address: popped!.address,
      );

      final submission = FakeRequestSubmissionService(requestId: 'req-1');
      final compose = ComposeRequestController(submission)..setTier(_tier);
      final requestId = await compose.submitFromLocation(
        location.state,
        defaultDescription: 'Delivery request',
        currentLocationLabel: 'Current location',
      );

      expect(requestId, 'req-1');
      expect(submission.submitCount, 1);
      final draft = submission.lastDraft!;
      expect(draft.pickupLat, 33.9012);
      expect(draft.pickupLng, 35.6033);
      expect(draft.dropoffLat, 33.9012);
      expect(draft.dropoffLng, 35.6033);
      // RSUM-04: localized label, coordinates carried structurally above.
      expect(draft.pickupAddress, 'Current location');
      expect(draft.dropoffAddress, 'Current location');
    },
  );
}
