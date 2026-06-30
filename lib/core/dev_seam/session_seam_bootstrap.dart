import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/auth_token_store.dart';
import '../network/mock_gateway_client.dart';
import '../onboarding/onboarding_cubit.dart';
import '../role/role_cubit.dart';
import '../role/user_role.dart';
import '../session/account_status_gate.dart';
import '../../features/biometric_auth/data/shared_prefs_pin_repository.dart';
import '../../features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'dev_seam.dart';
import 'dev_seam_config.dart';

/// DEBUG-ONLY test harness that seeds app state from `jeeb.seam.session` so a
/// Maestro flow can deterministically start mid-journey (62_SEAM_HARNESS.md,
/// RC-1 in 61_W0_QA_RESULTS.md).
///
/// It MUST run during [Bootstrap.minimal] — AFTER [DevSeam.resolve] (so
/// `DevSeam.current` is populated) and AFTER `SharedPreferences.getInstance()`,
/// but BEFORE the first frame paints. That ordering matters: the root widget's
/// `OnboardingCubit` / `RoleCubit` read their persisted prefs in their
/// constructors, the `BiometricLockCubit` reads the biometric preference in its
/// `..evaluate()` (kicked from `app.dart`), and the `SessionCubit` reads the
/// token store in `refresh()` (kicked from `JeebApp.initState`). Seeding the
/// underlying stores before any of those run means the very first router
/// redirect already sees the seeded state — no flash, no race.
///
/// What it seeds (the real stores the cubits/gates read — no parallel state):
///   * onboarding-complete flag  → [SharedPreferences] `app.onboarding.completed`
///                                 (read by [OnboardingCubit])
///   * active role               → [SharedPreferences] `app.role`
///                                 (read by [RoleCubit])
///   * auth token + userId       → [AuthTokenStore] (secure keystore)
///                                 (read by [SessionCubit])
///   * biometric enrolled        → [SharedPreferences] biometric enabled + PIN
///                                 (read by [BiometricPreferenceRepositoryImpl]
///                                  + [SharedPrefsPinRepository], consumed by
///                                  [BiometricLockCubit] and the login affordance)
///   * account blocked           → [SharedPreferences] [kAccountBlockedKey]
///                                 (read by [SeededAccountStatusGate])
///
/// Release-inert: every entry point is `kDebugMode`-gated, and the only caller
/// ([Bootstrap.minimal]) already short-circuits [DevSeam.resolve] in release, so
/// `DevSeam.current` is empty and [seed] is a no-op anyway. The seam keys are
/// also stripped from the native `seamKeys` whitelist effect in release because
/// the Dart `DevSeamConfig` is never populated.
class SessionSeamBootstrap {
  SessionSeamBootstrap._();

  /// Canonical seeded userIds (match `jeeb-mock-backend/src/fixtures/seed.ts`).
  /// The persisted userId is what JM-006's account-status gate reads via
  /// `GET /users/:id` (NOT `/users/me` — 42_GUARDRAILS_MOCK W-1 FLOOR), so it
  /// must be a real seeded id the mock resolves.
  static const String customerUserId = 'user-client-001';
  static const String jeeberUserId = 'user-jeeber-002';

  /// SharedPreferences key the debug-only [SeededAccountStatusGate] reads. Set
  /// true by the `suspended` seed so the router lands `/account-status` even
  /// before the real JM-006 account-status cubit (which will `GET /users/:id`)
  /// lands. Defaults absent → not blocked.
  static const String kAccountBlockedKey = 'seam.account_blocked';

  /// Builds a `mock-jwt-access-<userId>` token in the SAME shape the mock issues
  /// (`auth-service.ts tokenBundle`). It is NOT a parseable JWT, so
  /// `SessionCubit` classifies it as authenticated by presence — exactly the
  /// real logged-in path.
  static String _accessTokenFor(String userId) => 'mock-jwt-access-$userId';
  static String _refreshTokenFor(String userId) => 'mock-jwt-refresh-$userId';

