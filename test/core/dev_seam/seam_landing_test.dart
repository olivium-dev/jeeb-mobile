import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_source.dart';
import 'package:jeeb_mobile/core/dev_seam/session_seam_bootstrap.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SEAM-LANDING REGRESSION GUARD (66_W2_QA_RESULTS).
///
/// The dev-seam landing has now broken TWICE (RC-1 in 61, then the W2 0/18 in
/// 66 — a boot-hold on the 2nd `clearState` launch). This suite locks the
/// landing CONTRACT (62_SEAM_HARNESS §0/§3, the W1 §W1-0 table, the W2 §W2-0
/// table) at the level future waves actually regress: the resolved
/// `DevSeamConfig` and the REAL state each seam writes that the router's
/// gates + route pin read on the first redirect. If any future change makes a
/// seam value stop landing on its documented screen, one of these fails.
///
/// Two layers, both source-of-truth:
///   1. SESSION landing — `SessionSeamBootstrap.seed()` seeds the SAME prefs +
///      token store the `OnboardingCubit` / `RoleCubit` / `SessionCubit`
///      (`SessionGate`) read; this asserts the seeded state matches the gate
///      inputs that `app_router._firstRunRedirect` keys on for the documented
///      destination.
///   2. JOURNEY/KYC/WALLET landing — `DevSeam.resolve()` folds the journey's
///      route pin into `DevSeamConfig.route` (the EXISTING `_devRoute` pin the
///      router lands on); this asserts each value pins (or deliberately does
///      NOT pin) the documented deep route.
///
/// Boot-hold guard: the mock-seed POSTs must NEVER hold boot. `seed(...,
/// awaitMockSeed: false)` (the production `Bootstrap.minimal` call) must
/// complete promptly even when the mock is hung, AND must still seed the local
/// session state (the landing decider) synchronously.

/// In-memory token store so the seam's `_logIn` / `clear` don't touch the
/// secure-storage platform channel in a headless test. Mirrors the real
/// `AuthTokenStore` surface.
class _MemTokenStore implements AuthTokenStore {
  String? _access;
  String? _refresh;
  String? _userId;

  @override
  Future<String?> get accessToken async => _access;
  @override
  Future<String?> get refreshToken async => _refresh;
  @override
  Future<String?> get userId async => _userId;
  @override
  Future<bool> get hasToken async => _access != null;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    _userId = userId;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _userId = null;
  }
}

/// A dev-seam source list that yields a single fixed config — drives the REAL
/// `DevSeam.resolve()` (including the journey route-pin fold) without intent
/// extras / a device file / dart-defines.
class _FixedSource implements DevSeamSource {
  const _FixedSource(this.config);
  final DevSeamConfig config;
  @override
  Future<DevSeamConfig> read() async => config;
}

