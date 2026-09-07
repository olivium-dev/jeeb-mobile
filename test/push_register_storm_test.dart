import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/notifications/data/device_token_registrar.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';

/// DEVICE JUDGE F3 — during the live 502 window (device logcat pid 12173) the
/// app sent `PUT /api/PushNotification/register` 39 times in 62s while every
/// Cloudflare body carried `retry_after: 60`. These tests pin the properties
/// the registrar must hold: single-flight, bounded exponential backoff with
/// jitter, Retry-After obedience, and a bounded budget only a real trigger
/// re-arms.

/// The outage client: every PUT answers the way the Cloudflare edge did.
class _OutageDio extends Fake implements Dio {
  _OutageDio({
    required this.elapsed,
    this.retryAfterSeconds,
    this.retryAfterHeader,
  });

  /// Virtual elapsed time — `DateTime.now()` is not faked by fake_async.
  final Duration Function() elapsed;

  /// Body member `retry_after`, exactly as the live 502 pages carried it.
  final int? retryAfterSeconds;

  /// Response header, the RFC spelling.
  final int? retryAfterHeader;

  final List<Duration> calls = <Duration>[];
  int _concurrent = 0;
  int maxConcurrent = 0;

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls.add(elapsed());
    _concurrent++;
    if (_concurrent > maxConcurrent) maxConcurrent = _concurrent;
    // A real hop, so an overlapping caller is observable as concurrency.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _concurrent--;
    final requestOptions = RequestOptions(path: path);
    throw DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: requestOptions,
        statusCode: 502,
        headers: Headers.fromMap(<String, List<String>>{
          if (retryAfterHeader != null)
            'retry-after': <String>['$retryAfterHeader'],
        }),
        data: <String, dynamic>{
          'title': 'Error 502: Bad gateway',
          'status': 502,
          'error_name': 'origin_bad_gateway',
          'cloudflare_error': true,
          'retryable': true,
          if (retryAfterSeconds != null) 'retry_after': retryAfterSeconds,
        },
      ),
    );
  }
}

