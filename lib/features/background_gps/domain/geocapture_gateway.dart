import 'gps_sample.dart';
import 'location_permission.dart';

/// Wraps the `geocapture-flutter` package so the cubit (and tests) don't
/// reach for plugin code directly. Per JEEB-BOUNDARIES §F9, all GPS access
/// goes through this gateway — hand-rolled `Geolocator`/`location` calls
/// are PR-blocking.
///
/// Concrete implementations:
///   * `GeocaptureFlutterGateway` — production shim over the
///     `geocapture-flutter` plugin. Lives behind DI so it's swapped at
///     bootstrap time, never imported by the cubit.
///   * `FakeGeocaptureGateway` — used by widget/unit tests to script
///     permission decisions and sample streams without spinning up the
///     platform channel.
abstract class GeocaptureGateway {
  /// Current permission as reported by the OS. Read once on cubit start
  /// and re-read after every prompt.
  Future<LocationPermission> currentPermission();

  /// Triggers the system prompt. Returns whatever permission the user
  /// granted (potentially still [LocationPermission.denied] if they
  /// dismissed it).
  Future<LocationPermission> requestAlwaysPermission();

  /// Broadcast stream of fixes. The gateway is responsible for asking the
  /// plugin for the right desired accuracy + distance filter; the cubit
  /// only throttles by *time* and drops by *accuracy*. The stream MUST be
  /// idempotent across multiple `listen`s within the cubit's lifecycle —
  /// the production shim wraps the plugin stream with a `BroadcastStream`.
  Stream<GpsSample> samples();

  /// Stops the underlying plugin from collecting fixes. Cubit calls this
  /// on every transition out of the active-delivery phase so the foreground
  /// service / background task is torn down promptly.
  Future<void> stop();
}
