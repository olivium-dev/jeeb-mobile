import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/courier_position_channel.dart';
import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';

enum LiveTrackingViewMode { loading, ready, error }

enum LiveTrackingEvent {
  none,
  jeeberOnTheWay,
  jeeberAtDoor,

  deliveredAutoAdvance,
}

class LiveTrackingState extends Equatable {
  const LiveTrackingState({
    this.mode = LiveTrackingViewMode.loading,
    this.trackingInfo,
    this.failure,
    this.errorKind,
    this.refreshError,
    this.lastSuccessAt,
    this.streamUnavailable = false,
    this.streamFailure,
    this.pendingEvent = LiveTrackingEvent.none,
    this.handoverCode,
  });

  final LiveTrackingViewMode mode;
  final DeliveryTrackingInfo? trackingInfo;

  /// The cold-load failure the copy family renders.
  final AppFailure? failure;

  final LiveTrackingErrorKind? errorKind;

  /// A warm refresh failed while rows are on screen: a note, not a rung.
  final AppFailure? refreshError;

  final DateTime? lastSuccessAt;

  /// The live-position socket could not be opened.
  final bool streamUnavailable;

  final CourierPositionOpenFailure? streamFailure;

  final LiveTrackingEvent pendingEvent;

  final String? handoverCode;

  bool get isAtDoor =>
      trackingInfo?.currentStage == TrackingStage.atDoor;

  LiveTrackingState copyWith({
    LiveTrackingViewMode? mode,
    DeliveryTrackingInfo? trackingInfo,
    AppFailure? failure,
    LiveTrackingErrorKind? errorKind,
    bool clearError = false,
    AppFailure? refreshError,
    bool clearRefreshError = false,
    DateTime? lastSuccessAt,
    bool? streamUnavailable,
    CourierPositionOpenFailure? streamFailure,
    LiveTrackingEvent? pendingEvent,
    String? handoverCode,
  }) {
    return LiveTrackingState(
      mode: mode ?? this.mode,
      trackingInfo: trackingInfo ?? this.trackingInfo,
      failure: clearError ? null : (failure ?? this.failure),
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      refreshError:
          clearRefreshError ? null : (refreshError ?? this.refreshError),
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      streamUnavailable: streamUnavailable ?? this.streamUnavailable,
      streamFailure: (streamUnavailable ?? this.streamUnavailable)
          ? (streamFailure ?? this.streamFailure)
          : null,
      pendingEvent: pendingEvent ?? LiveTrackingEvent.none,
      handoverCode: handoverCode ?? this.handoverCode,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        trackingInfo,
        failure,
        errorKind,
        refreshError,
        lastSuccessAt,
        streamUnavailable,
        streamFailure,
        pendingEvent,
        handoverCode,
      ];
}