  /// Seeds app state from `DevSeam.current.sessionSeed` (session/role/token/
  /// biometric/account-status) AND, when a `jeeb.seam.journey` value is present,
  /// makes the mock hold the deterministic mid-journey rows for it via
  /// `POST /__mock/seed/journey` (63_W1_TEST_PLAN §4). For Wave 2 it ALSO, when
  /// a `jeeb.seam.kyc_status` / `jeeb.seam.wallet_state` value is present
  /// (65_W2_TEST_PLAN §3): (a) writes the seeded jeeber KYC status to a
  /// client-side store the DELIVERY-tab/offer gates read on first frame and
  /// `POST`s `/__mock/seed/kyc` so `GET …/kyc` + getMe reflect it; (b) `POST`s
  /// `/__mock/seed/wallet` so the wallet hub + offer composer read the seeded
  /// balance/affordability. No-op in release and when no extra was passed. Must
  /// never throw — a seeding failure degrades to "no seed" (the flow then fails
  /// its precondition loudly, rather than crashing the app at boot).
  ///
  /// [tokenStore] is injectable so widget/unit tests can pass an in-memory store
  /// without the secure-storage platform channel. [mockSeedClient] is injectable
  /// so tests can supply a fake Dio for the mock seed POSTs (journey/kyc/wallet).
  /// Production passes the defaults.
  ///
  /// [awaitMockSeed] controls whether [seed] AWAITS the mock-seed POSTs
  /// (journey/kyc/wallet) before returning. This is the LANDING-FIX hardening
  /// (66_W2_QA_RESULTS — the 2nd-`clearState`-launch boot-hold regression):
  ///
  ///   * The **landing** is decided ENTIRELY by the local session-state seed
  ///     (onboarding/role/token in prefs+keystore), which is always awaited and
  ///     completes in a few ms — so the router's first redirect always sees the
  ///     seeded session and lands on the right screen.
  ///   * The **mock-seed POSTs** only make the mock HOLD rows the screens fetch
  ///     LATER (after first frame). Awaiting them inside [Bootstrap.minimal]
  ///     blocks the splash→app hand-off for up to 3×[_journeySeedTimeout] when
  ///     the emulator network to `10.0.2.2` is slow under Maestro load — which is
  ///     exactly what made `shell_tab_requests` miss the 30s QA window on a
  ///     second `clearState` launch (0/18 in 66). So PRODUCTION
  ///     ([Bootstrap.minimal]) passes `awaitMockSeed: false`: the POSTs are
  ///     fired (still bounded + fail-safe) but boot does NOT wait on them. The
  ///     shell tab bar paints the moment the local seed + first redirect settle.
  ///
  /// Defaults to `true` so the existing unit tests (which await [seed] then
  /// assert the POST fired) keep their synchronous contract unchanged.
  static Future<void> seed({
    required SharedPreferences prefs,
    AuthTokenStore? tokenStore,
    Dio? mockSeedClient,
    bool awaitMockSeed = true,
  }) async {
    if (!kDebugMode) return;
    final seed = DevSeam.current.sessionSeed;
    final journey = DevSeam.current.journeySeed;
    final kyc = DevSeam.current.kycStatusSeed;
    final wallet = DevSeam.current.walletStateSeed;
    if (seed == SessionSeed.none &&
        journey == JourneySeed.none &&
        kyc == KycStatusSeed.none &&
        wallet == WalletStateSeed.none) {
      return;
    }

    final tokens = tokenStore ?? AuthTokenStore();
    try {
      // Start from a clean slate every seed so a re-launch in the same Maestro
      // session can't leak prior state (the flows also `clearState`, but seeding
      // explicitly is belt-and-braces and keeps the seed self-contained).
      await _resetSeededState(prefs, tokens);

      switch (seed) {
        case SessionSeed.none:
          // No session seed — a journey-only launch is valid (the journey seed
          // below still runs). Fall through to journey seeding.
          break;

        case SessionSeed.customerLoggedIn:
          await _completeOnboarding(prefs);
          await _setRole(prefs, UserRole.client);
          await _logIn(tokens, customerUserId);

        case SessionSeed.jeeberLoggedIn:
          await _completeOnboarding(prefs);
          await _setRole(prefs, UserRole.jeeber);
          await _logIn(tokens, jeeberUserId);

        case SessionSeed.loggedOutReturning:
          await _completeOnboarding(prefs);
        // No token → the first-run session gate sends the user to `/login`.

        case SessionSeed.biometricEnrolled:
          await _completeOnboarding(prefs);
          await _setRole(prefs, UserRole.client);
          await _logIn(tokens, customerUserId);
          await _enrollBiometric(prefs);
        // onboarded + token + biometric LOCKED → the biometric gate holds
        // the user on `/lock`.

        case SessionSeed.biometricEnrolledLoggedOut:
          await _completeOnboarding(prefs);
          await _enrollBiometric(prefs);
        // No token → `/login`, but `login_biometric_affordance` is shown
        // because the biometric preference is enabled.

        case SessionSeed.suspended:
          await _completeOnboarding(prefs);
          await _setRole(prefs, UserRole.client);
          await _logIn(tokens, customerUserId);
          await prefs.setBool(kAccountBlockedKey, true);
        // onboarded + token + account blocked → `/account-status`.

        case SessionSeed.superLoginPlus:
          // QA-only seam: write a REAL gateway JWT (minted via /auth/tokens) into
          // AuthTokenStore so the app makes authenticated /v1/* calls against the
          // LIVE gateway as the seeded user — without OTP.
          //
          // GUARD: this case is only reachable when kDebugMode is true (the entire
          // seed() method short-circuits when !kDebugMode). The token is supplied
          // at launch time via `adb am start -e 'jeeb.seam.super_login_token'
          // '<JWT>'` and is NEVER baked into the binary.
          //
          // Falls back gracefully: if the token extra is absent (empty), the seam
          // completes onboarding + role but writes no token → the router lands on
          // `/login` (the user sees the login screen rather than crashing).
          await _completeOnboarding(prefs);
          await _setRole(prefs, _superLoginRole());
          final realToken = DevSeam.current.superLoginToken;
          if (realToken.isNotEmpty) {
            final refreshToken =
                DevSeam.current.superLoginRefreshToken.isNotEmpty
                ? DevSeam.current.superLoginRefreshToken
                : realToken; // fallback: use access token as refresh placeholder
            final userId = DevSeam.current.superLoginUserId.isNotEmpty
                ? DevSeam.current.superLoginUserId
                : null; // null → AuthTokenStore.save skips writing userId
            await tokens.save(
              accessToken: realToken,
              refreshToken: refreshToken,
              userId: userId,
            );
            debugPrint(
              'SessionSeamBootstrap super_login_plus: real gateway token '
              'written for userId=$userId',
            );
          } else {
            debugPrint(
              'SessionSeamBootstrap super_login_plus: no token supplied '
              '(jeeb.seam.super_login_token absent) — landing on /login',
            );
          }
      }
      if (seed != SessionSeed.none) {
        debugPrint('SessionSeamBootstrap seeded session: ${seed.name}');
      }

      // ── Mock-side seeds (journey/kyc/wallet) — OFF the boot critical path ──
      //
      // LANDING-FIX (66_W2_QA_RESULTS, supersedes the 64 jm-027/028/029 fix):
      // the local session-state seed above (prefs/token/role) has ALREADY
      // decided the landing and is complete. The three mock-seed POSTs below
      // only make the mock HOLD rows the screens fetch AFTER first frame — they
      // have zero bearing on whether the shell renders its tab bar. Awaiting them
      // in [Bootstrap.minimal] holds the splash → app hand-off for up to
      // 3×[_journeySeedTimeout] when the emulator network to `10.0.2.2` is slow
      // under Maestro load, which is exactly what made `shell_tab_requests` miss
      // the 30s QA window on a 2nd `clearState` launch (the 0/18 in 66).
      //
      // So they run as a SINGLE bounded, fail-safe future ([_seedMockState]).
      // Production ([Bootstrap.minimal], `awaitMockSeed: false`) fires it WITHOUT
      // waiting — the shell paints the instant the local seed + first redirect
      // settle, and the rows are in the mock by the time a flow navigates into
      // them (the journey/kyc POSTs answer in well under a second on a healthy
      // host). Tests (`awaitMockSeed: true`, the default) still await it so their
      // "POST fired by the time `seed()` returns" contract is unchanged.
      final mockSeed = _seedMockState(
        seed: seed,
        journey: journey,
        kyc: kyc,
        wallet: wallet,
        client: mockSeedClient,
      );
      // DEEP-LAND-FIX (68_W34_QA_RESULTS closeout): AWAIT the (bounded,
      // fail-safe) mock seed when the app deep-lands on a DATA screen OR a
      // kyc/wallet state seed is present — both feed the screen's first read.
      //
      //   * Route-pinned data screens (`DevSeam.current.route` non-empty — e.g.
      //     `/notifications`, `/disputes/:id`, `/wallet/activity`, `/wallet/
      //     transactions/:id`) fetch their rows on the FIRST frame; a detached
      //     journey POST races that fetch and the screen renders empty (the
      //     jm-057 0-rows symptom).
      //   * kyc/wallet seeds (`jeeb.seam.kyc_status` / `jeeb.seam.wallet_state`)
      //     drive the wallet the offer composer reads on SEND — a detached POST
      //     left the wallet at the default `sufficient`/40, so the O1 402 path
      //     (jm-045 AC5 / jm-046) never fired (the wallet seed never applied).
      //
      // A healthy mock answers each `/__mock/seed/*` in well under a second; the
      // bound ([_journeySeedTimeout]) still caps a hung mock so boot is never
      // held indefinitely. The shell-only landing with NO state seed (e.g. a bare
      // `customer_logged_in`) keeps the detached behaviour so the shell tab bar
      // paints instantly (the 66 boot-hold fix is preserved for that case).
      final deepLands = DevSeam.current.route.isNotEmpty;
      final hasStateSeed =
          kyc != KycStatusSeed.none || wallet != WalletStateSeed.none;
      if (awaitMockSeed || deepLands || hasStateSeed) {
        await mockSeed;
      } else {
        // Detached: never blocks boot. Already fail-safe internally, but guard
        // the detached future too so an unawaited rejection can't surface.
        unawaited(mockSeed);
      }
    } catch (error, stack) {
      // A dev-only seam must never crash startup; surface to console only.
      debugPrint('SessionSeamBootstrap seed failed ($seed): $error');
      debugPrint('$stack');
    }
  }

