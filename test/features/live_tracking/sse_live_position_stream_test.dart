import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/data/sse_live_position_stream.dart';

/// b02 wave C — N7, position axis.
///
/// The courier's POSITION is a STREAM, not an event, so a push cannot carry it.
/// The gateway already serves it as server-sent events — `StreamSseAsync`
/// (`Controllers/LocationController.cs:368-402`), reached via
/// `GET /v1/geo/jeeb/stream/{deliveryId}` (`:240`) when the request carries
/// `Accept: text/event-stream` (the negotiation at `:293-301`). SSE is
/// server-push: ONE held connection, and the gateway writes when it has
/// something, so it does not breach the no-polling rule.
///
/// No mobile `text/event-stream` consumer existed. This is it.
///
/// Wire format, verbatim from `EmitFrameAsync` (`:449-453`):
///   `event: position\ndata: {json}\n\n`   (or `event: last-seen` when stale)
/// serialized with `JsonSerializerDefaults.Web`, i.e. camelCase — the same
/// `position` / `polyline` shape the one-shot snapshot uses, which is why
/// `DeliveryTrackingInfo.fromTrackingJson` parses both.

/// Adapter that hands back a caller-driven byte stream, so a test can push SSE
/// frames one at a time and assert what the consumer emitted after each.
class _SseAdapter implements HttpClientAdapter {
  _SseAdapter({this.statusCode = 200});

  final int statusCode;
  final _bytes = StreamController<Uint8List>();
  RequestOptions? lastRequest;
  int fetchCount = 0;

  void emitRaw(String chunk) => _bytes.add(Uint8List.fromList(utf8.encode(chunk)));

  void emitFrame(String event, Map<String, Object?> data) =>
      emitRaw('event: $event\ndata: ${jsonEncode(data)}\n\n');

