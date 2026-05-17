import 'package:equatable/equatable.dart';

import '../domain/gps_sample.dart';

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

  BackgroundGpsState copyWith({
    BackgroundGpsPhase? phase,
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
