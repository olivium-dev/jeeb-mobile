import 'package:equatable/equatable.dart';

import '../domain/delivery_tracking_info.dart';

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
    this.errorMessage,
    this.errorTitle,
    this.pendingEvent = LiveTrackingEvent.none,
    this.handoverCode,
  });

  final LiveTrackingViewMode mode;
  final DeliveryTrackingInfo? trackingInfo;
  final String? errorMessage;

  final String? errorTitle;

  final LiveTrackingEvent pendingEvent;

  final String? handoverCode;

  bool get isAtDoor =>
      trackingInfo?.currentStage == TrackingStage.atDoor;

  LiveTrackingState copyWith({
    LiveTrackingViewMode? mode,
    DeliveryTrackingInfo? trackingInfo,
    String? errorMessage,
    String? errorTitle,
    bool clearError = false,
    LiveTrackingEvent? pendingEvent,
    String? handoverCode,
  }) {
    return LiveTrackingState(
      mode: mode ?? this.mode,
      trackingInfo: trackingInfo ?? this.trackingInfo,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorTitle: clearError ? null : (errorTitle ?? this.errorTitle),
      pendingEvent: pendingEvent ?? LiveTrackingEvent.none,
      handoverCode: handoverCode ?? this.handoverCode,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        trackingInfo,
        errorMessage,
        errorTitle,
        pendingEvent,
        handoverCode,
      ];
}
