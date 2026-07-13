import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/rate_limit_interceptor.dart';

/// Lowest-level Dio adapter that returns a scripted [ResponseBody] per request
/// and counts how many actually reach the wire. A request suppressed by the
/// [RateLimitInterceptor] must NOT increment [callCount] — that is the whole
/// point of the back-off (F3: kill the offers polling storm on a 429).
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  int get callCount => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _body(int status, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?headers,
    });

void main() {
  late DateTime now;
  DateTime clock() => now;

  Dio buildDio(_ScriptedAdapter adapter) {
    now = DateTime.utc(2026, 7, 13, 12);
    final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'));
    dio.interceptors.add(
      RateLimitInterceptor(
        clock: clock,
        maxJitter: Duration.zero, // deterministic window in tests
      ),
    );
    dio.httpClientAdapter = adapter;
    return dio;
  }

  test('a 429 with Retry-After suppresses subsequent GET polls until it clears',
      () async {
    // Only the FIRST read that reaches the wire trips the 429; a suppressed
    // read never reaches the adapter, so the next wire hit (post-window) is 200.
    var wireHits = 0;
    final adapter = _ScriptedAdapter((opts) {
      wireHits++;
      return wireHits == 1
          ? _body(429, headers: {'retry-after': ['30']})
          : _body(200);
    });
    final dio = buildDio(adapter);

    // First poll trips the 429.
    await expectLater(
      dio.get<dynamic>('/deliveries'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);

    // A poll fired INSIDE the Retry-After window is short-circuited locally —
    // it never reaches the adapter (no retry-on-schedule into a 429).
    await expectLater(
      dio.get<dynamic>('/deliveries'),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      dio.get<dynamic>('/v1/offers', queryParameters: {'requestId': 'r-1'}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1, reason: 'suppressed reads must not hit the wire');

    // Once Retry-After (30s) elapses, reads flow again.
    now = now.add(const Duration(seconds: 31));
    final ok = await dio.get<dynamic>('/deliveries');
    expect(ok.statusCode, 200);
    expect(adapter.callCount, 2);
  });

  test(
      'a concurrent 2xx does NOT wipe an open Retry-After window '
      '(BUG-C fan-out storm regression)', () async {
    // Reproduces the run-26 storm: the customer-home poll fires many reads
    // near-simultaneously. When the gateway rate limits, ONE of the batch 429s
    // and opens the back-off window, but the OTHER in-flight reads — which
    // passed onRequest before the window opened — land as 2xx a moment later.
    // The OLD onResponse cleared the window on any 2xx, so that trailing success
    // wiped the pause and the next scheduled poll immediately re-hammered the
    // still rate-limited gateway. The window must now stand for the full
    // Retry-After regardless of concurrent successes.
    final adapter = _ScriptedAdapter((opts) {
      if (opts.path == '/req429') return _body(429, headers: {'retry-after': ['30']});
      return _body(200); // /req200 (the concurrent success) and /poll
    });
    final dio = buildDio(adapter);

    // Fire the 429-bound read and a sibling success CONCURRENTLY: both pass
    // onRequest (window still closed — the 429's onError runs only after its
    // async adapter resolves) and both reach the wire.
    final f429 = dio.get<dynamic>('/req429');
    final f200 = dio.get<dynamic>('/req200');
    await expectLater(f429, throwsA(isA<DioException>()));
    final ok = await f200;
    expect(ok.statusCode, 200);
    expect(adapter.callCount, 2, reason: 'both concurrent reads hit the wire');

    // The trailing 2xx must NOT have cleared the window: a poll fired inside the
    // still-open 30s window is short-circuited locally and never reaches the
    // wire. (Under the old clear-on-2xx logic this read would have hit the wire.)
    await expectLater(
      dio.get<dynamic>('/poll'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 2,
        reason: 'window still open after a concurrent success — poll suppressed');

    // And it still self-heals once Retry-After elapses.
    now = now.add(const Duration(seconds: 31));
    final resumed = await dio.get<dynamic>('/poll');
    expect(resumed.statusCode, 200);
    expect(adapter.callCount, 3);
  });

  test('writes (POST) are NEVER suppressed by the back-off window', () async {
    final adapter = _ScriptedAdapter(
      (opts) => opts.method == 'GET' && opts.path == '/requests'
          ? _body(429, headers: {'retry-after': ['60']})
          : _body(200),
    );
    final dio = buildDio(adapter);

    await expectLater(
      dio.get<dynamic>('/requests'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);

    // A user action (accept offer / create request) must go through even while
    // the read back-off window is open.
    final res = await dio.post<dynamic>('/v1/offers/accept', data: {'id': 'o-1'});
    expect(res.statusCode, 200);
    expect(adapter.callCount, 2, reason: 'the POST must reach the wire');
  });

  test('an absent Retry-After header still opens a default back-off window',
      () async {
    final adapter = _ScriptedAdapter(
      (opts) => opts.path == '/requests' ? _body(429) : _body(200),
    );
    final dio = buildDio(adapter);

    await expectLater(
      dio.get<dynamic>('/requests'),
      throwsA(isA<DioException>()),
    );
    // Within the default window the next read is suppressed.
    await expectLater(
      dio.get<dynamic>('/requests'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
  });

  test('Retry-After as an HTTP-date is honored', () async {
    final retryDate = httpDateOf(now.add(const Duration(seconds: 20)));
    var wireHits = 0;
    final adapter = _ScriptedAdapter((opts) {
      wireHits++;
      return wireHits == 1
          ? _body(429, headers: {'retry-after': [retryDate]})
          : _body(200);
    });
    final dio = buildDio(adapter);

    await expectLater(
      dio.get<dynamic>('/deliveries'),
      throwsA(isA<DioException>()),
    );
    // 10s later → still inside the 20s date window → suppressed.
    now = now.add(const Duration(seconds: 10));
    await expectLater(
      dio.get<dynamic>('/deliveries'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);

    // Past the date → flows again.
    now = now.add(const Duration(seconds: 15));
    final ok = await dio.get<dynamic>('/deliveries');
    expect(ok.statusCode, 200);
    expect(adapter.callCount, 2);
  });
}

/// Format a UTC [DateTime] as an IMF-fixdate (RFC 7231) HTTP header value.
String httpDateOf(DateTime dt) {
  const wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final u = dt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${wk[u.weekday - 1]}, ${two(u.day)} ${mo[u.month - 1]} ${u.year} '
      '${two(u.hour)}:${two(u.minute)}:${two(u.second)} GMT';
}
