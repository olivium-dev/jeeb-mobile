import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/dev_seam/session_seam_bootstrap.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records EVERY mock-seed POST the [SessionSeamBootstrap] fires (journey + kyc
/// + wallet can all fire in one `seed()`), keyed by path, so the W2 tests can
/// assert each endpoint independently without a real socket.
class _MultiRecordingAdapter implements HttpClientAdapter {
  final Map<String, Map<String, dynamic>> byPath = {};
  final List<String> paths = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final data = options.data;
    if (data is Map) {
      byPath[options.path] = Map<String, dynamic>.from(data);
    }
    return ResponseBody.fromString(
      jsonEncode({'seeded': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// No-op token store so the seam's session seeding doesn't hit secure storage.
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

  Dio dioWith(_MultiRecordingAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:4010'));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  group('KycStatusSeed / WalletStateSeed parsing', () {
    test('kyc_status round-trips through fromWire (excluding none)', () {
      for (final seed in KycStatusSeed.values) {
        if (seed == KycStatusSeed.none) continue;
        expect(KycStatusSeed.fromWire(seed.wireValue), seed);
      }
    });

    test('wallet_state round-trips through fromWire (excluding none)', () {
      for (final seed in WalletStateSeed.values) {
        if (seed == WalletStateSeed.none) continue;
        expect(WalletStateSeed.fromWire(seed.wireValue), seed);
      }
    });

    test('absent / unknown values → none (no crash)', () {
      expect(KycStatusSeed.fromWire(null), KycStatusSeed.none);
      expect(KycStatusSeed.fromWire(''), KycStatusSeed.none);
      expect(KycStatusSeed.fromWire('bogus'), KycStatusSeed.none);
      expect(WalletStateSeed.fromWire(null), WalletStateSeed.none);
      expect(WalletStateSeed.fromWire('bogus'), WalletStateSeed.none);
    });

    test('fromMap maps both W2 seam keys', () {
      final config = DevSeamConfig.fromMap({
        'jeeb.seam.kyc_status': 'approved',
        'jeeb.seam.wallet_state': 'insufficient',
      });
      expect(config.kycStatusSeed, KycStatusSeed.approved);
      expect(config.walletStateSeed, WalletStateSeed.insufficient);
      expect(config.hasKycStatusSeed, isTrue);
      expect(config.hasWalletStateSeed, isTrue);
      expect(config.isEmpty, isFalse);
    });
  });

  group('new W2 JourneySeed values', () {
    test('route pins match the W2 contract', () {
      expect(JourneySeed.jeeberKycSubmitted.routePin,
          '/jeeber/onboarding/funding');
      expect(JourneySeed.jeeberActiveDelivery.routePin,
          '/jeeber/deliveries/del-jeeber-002-active/active');
      expect(JourneySeed.jeeberFeedWithRequest.routePin, isEmpty);
      expect(JourneySeed.jeeberPendingOffers.routePin, isEmpty);
    });

    test('wire values round-trip', () {
      expect(JourneySeed.fromWire('jeeber_kyc_submitted'),
          JourneySeed.jeeberKycSubmitted);
      expect(JourneySeed.fromWire('jeeber_feed_with_request'),
          JourneySeed.jeeberFeedWithRequest);
      expect(JourneySeed.fromWire('jeeber_pending_offers'),
          JourneySeed.jeeberPendingOffers);
      expect(JourneySeed.fromWire('jeeber_active_delivery'),
          JourneySeed.jeeberActiveDelivery);
    });
  });

  test('kyc seed POSTs { kycStatus, userId } to /__mock/seed/kyc', () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.jeeberLoggedIn,
      kycStatusSeed: KycStatusSeed.approved,
    ));
    final prefs = await freshPrefs();
    final adapter = _MultiRecordingAdapter();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dioWith(adapter),
    );

    expect(adapter.byPath['/__mock/seed/kyc'], isNotNull);
    expect(adapter.byPath['/__mock/seed/kyc']!['kycStatus'], 'approved');
    expect(adapter.byPath['/__mock/seed/kyc']!['userId'],
        SessionSeamBootstrap.jeeberUserId);
  });

  // The first-frame DELIVERY-tab/offer gate reads DevSeam.current.kycStatusSeed
  // synchronously via the integrator's SeamJeeberKycStatusGate — no prefs, no
  // race. These assert the seam field drives that gate exactly per the contract.
  test('SeamJeeberKycStatusGate maps the seeded kyc status', () {
    if (!kDebugMode) return;
    DevSeam.debugOverride(
        const DevSeamConfig(kycStatusSeed: KycStatusSeed.approved));
    expect(const SeamJeeberKycStatusGate().status, JeeberKycStatus.approved);
    expect(const SeamJeeberKycStatusGate().isApproved, isTrue);

    DevSeam.debugOverride(
        const DevSeamConfig(kycStatusSeed: KycStatusSeed.statusNone));
    expect(const SeamJeeberKycStatusGate().status, JeeberKycStatus.none);
    expect(const SeamJeeberKycStatusGate().isApproved, isFalse);

    DevSeam.debugOverride(
        const DevSeamConfig(kycStatusSeed: KycStatusSeed.pending));
    expect(const SeamJeeberKycStatusGate().status, JeeberKycStatus.pending);

    DevSeam.debugOverride(
        const DevSeamConfig(kycStatusSeed: KycStatusSeed.rejected));
    expect(const SeamJeeberKycStatusGate().status, JeeberKycStatus.rejected);
  });

  test('wallet seed POSTs { state, userId } to /__mock/seed/wallet', () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.jeeberLoggedIn,
      walletStateSeed: WalletStateSeed.insufficient,
    ));
    final prefs = await freshPrefs();
    final adapter = _MultiRecordingAdapter();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dioWith(adapter),
    );

    expect(adapter.byPath['/__mock/seed/wallet'], isNotNull);
    expect(adapter.byPath['/__mock/seed/wallet']!['state'], 'insufficient');
    expect(adapter.byPath['/__mock/seed/wallet']!['userId'],
        SessionSeamBootstrap.jeeberUserId);
  });

  test('JM-045-shaped launch fires all three seeds (journey + kyc + wallet)',
      () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.jeeberLoggedIn,
      kycStatusSeed: KycStatusSeed.approved,
      walletStateSeed: WalletStateSeed.sufficient,
      journeySeed: JourneySeed.jeeberFeedWithRequest,
    ));
    final prefs = await freshPrefs();
    final adapter = _MultiRecordingAdapter();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dioWith(adapter),
    );

    expect(adapter.byPath['/__mock/seed/journey']?['journey'],
        'jeeber_feed_with_request');
    expect(adapter.byPath['/__mock/seed/kyc']?['kycStatus'], 'approved');
    expect(adapter.byPath['/__mock/seed/wallet']?['state'], 'sufficient');
  });

  test('no W2 seam → no kyc/wallet POST', () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.jeeberLoggedIn,
    ));
    final prefs = await freshPrefs();
    final adapter = _MultiRecordingAdapter();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dioWith(adapter),
    );

    expect(adapter.byPath.containsKey('/__mock/seed/kyc'), isFalse);
    expect(adapter.byPath.containsKey('/__mock/seed/wallet'), isFalse);
  });

  test('a kyc/wallet-only launch (no session) still seeds the mock', () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      kycStatusSeed: KycStatusSeed.pending,
      walletStateSeed: WalletStateSeed.empty,
    ));
    final prefs = await freshPrefs();
    final adapter = _MultiRecordingAdapter();

    await SessionSeamBootstrap.seed(
      prefs: prefs,
      tokenStore: _FakeTokenStore(),
      mockSeedClient: dioWith(adapter),
    );

    expect(adapter.byPath['/__mock/seed/kyc']?['kycStatus'], 'pending');
    expect(adapter.byPath['/__mock/seed/wallet']?['state'], 'empty');
  });

  test('a failing kyc/wallet POST never throws (degrades to no-seed)', () async {
    if (!kDebugMode) return;
    DevSeam.debugOverride(const DevSeamConfig(
      sessionSeed: SessionSeed.jeeberLoggedIn,
      kycStatusSeed: KycStatusSeed.approved,
      walletStateSeed: WalletStateSeed.sufficient,
    ));
    final prefs = await freshPrefs();
    // No working adapter base → the POST throws; seed must swallow it.
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
}
