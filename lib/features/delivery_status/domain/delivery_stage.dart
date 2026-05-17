/// The four canonical milestones in a Jeeb delivery's life, in order.
///
/// Mirrors the `pending → matched → picked_up → in_transit → delivered`
/// machine that lives in jeeb-gateway (`src/JeebGateway/Requests/`). The
/// `pending` state never reaches this screen — the user only navigates here
/// once a Jeeber has been matched. Cancellation is a terminal side-state
/// modelled by [DeliveryLifecycle], not by inserting a new stage here, so the
/// stepper widget can keep rendering four equally-weighted segments.
enum DeliveryStage {
  matched,
  pickedUp,
  inTransit,
  delivered,
}

/// Ordering helpers — the cubit and progress widget both need to ask "is
/// stage X at or before stage Y?" without hardcoding the enum index.
extension DeliveryStageOrdering on DeliveryStage {
  /// Zero-based position used by the progress stepper.
  int get order => index;

  bool isAtOrBefore(DeliveryStage other) => order <= other.order;
  bool isBefore(DeliveryStage other) => order < other.order;
}

/// Total count of milestone steps — exposed as a named constant so the UI
/// and tests don't recompute `DeliveryStage.values.length` inline.
const int kDeliveryStageCount = 4;
