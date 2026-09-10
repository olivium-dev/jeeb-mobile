import 'dart:async';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/realtime/realtime_socket_policy.dart';
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
class RealtimeCourierPositionChannel
    implements
        CourierPositionChannel,
        CourierPositionChannelOutcome,
        CancellableCourierPositionChannel {
  RealtimeCourierPositionChannel(
    this._dio, {
    WebSocketChannel Function(Uri uri)? channelFactory,
    Duration keepAlive = kCourierPositionKeepAlive,
    Duration joinTimeout = kCourierPositionJoinTimeout,
    RealtimeSocketPolicy socketPolicy = const RealtimeSocketPolicy(),
  }) : _channelFactory = channelFactory,
       _keepAlive = keepAlive,
       _joinTimeout = joinTimeout,
       _socketPolicy = socketPolicy;

  final Dio _dio;
  final WebSocketChannel Function(Uri uri)? _channelFactory;
  final Duration _keepAlive;
  final Duration _joinTimeout;
  final RealtimeSocketPolicy _socketPolicy;

  @override
  Future<Stream<CourierPositionFix>?> open({
    required String deliveryId,
  }) async => (await openWithOutcome(deliveryId: deliveryId)).positions;

  @override
  Future<CourierPositionOpenResult> openWithOutcome({
    required String deliveryId,
  }) => openAttempt(deliveryId: deliveryId).result;

  @override
  CourierPositionOpenAttempt openAttempt({required String deliveryId}) {
    final cancellation = CancelToken();
    CourierPositionSocket? socket;
    final result = _open(
      deliveryId,
      cancellation,
      (created) => socket = created,
    );
    return CourierPositionOpenAttempt(
      result: result,
      cancel: () async {
        cancellation.cancel();
        await socket?.close();
      },
    );
  }

  Future<CourierPositionOpenResult> _open(
    String deliveryId,
    CancelToken cancellation,
    void Function(CourierPositionSocket) onSocket,
  ) async {
    // The descriptor's `socketUrl` must normalize to this compile-time
    // mobile-owned authority. If it is absent, no descriptor can ever open a
    // socket, so avoid an otherwise guaranteed gateway bootstrap failure (for
    // example a 503 from an intentionally unconfigured realtime deployment).
    if (_socketPolicy.configuredUri() == null) {
      return const CourierPositionOpenResult.failed(
        CourierPositionOpenFailure.unavailable,
      );
    }
    final resolved = await _resolve(deliveryId, cancelToken: cancellation);
    final descriptor = resolved.descriptor;
    if (cancellation.isCancelled) {
      return const CourierPositionOpenResult.failed(
        CourierPositionOpenFailure.transport,
      );
    }
    if (descriptor == null) {
      return CourierPositionOpenResult.failed(
        _resolveFailureKind(resolved.failure),
      );
    }
    final socketUri = _socketUriOf(descriptor);
    if (socketUri == null || descriptor.token.isEmpty) {
      return const CourierPositionOpenResult.failed(
        CourierPositionOpenFailure.unavailable,
      );
    }
    final socket = CourierPositionSocket(
      socketUri: socketUri,
      token: descriptor.token,
      channel: descriptor.channel,
      stream: descriptor.stream,
      channelFactory: _channelFactory,
      keepAlive: _keepAlive,
      joinTimeout: _joinTimeout,
    );
    onSocket(socket);
    try {
      await socket.connect();
    } on CourierPositionSocketException catch (error) {
      await socket.close();
      return CourierPositionOpenResult.failed(error.failure);
    } catch (_) {
      await socket.close();
      return const CourierPositionOpenResult.failed(
        CourierPositionOpenFailure.connectFailed,
      );
    }
    return CourierPositionOpenResult.opened(socket.positions);
  }

  CourierPositionOpenFailure _resolveFailureKind(AppFailure? failure) {
    if (failure == null) return CourierPositionOpenFailure.unavailable;
    return switch (failure.kind) {
      AppFailureKind.unauthorized ||
      AppFailureKind.forbidden => CourierPositionOpenFailure.authRejected,
      AppFailureKind.network ||
      AppFailureKind.timeout => CourierPositionOpenFailure.transport,
      AppFailureKind.notFound => CourierPositionOpenFailure.unavailable,
      _ => CourierPositionOpenFailure.unavailable,
    };
  }

  /// Fetch descriptor; null on any failure (tracking screen never faulted).
  Future<DeliveryPositionChannelDescriptor?> resolve(String deliveryId) async =>
      (await _resolve(deliveryId)).descriptor;

  Future<({DeliveryPositionChannelDescriptor? descriptor, AppFailure? failure})>
  _resolve(String deliveryId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/realtime/jeeb:delivery:$deliveryId',
        cancelToken: cancelToken,
      );
      return (descriptor: _parse(deliveryId, response.data), failure: null);
    } catch (e) {
      return (descriptor: null, failure: AppFailure.of(e));
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
    final returnedId = (data['deliveryId'] ?? data['delivery_id']) as String?;
    if (!_bindingAllowed(deliveryId, returnedId, topic)) return null;
    final channel = data['channel'] as String?;
    final stream = data['stream'] as String?;
    if (channel != 'topic:$topic' || !_allowedStreams.contains(stream)) {
      return null;
    }
    return _descriptorFrom(data, returnedId!, topic, token, channel!, stream!);
  }

  bool _bindingAllowed(String requestedId, String? returnedId, String topic) =>
      requestedId.isNotEmpty &&
      returnedId == requestedId &&
      topic == 'jeeb:delivery:$requestedId';

  DeliveryPositionChannelDescriptor _descriptorFrom(
    Map<String, dynamic> data,
    String deliveryId,
    String topic,
    String token,
    String channel,
    String stream,
  ) {
    final socketUrl = (data['socketUrl'] ?? data['socket_url']) as String?;
    final expiresAt = (data['expiresAt'] ?? data['expires_at']) as String?;
    return DeliveryPositionChannelDescriptor(
      deliveryId: deliveryId,
      topic: topic,
      channel: channel,
      stream: stream,
      token: token,
      socketUrl: socketUrl,
      expiresAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
    );
  }

  /// Require encrypted transport outside the explicitly selected dev flavor.
  Uri? _socketUriOf(DeliveryPositionChannelDescriptor descriptor) {
    return _socketPolicy.descriptorUri(descriptor.socketUrl);
  }
}

const _allowedStreams = <String>{'location'};
