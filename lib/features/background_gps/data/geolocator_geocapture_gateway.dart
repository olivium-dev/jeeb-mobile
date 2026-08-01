import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import 'package:geolocator/geolocator.dart' as geo;

import '../domain/geocapture_gateway.dart';
import '../domain/gps_sample.dart';
import '../domain/location_permission.dart' as domain;

/// Production [GeocaptureGateway] shim over the `geolocator` plugin
/// (T-MOB-012 / T-MOB-017). It is the device-backed drop-in behind the same
/// port [FakeGeocaptureGateway] implements, so the cubit, picker, and tests
/// never import `geolocator` directly — `dart analyze` stays green without a
/// Maps key and the Fakes remain the unit-test seam.
///
/// Permission mapping (`geolocator` → domain):
///   * denied             → [domain.LocationPermission.denied]
///   * deniedForever      → [domain.LocationPermission.deniedForever]
///   * whileInUse         → [domain.LocationPermission.whileInUse]
///   * always             → [domain.LocationPermission.always]
///   * unableToDetermine  → [domain.LocationPermission.notDetermined]
///
/// ## Why the two request methods are the SAME geolocator call
///
/// `geolocator` exposes exactly one entry point — `Geolocator.requestPermission()`
/// — and decides INTERNALLY which Android permissions go into the request array
/// by reading the CURRENT status first (`geolocator_android-5.0.3`
/// `PermissionManager.java:104-111`):
///
/// ```java
/// if (SDK_INT >= Q && hasPermissionInManifest(ACCESS_BACKGROUND_LOCATION)) {
///   if (checkPermissionStatus(activity) == whileInUse) {
///     permissionsToRequest.add(ACCESS_BACKGROUND_LOCATION);
///   }
/// }
/// ```
///
/// So the SEQUENCE is what makes the flow incremental, not the arguments:
///   * called while the status is `denied`/`notDetermined` → requests
///     FINE + COARSE only (the foreground step), and
///   * called again once the status is `whileInUse` → adds
///     `ACCESS_BACKGROUND_LOCATION` (the escalation step).
///
/// [requestWhileInUsePermission] and [requestAlwaysPermission] are therefore
/// two named positions in that sequence rather than two different plugin calls.
/// Keeping them distinct on the port is deliberate: it is what stops a future
/// caller from "simplifying" the cubit back into a single request, which is the
/// exact shape Android 11+ ignores outright.
///
/// **`ACCESS_BACKGROUND_LOCATION` must stay declared in `AndroidManifest.xml`**
/// — both branches above are gated on `hasPermissionInManifest`, so without it
/// `checkPermission()` can never return `always` (`PermissionManager.java:71-76`)
/// and the whole upload pipeline parks silently.
///
/// The stream is wrapped as a broadcast so the cubit can `listen` more than once
/// per lifecycle (the port contract requires idempotent listens).
class GeolocatorGeocaptureGateway implements GeocaptureGateway {
  GeolocatorGeocaptureGateway({
    geo.LocationSettings? locationSettings,
    TargetPlatform? platform,
  }) : _locationSettings =
            locationSettings ?? defaultSettings(platform ?? defaultTargetPlatform);

  /// Minimum distance, in metres, a jeeber must move before the OS emits a new
  /// fix. A stationary courier legitimately produces NOTHING — do not read an
  /// empty upload log as "the pipeline is dead" without first checking they
  /// actually moved.
  static const distanceFilterMeters = 10;

  /// The production location settings.
  ///
  /// ## P1, 2026-08-01 — why Android gets a foreground service
  ///
  /// Keeping the uploader alive across screens (the `BackgroundGpsCubit`
  /// singleton) fixes only the Dart half of "the courier stopped reporting".
  /// The OS half is this: a plain `getPositionStream` belongs to the activity,
  /// and once the app is no longer visible Android applies background location
  /// throttling (API 26+, tightened every release since) — the app is handed a
  /// couple of fixes an HOUR instead of one per 10 m. The cubit stays in
  /// `phase:"tracking"` the whole time, so the failure is invisible from the
  /// `bg_gps_phase` breadcrumb: it looks alive and reports nothing.
  ///
  /// `AndroidSettings.foregroundNotificationConfig` is geolocator's supported
  /// answer. Supplying it makes the plugin run its own
  /// `GeolocatorLocationService` in the foreground
  /// (`geolocator_android-5.0.3` declares it with
  /// `android:foregroundServiceType="location"`), which exempts the stream from
  /// background throttling and shows the jeeber a persistent notification — the
  /// honest disclosure that their location is being shared, which is exactly
  /// what we want a courier app to display.
  ///
  /// **What this does NOT buy** (geolocator documents this on the field, and it
  /// is the honest answer to "what if the app is killed outright"): the
  /// foreground service raises the process's priority, it does not resurrect
  /// it. If the jeeber force-stops the app, or Android kills the process under
  /// memory pressure, the stream dies with it and NOTHING re-arms it until the
  /// app is reopened and the active-delivery flow re-mounts. Surviving process
  /// death needs a background isolate (`flutter_background_service` or
  /// equivalent) that is not tied to the main engine — a separate change, not
  /// smuggled in here.
  ///
  /// iOS keeps the plain settings: `UIBackgroundModes: location` plus the
  /// `always` authorization already grant continuous background delivery there,
  /// with no service object to configure.
  @visibleForTesting
  static geo.LocationSettings defaultSettings(TargetPlatform platform) {
    if (platform != TargetPlatform.android) {
      return const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      );
    }
    return geo.AndroidSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
      // Without a wake lock the device sleeps and the OS delivers the whole
      // backlog at once when it next wakes — a customer map that jumps in
      // bursts instead of gliding. WAKE_LOCK is already declared.
      foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
        notificationTitle: _notificationTitle,
        notificationText: _notificationText,
        notificationChannelName: _notificationChannelName,
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  // Deliberately not routed through `AppLocalizations`: these strings are
  // consumed by the Android platform channel from `configureDependencies`,
  // which is synchronous, while this app's ARB layer loads from an asset
  // bundle asynchronously and needs a Locale that only exists once the widget
  // tree is up. The same trade-off is already taken for the push channel
  // (`firebase_messaging_transport.dart`'s `jeebDefaultChannel`). Localising
  // both together belongs in a bootstrap-locale change, not in a P1 fix.
  static const _notificationTitle = 'Delivery in progress';
  static const _notificationText =
      'Sharing your location with the customer until you complete this '
      'delivery.';
  static const _notificationChannelName = 'Live delivery location';

