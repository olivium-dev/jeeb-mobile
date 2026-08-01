// P0 — the jeeber GPS uploader was DEAD on Android 10+, and dead SILENTLY.
//
// Root cause (re-derived first-hand from `geolocator_android-5.0.3`, not from a
// prior report):
//
//   PermissionManager.java:71-76   checkPermissionStatus()
//     boolean wantsBackgroundLocation =
//         PermissionUtils.hasPermissionInManifest(
//             context, Manifest.permission.ACCESS_BACKGROUND_LOCATION);
//     if (!wantsBackgroundLocation) return LocationPermission.whileInUse;
//
//   PermissionManager.java:104-111 requestPermission()
//     if (SDK_INT >= Q && hasPermissionInManifest(ACCESS_BACKGROUND_LOCATION)) {
//       if (checkPermissionStatus(activity) == whileInUse) {
//         permissionsToRequest.add(ACCESS_BACKGROUND_LOCATION);
//       }
//     }
//
// Both gates read the MANIFEST. With only FINE + COARSE declared, geolocator
// could not return `always` on any API >= 29 no matter what the user tapped, so
// `BackgroundGpsCubit.start()` — which demands `always` — parked in
// `permissionDenied` on every delivery and `POST /location/update` was never
// called once. `adb shell pm grant … ACCESS_BACKGROUND_LOCATION` exits 0 and
// does nothing while the app does not declare it, which is why hand-testing
// never caught it.
//
// This suite pins BOTH halves of the fix:
//   §1 the manifest declaration (the cause), as an invariant;
//   §2 the Android 10+ INCREMENTAL runtime flow, including the denial and the
//      permanently-denied paths — a request that succeeds is not the interesting
//      case here;
//   §3 the `[jeeb-diag]` breadcrumb (the failure is now LOUD in logcat);
//   §4 the OMDS banner on the Active Delivery screen (the failure is now loud
//      to the jeeber, who is the only person who can fix it).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/widgets/gps_permission_banner.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_cubit.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_state.dart';
import 'package:jeeb_mobile/features/background_gps/data/fake_geocapture_gateway.dart';
import 'package:jeeb_mobile/features/background_gps/data/in_memory_location_uploader.dart';
import 'package:jeeb_mobile/features/background_gps/domain/gps_sample.dart';
import 'package:jeeb_mobile/features/background_gps/domain/location_permission.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _deliveryId = 'DLV-770001';
const _dropOff = DropOffAddress(label: 'Verdun', lat: 33.88, lng: 35.49);

/// A fix the accuracy filter REJECTS (default `maxAccuracyMeters` is 50), so it
/// changes cubit state without changing the phase.
GpsSample _lowAccuracySample() => GpsSample(
      latitude: 33.9,
      longitude: 35.51,
      accuracyMeters: 400,
      speedMps: 6,
      headingDegrees: 90,
      capturedAt: DateTime.utc(2026, 7, 31, 10),
    );

BackgroundGpsCubit _cubit(FakeGeocaptureGateway gateway) {
  final cubit = BackgroundGpsCubit(
    gateway: gateway,
    uploader: InMemoryLocationUploader(),
  );
  addTearDown(cubit.close);
  addTearDown(gateway.dispose);
  return cubit;
}

class _InertRepo implements ActiveDeliveryRepository {
  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async =>
      const JeeberDelivery(
        id: _deliveryId,
        status: JeeberDeliveryStatus.inTransit,
        dropOff: _dropOff,
      );

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async =>
      to;

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async =>
      JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async =>
      'object-ref';
}

Widget _host(ActiveDeliveryCubit cubit, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ActiveDeliveryJeeberScreen(
        deliveryId: _deliveryId,
        cubit: cubit,
        onOpenChat: () {},
      ),
    );

ActiveDeliveryCubit _screenCubit({BackgroundGpsCubit? gps}) =>
    ActiveDeliveryCubit(
      repository: _InertRepo(),
      deliveryId: _deliveryId,
      refreshSignals: const Stream<void>.empty(),
      gpsUploader: gps,
    )..emit(const ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: JeeberDelivery(
          id: _deliveryId,
          status: JeeberDeliveryStatus.inTransit,
          dropOff: _dropOff,
        ),
      ));

