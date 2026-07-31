import 'package:equatable/equatable.dart';

import '../domain/gps_sample.dart';
import '../domain/location_permission.dart';

/// High-level phase the screen layer renders off.
enum BackgroundGpsPhase {
  /// Cubit was constructed but `start` hasn't been called yet, or the
  /// active delivery just ended and we tore everything down.
  idle,

  /// Waiting for the OS prompt to come back.
  requestingPermission,

  /// User refused (or revoked) Always-on access. UI shows the inline
  /// "open system settings" hint.
  permissionDenied,

  /// Stream is live and samples are being filtered + uploaded.
  tracking,

  /// Upload loop tripped the consecutive-failure budget and stopped.
  /// The auto-offline banner picks this up via the role-eligibility flow.
  error,
}

/// Why an upload was skipped — used by tests to assert filter behaviour
/// without inspecting log lines. The state only ever holds the *most
/// recent* skip reason; consumers don't need a history.
enum GpsSampleSkipReason {
  /// Accuracy worse than [BackgroundGpsConfig.maxAccuracyMeters].
  accuracyTooLow,

  /// Sample arrived before [BackgroundGpsConfig.activeInterval] or
  /// [stationaryInterval] elapsed since the last upload.
  throttled,
}

class BackgroundGpsState extends Equatable {
  const BackgroundGpsState({
    this.phase = BackgroundGpsPhase.idle,
    this.permission = LocationPermission.notDetermined,
    this.deliveryId,
    this.lastUploaded,
    this.lastUploadAt,
    this.lastSkipReason,
    this.stationary = false,
    this.consecutiveFailures = 0,
    this.uploadedCount = 0,
    this.discardedCount = 0,
  });

  final BackgroundGpsPhase phase;

  /// The LAST permission the OS reported, kept so
  /// [BackgroundGpsPhase.permissionDenied] is not an opaque dead end. The UI
  /// needs the distinction: [LocationPermission.whileInUse] means the jeeber
  /// still has an in-app upgrade path ("Allow all the time"), while
  /// [LocationPermission.deniedForever] means only the OS settings page can
  /// help. Also stamped onto the `bg_gps_phase` `[jeeb-diag]` breadcrumb, so a
  /// logcat grep says WHICH permission blocked the upload rather than just
  /// "denied".
  final LocationPermission permission;

  /// Active delivery being tracked. `null` outside [BackgroundGpsPhase.tracking].
  final String? deliveryId;

  /// Most recent sample that passed the filter and was POSTed. Drives
  /// the "last known" marker the QA hooks read in dev builds.
  final GpsSample? lastUploaded;

  /// Wall-clock time of the last successful upload, used by the throttle
  /// to decide whether to keep or drop the next sample.
  final DateTime? lastUploadAt;

  /// Reason the most recent sample was dropped, or `null` if the last
  /// sample was uploaded.
  final GpsSampleSkipReason? lastSkipReason;

  /// `true` once the rolling speed falls below
  /// [BackgroundGpsConfig.stationaryThresholdMps]; flips the cadence to
  /// the stationary interval. Surfaced to the UI as a subtle status pill.
  final bool stationary;

  /// Streak of consecutive transient upload failures. Reset to 0 on the
  /// first success.
  final int consecutiveFailures;

  /// Lifetime counter of accepted uploads, for the QA overlay + tests.
  final int uploadedCount;

  /// Lifetime counter of samples discarded by accuracy/throttle. Same
  /// audience as [uploadedCount].
  final int discardedCount;

  /// True when the uploader is PARKED on a missing background-location grant —
  /// the customer's live-tracking map is receiving nothing and only the jeeber
  /// can fix it. This is the whole trigger for the Active Delivery banner: for
  /// months this state existed with no UI and no log line, so a jeeber drove an
  /// entire delivery while the map stayed empty and nothing anywhere said so.
  bool get isBlockedOnPermission =>
      phase == BackgroundGpsPhase.permissionDenied;

  /// True when re-prompting in-app is pointless and the jeeber must be sent to
  /// the OS settings page — either a permanent denial, or the Android 11+
  /// "Allow all the time" upgrade, which the platform only exposes there.
  bool get needsSystemSettings =>
      permission == LocationPermission.deniedForever ||
      permission == LocationPermission.whileInUse;

  BackgroundGpsState copyWith({
    BackgroundGpsPhase? phase,
    LocationPermission? permission,
    Object? deliveryId = _sentinel,
    Object? lastUploaded = _sentinel,
    Object? lastUploadAt = _sentinel,
    Object? lastSkipReason = _sentinel,
    bool? stationary,
    int? consecutiveFailures,
    int? uploadedCount,
    int? discardedCount,
  }) {
    return BackgroundGpsState(
      phase: phase ?? this.phase,
      permission: permission ?? this.permission,
      deliveryId: identical(deliveryId, _sentinel)
          ? this.deliveryId
          : deliveryId as String?,
      lastUploaded: identical(lastUploaded, _sentinel)
          ? this.lastUploaded
          : lastUploaded as GpsSample?,
      lastUploadAt: identical(lastUploadAt, _sentinel)
          ? this.lastUploadAt
          : lastUploadAt as DateTime?,
      lastSkipReason: identical(lastSkipReason, _sentinel)
          ? this.lastSkipReason
          : lastSkipReason as GpsSampleSkipReason?,
      stationary: stationary ?? this.stationary,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      uploadedCount: uploadedCount ?? this.uploadedCount,
      discardedCount: discardedCount ?? this.discardedCount,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        permission,
        deliveryId,
        lastUploaded,
        lastUploadAt,
        lastSkipReason,
        stationary,
        consecutiveFailures,
        uploadedCount,
        discardedCount,
      ];
}

const Object _sentinel = Object();
