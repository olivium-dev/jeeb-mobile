import 'dart:convert';

/// The Phoenix **v2** wire format, in one place.
///
/// Phoenix's v2 serializer puts every frame on the wire as a five-element JSON
/// ARRAY — `[joinRef, ref, topic, event, payload]` — not as the object the v1
/// serializer used. Two Jeeb surfaces speak it: the chat socket
/// (`LiveRealtimeChatSocket`, joining `jeeb:chat:{conversationId}`) and the
/// courier-position socket (`CourierPositionSocket`, joining
/// `topic:jeeb:delivery:{deliveryId}`). They share nothing else — different
/// channels, different join params, different payload projections, different
/// keepalives — but they cannot disagree about the FRAME, and this is the
/// smallest thing that guarantees they do not.
///
/// Deliberately pure: no socket, no timer, no state. The one piece both
/// surfaces need is the encode/decode, and that is all that is here. Sharing
/// the sockets themselves would mean sharing a keepalive policy that is
/// genuinely different between them (see [CourierPositionSocket]'s doc on why
/// a `topic:*` channel needs a channel-level `ping` and a chat channel does
/// not), and a shared class papering over that difference is how the wrong one
/// gets used.
class PhoenixV2Frame {
  const PhoenixV2Frame({
    required this.topic,
    required this.event,
    required this.payload,
    this.joinRef,
    this.ref,
  });

  /// The Phoenix topic the frame is on — the FULL topic including any channel
  /// prefix (`topic:jeeb:delivery:x`), not the product topic inside it.
  final String? topic;

  /// The channel event: `phx_reply`, `phx_close`, `presence_state`, or a
  /// product event such as `event` / `message_created`.
  final String? event;

  /// The frame payload. `null` when the wire carried something that is not a
  /// JSON object there (Phoenix always sends one, but a decoder that assumes
  /// so is a decoder that throws on a malformed frame).
  final Map<String, Object?>? payload;

  final String? joinRef;
  final String? ref;

  /// Whether this is one of Phoenix's own lifecycle frames rather than a
  /// product event. Both sockets drop these; neither should have to remember
  /// the list.
  bool get isLifecycle =>
      event == null ||
      event == 'phx_reply' ||
      event == 'phx_close' ||
      event == 'phx_error' ||
      event!.startsWith('presence');

  /// Decode one inbound WebSocket message.
  ///
  /// Returns `null` — never throws — for anything that is not a well-formed v2
  /// frame: a non-JSON string, a JSON object (the v1 shape), a short array.
  /// Callers treat `null` as "not for us" and carry on; a socket that dies on a
  /// stray frame takes a live subscription with it.
  static PhoenixV2Frame? decode(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final decoded = jsonDecode(text);
      if (decoded is! List || decoded.length < 5) return null;
      final payload = decoded[4];
      return PhoenixV2Frame(
        joinRef: decoded[0] as String?,
        ref: decoded[1] as String?,
        topic: decoded[2] as String?,
        event: decoded[3] as String?,
        payload: payload is Map ? payload.cast<String, Object?>() : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Encode an outbound frame to the string a Phoenix v2 socket expects.
  static String encode({
    String? joinRef,
    String? ref,
    required String topic,
    required String event,
    Map<String, Object?> payload = const <String, Object?>{},
  }) =>
      jsonEncode(<Object?>[joinRef, ref, topic, event, payload]);

  /// The transport-level keepalive every Phoenix socket accepts, on the
  /// reserved `phoenix` topic. Keeps the SOCKET from being reaped; it does not
  /// speak to any channel's own liveness rules.
  static String encodeTransportHeartbeat(String ref) => encode(
        ref: ref,
        topic: 'phoenix',
        event: 'heartbeat',
      );
}
