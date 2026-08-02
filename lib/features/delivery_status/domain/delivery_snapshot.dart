import 'package:equatable/equatable.dart';

import 'delivery_address.dart';
import 'delivery_stage.dart';
import 'delivery_tier.dart';
import 'jeeber_summary.dart';

enum DeliveryLifecycle { active, completed, cancelled }

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

  final String id;

  final DeliveryStage stage;

  final DeliveryLifecycle lifecycle;

  final Map<DeliveryStage, DateTime> stageTimestamps;

  final DeliveryAddress pickup;
  final DeliveryAddress dropoff;
  final DeliveryTier tier;

  final JeeberSummary? jeeber;

  final int? etaMinutes;

  bool get isEtaVisible =>
      lifecycle == DeliveryLifecycle.active &&
      stage == DeliveryStage.inTransit &&
      etaMinutes != null;

  bool get isInFlight => lifecycle == DeliveryLifecycle.active;

  bool get canCancel =>
      lifecycle == DeliveryLifecycle.active &&
      stage.isBefore(DeliveryStage.pickedUp);

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
