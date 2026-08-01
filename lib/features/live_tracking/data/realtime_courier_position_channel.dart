import 'dart:async';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/courier_position_channel.dart';
import 'courier_position_socket.dart';

/// What `GET /v1/realtime/jeeb:delivery:{deliveryId}` hands back
/// (`DeliveryPositionChannelDescriptor`, jeeb-gateway #339 `3c1015d`): the
/// topic to subscribe to, the Phoenix channel that routes it, the stream to
/// select, a device-reachable socket url, and a short-lived subscribe-only
/// credential scoped to that ONE topic.
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

  /// Product topic — `jeeb:delivery:{deliveryId}`. The credential is scoped to
  /// exactly this.
  final String topic;

  /// The Phoenix channel to join — `topic:{topic}`. Spelled out by the gateway
  /// so this client never has to reconstruct the service's routing prefix.
  final String channel;

  /// The envelope stream to keep — `location`. Load-bearing on the SERVER too:
  /// `LiveComm.Throttle` keys its policy table by stream name and `location`
  /// carries `interval_ms: 1000, distance_threshold_m: 5`, so positions are
  /// coalesced upstream rather than by us.
  final String stream;

  /// Guardian credential: one topic, `subscribe` only, minutes-long.
  final String token;

  /// Device-reachable WebSocket url, or `null` when the deployment has not
  /// configured `Services:Realtime:PublicSocketUrl`.
  ///
  /// `null` is the DEFAULT on the gateway, deliberately: `Services:Realtime:
  /// BaseUrl` is routinely a loopback the gateway dials, and deriving a socket
  /// url from it would hand a phone `ws://127.0.0.1/...`, which fails silently
  /// and reads as a product bug. So a null here means "this deployment has no
  /// device-reachable socket" and the only correct response is to degrade.
  final String? socketUrl;

  /// When [token] stops being accepted. Advisory here: Guardian verifies the
  /// credential at socket CONNECT, so an already-open subscription is not
  /// dropped when it lapses.
  final DateTime? expiresAt;
}

/// [CourierPositionChannel] over the gateway descriptor + the realtime Phoenix
/// socket.
///
/// ## The whole shape, in order
///
///  1. `GET /v1/realtime/jeeb:delivery:{deliveryId}` on the SAME authenticated
///     Dio the rest of the app uses. The gateway authenticates the caller and
///     asks delivery-service whether the delivery is theirs; a non-party gets
///     403 before any credential is minted.
///  2. If that yields a descriptor WITH a `socketUrl`, connect to it and join.
///  3. Anything else — 403, 404, 503, transport failure, a null or unusable
///     `socketUrl`, a refused join — returns `null`, and the tracking screen is
///     exactly what it was before this class existed.
///
/// ## The client never talks to the realtime service's own minter
///
/// `realtime-comunication-service` ships an OPEN, unauthenticated
/// `POST /api/auth/token` that hands out `topics: ["*"], scopes:
/// ["subscribe","publish"]` to anyone who asks — `ChatRealtimeResolver` uses it
/// today. This class deliberately does not: the gateway mints the credential
/// itself, narrowed to one delivery and to `subscribe`, precisely so a
/// customer's reach is bounded by something. If the gateway cannot mint one it
/// answers 503 and we degrade — we do NOT fall back to the open minter, because
/// the fallback would be a strictly larger grant than the thing that failed.
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
      // Unreachable host, rejected upgrade, TLS failure — all the same answer.
      await socket.close();
      return null;
    }
    return socket.positions;
  }

  /// Fetch the descriptor, or `null` on ANY failure. Total by construction: a
  /// tracking screen must never be faulted by a subscription that is not there.
  Future<DeliveryPositionChannelDescriptor?> resolve(String deliveryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/realtime/jeeb:delivery:$deliveryId',
      );
      return _parse(deliveryId, response.data);
    } on DioException {
      // 403 not-a-party, 404 unknown delivery, 400 unsafe id, 503 no credential
      // configured, or no route at all on an older gateway.
      return null;
    } catch (_) {
      // A malformed body reaches the wire through casts; "null on any failure"
      // is the contract, and enumerating a parser's throwables is how such a
      // promise comes to be false.
      return null;
    }
  }

  /// The gateway serializes its DTO camelCase (ASP.NET Core default, no STJ
  /// rename annotations). snake_case is accepted too, exactly as
  /// `ChatRealtimeResolver` does, so a serializer setting on the other side
  /// cannot silently blank the feed.
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
      // Derived ONLY as a fallback. The gateway sends `channel` so the routing
      // prefix is its decision, not ours; reconstructing it by default would
      // put the service's routing table back in the client.
      channel: (channel != null && channel.isNotEmpty) ? channel : 'topic:$topic',
      stream: (stream != null && stream.isNotEmpty) ? stream : 'location',
      token: token,
      socketUrl: socketUrl,
      expiresAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
    );
  }

  /// The socket url, or `null` when there is nothing usable to dial.
  ///
  /// Refuses a non-`ws(s)` scheme rather than trying it: an `http://` url here
  /// would be a deployment mistake, and dialling it produces an obscure
  /// transport error in place of a clean degrade.
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