void main() {
  group('§1 manifest — the CAUSE', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('ACCESS_BACKGROUND_LOCATION is declared', () {
      expect(
        manifest.contains('android.permission.ACCESS_BACKGROUND_LOCATION'),
        isTrue,
        reason: 'geolocator gates BOTH checkPermission() and '
            'requestPermission() on hasPermissionInManifest(...BACKGROUND...). '
            'Without this line `always` is UNREACHABLE on API >= 29, '
            'BackgroundGpsCubit parks on every delivery, and the customer '
            'live-tracking map never receives a single fix.',
      );
    });

    test('the foreground permissions it escalates FROM are still declared', () {
      // getLocationPermissionsFromManifest (PermissionManager.java:209-219)
      // THROWS PermissionUndefinedException when neither is present — which
      // would break the one-shot pickup-location flow too, not just this one.
      expect(manifest.contains('android.permission.ACCESS_FINE_LOCATION'),
          isTrue);
      expect(manifest.contains('android.permission.ACCESS_COARSE_LOCATION'),
          isTrue);
    });

    // P1, 2026-08-01. `always` makes the permission REACHABLE; it does not keep
    // the stream alive once the app is no longer visible. A plain position
    // stream belongs to the activity, so Android's background-location
    // throttling (API 26+) starves it while the cubit still reports
    // `phase:"tracking"`. The gateway now asks geolocator for a foreground
    // service (`AndroidSettings.foregroundNotificationConfig`), and these two
    // permissions are what make that service legal to start.
    test('the foreground-service permissions backing background streaming are '
        'declared', () {
      expect(
        manifest.contains('android.permission.FOREGROUND_SERVICE'),
        isTrue,
        reason: 'startForeground() requires it from API 28.',
      );
      expect(
        manifest.contains('android.permission.FOREGROUND_SERVICE_LOCATION'),
        isTrue,
        reason: 'This app targets SDK 34, where a `location`-typed foreground '
            'service ALSO needs the typed permission — without it '
            'startForeground() throws SecurityException and the uploader dies '
            'the instant the jeeber backgrounds the app.',
      );
    });
  });

  group('§2 runtime flow — Android 10+ incremental escalation', () {
    test('a cold start asks for FOREGROUND first, then background — never '
        'both in one request', () async {
      // Android 11+ IGNORES a combined foreground+background request and
      // grants neither, so the order here is the whole fix.
      final gateway = FakeGeocaptureGateway(
        permissionScript: <LocationPermission>[
          LocationPermission.notDetermined, // currentPermission
          LocationPermission.whileInUse, // after the FOREGROUND request
          LocationPermission.always, // after the BACKGROUND escalation
        ],
      );
      final cubit = _cubit(gateway);

      await cubit.start(_deliveryId);

      expect(gateway.permissionCalls, ['current', 'whileInUse', 'always']);
      expect(gateway.whileInUseRequestCount, 1);
      expect(gateway.alwaysRequestCount, 1);
      expect(cubit.state.phase, BackgroundGpsPhase.tracking);
      expect(cubit.state.permission, LocationPermission.always);
    });

    test('an app that already holds whileInUse skips straight to the '
        'background escalation', () async {
      final gateway = FakeGeocaptureGateway(
        permissionScript: <LocationPermission>[
          LocationPermission.whileInUse,
          LocationPermission.always,
        ],
      );
      final cubit = _cubit(gateway);

      await cubit.start(_deliveryId);

      expect(gateway.permissionCalls, ['current', 'always']);
      expect(gateway.whileInUseRequestCount, 0,
          reason: 're-asking for a permission already held is user-hostile');
      expect(cubit.state.phase, BackgroundGpsPhase.tracking);
    });

    test('already `always` raises no prompt at all', () async {
      final gateway = FakeGeocaptureGateway(
        initialPermission: LocationPermission.always,
      );
      final cubit = _cubit(gateway);

      await cubit.start(_deliveryId);

      expect(gateway.requestCount, 0);
      expect(cubit.state.phase, BackgroundGpsPhase.tracking);
    });

    test('DENIAL PATH: the escalation coming back whileInUse parks the '
        'uploader — it does NOT start streaming', () async {
      // The Android 11+ FIRST-RUN outcome: the platform does not grant
      // "Allow all the time" from a dialog at all. Uploading on a whileInUse
      // grant is exactly the "pretend it worked" behaviour that produced a
      // customer map full of nothing.
      final gateway = FakeGeocaptureGateway(
        permissionScript: <LocationPermission>[
          LocationPermission.whileInUse, // current
          LocationPermission.whileInUse, // escalation refused/deferred
        ],
      );
      final cubit = _cubit(gateway);

      await cubit.start(_deliveryId);

      expect(cubit.state.phase, BackgroundGpsPhase.permissionDenied);
      expect(cubit.state.permission, LocationPermission.whileInUse);
      expect(cubit.state.needsSystemSettings, isTrue,
          reason: 'only the OS settings page exposes "Allow all the time"');
    });

    test('PERMANENTLY-DENIED PATH: deniedForever raises NO prompt — the OS '
        'would silently drop it — and routes to settings', () async {
      final gateway = FakeGeocaptureGateway(
        initialPermission: LocationPermission.deniedForever,
      );
      final cubit = _cubit(gateway);

      await cubit.start(_deliveryId);

      expect(gateway.requestCount, 0,
          reason: 'a request from deniedForever is a silent no-op; firing one '
              'anyway re-creates the original silent-failure defect');
      expect(cubit.state.phase, BackgroundGpsPhase.permissionDenied);
      expect(cubit.state.needsSystemSettings, isTrue);
    });

    test('plain denial parks without pretending, and stays retryable',
        () async {
      final gateway = FakeGeocaptureGateway(
        permissionScript: <LocationPermission>[
          LocationPermission.denied,
          LocationPermission.denied,
        ],
      );
      final cubit = _cubit(gateway);

      await cubit.start(_deliveryId);

      expect(gateway.whileInUseRequestCount, 1);
      expect(cubit.state.phase, BackgroundGpsPhase.permissionDenied);
      expect(cubit.state.needsSystemSettings, isFalse,
          reason: 'a plain denial can still be recovered by an in-app prompt');
    });

    test('retryPermission re-walks the escalation and recovers to tracking',
        () async {
      final gateway = FakeGeocaptureGateway(
        permissionScript: <LocationPermission>[
          LocationPermission.whileInUse, // current
          LocationPermission.whileInUse, // 1st attempt: user did not upgrade
          LocationPermission.whileInUse, // current, on the retry
          LocationPermission.always, // …and this time they did
        ],
      );
      final cubit = _cubit(gateway);
      await cubit.start(_deliveryId);
      expect(cubit.state.phase, BackgroundGpsPhase.permissionDenied);

      // The jeeber went to settings and chose "Allow all the time".
      await cubit.retryPermission();

      expect(cubit.state.phase, BackgroundGpsPhase.tracking);
      expect(cubit.state.permission, LocationPermission.always);
    });

    test('openSystemSettings reaches the gateway', () async {
      final gateway = FakeGeocaptureGateway();
      final cubit = _cubit(gateway);

      await expectLater(cubit.openSystemSettings(), completion(isTrue));
      expect(gateway.openAppSettingsCount, 1);
    });
  });

  group('§3 [jeeb-diag] breadcrumb — the failure is LOUD in logcat', () {
    late List<String> lines;

    setUp(() {
      lines = <String>[];
      Diag.enabledOverride = true;
      Diag.sink = lines.add;
    });
    tearDown(Diag.resetForTest);

    List<Map<String, Object?>> events(String name) => lines
        .where((l) => l.startsWith(Diag.prefix))
        .map((l) => jsonDecode(l.substring(Diag.prefix.length + 1))
            as Map<String, Object?>)
        .where((r) => r['name'] == name)
        .toList();

    test('a PARKED uploader emits a phase breadcrumb naming the blocking '
        'permission', () async {
      final gateway = FakeGeocaptureGateway(
        permissionScript: <LocationPermission>[
          LocationPermission.whileInUse,
          LocationPermission.whileInUse,
        ],
      );
      final cubit = _cubit(gateway);

      await cubit.start(_deliveryId);

      final phases = events('bg_gps_phase');
      final parked = phases.last['data']! as Map<String, Object?>;
      expect(parked['phase'], 'permissionDenied');
      expect(parked['permission'], 'whileInUse');
      expect(parked['deliveryId'], _deliveryId);

      // …and a `_failure`-suffixed record, which `Diag._isFailureRecord`
      // matches to flush the persistence buffer promptly.
      final failures = events('bg_gps_permission_failure');
      expect(failures, hasLength(1));
      expect(
        (failures.single['data']! as Map<String, Object?>)['permission'],
        'whileInUse',
      );
    });

    test('a HEALTHY uploader emits a distinguishable tracking breadcrumb and '
        'NO failure record', () async {
      final gateway = FakeGeocaptureGateway(
        initialPermission: LocationPermission.always,
      );
      final cubit = _cubit(gateway);

      await cubit.start(_deliveryId);

      final parkedOrTracking = events('bg_gps_phase')
          .map((r) => (r['data']! as Map<String, Object?>)['phase'])
          .toList();
      expect(parkedOrTracking, contains('tracking'));
      expect(events('bg_gps_permission_failure'), isEmpty);

      // The point of the whole breadcrumb: the two runs are TELLABLE APART
      // from logcat alone. Before this change both emitted nothing.
      expect(parkedOrTracking, isNot(contains('permissionDenied')));
    });

    test('per-fix skip/throttle churn does NOT emit phase breadcrumbs',
        () async {
      final gateway = FakeGeocaptureGateway(
        initialPermission: LocationPermission.always,
      );
      final cubit = _cubit(gateway);
      await cubit.start(_deliveryId);
      final before = events('bg_gps_phase').length;

      // Accuracy-rejected fixes change state but not phase.
      await gateway.emit(_lowAccuracySample());
      await gateway.emit(_lowAccuracySample());

      expect(events('bg_gps_phase').length, before,
          reason: 'a phase line must mean something actually moved, or the '
              'stream floods and stops being readable');
    });
  });

  group('§4 banner — the failure is LOUD to the jeeber', () {
    testWidgets('a parked uploader raises the banner on the Active Delivery '
        'screen', (tester) async {
      final cubit = _screenCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(GpsPermissionBanner.bannerKey), findsNothing,
          reason: 'no banner while nothing is wrong');

      cubit.emit(cubit.state.copyWith(
        gpsPhase: BackgroundGpsPhase.permissionDenied,
        gpsNeedsSystemSettings: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(GpsPermissionBanner.bannerKey), findsOneWidget);
      expect(find.text('Live tracking is off'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('a recoverable denial offers the in-app prompt instead of '
        'settings', (tester) async {
      final cubit = _screenCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      cubit.emit(cubit.state.copyWith(
        gpsPhase: BackgroundGpsPhase.permissionDenied,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Allow location'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);
      await cubit.close();
    });

    testWidgets('the CTA reaches the uploader — tapping it opens settings',
        (tester) async {
      final gateway = FakeGeocaptureGateway(
        initialPermission: LocationPermission.deniedForever,
      );
      final gps = BackgroundGpsCubit(
        gateway: gateway,
        uploader: InMemoryLocationUploader(),
      );
      final cubit = _screenCubit(gps: gps);
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      // The uploader parks on its OWN — nothing here forces the state, so this
      // exercises the real path: gateway → cubit → mirror → screen.
      // `runAsync` because the cubit's teardown/permission awaits resolve on
      // microtasks the fake-async test zone only drains while pumping.
      await tester.runAsync(() => gps.start(_deliveryId));
      await tester.pumpAndSettle();
      expect(find.byKey(GpsPermissionBanner.bannerKey), findsOneWidget,
          reason: 'the MIRROR must carry the park through to the screen');

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(gateway.openAppSettingsCount, 1);
      await tester.runAsync(cubit.close);
      await tester.runAsync(gateway.dispose);
    });

    testWidgets('the banner is localized (ar) — no English leaks through',
        (tester) async {
      final cubit = _screenCubit();
      await tester.pumpWidget(_host(cubit, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      cubit.emit(cubit.state.copyWith(
        gpsPhase: BackgroundGpsPhase.permissionDenied,
        gpsNeedsSystemSettings: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('التتبّع المباشر متوقّف'), findsOneWidget);
      expect(find.text('Live tracking is off'), findsNothing);
      await cubit.close();
    });
  });
}