  Future<void> endStream() => _bytes.close();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    lastRequest = options;
    return ResponseBody(_bytes.stream, statusCode, headers: {
      Headers.contentTypeHeader: ['text/event-stream'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _frame({
  double lat = 33.88,
  double lng = 35.49,
  List<List<double>> polyline = const [
    [33.88, 35.49],
    [33.9, 35.5],
  ],
}) =>
    <String, Object?>{
      'deliveryId': 'DLV-N7',
      'jeeberId': 'JBR-1',
      'position': {'lat': lat, 'lng': lng, 'accuracy': 8.0},
      'polyline': polyline,
      'stale': false,
      'secondsSinceUpdate': 1.0,
      'serverTimestamp': '2026-07-27T10:00:00Z',
    };

/// The SSE open path crosses several async hops (Dio interceptor chain →
/// adapter → `onListen`), so a bare microtask drain is not enough to see the
/// request land. Real (tiny) delay, deliberately.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late Dio dio;
  late _SseAdapter adapter;

  setUp(() {
    adapter = _SseAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://gateway.invalid'))
      ..httpClientAdapter = adapter;
  });

  test('requests the SSE route with Accept: text/event-stream and NO receive '
      'timeout', () async {
    final stream = SseLivePositionStream(dio);
    final sub = stream.watchLivePosition(deliveryId: 'DLV-N7').listen((_) {});
    addTearDown(sub.cancel);
    await _settle();

    final req = adapter.lastRequest;
    expect(req, isNotNull);
    expect(req!.path, '/v1/geo/jeeb/stream/DLV-N7');
    expect(
      req.headers[Headers.acceptHeader],
      contains('text/event-stream'),
      reason: 'without this header the gateway content-negotiates DOWN to the '
          'one-shot JSON polyline snapshot (LocationController.cs:293-301) — '
          'the stream would never open and the marker would freeze silently',
    );
    expect(
      req.responseType,
      ResponseType.stream,
      reason: 'a buffered response type would wait for a body that never ends',
    );
    expect(
      req.receiveTimeout,
      Duration.zero,
      reason: 'the app-wide Dio sets receiveTimeout: 15s; a held SSE connection '
          'must disable it or the stream is torn down mid-delivery',
    );
    await adapter.endStream();
  });

  test('each SSE frame becomes exactly one position emission', () async {
    final stream = SseLivePositionStream(dio);
    final seen = <double>[];
    final sub = stream
        .watchLivePosition(deliveryId: 'DLV-N7')
        .listen((p) => seen.add(p.jeeberPosition!.lat));
    addTearDown(sub.cancel);
    await _settle();

    adapter.emitFrame('position', _frame(lat: 33.10));
    await _settle();
    adapter.emitFrame('position', _frame(lat: 33.20));
    await _settle();

    expect(seen, [33.10, 33.20]);
    expect(adapter.fetchCount, 1,
        reason: 'ONE held connection — not one request per frame');
    await adapter.endStream();
  });

  test('a frame split across two TCP chunks is still parsed once', () async {
    final stream = SseLivePositionStream(dio);
    final seen = <double>[];
    final sub = stream
        .watchLivePosition(deliveryId: 'DLV-N7')
        .listen((p) => seen.add(p.jeeberPosition!.lat));
    addTearDown(sub.cancel);
    await _settle();

    final whole = 'event: position\ndata: ${jsonEncode(_frame(lat: 34.5))}\n\n';
    final cut = whole.length ~/ 2;
    adapter.emitRaw(whole.substring(0, cut));
    await _settle();
    expect(seen, isEmpty, reason: 'a half frame must not emit');

    adapter.emitRaw(whole.substring(cut));
    await _settle();
    expect(seen, [34.5]);
    await adapter.endStream();
  });

  test('a last-seen (stale) frame still carries its position through',
      () async {
    final stream = SseLivePositionStream(dio);
    final seen = <double>[];
    final sub = stream
        .watchLivePosition(deliveryId: 'DLV-N7')
        .listen((p) => seen.add(p.jeeberPosition!.lat));
    addTearDown(sub.cancel);
    await _settle();

    adapter.emitFrame('last-seen', _frame(lat: 35.5));
    await _settle();
    expect(seen, [35.5],
        reason: 'the gateway switches the event NAME on staleness '
            '(LocationController.cs:446) but the frame still holds the last '
            'known fix — dropping it would blank a marker that should read '
            '"last seen here"');
    await adapter.endStream();
  });

  test('a malformed data line is skipped, not fatal to the stream', () async {
    final stream = SseLivePositionStream(dio);
    final seen = <double>[];
    var errored = false;
    final sub = stream
        .watchLivePosition(deliveryId: 'DLV-N7')
        .listen((p) => seen.add(p.jeeberPosition!.lat),
            onError: (_) => errored = true);
    addTearDown(sub.cancel);
    await _settle();

    adapter.emitRaw('event: position\ndata: {not json\n\n');
    await _settle();
    adapter.emitFrame('position', _frame(lat: 36.5));
    await _settle();

    expect(errored, isFalse);
    expect(seen, [36.5], reason: 'one bad frame must not kill the connection');
    await adapter.endStream();
  });

  test('a frame with no position and no polyline is dropped (nothing to '
      'overlay)', () async {
    final stream = SseLivePositionStream(dio);
    final seen = <Object?>[];
    final sub =
        stream.watchLivePosition(deliveryId: 'DLV-N7').listen(seen.add);
    addTearDown(sub.cancel);
    await _settle();

    adapter.emitRaw('event: position\ndata: {"deliveryId":"DLV-N7"}\n\n');
    await _settle();
    expect(seen, isEmpty,
        reason: 'an empty overlay must not clear a marker the screen already '
            'has — the pre-first-fix case');
    await adapter.endStream();
  });

  test('a non-200 (403 not-a-party) closes the stream without emitting',
      () async {
    adapter = _SseAdapter(statusCode: 403);
    dio = Dio(BaseOptions(baseUrl: 'http://gateway.invalid'))
      ..httpClientAdapter = adapter;
    final stream = SseLivePositionStream(dio);
    final seen = <Object?>[];
    var done = false;
    stream
        .watchLivePosition(deliveryId: 'DLV-N7')
        .listen(seen.add, onDone: () => done = true);
    await adapter.endStream();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(seen, isEmpty);
    expect(done, isTrue,
        reason: 'a 403 must terminate the stream cleanly, not hang open — the '
            'screen keeps its last-known marker');
  });
}
