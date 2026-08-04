/// Four canonical milestones in Jeeb delivery's life; pending never reaches screen (only
/// after Jeeber matched). Cancellation is terminal side-state via [DeliveryLifecycle], so
/// stepper keeps rendering four equally-weighted segments.
enum DeliveryStage {
  matched,
  pickedUp,
  inTransit,
  delivered,
}

/// Ordering helpers to ask "is stage X at or before stage Y?" without hardcoding enum index.
extension DeliveryStageOrdering on DeliveryStage {
  int get order => index;

  bool isAtOrBefore(DeliveryStage other) => order <= other.order;
  bool isBefore(DeliveryStage other) => order < other.order;
}

/// Total milestone step count; named constant so UI/tests don't recompute inline.
const int kDeliveryStageCount = 4;