  /// Applies the mock-side seeds (journey rows, KYC status, wallet balance) for
  /// the resolved seeds. Each POST is independently bounded by
  /// [_journeySeedTimeout] and fail-safe (a failure/timeout degrades to "no
  /// seed" for that one POST and is logged — it never throws, so a detached
  /// invocation can't surface an unhandled rejection and an awaited one always
  /// completes). Runs AFTER the local session seed so the token/role are in
  /// place. Never holds the boot critical path when invoked detached.
  static Future<void> _seedMockState({
    required SessionSeed seed,
    required JourneySeed journey,
    required KycStatusSeed kyc,
    required WalletStateSeed wallet,
    required Dio? client,
  }) async {
    // Wave 1 journey seam (63_W1_TEST_PLAN §4): make the mock hold the
    // deterministic mid-journey rows for this journey value.
    if (journey != JourneySeed.none) {
      await _guardSeed(
        () => _seedJourneyInMock(journey, client),
        'journey ${journey.name}',
      );
    }

    // Wave 2 jeeber seam (65_W2_TEST_PLAN §3.1/§3.2). All W2 jeeber flows run as
    // `jeeber_logged_in`, so the seeded user is user-jeeber-002 (the only
    // session id that owns a KYC/wallet record). Resolve the target id from the
    // seeded session so a future customer kyc/wallet variant slots in cleanly;
    // default to the jeeber id for a kyc/wallet-only launch.
    final seamUserId = seed == SessionSeed.customerLoggedIn
        ? customerUserId
        : jeeberUserId;

    // (a) KYC status. The first-frame DELIVERY-tab gate (JM-036) and offer gate
    // (JM-044) read `DevSeam.current.kycStatusSeed` SYNCHRONOUSLY via the
    // integrator's [SeamJeeberKycStatusGate] — no client-side store the seam
    // writes, so the gate is correct on the first synchronous build regardless
    // of how/whether this POST resolves. This POST is purely for the LIVE path
    // (`GET …/kyc` + getMe) once the real gate replaces the seam gate (U1).
    if (kyc != KycStatusSeed.none) {
      await _guardSeed(
        () => _seedKycInMock(kyc, seamUserId, client),
        'kyc_status ${kyc.wireValue}',
      );
    }

    // (b) Wallet state. MOCK-side only (no client store the seam owns): the
    // wallet hub + offer composer fetch the seeded balance/affordability.
    if (wallet != WalletStateSeed.none) {
      await _guardSeed(
        () => _seedWalletInMock(wallet, seamUserId, client),
        'wallet_state ${wallet.wireValue}',
      );
    }
  }

