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

  /// STEP 1 of the Android 10+ (API 29+) incremental escalation: ask for the
  /// FOREGROUND ("while in use") location permission only.
  ///
  /// This step exists because the platform forbids the shortcut. From Android
  /// 11 (API 30) on, an app that requests a foreground location permission and
  /// `ACCESS_BACKGROUND_LOCATION` in the SAME call has the whole request
  /// ignored and is granted neither. So background access can only ever be
  /// reached in two separate prompts, in this order.
  ///
  /// Returns whatever the user granted — [LocationPermission.denied] if they
  /// dismissed it, [LocationPermission.deniedForever] if the OS will not prompt
  /// again.
  Future<LocationPermission> requestWhileInUsePermission();

  /// STEP 2: escalate an existing [LocationPermission.whileInUse] grant to
  /// background ("Allow all the time") access.
  ///
  /// MUST be called only after the foreground permission is held — see
  /// [requestWhileInUsePermission]. On Android 11+ this does not raise a plain
  /// dialog: the platform routes the user to the app's location settings page
  /// where they choose "Allow all the time". The caller therefore MUST NOT
  /// assume the returned value is [LocationPermission.always]; a
  /// [LocationPermission.whileInUse] result means "the user has not upgraded
  /// (yet)", not "an error occurred".
  Future<LocationPermission> requestAlwaysPermission();

  /// Opens this app's OS settings page so the user can grant background
  /// location after a permanent denial, or complete the Android 11+ "Allow all
  /// the time" upgrade by hand. Returns `false` when the page could not be
  /// opened. The caller re-reads [currentPermission] when the app resumes.
  Future<bool> openAppSettings();

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