/// Never answers until released: the in-flight window single-flight must cover.
class _HangingDio extends Fake implements Dio {
  final List<String> paths = <String>[];
  final Completer<void> release = Completer<void>();

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    paths.add(path);
    await release.future;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
    );
  }
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) _data[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Future<AuthTokenStore> signedInStore({String userId = 'u1'}) async {
    final store = AuthTokenStore(storage: _FakeSecureStorage());
    await store.save(
      accessToken: 'mock-jwt-access-$userId',
      refreshToken: 'mock-refresh-$userId',
      userId: userId,
    );
    return store;
  }

  /// Runs [body] under fake time with an outage client wired to that same
  /// virtual clock, so both the registrar and the assertions read one timeline.
  void withOutage(
    AuthTokenStore tokenStore,
    FakePushTransport transport, {
    int? retryAfterSeconds,
    int? retryAfterHeader,
    required void Function(
      FakeAsync async,
      DeviceTokenRegistrar registrar,
      _OutageDio dio,
    ) body,
  }) {
    fakeAsync((async) {
      final dio = _OutageDio(
        elapsed: () => async.elapsed,
        retryAfterSeconds: retryAfterSeconds,
        retryAfterHeader: retryAfterHeader,
      );
      final registrar = DeviceTokenRegistrar(
        dio: dio,
        tokenStore: tokenStore,
        transport: transport,
        prefs: prefs,
        clock: () =>
            DateTime.fromMillisecondsSinceEpoch(async.elapsed.inMilliseconds),
      );
      body(async, registrar, dio);
      unawaited(registrar.dispose());
      async.flushMicrotasks();
    });
  }

  test(
      'F3: a 62s outage window does not become a register storm — backoff is '
      'exponential, not a flat 3s tick', () async {
    final tokenStore = await signedInStore();
    withOutage(
      tokenStore,
      FakePushTransport(token: 'fcm-storm-token'),
      body: (async, registrar, dio) {
        unawaited(registrar.start());
        // The device window: 62 seconds of unbroken 502s.
        async.elapse(const Duration(seconds: 62));
        async.flushMicrotasks();
        expect(
          dio.calls.length,
          lessThanOrEqualTo(6),
          reason: 'F3 measured 39 wire PUTs in 62s — 13 registrar rounds on a '
              'flat 3s tick, each fanned to 3 by RetryInterceptor. Exponential '
              'backoff off a 3s base rounds at 0/3/9/21/45s: at most 6 here.',
        );
      },
    );
  });

  test('F3: the gaps grow — each backoff is strictly longer than the last',
      () async {
    final tokenStore = await signedInStore();
    withOutage(
      tokenStore,
      FakePushTransport(token: 'fcm-growth-token'),
      body: (async, registrar, dio) {
        unawaited(registrar.start());
        async.elapse(const Duration(minutes: 10));
        async.flushMicrotasks();

        expect(dio.calls.length, greaterThanOrEqualTo(4),
            reason: 'the registrar must still retry — this fix is not a mute');
        final gaps = <Duration>[
          for (var i = 1; i < dio.calls.length; i++)
            dio.calls[i] - dio.calls[i - 1],
        ];
        for (var i = 1; i < gaps.length; i++) {
          expect(
            gaps[i],
            greaterThan(gaps[i - 1]),
            reason: 'gap ${i + 1} (${gaps[i]}) must exceed gap $i '
                '(${gaps[i - 1]}) — HEAD ticks a flat 3s forever',
          );
        }
      },
    );
  });

  test('F3: two installs do not retry in lockstep (jitter)', () async {
    final gapSets = <List<int>>[];
    for (var run = 0; run < 2; run++) {
      final tokenStore = await signedInStore(userId: 'jitter$run');
      withOutage(
        tokenStore,
        FakePushTransport(token: 'fcm-jitter-$run'),
        body: (async, registrar, dio) {
          unawaited(registrar.start());
          async.elapse(const Duration(minutes: 10));
          async.flushMicrotasks();
          gapSets.add(<int>[
            for (var i = 1; i < dio.calls.length; i++)
              (dio.calls[i] - dio.calls[i - 1]).inMilliseconds,
          ]);
        },
      );
    }
    expect(gapSets[0], isNotEmpty);
    expect(
      gapSets[0],
      isNot(equals(gapSets[1])),
      reason: 'identical schedules across installs are a thundering herd; the '
          'backoff must carry jitter',
    );
  });

  test('F3: a body `retry_after: 60` is obeyed — no second PUT inside 60s',
      () async {
    final tokenStore = await signedInStore();
    withOutage(
      tokenStore,
      FakePushTransport(token: 'fcm-retryafter-token'),
      retryAfterSeconds: 60,
      body: (async, registrar, dio) {
        unawaited(registrar.start());
        async.elapse(const Duration(seconds: 59));
        async.flushMicrotasks();
        expect(dio.calls.length, 1,
            reason: 'the 502 body said "back off for at least 60 seconds"');

        async.elapse(const Duration(seconds: 40));
        async.flushMicrotasks();
        expect(dio.calls.length, greaterThanOrEqualTo(2),
            reason: 'after the honoured window the registrar must try again');
      },
    );
  });

  test('F3: a `Retry-After: 45` header is obeyed too', () async {
    final tokenStore = await signedInStore();
    withOutage(
      tokenStore,
      FakePushTransport(token: 'fcm-header-token'),
      retryAfterHeader: 45,
      body: (async, registrar, dio) {
        unawaited(registrar.start());
        async.elapse(const Duration(seconds: 44));
        async.flushMicrotasks();
        expect(dio.calls.length, 1);

        async.elapse(const Duration(seconds: 40));
        async.flushMicrotasks();
        expect(dio.calls.length, greaterThanOrEqualTo(2));
      },
    );
  });

  test('F3: concurrent 502 rounds never overlap on the wire', () async {
    final tokenStore = await signedInStore();
    withOutage(
      tokenStore,
      FakePushTransport(token: 'fcm-overlap-token'),
      body: (async, registrar, dio) {
        // start + login + resume inside one window: the three-chain overlap
        // the device log showed.
        unawaited(registrar.start());
        unawaited(registrar.notifyLogin());
        unawaited(registrar.revalidate());
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();
        expect(dio.maxConcurrent, 1,
            reason: 'overlapping PUTs are the burst signature');
      },
    );
  });

  test(
      'F3: the attempt budget is bounded per session, and an app resume inside '
      'the backoff window does not re-fire', () async {
    final tokenStore = await signedInStore();
    withOutage(
      tokenStore,
      FakePushTransport(token: 'fcm-budget-token'),
      body: (async, registrar, dio) {
        unawaited(registrar.start());
        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        final spent = dio.calls.length;
        expect(spent, lessThanOrEqualTo(10),
            reason: 'a bounded budget, not 40 rounds x 3 wire sends');

        // Ten app resumes while the outage continues: none may add a PUT — the
        // budget is spent and the cooldown window is still open.
        for (var i = 0; i < 10; i++) {
          unawaited(registrar.revalidate());
          async.elapse(const Duration(seconds: 1));
        }
        async.flushMicrotasks();
        expect(dio.calls.length, spent,
            reason: 'resume must not re-arm inside the backoff window');

        // Past the cooldown a resume is a real trigger again — exactly one PUT.
        async.elapse(const Duration(minutes: 20));
        async.flushMicrotasks();
        expect(dio.calls.length, spent,
            reason: 'nothing is armed once the budget is spent');
        unawaited(registrar.revalidate());
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(dio.calls.length, spent + 1,
            reason: 'resume after the cooldown re-arms one attempt');
      },
    );
  });

  test('F3: a real trigger (FCM token rotation) re-arms after exhaustion',
      () async {
    final tokenStore = await signedInStore();
    final transport = FakePushTransport(token: 'fcm-rotate-v1');
    withOutage(
      tokenStore,
      transport,
      body: (async, registrar, dio) {
        unawaited(registrar.start());
        async.elapse(const Duration(minutes: 30));
        async.flushMicrotasks();
        final spent = dio.calls.length;

        transport.emitTokenRefresh('fcm-rotate-v2');
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(dio.calls.length, spent + 1,
            reason: 'a rotated token is a new registration — exactly one PUT');
      },
    );
  });

  test('F3: registration is single-flight — concurrent triggers share one PUT',
      () async {
    final tokenStore = await signedInStore();
    final dio = _HangingDio();
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: FakePushTransport(token: 'fcm-singleflight-token'),
      prefs: prefs,
    );
    unawaited(registrar.start());
    unawaited(registrar.notifyLogin());
    unawaited(registrar.revalidate());
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(dio.paths.length, 1,
        reason: 'one in-flight registration per (user, token), not three');

    dio.release.complete();
    await Future<void>.delayed(Duration.zero);
    await registrar.dispose();
  });
}
