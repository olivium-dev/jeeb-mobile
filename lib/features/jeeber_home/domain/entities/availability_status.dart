import 'package:equatable/equatable.dart';

enum AvailabilityState {
  online,

  offline,

  autoOffline,
}

class AvailabilityStatus extends Equatable {
  const AvailabilityStatus({
    required this.state,
    required this.activeDeliveryCount,
    this.lastActivityAt,
  });

  static const initial = AvailabilityStatus(
    state: AvailabilityState.offline,
    activeDeliveryCount: 0,
  );

  final AvailabilityState state;

  final int activeDeliveryCount;

  final DateTime? lastActivityAt;

  bool get isOnline => state == AvailabilityState.online;

  AvailabilityStatus copyWith({
    AvailabilityState? state,
    int? activeDeliveryCount,
    DateTime? lastActivityAt,
  }) {
    return AvailabilityStatus(
      state: state ?? this.state,
      activeDeliveryCount: activeDeliveryCount ?? this.activeDeliveryCount,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }

  @override
  List<Object?> get props => [state, activeDeliveryCount, lastActivityAt];
}