  /// Runs a single mock-seed POST, swallowing any error/timeout so one failed
  /// POST never aborts the others (or surfaces as an unhandled rejection on the
  /// detached future). Logs the outcome for diagnosis.
  static Future<void> _guardSeed(
    Future<void> Function() post,
    String label,
  ) async {
    try {
      await post();
      debugPrint('SessionSeamBootstrap seeded $label');
    } catch (error) {
      debugPrint('SessionSeamBootstrap mock-seed $label failed: $error');
    }
  }

  /// The dev-only mock journey-seed endpoint (62_SEAM_HARNESS §"W1 journey
  /// seam"). It is an `/__mock/*` admin path that the gateway rewrite map does
  /// NOT touch (no prefix matches), so it reaches the Express mock verbatim at
  /// the configured base URL (`:4010`).
  static const String _journeySeedPath = '/__mock/seed/journey';

  /// The dev-only mock kyc-seed endpoint (65_W2_TEST_PLAN §3.1). Same `/__mock/*`
  /// admin namespace as the journey seed — the rewrite map does NOT touch it, so
  /// it reaches the Express mock verbatim. The mock stores the status so
  /// `GET /user-management/users/:userId/kyc` (and getMe) reflect the seed.
  static const String _kycSeedPath = '/__mock/seed/kyc';

