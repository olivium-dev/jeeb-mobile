import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/realtime/phoenix_v2_frame.dart';
import '../domain/courier_position_channel.dart';

/// The default channel-level keepalive cadence.
///
/// ## This number is set by the SERVER, not chosen for comfort
///
/// `LiveCommWeb.Channels.TopicChannel` schedules an internal `:heartbeat`
/// message to itself every **25 s** and increments a `missed_heartbeats`
/// counter each time. At **3** it pushes an `error` frame
/// (`code: "heartbeat_timeout"`) and stops the channel — so a subscriber that
/// never speaks is disconnected after roughly **75 s**. The ONLY thing that
/// resets that counter is a client `ping` on the channel
/// (`handle_in("ping", …)`); the transport-level `phoenix`/`heartbeat` frame
/// does not, because it never reaches the channel process.
///
/// 20 s therefore leaves room for one lost frame before the server's 75 s
/// ceiling. A longer interval trades the glide for nothing.
///
/// ## Say plainly what this is
///
/// It is a periodic WRITE on a live socket, and `armed-poll-inventory.py` will
/// see it as a new timer site. It is **not** a poll and it does not make this a
/// poll: it carries no request for data, receives no body, and the positions it
/// keeps flowing arrive unbidden from the server. It is the cost of holding a
/// push transport open, and the alternative is not "fewer timers" — it is a
/// subscription that dies every 75 s and a marker that freezes with it.
const Duration kCourierPositionKeepAlive = Duration(seconds: 20);

/// A subscribe-only Phoenix client for ONE delivery's courier-position stream.
///
/// ## What it joins, and why that string is not obvious
///
/// `realtime-comunication-service` routes `channel "topic:*"` to
/// `LiveCommWeb.Channels.TopicChannel`, and the ACL is checked against the
/// topic with that routing prefix REMOVED. So the product topic is
/// `jeeb:delivery:{deliveryId}` — which is what the gateway scopes the
/// credential to — while the string actually joined is
/// `topic:jeeb:delivery:{deliveryId}`. The gateway spells both out in its
/// descriptor (`topic` and `channel`) precisely so this client does not have to
/// know the service's routing table; this class uses `channel` verbatim and
/// never reconstructs it.
///
/// The join payload carries `{"streams": ["location"]}`. `TopicChannel` records
/// it (`assign(:subscribed_streams, …)`) but does NOT filter its PubSub fan-out
/// by it — `handle_info({:event, envelope}, …)` pushes every envelope on the
/// topic. So the stream selection is declared on the join for the server's
/// benefit AND enforced here, on arrival. A client that trusted the join alone
/// would render whatever else was ever published on that topic.
///
/// ## Inbound shape
///
/// `TopicChannel` pushes product events as the event name `"event"` with a
/// `LiveComm.Protocol.Envelope` as the payload:
/// `{v, id, type, topic, stream, ts, seq, meta, data}`. The gateway's
/// `CourierPositionPublisher` puts the fix in `data` as
/// `{lat, lng, accuracy, deliveryId, jeeberId, timestamp}`.
///
/// ## Lifecycle
///
/// One socket, one channel, one delivery. [positions] is single-subscription
/// and OWNS the socket: cancelling it closes the WebSocket. It closes (rather
/// than erroring) on every failure — a transport that reports its own death as
/// an error the caller must catch is a transport that eventually faults a
/// screen.
///
/// There is deliberately **no reconnect**. A dropped socket leaves the tracking
/// screen on exactly the four triggers it had before this class existed (mount,
/// push, resume, retry), which is the specified degradation; a reconnect loop
/// would be a timer whose tick performs a gateway read, i.e. the poll this
/// whole line of work deleted.
class CourierPositionSocket {
  CourierPositionSocket({
    required Uri socketUri,
    required String token,
    required String channel,
    required String stream,
    WebSocketChannel Function(Uri uri)? channelFactory,
    Duration keepAlive = kCourierPositionKeepAlive,
  })  : _socketUri = socketUri,
        _token = token,
        _channel = channel,
        _stream = stream,
        _keepAlive = keepAlive,
        _channelFactory = channelFactory ?? WebSocketChannel.connect {
    _out = StreamController<CourierPositionFix>(onCancel: close);
  }

  final Uri _socketUri;

  /// The gateway-minted Guardian credential: ONE topic, `subscribe` only,
  /// minutes-long. Presented on the socket UPGRADE, which is where
  /// `LiveCommSocket.connect/3` reads it — a connect with no `token` param is
  /// rejected `missing_token` before any channel is reachable.
  final String _token;

  /// The full Phoenix channel to join, from the descriptor's `channel` field.
  final String _channel;

  /// The envelope stream to keep (`location`). Enforced on arrival — see the
  /// class doc on why the join payload alone is not a filter.
  final String _stream;

  final Duration _keepAlive;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  late final StreamController<CourierPositionFix> _out;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _frames;
  Timer? _keepAliveTimer;
  bool _closed = false;
  int _ref = 0;
  String? _joinRef;

  /// The live position feed. Single-subscription; cancelling closes the socket.
  Stream<CourierPositionFix> get positions => _out.stream;