/// A never-resolving adapter — models a stalled/unreachable mock. The detached
/// mock-seed POST must NOT hold boot when `awaitMockSeed: false`.
class _HangingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      Completer<ResponseBody>().future; // never completes
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(DevSeam.debugReset);

  Future<SharedPreferences> freshPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  /// Resolves the seam through the REAL `DevSeam.resolve()` from a single fixed
  /// source so the journey route-pin fold (`_applyJourneyRoutePin`) runs exactly
  /// as in production.
  Future<void> resolveSeam(DevSeamConfig config) =>
      DevSeam.resolve(sources: [_FixedSource(config)]);

  // ── 1. SESSION landing contract (62 §3) ────────────────────────────────────
  // Each value seeds onboarding/role/token/biometric/account-status; we assert
  // the seeded state == the gate inputs the router redirect keys on for the
  // documented destination.
  group('jeeb.seam.session lands per 62 §3', () {
    test('customer_logged_in → onboarded + role=client + token (→ shell '
        'Requests tab)', () async {
      if (!kDebugMode) return;
      await resolveSeam(
          const DevSeamConfig(sessionSeed: SessionSeed.customerLoggedIn));
      final prefs = await freshPrefs();
      final tokens = _MemTokenStore();

      await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);

      // Onboarding complete → the redirect does NOT send to /onboarding.
      expect(OnboardingCubit(prefs: prefs).isCompleted, isTrue);
      // role=client → ShellScreen renders the customer tab set (Requests first).
      expect(RoleCubit(prefs: prefs).state, UserRole.client);
      // Token present → SessionGate is authenticated → shell `/` allowed.
      expect(await tokens.hasToken, isTrue);
      expect(await tokens.userId, SessionSeamBootstrap.customerUserId);
      // Not biometric-locked, not account-blocked.
      expect(
          prefs.getBool(BiometricPreferenceRepositoryImpl.kEnabledKey), isNull);
      expect(prefs.getBool(SessionSeamBootstrap.kAccountBlockedKey), isNull);
    });

    test('jeeber_logged_in → onboarded + role=jeeber + token (→ shell '
        'Dashboard tab)', () async {
      if (!kDebugMode) return;
      await resolveSeam(
          const DevSeamConfig(sessionSeed: SessionSeed.jeeberLoggedIn));
      final prefs = await freshPrefs();
      final tokens = _MemTokenStore();

      await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);

      expect(OnboardingCubit(prefs: prefs).isCompleted, isTrue);
      expect(RoleCubit(prefs: prefs).state, UserRole.jeeber);
      expect(await tokens.hasToken, isTrue);
      expect(await tokens.userId, SessionSeamBootstrap.jeeberUserId);
    });

    test('logged_out_returning → onboarded + NO token (→ /login)', () async {
      if (!kDebugMode) return;
      await resolveSeam(
          const DevSeamConfig(sessionSeed: SessionSeed.loggedOutReturning));
      final prefs = await freshPrefs();
      final tokens = _MemTokenStore();

      await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);

      expect(OnboardingCubit(prefs: prefs).isCompleted, isTrue);
      // No token → SessionGate.isUnauthenticated → redirect to /login.
      expect(await tokens.hasToken, isFalse);
    });

    test('biometric_enrolled → onboarded + token + biometric enabled + PIN '
        '(→ /lock)', () async {
      if (!kDebugMode) return;
      await resolveSeam(
          const DevSeamConfig(sessionSeed: SessionSeed.biometricEnrolled));
      final prefs = await freshPrefs();
      final tokens = _MemTokenStore();

      await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);

      expect(await tokens.hasToken, isTrue);
      // enabled + PIN → BiometricLockCubit holds /lock on the unavailable gateway.
      expect(prefs.getBool(BiometricPreferenceRepositoryImpl.kEnabledKey), true);
      expect(prefs.getString(SharedPrefsPinRepository.kPinKey), '0000');
    });

    test('biometric_enrolled_logged_out → onboarded + NO token + biometric '
        'enabled (→ /login + affordance)', () async {
      if (!kDebugMode) return;
      await resolveSeam(const DevSeamConfig(
          sessionSeed: SessionSeed.biometricEnrolledLoggedOut));
      final prefs = await freshPrefs();
      final tokens = _MemTokenStore();

      await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);

      expect(OnboardingCubit(prefs: prefs).isCompleted, isTrue);
      expect(await tokens.hasToken, isFalse);
      // The login biometric affordance keys on the enabled preference.
      expect(prefs.getBool(BiometricPreferenceRepositoryImpl.kEnabledKey), true);
    });

    test('suspended → onboarded + token + account-blocked flag '
        '(→ /account-status)', () async {
      if (!kDebugMode) return;
      await resolveSeam(
          const DevSeamConfig(sessionSeed: SessionSeed.suspended));
      final prefs = await freshPrefs();
      final tokens = _MemTokenStore();

      await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);

      expect(await tokens.hasToken, isTrue);
      // SeededAccountStatusGate.isBlocked reads this flag → /account-status.
      expect(prefs.getBool(SessionSeamBootstrap.kAccountBlockedKey), true);
    });

    test('a re-seed (2nd launch) resets prior state — a later un-seeded launch '
        'is pristine', () async {
      if (!kDebugMode) return;
      final prefs = await freshPrefs();
      final tokens = _MemTokenStore();

      // 1st launch: suspended customer.
      await resolveSeam(
          const DevSeamConfig(sessionSeed: SessionSeed.suspended));
      await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);
      expect(prefs.getBool(SessionSeamBootstrap.kAccountBlockedKey), true);

      // 2nd launch (same Maestro session): logged_out_returning must NOT inherit
      // the blocked flag, the role, or the token from launch 1.
      await resolveSeam(
          const DevSeamConfig(sessionSeed: SessionSeed.loggedOutReturning));
      await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);
      expect(prefs.getBool(SessionSeamBootstrap.kAccountBlockedKey), isNull);
      expect(prefs.getString(RoleCubit.rolePrefKey), isNull);
      expect(await tokens.hasToken, isFalse);
    });
  });

  // ── 2. JOURNEY route-pin landing contract (62 §W1-0 + §W2-0) ────────────────
  // The resolved DevSeamConfig.route IS the router's `_devRoute` pin. Assert each
  // journey pins (or deliberately does NOT pin) its documented deep route.
  group('jeeb.seam.journey route pin lands per the contract', () {
    final expectedPins = <JourneySeed, String>{
      // W1 (63 §4.3 / 62 §W1-0)
      JourneySeed.pendingRequest: '/requests/req-client-001-pending/waiting',
      JourneySeed.pendingRequestNoCoverage:
          '/requests/req-client-001-pending/waiting',
      JourneySeed.offersReceived: '', // shell landing — flow navigates
      JourneySeed.orderAccepted: '/chat/conv-journey-accepted',
      JourneySeed.activeDelivery: '/orders/del-client-001-active/tracking',
      JourneySeed.deliveryMarkedDone:
          '/orders/del-client-001-delivered/receipt',
      JourneySeed.jeeberRatingPending:
          '/orders/del-jeeber-002-delivered/mutual-rate?mode=jeeber',
      JourneySeed.hasSavedAddresses: '', // shell landing — flow navigates
      // W2 (65 §3.3 / 62 §W2-0)
      JourneySeed.jeeberKycSubmitted: '/jeeber/onboarding/funding',
      JourneySeed.jeeberFeedWithRequest: '', // shell landing
      JourneySeed.jeeberPendingOffers: '', // shell landing
      JourneySeed.jeeberActiveDelivery:
          '/jeeber/deliveries/del-jeeber-002-active/active',
      // W3/W4 (30_BACKLOG W3/W4 / 62 §W3-W4)
      JourneySeed.hasNotifications: '/notifications',
      JourneySeed.disputeOpen: '/disputes/dispute-client-001-open',
      JourneySeed.jeeberHasReviews: '', // shell landing — flow navigates
      JourneySeed.walletWithLedger: '', // shell landing — flow navigates
      // W3/W4 flow-contract values (67_W34_TEST_PLAN). Each flow passes an
      // explicit `jeeb.route`, so these journeys carry NO own route pin (the
      // explicit route lands them); the journey value only drives the mock seed.
      JourneySeed.jeeberWalletFeeTxn: '',
      JourneySeed.jeeberWalletRefundTxn: '',
      JourneySeed.hasOpenDispute: '',
      JourneySeed.jeeberColdStartProfile: '',
      JourneySeed.jeeberWalletLedger: '',
    };

    // The session a flow pairs with each journey (a journey is always layered
    // on a `jeeb.seam.session` base seed). Customer journeys pair with the
    // customer session; jeeber-side journeys with the jeeber session. The pin
    // is independent of this choice (it is folded from the journey alone), but
    // pairing exactly as a flow does keeps the contract honest. Defaults are
    // derived from the name heuristic; entries here OVERRIDE that heuristic
    // where the name does not match the journey's role.
    final sessionForJourney = <JourneySeed, SessionSeed>{
      // `jeeber_has_reviews` is exercised by a CUSTOMER viewing a jeeber's
      // public profile (JM-067), so it pairs with the customer session even
      // though its name starts with "jeeber".
      JourneySeed.jeeberHasReviews: SessionSeed.customerLoggedIn,
      // `wallet_with_ledger` is a JEEBER money surface (JM-052/055/056), so it
      // pairs with the jeeber session even though its name starts with "wallet".
      JourneySeed.walletWithLedger: SessionSeed.jeeberLoggedIn,
    };

    test('every JourneySeed is covered by this contract (no silent additions)',
        () {
      // If a future wave adds a JourneySeed, this forces a landing decision here
      // rather than letting it ship with an unverified landing.
      final covered = {...expectedPins.keys, JourneySeed.none};
      expect(covered, containsAll(JourneySeed.values),
          reason: 'A new JourneySeed was added without a landing assertion — '
              'add it to expectedPins with its documented route pin (or "" for '
              'a shell-landing journey).');
    });

    for (final entry in expectedPins.entries) {
      test('${entry.key.name} pins "${entry.value.isEmpty ? '(shell)' : entry.value}"',
          () async {
        if (!kDebugMode) return;
        // Pair with a session seed exactly as a flow does (session + journey).
        final session = sessionForJourney[entry.key] ??
            (entry.key.name.startsWith('jeeber')
                ? SessionSeed.jeeberLoggedIn
                : SessionSeed.customerLoggedIn);
        await resolveSeam(DevSeamConfig(
          sessionSeed: session,
          journeySeed: entry.key,
        ));
        expect(DevSeam.current.route, entry.value,
            reason: '${entry.key.name} must land on '
                '"${entry.value}" via the route pin');
      });
    }

    test('an explicit jeeb.route overrides a journey route pin', () async {
      if (!kDebugMode) return;
      await resolveSeam(const DevSeamConfig(
        route: '/custom/deep/link',
        sessionSeed: SessionSeed.customerLoggedIn,
        journeySeed: JourneySeed.activeDelivery, // would otherwise pin /tracking
      ));
      expect(DevSeam.current.route, '/custom/deep/link');
    });
  });

  // ── 3. KYC / WALLET state landing (62 §W2-0) ────────────────────────────────
  // These deliberately have NO route pin of their own — they seed CONTENT, not a
  // landing. The session seed decides where the app lands; the kyc/wallet value
  // drives what the jeeber screens render there.
  group('kyc_status / wallet_state do not pin a route (state seeds only)', () {
    test('kyc_status=approved + jeeber session lands on the shell (no own pin)',
        () async {
      if (!kDebugMode) return;
      await resolveSeam(const DevSeamConfig(
        sessionSeed: SessionSeed.jeeberLoggedIn,
        kycStatusSeed: KycStatusSeed.approved,
      ));
      // No route pin → shell landing (`shell_tab_dashboard`); the gate reads the
      // kyc seed synchronously to show the feed vs the register prompt.
      expect(DevSeam.current.route, isEmpty);
      expect(DevSeam.current.kycStatusSeed, KycStatusSeed.approved);
    });

    test('wallet_state=insufficient does not pin a route', () async {
      if (!kDebugMode) return;
      await resolveSeam(const DevSeamConfig(
        sessionSeed: SessionSeed.jeeberLoggedIn,
        walletStateSeed: WalletStateSeed.insufficient,
      ));
      expect(DevSeam.current.route, isEmpty);
      expect(DevSeam.current.walletStateSeed, WalletStateSeed.insufficient);
    });
  });

  // ── 4. BOOT-HOLD guard (the 66 0/18 root cause) ─────────────────────────────
  // The mock-seed POSTs must NEVER hold boot. The production Bootstrap.minimal
  // call passes `awaitMockSeed: false`: `seed()` must (a) complete promptly even
  // when the mock POST hangs, and (b) STILL seed the local session state (the
  // landing decider) synchronously before returning.
  group('boot-hold guard (awaitMockSeed: false)', () {
    test('a hung mock does not delay seed() AND the session state is still '
        'seeded synchronously', () async {
      if (!kDebugMode) return;
      await resolveSeam(const DevSeamConfig(
        sessionSeed: SessionSeed.customerLoggedIn,
        journeySeed: JourneySeed.offersReceived, // shell-landing journey + POST
      ));
      final prefs = await freshPrefs();
      final tokens = _MemTokenStore();
      // A hung adapter models a slow/unreachable mock; with awaitMockSeed:false
      // the boot path must not wait on it at all.
      final hungDio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:4010'))
        ..httpClientAdapter = _HangingAdapter();

      final sw = Stopwatch()..start();
      await SessionSeamBootstrap.seed(
        prefs: prefs,
        tokenStore: tokens,
        mockSeedClient: hungDio,
        awaitMockSeed: false,
      );
      sw.stop();

      // Boot returns immediately — never waits on the (detached) POST.
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)),
          reason: 'awaitMockSeed:false must not block boot on the mock POST');
      // The LANDING decider (local session state) is nonetheless fully seeded.
      expect(OnboardingCubit(prefs: prefs).isCompleted, isTrue);
      expect(RoleCubit(prefs: prefs).state, UserRole.client);
      expect(await tokens.hasToken, isTrue);
    });
  });
}