  /// The dev-only mock wallet-seed endpoint (65_W2_TEST_PLAN §3.2). Same
  /// `/__mock/*` admin namespace; rewrite-map-exempt. The mock stores the
  /// balance/affordability so `GET /wallet-service/v1/jeeb/wallet` reflects it.
  static const String _walletSeedPath = '/__mock/seed/wallet';

  /// Hard ceiling on how long the journey-seed POST may take. The default
  /// [MockGatewayClient] Dio uses 15s connect + 15s receive — a stalled connect
  /// alone could therefore hold `Bootstrap.minimal()` (and the splash) for up to
  /// 30s, which is exactly the 30s QA window `shell_tab_requests` must appear
  /// within. This bound guarantees the seam can never delay the first frame past
  /// a few seconds; on timeout we degrade to "no seed" (the screen then shows
  /// its own loading/empty state). The mock answers `/__mock/seed/journey` in
  /// well under this on a healthy host.
  static const Duration _journeySeedTimeout = Duration(seconds: 10);

  /// POSTs `{ journey: <wireValue> }` to the mock so it holds the deterministic
  /// rows for this journey. [client] is injectable so tests can pass a fake Dio
  /// without a real socket; production builds a Dio against the same base URL +
  /// rewrite the app uses ([MockGatewayClient]), but with tight timeouts so the
  /// seam never blocks boot (the default client is only built when no test
  /// client is supplied, so tests keep their fast in-memory adapter).
  ///
  /// The POST is additionally `.timeout`-bounded by [_journeySeedTimeout] as a
  /// belt-and-braces ceiling independent of the Dio connect/receive timeouts.
  static Future<void> _seedJourneyInMock(
    JourneySeed journey,
    Dio? client,
  ) async {
    final dio = client ?? _seedDio();
    final response = await dio
        .post<Object?>(_journeySeedPath, data: {'journey': journey.wireValue})
        .timeout(_journeySeedTimeout);
    debugPrint(
      'SessionSeamBootstrap journey-seed ${journey.wireValue} '
      '→ ${response.statusCode} ${response.data}',
    );
  }

  /// POSTs `{ kycStatus, userId }` to the mock so the live KYC path
  /// (`GET …/kyc` + getMe) reflects the seeded status for [userId]. Bounded by
  /// [_journeySeedTimeout] (belt-and-braces, independent of the Dio timeouts) so
  /// a slow/unreachable mock can never hold the first frame — the first-frame
  /// DELIVERY-tab/offer gate reads `DevSeam.current.kycStatusSeed` synchronously
  /// (via `SeamJeeberKycStatusGate`), not this POST, so the gate is correct
  /// regardless of how this POST resolves.
  static Future<void> _seedKycInMock(
    KycStatusSeed kyc,
    String userId,
    Dio? client,
  ) async {
    final dio = client ?? _seedDio();
    final response = await dio
        .post<Object?>(
          _kycSeedPath,
          data: {'kycStatus': kyc.wireValue, 'userId': userId},
        )
        .timeout(_journeySeedTimeout);
    debugPrint(
      'SessionSeamBootstrap kyc-seed ${kyc.wireValue} ($userId) '
      '→ ${response.statusCode} ${response.data}',
    );
  }

