import 'dart:convert';

class PhoenixV2Frame {
  const PhoenixV2Frame({
    required this.topic,
    required this.event,
    required this.payload,
    this.joinRef,
    this.ref,
  });

  final String? topic;

  final String? event;

  final Map<String, Object?>? payload;

  final String? joinRef;
  final String? ref;

  bool get isLifecycle =>
      event == null ||
      event == 'phx_reply' ||
      event == 'phx_close' ||
      event == 'phx_error' ||
      event!.startsWith('presence');

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

  static String encode({
    String? joinRef,
    String? ref,
    required String topic,
    required String event,
    Map<String, Object?> payload = const <String, Object?>{},
  }) =>
      jsonEncode(<Object?>[joinRef, ref, topic, event, payload]);

  static String encodeTransportHeartbeat(String ref) => encode(
        ref: ref,
        topic: 'phoenix',
        event: 'heartbeat',
      );
}
