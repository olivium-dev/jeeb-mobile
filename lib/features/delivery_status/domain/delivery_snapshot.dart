import 'package:equatable/equatable.dart';

import 'delivery_address.dart';
import 'delivery_stage.dart';
import 'delivery_tier.dart';
import 'jeeber_summary.dart';

/// Top-level lifecycle bucket. Distinct from [DeliveryStage] because the
/// happy path (matched → delivered) and the side states (cancelled) need to
/// be reasoned about separately by the UI — the stepper only animates while
/// `lifecycle == active`, and action buttons collapse once it's terminal.
enum DeliveryLifecycle { active, completed, cancelled }

/// Immutable snapshot of a delivery as understood by the gateway right now.
///
/// The cubit re-emits a new snapshot per upstream tick. The status screen
/// is a pure function of this snapshot — no widget state, no animation
/// triggers beyond what [stage] implies.
class DeliverySnapshot extends Equatable {
  const DeliverySnapshot({
    required this.id,
    required this.stage,
    required this.lifecycle,
    required this.stageTimestamps,
    required this.pickup,
    required this.dropoff,
    required this.tier,
    this.jeeber,
    this.etaMinutes,
  });

  /// Stable id matching the gateway's `requestId`. Surfaced in the app bar
  /// subtitle and used as a stable key for the screen.
  final String id;

  /// Current milestone. Drives the stepper highlight + animation.
  final DeliveryStage stage;

  /// Whether the delivery is still in motion, completed, or cancelled.
  final DeliveryLifecycle lifecycle;

  /// Server-supplied timestamps for each milestone that has already been
  /// reached. Stages that haven't been hit yet are absent from the map.
  final Map<DeliveryStage, DateTime> stageTimestamps;

  final DeliveryAddress pickup;
  final DeliveryAddress dropoff;
  final DeliveryTier tier;

  /// Null until the matching step completes.
  final JeeberSummary? jeeber;

  /// Estimated minutes until arrival. Only meaningful while the delivery is
  /// in transit — gateway will return null in the matched / picked_up
  /// phases. Negative or zero values are clamped to "arriving" by the UI.
  final int? etaMinutes;

  /// True once the courier is en route to the dropoff. ETA only renders for
  /// this slice of the lifecycle so the badge doesn't lie while the courier
  /// is still standing at pickup.
  bool get isEtaVisible =>
      lifecycle == DeliveryLifecycle.active &&
      stage == DeliveryStage.inTransit &&
      etaMinutes != null;

  /// True if the delivery is still racing toward the dropoff — gates the
  /// cancel + contact actions in the UI.
  bool get isInFlight => lifecycle == DeliveryLifecycle.active;

  /// Per BR-4 in the cancellation matrix, the sender can only cancel before
  /// the courier picks up. Once the parcel is in hand, the cancel CTA is
  /// hidden — the user must escalate via dispute instead.
  bool get canCancel =>
      lifecycle == DeliveryLifecycle.active &&
      stage.isBefore(DeliveryStage.pickedUp);

  /// Contact action is gated on the gateway exposing a dialable number —
  /// pre-pickup the gateway intentionally withholds it for spam reasons.
  bool get canContactJeeber =>
      lifecycle == DeliveryLifecycle.active &&
      jeeber?.phoneE164 != null &&
      jeeber!.phoneE164!.isNotEmpty;

  DeliverySnapshot copyWith({
    String? id,
    DeliveryStage? stage,
    DeliveryLifecycle? lifecycle,
    Map<DeliveryStage, DateTime>? stageTimestamps,
    DeliveryAddress? pickup,
    DeliveryAddress? dropoff,
    DeliveryTier? tier,
    JeeberSummary? jeeber,
    bool clearJeeber = false,
    int? etaMinutes,
    bool clearEta = false,
  }) {
    return DeliverySnapshot(
      id: id ?? this.id,
      stage: stage ?? this.stage,
      lifecycle: lifecycle ?? this.lifecycle,
      stageTimestamps: stageTimestamps ?? this.stageTimestamps,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      tier: tier ?? this.tier,
      jeeber: clearJeeber ? null : (jeeber ?? this.jeeber),
      etaMinutes: clearEta ? null : (etaMinutes ?? this.etaMinutes),
    );
  }

  @override
  List<Object?> get props => [
        id,
        stage,
        lifecycle,
        stageTimestamps,
        pickup,
        dropoff,
        tier,
        jeeber,
        etaMinutes,
      ];
}
