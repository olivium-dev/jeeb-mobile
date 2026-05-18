import 'package:equatable/equatable.dart';

import '../domain/delivery_tracking_info.dart';

enum LiveTrackingViewMode { loading, ready, error }

class LiveTrackingState extends Equatable {
  const LiveTrackingState({
    this.mode = LiveTrackingViewMode.loading,
    this.trackingInfo,
    this.errorMessage,
  });

  final LiveTrackingViewMode mode;
  final DeliveryTrackingInfo? trackingInfo;
  final String? errorMessage;

  LiveTrackingState copyWith({
    LiveTrackingViewMode? mode,
    DeliveryTrackingInfo? trackingInfo,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LiveTrackingState(
      mode: mode ?? this.mode,
      trackingInfo: trackingInfo ?? this.trackingInfo,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [mode, trackingInfo, errorMessage];
}
