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
  String get apiValue {
    switch (this) {
      case JeeberDeliveryStatus.ordered:
        return 'ordered';
      case JeeberDeliveryStatus.picked:
        return 'picked';
      case JeeberDeliveryStatus.inTransit:
        return 'in_transit';
      case JeeberDeliveryStatus.atDoor:
        return 'at_door';
      case JeeberDeliveryStatus.done:
        return 'done';
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

  static JeeberDeliveryStatus fromApi(String value) {
    switch (value) {
      case 'ordered':
        return JeeberDeliveryStatus.ordered;
      case 'picked':
        return JeeberDeliveryStatus.picked;
      case 'in_transit':
        return JeeberDeliveryStatus.inTransit;
      case 'at_door':
        return JeeberDeliveryStatus.atDoor;
      case 'done':
        return JeeberDeliveryStatus.done;
    }
    return JeeberDeliveryStatus.ordered;
  }
}
