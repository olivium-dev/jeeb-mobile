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
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

void main() {
  testWidgets(
    'a throwing reverse geocoder leaves the pin confirmable and submission '
    'uses raw coordinates with the existing fallback label',
    (tester) async {
      await sl.reset();
      addTearDown(sl.reset);

      final reverseGeocoder = _ThrowingReverseGeocoder();
      sl.registerLazySingleton<ReverseGeocoder>(() => reverseGeocoder);

      final locationCubit = LocationSelectCubit(
        repository: const FakeLocationSelectRepository(),
        userId: 'customer-1',
      );
      addTearDown(locationCubit.close);
      await locationCubit.load();

      final submission = FakeRequestSubmissionService(requestId: 'req-pin');
      final compose = ComposeRequestController(submission);
      late MapCaptureController mapController;
      LocationPoint? returnedPoint;
      String? submittedId;

      final router = GoRouter(
        initialLocation: '/from',
        routes: <RouteBase>[
          GoRoute(
            path: '/from',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final point = await context.pushNamed<LocationPoint?>(
                    'capture-location',
                  );
                  if (point == null) return;
                  returnedPoint = point;
                  locationCubit.markPinned(
                    latitude: point.latitude,
                    longitude: point.longitude,
                    address: point.address,
                  );
                  submittedId = await compose.submitFromLocation(
                    locationCubit.state,
                  );
                },
                child: const Text('OPEN MAP'),
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

      await tester.pumpWidget(_harness(router));
      await tester.tap(find.text('OPEN MAP'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      const pinned = LocationPoint(latitude: 33.9123, longitude: 35.5234);
      mapController.updateCenter(pinned);
      mapController.markReady();
      await tester.pump();
      await tester.pump();

      expect(reverseGeocoder.callCount, 1);
      expect(find.text('33.9123, 35.5234'), findsOneWidget);
      final captureCta = tester.widget<OmdsPrimaryButton>(
        find.byType(OmdsPrimaryButton),
      );
      expect(captureCta.isEnabled, isTrue);

      await tester.tap(find.bySemanticsIdentifier('capture_location_pin_cta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(returnedPoint, pinned);
      expect(locationCubit.state.canConfirm, isTrue);
      expect(submittedId, 'req-pin');
      expect(submission.submitCount, 1);
      expect(submission.lastDraft?.pickupLat, pinned.latitude);
      expect(submission.lastDraft?.pickupLng, pinned.longitude);
      expect(submission.lastDraft?.dropoffLat, pinned.latitude);
      expect(submission.lastDraft?.dropoffLng, pinned.longitude);
      expect(
        submission.lastDraft?.pickupAddress,
        'Current location (33.9123, 35.5234)',
      );
      expect(
        submission.lastDraft?.dropoffAddress,
        'Current location (33.9123, 35.5234)',
      );
    },
  );
}

Widget _harness(GoRouter router) => MaterialApp.router(
  routerConfig: router,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
);

class _ThrowingReverseGeocoder implements ReverseGeocoder {
  int callCount = 0;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    callCount++;
    throw StateError('platform channel failed');
  }
}