  /// How many `location` fixes have actually ARRIVED on this socket.
  ///
  /// Counts arrivals, not arming, for the same reason the cubit's
  /// `debugPositionReadCount` does: the instrument it replaces in spirit
  /// (`debugPositionStreamWired`) returned `true` for a stream that had been
  /// opened once and dead ever since, which is how a silent feed went unnoticed
  /// for four days.
  int get frameCount => _frameCount;
  int _frameCount = 0;

  /// Connect and join. Throws on a transport failure so the caller can degrade;
  /// [CourierPositionChannel.open] is the one place that catches it.
  Future<void> connect() async {
    if (_socket != null) {
      throw StateError('CourierPositionSocket already connected');
    }
    final uri = _socketUri.replace(queryParameters: <String, String>{
      ..._socketUri.queryParameters,
      'vsn': '2.0.0',
      'token': _token,
    });
    final socket = _channelFactory(uri);
    _socket = socket;
    await socket.ready;
    _frames = socket.stream.listen(
      _onFrame,
      // A transport error is a DEATH, not something the screen should be asked
      // to handle: close the feed so the cubit's leg simply ends.
      onError: (Object _, StackTrace _) => unawaited(close()),
      onDone: () => unawaited(close()),
      cancelOnError: false,
    );
    _join();
    _keepAliveTimer = Timer.periodic(_keepAlive, (_) => _sendKeepAlive());
  }

  void _join() {
    final joinRef = '${++_ref}';
    _joinRef = joinRef;
    _send(PhoenixV2Frame.encode(
      joinRef: joinRef,
      ref: joinRef,
      topic: _channel,
      event: 'phx_join',
      payload: <String, Object?>{
        'streams': <String>[_stream],
      },
    ));
  }

  /// Both halves, on one timer: the CHANNEL `ping` that resets
  /// `TopicChannel.missed_heartbeats`, and the transport `heartbeat` that keeps
  /// the socket itself from being reaped. They are different mechanisms on
  /// different processes; sending only one of them still ends the subscription,
  /// just at a different timeout.
  void _sendKeepAlive() {
    _send(PhoenixV2Frame.encode(
      joinRef: _joinRef,
      ref: '${++_ref}',
      topic: _channel,
      event: 'ping',
    ));
    _send(PhoenixV2Frame.encodeTransportHeartbeat('${++_ref}'));
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null || _closed) return;
    try {
      socket.sink.add(frame);
    } catch (_) {
      // A sink that has already gone away. The close path is what tears the
      // rest down; a throw here would escape a Timer callback into the zone.
    }
  }

  void _onFrame(dynamic raw) {
    if (_out.isClosed) return;
    final frame = PhoenixV2Frame.decode(raw);
    if (frame == null) return;
    // Defensive: this socket joins exactly one channel.
    if (frame.topic != null && frame.topic != _channel) return;
    if (frame.isLifecycle) return;
    // `TopicChannel` names every product push `event` (replays come back as
    // `replay_event`, which this deliberately does not accept — a replayed fix
    // is a position the courier has already left).
    if (frame.event != 'event') return;
    final envelope = frame.payload;
    if (envelope == null) return;
    // THE stream filter. The server does not apply the join's `streams` to its
    // fan-out, so without this the map would move on anything ever published to
    // this delivery's topic.
    if (envelope['stream'] != _stream) return;
    final data = envelope['data'];
    if (data is! Map) return;
    final fix = _readFix(data.cast<String, Object?>());
    if (fix == null) return;
    _frameCount++;
    _out.add(fix);
  }

  /// Project one envelope `data` onto a fix, or `null` when it does not carry
  /// a usable one.
  ///
  /// `num`, not `double`: JSON `33` decodes to `int` and `as double` on it
  /// throws. That cast is the single most common way a wire projection turns a
  /// working feed into a silent one.
  CourierPositionFix? _readFix(Map<String, Object?> data) {
    final lat = data['lat'];
    final lng = data['lng'];
    if (lat is! num || lng is! num) return null;
    final accuracy = data['accuracy'];
    final timestamp = data['timestamp'];
    return CourierPositionFix(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      accuracy: accuracy is num ? accuracy.toDouble() : null,
      timestamp: timestamp is String ? DateTime.tryParse(timestamp) : null,
      jeeberId: data['jeeberId'] as String?,
    );
  }

  /// Idempotent. Reached from four directions — the subscriber cancelling, a
  /// transport error, the server closing the channel, and the cubit closing —
  /// so it must be safe to call twice.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    await _frames?.cancel();
    _frames = null;
    try {
      await _socket?.sink.close();
    } catch (_) {
      // Already-disposed sink — the intent (release) is satisfied.
    }
    _socket = null;
    // NOT awaited, and that is not laziness. This method is itself the
    // controller's `onCancel`, and `StreamController.close()` completes only
    // once the controller is done delivering — awaiting it from inside its own
    // cancel callback is a cycle. Closing is what matters; when it completes is
    // not observable to anyone here.
    if (!_out.isClosed) unawaited(_out.close());
  }
}
