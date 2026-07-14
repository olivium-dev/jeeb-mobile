/// Shared delivery-lifecycle status vocabulary (JEBV4-309).
///
/// Extracted from `chat_detail_screen.dart` (`_isTerminalStatus` /
/// `_isDeliveredStatus`, JEBV4-282) so every surface that reads the wire
/// `statusId` (the chat status chip poll AND the customer delivery-details hub)
/// classifies it the SAME way. Tolerant of the CapitalCase, snake_case, and
/// legacy aliases the wire can carry — every check normalizes by lowercasing
/// and stripping `_` first (so `Picked`, `picked`, `picked_up`, `pickedup` all
/// collapse to the same token).
///
/// Mirrors the terminal collapse in `JeeberDeliveryStatusX.fromApi` and the
/// gateway transition machine (`ordered → picked → in_transit → at_door → done`,
/// side-state `cancelled`).
abstract final class DeliveryStatusVocab {
  static String _norm(String? statusId) =>
      (statusId ?? '').toLowerCase().replaceAll('_', '').trim();

  /// SUCCESSFUL delivery-completion statuses (the subset of [isTerminal] that
  /// earns a rating). Cancelled / expired / disputed / failed terminals are
  /// deliberately excluded — no rating for a non-delivered order.
  static const Set<String> _delivered = <String>{
    'done',
    'delivered',
    'completed',
  };

  /// Cancelled-class statuses. `cancelled` / `canceled` spellings both occur on
  /// the wire.
  static const Set<String> _cancelled = <String>{
    'cancelled',
    'canceled',
  };

  /// Every terminal status — the delivery can no longer advance. Matches the
  /// `chat_detail_screen` poll's stop set exactly.
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

  /// Pre-pickup / on-hold statuses where a FREE MVP cancel is still allowed
  /// (JEBV4-289: no cancellation fees, free cancel before pickup). Everything
  /// from order placement up to — but NOT including — `Picked`. Once the parcel
  /// is in hand (`Picked`/`InTransit`/`AtDoor`) or the order is terminal, cancel
  /// is hidden. This is an explicit allow-list: an unknown/empty status is NOT
  /// cancel-allowed here (the hub decides fail-open behaviour separately).
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

  /// True for a SUCCESSFUL delivery completion (Done/delivered/completed).
  static bool isDelivered(String? statusId) {
    final n = _norm(statusId);
    return n.isNotEmpty && _delivered.contains(n);
  }

  /// True for a cancelled-class terminal (cancelled/canceled).
  static bool isCancelled(String? statusId) {
    final n = _norm(statusId);
    return n.isNotEmpty && _cancelled.contains(n);
  }

  /// True for ANY terminal status (delivery can no longer advance).
  static bool isTerminal(String? statusId) {
    final n = _norm(statusId);
    return n.isNotEmpty && _terminal.contains(n);
  }

  /// True only for a KNOWN pre-pickup / on-hold status. Empty / unknown → false
  /// (callers must never surface a free-cancel affordance from this method on an
  /// unrecognised status).
  static bool isCancelAllowed(String? statusId) =>
      _prePickup.contains(_norm(statusId));
}
