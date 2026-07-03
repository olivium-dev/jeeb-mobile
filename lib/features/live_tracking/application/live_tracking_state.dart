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
    this.errorTitle,
    this.pendingEvent = LiveTrackingEvent.none,
    this.handoverCode,
  });

  final LiveTrackingViewMode mode;
  final DeliveryTrackingInfo? trackingInfo;
  final String? errorMessage;

  /// Optional heading rendered above [errorMessage] in the error state — set
  /// for the distinct 404 "delivery not found" case so it reads differently
  /// from a transient server/GPS error. Null for the generic error states.
  final String? errorTitle;

  /// T-MOB-017: One-shot event for the screen listener (AC3 + AC4).
  final LiveTrackingEvent pendingEvent;

  /// G4 (sprint-009): the delivery hand-over code re-hydrated from the local
  /// [HandoverCodeStore] (persisted at offer-accept time; restart-safe). Null
  /// when the device never received it (e.g. reinstall) — the at-door card
  /// then routes to the OTP screen's SMS fallback instead. Never logged.
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
