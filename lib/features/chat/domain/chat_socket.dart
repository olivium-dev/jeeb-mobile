/// Transport-agnostic chat socket contract.
///
/// The cubit talks to this — never to `WebSocketChannel` directly — so unit
/// tests can wire in a deterministic in-memory fake without bringing
/// `dart:io` `WebSocket` or `package:web_socket_channel` into the test
/// process.
///
/// Lifecycle:
///   1. Construct.
///   2. `connect()` — opens the socket. Throws on immediate failure (e.g.
///      malformed URL, DNS error). Async failures surface via [events]
///      closing or [errors] emitting.
///   3. `send(json)` — fire-and-forget; the cubit pairs server acks with
///      client ids out-of-band.
///   4. `close()` — idempotent. After close, [events] is done.
abstract class ChatSocket {
  /// Stream of incoming envelopes already JSON-decoded into a `Map`.
  /// Closes when the peer closes or [close] is called.
  Stream<Map<String, Object?>> get events;

  /// Side-channel for transport errors (socket reset, frame decode failure).
  /// Separate from [events] so the cubit can keep one subscription per
  /// concern.
  Stream<Object> get errors;

  Future<void> connect();

  void send(Map<String, Object?> envelope);

  Future<void> close();
}
