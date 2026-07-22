/// The Jeeber-side delivery lifecycle.
///
/// The first five values map directly to the successful gateway transition
/// machine (T-BE-009). The remaining values are unsuccessful terminal states
/// and deliberately remain distinct so they can never render as `Done`.
/// The valid forward transitions are:
///   ordered → picked → in_transit → at_door → done
enum JeeberDeliveryStatus {
  ordered,
  picked,
  inTransit,
  atDoor,
  done,
  cancelled,
  expired,
  disputed,
}

/// Ordered stages shown by the successful-delivery progress stepper.
const jeeberDeliveryProgressStages = <JeeberDeliveryStatus>[
  JeeberDeliveryStatus.ordered,
  JeeberDeliveryStatus.picked,
  JeeberDeliveryStatus.inTransit,
  JeeberDeliveryStatus.atDoor,
  JeeberDeliveryStatus.done,
];

extension JeeberDeliveryStatusX on JeeberDeliveryStatus {
  /// Gateway string for this status used in the POST body.
  ///
  /// JM-051: the real mock (`delivery-service.ts` SM-1 table) speaks the
  /// CapitalCase form (`Ordered/Picked/InTransit/AtDoor/Done`); the
  /// `POST /v1/delivery/status/transition` `to` field is matched against that
  /// table exactly, so we emit CapitalCase here.
  String get apiValue {
    switch (this) {
      case JeeberDeliveryStatus.ordered:
        return 'Ordered';
      case JeeberDeliveryStatus.picked:
        return 'Picked';
      case JeeberDeliveryStatus.inTransit:
        return 'InTransit';
      case JeeberDeliveryStatus.atDoor:
        return 'AtDoor';
      case JeeberDeliveryStatus.done:
        return 'Done';
      case JeeberDeliveryStatus.cancelled:
        return 'Cancelled';
      case JeeberDeliveryStatus.expired:
        return 'Expired';
      case JeeberDeliveryStatus.disputed:
        return 'FailedNeedsEscalation';
    }
  }

  /// The next valid forward status, or null if this is terminal.
  JeeberDeliveryStatus? get next {
    final idx = jeeberDeliveryProgressStages.indexOf(this);
    if (idx < 0 || this == JeeberDeliveryStatus.done) return null;
    return jeeberDeliveryProgressStages[idx + 1];
  }

  /// True for a successfully delivered terminal.
  bool get isSuccessfulTerminal => this == JeeberDeliveryStatus.done;

  /// True for cancellation, expiry, or a disputed/admin-escalated terminal.
  bool get isUnsuccessfulTerminal =>
      this == JeeberDeliveryStatus.cancelled ||
      this == JeeberDeliveryStatus.expired ||
      this == JeeberDeliveryStatus.disputed;

  /// True once the delivery can no longer advance.
  bool get isTerminal => isSuccessfulTerminal || isUnsuccessfulTerminal;

  /// Parse a gateway status. Tolerates both the real-mock CapitalCase form
  /// (`InTransit`, `AtDoor`, `Done`) and the legacy lowercase/underscore form
  /// (`in_transit`, `at_door`) so older fixtures + tests keep parsing. Unknown
  /// → `ordered` (never crashes — 40_GUARDRAILS_ARCH §4 defensive parse).
  static JeeberDeliveryStatus fromApi(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      // `accepted` is the pre-pickup ordered stage on the jeeber side.
      case 'ordered':
      case 'accepted':
        return JeeberDeliveryStatus.ordered;
      // `pickedup` is the underscore-stripped legacy `picked_up` alias
      // (DeliveryStatusAlias: picked_up ⇒ Picked). Pre-fix it fell through to
      // the `ordered` default and re-rendered an in-flight delivery at step 1
      // (sprint-009 scenario matrix #11).
      case 'picked':
      case 'pickedup':
        return JeeberDeliveryStatus.picked;
      // `headingoff` is the underscore-stripped legacy `heading_off` alias
      // (DeliveryStatusAlias: heading_off ⇒ InTransit).
      case 'intransit':
      case 'headingoff':
        return JeeberDeliveryStatus.inTransit;
      case 'atdoor':
        return JeeberDeliveryStatus.atDoor;
      case 'done':
      case 'delivered':
      case 'completed':
      case 'rated':
        return JeeberDeliveryStatus.done;
      case 'cancelled':
      case 'canceled':
        return JeeberDeliveryStatus.cancelled;
      case 'expired':
        return JeeberDeliveryStatus.expired;
      case 'disputed':
      case 'failedneedsescalation':
        return JeeberDeliveryStatus.disputed;
    }
    return JeeberDeliveryStatus.ordered;
  }
}