  final geo.LocationSettings _locationSettings;

  /// The settings this gateway actually hands geolocator. Exposed so the
  /// foreground-service guard can assert on the wiring rather than re-deriving
  /// it from [defaultSettings].
  @visibleForTesting
  geo.LocationSettings get locationSettings => _locationSettings;

  StreamSubscription<geo.Position>? _subscription;
  StreamController<GpsSample>? _controller;

  @override
  Future<domain.LocationPermission> currentPermission() async {
    final permission = await geo.Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<domain.LocationPermission> requestWhileInUsePermission() async {
    final permission = await geo.Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Future<domain.LocationPermission> requestAlwaysPermission() async {
    final permission = await geo.Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Stream<GpsSample> samples() {
    final existing = _controller;
    if (existing != null && !existing.isClosed) return existing.stream;
    // close_sinks can't trace the close across methods — the controller is
    // closed in stop() (and on the last listener cancel). Long-lived by design.
    // ignore: close_sinks
    final controller = StreamController<GpsSample>.broadcast(
      onCancel: () => _subscription?.cancel(),
    );
    _controller = controller;
    _subscription = geo.Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(
      (position) => controller.add(_toSample(position)),
      onError: controller.addError,
    );
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller?.close();
    _controller = null;
  }

  /// One-shot current fix for the "centre on my location" affordance. Not on
  /// the [GeocaptureGateway] port (that streams); the map picker calls it
  /// directly via the concrete adapter the DI container provides.
  Future<GpsSample> currentFix() async {
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: _locationSettings,
    );
    return _toSample(position);
  }

  /// Whether the device's location services (the OS-level GPS toggle) are on.
  /// A `false` here is distinct from a denied app permission: the recovery UI
  /// (JEBV4-176) routes it to the "turn on location services" affordance
  /// ([openLocationSettings]) rather than the app-permission one. Not on the
  /// streaming [GeocaptureGateway] port — the one-shot current-location
  /// resolver calls it directly via this concrete adapter.
  Future<bool> isLocationServiceEnabled() =>
      geo.Geolocator.isLocationServiceEnabled();

  /// Opens the OS location-services settings page (device GPS toggle). Used by
  /// the GPS-recovery UI's "open settings" CTA when location services are off.
  Future<bool> openLocationSettings() => geo.Geolocator.openLocationSettings();

  /// Opens this app's OS settings page so the user can grant the location
  /// permission after a permanent denial. Used by the GPS-recovery UI's
  /// "open settings" CTA when the app permission is denied, and by the
  /// Active Delivery screen's background-location banner (Android 11+ routes
  /// the "Allow all the time" upgrade through this page).
  @override
  Future<bool> openAppSettings() => geo.Geolocator.openAppSettings();

  GpsSample _toSample(geo.Position position) {
    final heading = position.heading;
    return GpsSample(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedMps: position.speed,
      headingDegrees: heading.isNaN ? 0 : heading,
      capturedAt: position.timestamp,
    );
  }

  domain.LocationPermission _mapPermission(geo.LocationPermission permission) {
    switch (permission) {
      case geo.LocationPermission.denied:
        return domain.LocationPermission.denied;
      // Kept DISTINCT from `denied` (it used to collapse into it): the OS will
      // not prompt again from here, so re-requesting is a silent no-op and the
      // only honest affordance is the settings page.
      case geo.LocationPermission.deniedForever:
        return domain.LocationPermission.deniedForever;
      case geo.LocationPermission.whileInUse:
        return domain.LocationPermission.whileInUse;
      case geo.LocationPermission.always:
        return domain.LocationPermission.always;
      case geo.LocationPermission.unableToDetermine:
        return domain.LocationPermission.notDetermined;
    }
  }
}
