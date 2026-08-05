import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import 'package:geolocator/geolocator.dart' as geo;

import '../domain/geocapture_gateway.dart';
import '../domain/gps_sample.dart';
import '../domain/location_permission.dart' as domain;

/// Production [GeocaptureGateway] shim over `geolocator` plugin.
class GeolocatorGeocaptureGateway implements GeocaptureGateway {
  GeolocatorGeocaptureGateway({
    geo.LocationSettings? locationSettings,
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform,
       _locationSettings =
           locationSettings ??
           defaultSettings(platform ?? defaultTargetPlatform);

  /// Minimum distance in metres before OS emits new fix; stationary courier produces nothing.
  static const distanceFilterMeters = 10;

  /// Android requires foregroundNotificationConfig to avoid background throttling (API 26+).
  /// Keeps uploader alive across screens by exempting stream from background throttling.
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
      // Wake lock prevents device sleep burst-delivery; WAKE_LOCK already declared.
      foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
        notificationTitle: _notificationTitle,
        notificationText: _notificationText,
        notificationChannelName: _notificationChannelName,
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  /// Not localized: consumed by Android platform channel synchronously before widget tree is up.
  static const _notificationTitle = 'Delivery in progress';
  static const _notificationText =
      'Sharing your location with the customer until you complete this '
      'delivery.';
  static const _notificationChannelName = 'Live delivery location';

  final geo.LocationSettings _locationSettings;
  final TargetPlatform _platform;

  @override
  bool get supportsBackgroundTrackingWithWhileInUse {
    final settings = _locationSettings;
    return _platform == TargetPlatform.android &&
        settings is geo.AndroidSettings &&
        settings.foregroundNotificationConfig != null;
  }

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
    // ignore: close_sinks
    final controller = StreamController<GpsSample>.broadcast(
      onCancel: () => _subscription?.cancel(),
    );
    _controller = controller;
    _subscription =
        geo.Geolocator.getPositionStream(
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

  /// Current fix for "centre on my location" affordance; not on the streaming port.
  Future<GpsSample> currentFix() async {
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: _locationSettings,
    );
    return _toSample(position);
  }

  /// OS-level GPS toggle status; distinct from app permission (routes to different recovery UI).
  Future<bool> isLocationServiceEnabled() =>
      geo.Geolocator.isLocationServiceEnabled();

  /// Opens OS location-services settings page.
  Future<bool> openLocationSettings() => geo.Geolocator.openLocationSettings();

  /// Opens app's OS settings page for location permission upgrade.
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
      // Keep distinct from denied: OS won't prompt again, only settings page helps.
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
