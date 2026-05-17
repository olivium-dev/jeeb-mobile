import 'package:equatable/equatable.dart';

/// Whether the Jeeber is currently accepting new offers and the reason
/// they're not (if applicable).
enum AvailabilityState {
  /// The Jeeber is online and the matching engine may surface offers.
  online,

  /// The Jeeber tapped the toggle off, or hasn't tapped it on yet.
  offline,

  /// The system flipped the Jeeber offline (8h inactivity, server-side
  /// kick, etc.). Distinguished from [offline] so the UI can surface a
  /// non-dismissible explanation instead of looking like the Jeeber
  /// turned themselves off.
  autoOffline,
}

/// Snapshot returned from [AvailabilityGateway]. Used both as the in-flight
/// "current truth" the cubit holds, and as the response shape the gateway
/// emits after every PUT.
class AvailabilityStatus extends Equatable {
  const AvailabilityStatus({
    required this.state,
    required this.activeDeliveryCount,
    this.lastActivityAt,
  });

  /// Convenience constant for the cold-start "before the first fetch" frame.
  static const initial = AvailabilityStatus(
    state: AvailabilityState.offline,
    activeDeliveryCount: 0,
  );

  /// Current online/offline state.
  final AvailabilityState state;

  /// Number of deliveries currently assigned to this Jeeber. Surfaced
  /// alongside the toggle so a Jeeber who's online never wonders whether
  /// they have a pending pickup queued up.
  final int activeDeliveryCount;

  /// Wall-clock timestamp of the most recent activity (toggle, accepted
  /// offer, etc.). Drives the 8-hour auto-offline rule. `null` until the
  /// gateway has confirmed at least one transition.
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
