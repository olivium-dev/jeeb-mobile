/// Transport-agnostic chat socket contract for testable unit isolation.
/// Lifecycle: construct → connect() → send(json) × many → close() (idempotent).
/// Immediate failures (DNS, malformed URL) throw; async failures surface via events/errors streams.
abstract class ChatSocket {
  /// Stream of incoming envelopes (JSON-decoded Map). Closes when peer closes or close() called.
  Stream<Map<String, Object?>> get events;

  /// Side-channel for transport errors (reset, frame decode); separate from events.
  Stream<Object> get errors;

  Future<void> connect();

  void send(Map<String, Object?> envelope);

  Future<void> close();
}
