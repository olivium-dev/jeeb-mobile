abstract final class DeliveryStatusVocab {
  static String _norm(String? statusId) =>
      (statusId ?? '').toLowerCase().replaceAll('_', '').trim();

  static const Set<String> _delivered = <String>{
    'done',
    'delivered',
    'completed',
  };

  static const Set<String> _cancelled = <String>{
    'cancelled',
    'canceled',
  };

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

  static const Set<String> _prePickup = <String>{
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

  static bool isCancelAllowed(String? statusId) =>
      _prePickup.contains(_norm(statusId));
}
