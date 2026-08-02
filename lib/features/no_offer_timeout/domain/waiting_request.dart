
import 'package:equatable/equatable.dart';

enum WaitingRequestPhase {
  broadcasting,
  offersArrived,
  matched,
  cancelled,
  expired,
  closed,
}

extension WaitingRequestPhaseX on WaitingRequestPhase {
  bool get isTerminal => switch (this) {
    WaitingRequestPhase.broadcasting ||
    WaitingRequestPhase.offersArrived => false,
    WaitingRequestPhase.matched ||
    WaitingRequestPhase.cancelled ||
    WaitingRequestPhase.expired ||
    WaitingRequestPhase.closed => true,
  };
}

class WaitingRequest extends Equatable {
  const WaitingRequest({
    required this.requestId,
    required this.phase,
    required this.notifiedCount,
    required this.offerCount,
    required this.receivedAt,
    this.remainingAtReceipt,
    this.displayId,
    this.tier,
    this.title,
  });

  final String requestId;

  final WaitingRequestPhase phase;

  final int notifiedCount;

  final int offerCount;

  final DateTime receivedAt;

  final Duration? remainingAtReceipt;

  final String? displayId;

  final String? tier;

  final String? title;

  bool get hasOffers =>
      offerCount > 0 || phase == WaitingRequestPhase.offersArrived;

  DateTime? get deadline {
    final remaining = remainingAtReceipt;
    return remaining == null ? null : receivedAt.add(remaining);
  }

  WaitingRequest copyWith({
    WaitingRequestPhase? phase,
    int? notifiedCount,
    int? offerCount,
    String? displayId,
    String? tier,
    String? title,
  }) => WaitingRequest(
    requestId: requestId,
    phase: phase ?? this.phase,
    notifiedCount: notifiedCount ?? this.notifiedCount,
    offerCount: offerCount ?? this.offerCount,
    receivedAt: receivedAt, // anchor NEVER re-stamped here
    remainingAtReceipt: remainingAtReceipt, // carried as a PAIR
    displayId: displayId ?? this.displayId,
    tier: tier ?? this.tier,
    title: title ?? this.title,
  );

  @override
  List<Object?> get props => [
    requestId,
    phase,
    notifiedCount,
    offerCount,
    receivedAt,
    remainingAtReceipt,
    displayId,
    tier,
    title,
  ];
}
