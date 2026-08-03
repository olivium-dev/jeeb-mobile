import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/dev_seam/session_seam_bootstrap.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the journey-seed POST the [SessionSeamBootstrap] fires so the test
/// can assert the path + body without a real socket. Returns a fixed 200.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? captured;
  Map<String, dynamic>? capturedBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    final data = options.data;
    if (data is Map) {
      capturedBody = Map<String, dynamic>.from(data);
    }
    return ResponseBody.fromString(
      jsonEncode({'seeded': true, 'journey': data is Map ? data['journey'] : null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// A never-resolving adapter that models a stalled/unresponsive mock. The seam
/// must NOT wait on it indefinitely — its bounded timeout has to win so the
/// first frame (and the shell tab bar) is never held for the full Dio window.
class _HangingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    // Never completes — the seam's `.timeout` must be what unblocks boot.
    return Completer<ResponseBody>().future;
  }
}

/// A no-op token store so the seam's session seeding doesn't hit the secure
/// storage platform channel in a headless test.
class _FakeTokenStore implements AuthTokenStore {
  String? savedUserId;

  @override
  Future<String?> get accessToken async => null;
  @override
  Future<String?> get refreshToken async => null;
  @override
  Future<String?> get userId async => savedUserId;
  @override
  Future<bool> get hasToken async => savedUserId != null;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    savedUserId = userId;
  }

  @override
  Future<void> clear() async {
    savedUserId = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(DevSeam.debugReset);

  Future<SharedPreferences> freshPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  Dio dioWith(_RecordingAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:4010'));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  test('journey seed POSTs the wire value to /__mock/seed/journey', () async {
    if (!kDebugMode) return; // the seam is release-inert
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.customerLoggedIn,
      journeySeed: JourneySeed.deliveryMarkedDone,
    ));
    final prefs = await freshPrefs();
    final adapter = _RecordingAdapter();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dioWith(adapter),
    );

    expect(adapter.captured, isNotNull);
    expect(adapter.captured!.path, '/__mock/seed/journey');
    expect(adapter.captured!.method, 'POST');
    expect(adapter.capturedBody?['journey'], 'delivery_marked_done');
  });

  test('a W4 journey (has_notifications) POSTs its wire value to the mock',
      () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.customerLoggedIn,
      journeySeed: JourneySeed.hasNotifications,
    ));
    final prefs = await freshPrefs();
    final adapter = _RecordingAdapter();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dioWith(adapter),
    );

    expect(adapter.captured!.path, '/__mock/seed/journey');
    expect(adapter.capturedBody?['journey'], 'has_notifications');
  });

  test('a journey-only launch (no session seed) still seeds the mock', () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      journeySeed: JourneySeed.hasSavedAddresses,
    ));
    final prefs = await freshPrefs();
    final adapter = _RecordingAdapter();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dioWith(adapter),
    );

    expect(adapter.capturedBody?['journey'], 'has_saved_addresses');
  });

  test('no journey seed → no mock POST', () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.customerLoggedIn,
    ));
    final prefs = await freshPrefs();
    final adapter = _RecordingAdapter();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dioWith(adapter),
    );

    expect(adapter.captured, isNull);
  });

  test('the customer session seed sets the role + token alongside the journey',
      () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.customerLoggedIn,
      journeySeed: JourneySeed.activeDelivery,
    ));
    final prefs = await freshPrefs();
    final tokens = _FakeTokenStore();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: tokens,
      mockSeedClient: dioWith(_RecordingAdapter()),
    );

    expect(tokens.savedUserId, SessionSeamBootstrap.customerUserId);
  });

  test('a failing mock POST never throws (degrades to no-seed)', () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      journeySeed: JourneySeed.offersReceived,
    ));
    final prefs = await freshPrefs();
    // A Dio with no working adapter base → the POST throws; seed must swallow it.
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));

    await expectLater(
      SessionSeamBootstrap.seed(
        prefs: prefs,
        tokenStore: _FakeTokenStore(),
        mockSeedClient: dio,
      ),
      completes,
    );
  });

  // LANDING-FIX regression (64 jm-027/028/029): a stalled/unresponsive mock
  test('a hung mock POST is bounded — seed() completes fast, never blocks boot',
      () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.customerLoggedIn,
      journeySeed: JourneySeed.offersReceived, // shell-landing journey
    ));
    final prefs = await freshPrefs();
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:4010'))
      ..httpClientAdapter = _HangingAdapter();

    final sw = Stopwatch()..start();
    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dio,
    );
    sw.stop();

    // Ceiling: the seam's internal `_journeySeedTimeout` is 10s, so the bound
    expect(sw.elapsed, lessThan(const Duration(seconds: 15)),
        reason: 'journey-seed POST must be timeout-bounded so it cannot hold '
            'the first frame for the full Dio connect+receive window');
  });
}