  /// POSTs `{ state, userId }` to the mock so the wallet hub + offer composer
  /// read the seeded balance/affordability for [userId]. Bounded by
  /// [_journeySeedTimeout] and fail-safe (caught by [seed]).
  static Future<void> _seedWalletInMock(
    WalletStateSeed wallet,
    String userId,
    Dio? client,
  ) async {
    final dio = client ?? _seedDio();
    final response = await dio
        .post<Object?>(
          _walletSeedPath,
          data: {'state': wallet.wireValue, 'userId': userId},
        )
        .timeout(_journeySeedTimeout);
    debugPrint(
      'SessionSeamBootstrap wallet-seed ${wallet.wireValue} ($userId) '
      '→ ${response.statusCode} ${response.data}',
    );
  }

  /// The production journey-seed Dio: the same base URL + rewrite the app uses,
  /// but with tight connect/receive timeouts (vs the 15s defaults) so a slow or
  /// unreachable mock can never hold the first frame. Only built when no test
  /// client is injected.
  static Dio _seedDio() {
    final dio = MockGatewayClient.createDio();
    dio.options.connectTimeout = _journeySeedTimeout;
    dio.options.receiveTimeout = _journeySeedTimeout;
    dio.options.sendTimeout = _journeySeedTimeout;
    return dio;
  }

  static Future<void> _completeOnboarding(SharedPreferences prefs) =>
      prefs.setBool(OnboardingCubit.completedKey, true);

  static Future<void> _setRole(SharedPreferences prefs, UserRole role) =>
      prefs.setString(RoleCubit.rolePrefKey, role.storageKey);

  static UserRole _superLoginRole() {
    switch (DevSeam.current.superLoginRole.trim().toLowerCase()) {
      case 'jeeber':
      case 'driver':
      case 'delivery':
      case 'deliveryman':
      case 'delivery_man':
        return UserRole.jeeber;
      default:
        return UserRole.client;
    }
  }

  static Future<void> _logIn(AuthTokenStore tokens, String userId) =>
      tokens.save(
        accessToken: _accessTokenFor(userId),
        refreshToken: _refreshTokenFor(userId),
        userId: userId,
      );

  static Future<void> _enrollBiometric(SharedPreferences prefs) async {
    // Enable the preference AND seed a local PIN so the BiometricLockCubit's
    // `canChallenge = available || hasPin` is true on the production
    // (unavailable) gateway — without a challenge path it would fall straight
    // through to `disabled` and never hold `/lock`.
    await prefs.setBool(BiometricPreferenceRepositoryImpl.kEnabledKey, true);
    await prefs.setString(SharedPrefsPinRepository.kPinKey, '0000');
  }

  /// Clears every key/store this harness owns so a seed is deterministic and a
  /// later un-seeded launch returns to a pristine first-run.
  static Future<void> _resetSeededState(
    SharedPreferences prefs,
    AuthTokenStore tokens,
  ) async {
    await prefs.remove(OnboardingCubit.completedKey);
    await prefs.remove(RoleCubit.rolePrefKey);
    await prefs.remove(BiometricPreferenceRepositoryImpl.kEnabledKey);
    await prefs.remove(SharedPrefsPinRepository.kPinKey);
    await prefs.remove(kAccountBlockedKey);
    await tokens.clear();
  }
}

/// DEBUG-ONLY [AccountStatusGate] driven by a [SharedPreferences] flag the
/// [SessionSeamBootstrap] seeds (`jeeb.seam.session=suspended`).
///
/// This is the bridge that makes the `suspended` seam route to `/account-status`
/// today, before the real JM-006 account-status cubit (which will `GET
/// /users/:id` by the persisted userId and classify `status ∈ {suspended,
/// locked}`, D5) lands. When that cubit ships it REPLACES this gate in
/// `app.dart`; the seam contract (a blocked account → `/account-status`) is
/// unchanged. In release `app.dart` keeps the inert [AlwaysActiveAccountStatusGate].
///
/// Reads the flag eagerly at construction so the router's synchronous redirect
/// sees a stable value (the flag was written during bootstrap, before this is
/// built). [isBlocked] is therefore a pure getter (no async in the redirect
/// path) and `false` whenever the flag is absent — preserving the no-op gate
/// behaviour for every non-suspended seed and for un-seeded launches.
class SeededAccountStatusGate implements AccountStatusGate {
  SeededAccountStatusGate(SharedPreferences prefs)
    : _blocked =
          kDebugMode &&
          (prefs.getBool(SessionSeamBootstrap.kAccountBlockedKey) ?? false);

  final bool _blocked;

  @override
  bool get isBlocked => _blocked;
}
