enum DeliveryStatusStage {
  ordered,
  pickedUp,
  inTransit,
  atDoor,
  delivered,
  cancelled,
  otherTerminal,
  unknown,
}

abstract final class DeliveryStatusVocab {
  static String _norm(String? statusId) =>
      (statusId ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '').trim();

  static const Set<String> _ordered = <String>{
    'ordered',
    'accepted',
    'matched',
    'pending',
    'placed',
    'created',
    'new',
    'requested',
    'onhold',
    'held',
    'hold',
  };

  static const Set<String> _pickedUp = <String>{
    'picked',
    'pickedup',
    'atpickup',
  };

  static const Set<String> _inTransit = <String>{
    'intransit',
    'headingoff',
    'enroute',
  };

  static const Set<String> _atDoor = <String>{'atdoor'};

  static const Set<String> _delivered = <String>{
    'done',
    'delivered',
    'completed',
  };

  static const Set<String> _cancelled = <String>{'cancelled', 'canceled'};

  static const Set<String> _terminal = <String>{
    'done',
    'delivered',
    'completed',
    'rated',
    'cancelled',
    'canceled',
    'expired',
    'disputed',
    'failedneedsescalation',
  };

  static DeliveryStatusStage stageOf(String? statusId) {
    final normalized = _norm(statusId);
    if (_ordered.contains(normalized)) return DeliveryStatusStage.ordered;
    if (_pickedUp.contains(normalized)) return DeliveryStatusStage.pickedUp;
    if (_inTransit.contains(normalized)) return DeliveryStatusStage.inTransit;
    if (_atDoor.contains(normalized)) return DeliveryStatusStage.atDoor;
    if (_delivered.contains(normalized)) return DeliveryStatusStage.delivered;
    if (_cancelled.contains(normalized)) return DeliveryStatusStage.cancelled;
    if (_terminal.contains(normalized)) {
      return DeliveryStatusStage.otherTerminal;
    }
    return DeliveryStatusStage.unknown;
  }

  static bool isDelivered(String? statusId) {
    final n = _norm(statusId);
    return n.isNotEmpty && _delivered.contains(n);
  }

  static bool isCancelled(String? statusId) {
    final n = _norm(statusId);
    return n.isNotEmpty && _cancelled.contains(n);
  }

  static bool isTerminal(String? statusId) {
    final n = _norm(statusId);
    return n.isNotEmpty && _terminal.contains(n);
  }

  /// The chat CTA is labelled "Start delivery", so it is valid only before
  /// lifecycle work has begun. Unknown/missing states fail closed.
  static bool canStartFromChat(String? statusId) =>
      stageOf(statusId) == DeliveryStatusStage.ordered;

  static bool isCancelAllowed(String? statusId) =>
      _ordered.contains(_norm(statusId));
}
