import 'package:equatable/equatable.dart';

import '../domain/gps_sample.dart';
import '../domain/location_permission.dart';

/// High-level phase the screen layer renders off.
enum BackgroundGpsPhase {
  /// Constructed but `start` not called, or active delivery ended.
  idle,

  /// Waiting for OS permission prompt to return.
  requestingPermission,

  /// User refused or revoked Always-on access; UI shows settings hint.
  permissionDenied,

  /// Stream is live and samples are being filtered + uploaded.
  tracking,

  /// Upload loop hit consecutive-failure budget and stopped.
  error,
}

/// Why a sample was skipped; state holds only the most recent skip reason.
enum GpsSampleSkipReason {
  /// Accuracy worse than BackgroundGpsConfig.maxAccuracyMeters.
  accuracyTooLow,

  /// Sample arrived before configured interval elapsed since last upload.
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

  /// Last permission OS reported; distinguishes whileInUse (app upgrade path) from deniedForever (settings only).
  final LocationPermission permission;

  /// Active delivery being tracked; null outside tracking phase.
  final String? deliveryId;

  /// Most recent sample that passed filter and was uploaded; drives "last known" marker for QA.
  final GpsSample? lastUploaded;

  /// Wall-clock time of last successful upload; used by throttle to drop next sample.
  final DateTime? lastUploadAt;

  /// Reason most recent sample was dropped, or null if last sample was uploaded.
  final GpsSampleSkipReason? lastSkipReason;

  /// True when rolling speed falls below stationaryThresholdMps; flips cadence to stationary interval.
  final bool stationary;

  /// Streak of consecutive transient upload failures; reset to 0 on first success.
  final int consecutiveFailures;

  /// Accepted uploads for THIS tracking session (`start` resets it).
  final int uploadedCount;

  /// Samples discarded by accuracy/throttle in this session.
  final int discardedCount;

  /// True when uploader is parked on missing background-location grant (customer's live-tracking map receives nothing).
  bool get isBlockedOnPermission =>
      phase == BackgroundGpsPhase.permissionDenied;

  /// True when a blocked uploader cannot recover from an in-app foreground
  /// permission prompt and must send the jeeber to OS settings.
  bool get needsSystemSettings =>
      phase == BackgroundGpsPhase.permissionDenied &&
      (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.whileInUse);

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
