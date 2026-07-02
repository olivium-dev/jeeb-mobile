/// The Jeeber-side delivery status stages.
///
/// These map directly to the gateway transition machine (T-BE-009).
/// The valid forward transitions are:
///   ordered → picked → in_transit → at_door → done
enum JeeberDeliveryStatus {
  ordered,
  picked,
  inTransit,
  atDoor,
  done,
}

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
    }
  }

  /// The next valid forward status, or null if this is terminal.
  JeeberDeliveryStatus? get next {
    const values = JeeberDeliveryStatus.values;
    final idx = values.indexOf(this);
    if (idx < 0 || idx >= values.length - 1) return null;
    return values[idx + 1];
  }

  bool get isTerminal => this == JeeberDeliveryStatus.done;

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
      case 'picked':
        return JeeberDeliveryStatus.picked;
      case 'intransit':
        return JeeberDeliveryStatus.inTransit;
      case 'atdoor':
        return JeeberDeliveryStatus.atDoor;
      // Terminal states all collapse to `done` so the existing `!= done`
      // in-flight filter drops a cancelled/expired/delivered/rated delivery
      // from the jeeber's active list instead of re-rendering it as `ordered`.
      case 'done':
      case 'delivered':
      case 'cancelled':
      case 'canceled':
      case 'expired':
      case 'rated':
        return JeeberDeliveryStatus.done;
    }
    return JeeberDeliveryStatus.ordered;
  }
}
