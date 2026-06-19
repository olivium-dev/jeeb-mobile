import 'package:equatable/equatable.dart';

import '../domain/delivery_tracking_info.dart';

enum LiveTrackingViewMode { loading, ready, error }

/// T-MOB-017: One-shot event flags emitted alongside state transitions so
/// the screen's BlocListener can respond without double-firing.
enum LiveTrackingEvent {
  none,
  jeeberOnTheWay, // AC3: in_transit toast
  jeeberAtDoor,   // AC4: at_door OTP card slide-in

  /// JM-032 AC2: the delivery reached its terminal delivered state — the
  /// screen auto-advances to `delivered-receipt-confirm` (JM-033, D70).
  deliveredAutoAdvance,
}

class LiveTrackingState extends Equatable {
  const LiveTrackingState({
    this.mode = LiveTrackingViewMode.loading,
    this.trackingInfo,
    this.errorMessage,
    this.pendingEvent = LiveTrackingEvent.none,
  });

  final LiveTrackingViewMode mode;
  final DeliveryTrackingInfo? trackingInfo;
  final String? errorMessage;

  /// T-MOB-017: One-shot event for the screen listener (AC3 + AC4).
  final LiveTrackingEvent pendingEvent;

  bool get isAtDoor =>
      trackingInfo?.currentStage == TrackingStage.atDoor;

  LiveTrackingState copyWith({
    LiveTrackingViewMode? mode,
    DeliveryTrackingInfo? trackingInfo,
    String? errorMessage,
    bool clearError = false,
    LiveTrackingEvent? pendingEvent,
  }) {
    return LiveTrackingState(
      mode: mode ?? this.mode,
      trackingInfo: trackingInfo ?? this.trackingInfo,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingEvent: pendingEvent ?? LiveTrackingEvent.none,
    );
  }

  @override
  List<Object?> get props =>
      [mode, trackingInfo, errorMessage, pendingEvent];
}
