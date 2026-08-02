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

const jeeberDeliveryProgressStages = <JeeberDeliveryStatus>[
  JeeberDeliveryStatus.ordered,
  JeeberDeliveryStatus.picked,
  JeeberDeliveryStatus.inTransit,
  JeeberDeliveryStatus.atDoor,
  JeeberDeliveryStatus.done,
];

extension JeeberDeliveryStatusX on JeeberDeliveryStatus {
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

  JeeberDeliveryStatus? get next {
    if (this == JeeberDeliveryStatus.atDoor) return null;
    final idx = jeeberDeliveryProgressStages.indexOf(this);
    if (idx < 0 || this == JeeberDeliveryStatus.done) return null;
    return jeeberDeliveryProgressStages[idx + 1];
  }

  bool get isSuccessfulTerminal => this == JeeberDeliveryStatus.done;

  bool get isUnsuccessfulTerminal =>
      this == JeeberDeliveryStatus.cancelled ||
      this == JeeberDeliveryStatus.expired ||
      this == JeeberDeliveryStatus.disputed;

  bool get isTerminal => isSuccessfulTerminal || isUnsuccessfulTerminal;

  bool get isPollTerminal =>
      isSuccessfulTerminal ||
      this == JeeberDeliveryStatus.cancelled ||
      this == JeeberDeliveryStatus.expired;

  static JeeberDeliveryStatus fromApi(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'ordered':
      case 'accepted':
        return JeeberDeliveryStatus.ordered;
      case 'picked':
      case 'pickedup':
        return JeeberDeliveryStatus.picked;
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
