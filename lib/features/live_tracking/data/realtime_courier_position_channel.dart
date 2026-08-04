import 'dart:async';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/courier_position_channel.dart';
import 'courier_position_socket.dart';

/// Response from GET /v1/realtime/jeeb:delivery:{deliveryId}.
class DeliveryPositionChannelDescriptor {
  const DeliveryPositionChannelDescriptor({
    required this.deliveryId,
    required this.topic,
    required this.channel,
    required this.stream,
    required this.token,
    this.socketUrl,
    this.expiresAt,
  });

  final String deliveryId;
  final String topic;
  final String channel;
  /// Load-bearing on SERVER (Throttle policy keyed by stream name).
  final String stream;
  final String token;
  /// Null is DEFAULT (prevents accidental loopback dial).
  final String? socketUrl;
  final DateTime? expiresAt;
}

/// Gateway descriptor + Phoenix socket. Gateway mints credential narrowed to
/// one topic; do not fall back to realtime's open `/api/auth/token`.
class RealtimeCourierPositionChannel implements CourierPositionChannel {
  RealtimeCourierPositionChannel(
    this._dio, {
    WebSocketChannel Function(Uri uri)? channelFactory,
    Duration keepAlive = kCourierPositionKeepAlive,
  })  : _channelFactory = channelFactory,
        _keepAlive = keepAlive;

  final Dio _dio;
  final WebSocketChannel Function(Uri uri)? _channelFactory;
  final Duration _keepAlive;

  @override
  Future<Stream<CourierPositionFix>?> open({
    required String deliveryId,
  }) async {
    final descriptor = await resolve(deliveryId);
    if (descriptor == null) return null;
    final socketUri = _socketUriOf(descriptor);
    if (socketUri == null) return null;
    if (descriptor.token.isEmpty) return null;
    final socket = CourierPositionSocket(
      socketUri: socketUri,
      token: descriptor.token,
      channel: descriptor.channel,
      stream: descriptor.stream,
      channelFactory: _channelFactory,
      keepAlive: _keepAlive,
    );
    try {
      await socket.connect();
    } catch (_) {
      await socket.close();
      return null;
    }
    return socket.positions;
  }

  /// Fetch descriptor; null on any failure (tracking screen never faulted).
  Future<DeliveryPositionChannelDescriptor?> resolve(String deliveryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/realtime/jeeb:delivery:$deliveryId',
      );
      return _parse(deliveryId, response.data);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Gateway camelCase; accept snake_case fallback.
  DeliveryPositionChannelDescriptor? _parse(
    String deliveryId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final topic = data['topic'] as String?;
    final token = data['token'] as String?;
    if (topic == null || topic.isEmpty) return null;
    if (token == null || token.isEmpty) return null;
    final channel = data['channel'] as String?;
    final stream = data['stream'] as String?;
    final socketUrl = (data['socketUrl'] ?? data['socket_url']) as String?;
    final expiresAt = (data['expiresAt'] ?? data['expires_at']) as String?;
    return DeliveryPositionChannelDescriptor(
      deliveryId:
          (data['deliveryId'] ?? data['delivery_id']) as String? ?? deliveryId,
      topic: topic,
      channel: (channel != null && channel.isNotEmpty) ? channel : 'topic:$topic',
      stream: (stream != null && stream.isNotEmpty) ? stream : 'location',
      token: token,
      socketUrl: socketUrl,
      expiresAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
    );
  }

  /// Rejects non-ws(s) scheme (deployment error).
  Uri? _socketUriOf(DeliveryPositionChannelDescriptor descriptor) {
    final raw = descriptor.socketUrl;
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme != 'ws' && uri.scheme != 'wss') return null;
    if (uri.host.isEmpty) return null;
    return uri;
  }
}
