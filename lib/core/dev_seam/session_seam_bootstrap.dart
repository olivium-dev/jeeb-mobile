import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/dev_base_url.dart';
import '../network/auth_token_store.dart';
import '../network/jwt_expiry.dart';
import '../network/mock_gateway_client.dart';
import '../onboarding/onboarding_cubit.dart';
import '../role/role_cubit.dart';
import '../role/user_role.dart';
import '../session/account_status_gate.dart';
import '../../features/biometric_auth/data/shared_prefs_pin_repository.dart';
import '../../features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'dev_seam.dart';
import 'dev_seam_config.dart';

class SessionSeamBootstrap {
  SessionSeamBootstrap._();

  static const String customerUserId = 'user-client-001';
  static const String jeeberUserId = 'user-jeeber-002';

  static const String kAccountBlockedKey = 'seam.account_blocked';

  static String _accessTokenFor(String userId) => 'mock-jwt-access-$userId';
  static String _refreshTokenFor(String userId) => 'mock-jwt-refresh-$userId';

  static const bool _devSeamDisabledByDefine =
      bool.fromEnvironment('JEEB_DISABLE_DEV_SEAM');

  @visibleForTesting
  static bool? debugSeamDisabledOverride;

  static bool get _devSeamDisabled =>
      debugSeamDisabledOverride ?? _devSeamDisabledByDefine;

  static Future<void> seed({
    required SharedPreferences prefs,
    AuthTokenStore? tokenStore,
    Dio? mockSeedClient,
    bool awaitMockSeed = true,
  }) async {
    if (!kDebugMode || _devSeamDisabled) return;
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
      await _resetSeededState(prefs, tokens);

      switch (seed) {
        case SessionSeed.none:
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

        case SessionSeed.biometricEnrolled:
          await _completeOnboarding(prefs);
          await _setRole(prefs, UserRole.client);
          await _logIn(tokens, customerUserId);
          await _enrollBiometric(prefs);

        case SessionSeed.biometricEnrolledLoggedOut:
          await _completeOnboarding(prefs);
          await _enrollBiometric(prefs);

        case SessionSeed.suspended:
          await _completeOnboarding(prefs);
          await _setRole(prefs, UserRole.client);
          await _logIn(tokens, customerUserId);
          await prefs.setBool(kAccountBlockedKey, true);

        case SessionSeed.superLoginPlus:
          await _completeOnboarding(prefs);
          await _setRole(prefs, _superLoginRole());
          final realToken = DevSeam.current.superLoginToken;
          if (realToken.isEmpty) {
            debugPrint(
              'SessionSeamBootstrap super_login_plus: no token supplied '
              '(jeeb.seam.super_login_token absent) — landing on /login',
            );
            break;
          }
          // A stale seam file (it survives uninstall) must not fake a live
          // session: prove the token against the gateway before trusting it.
          final verdict = await _verifySeamToken(realToken, prefs);
          if (verdict == SeamTokenVerdict.rejected) {
            debugPrint(
              'SessionSeamBootstrap super_login_plus: seam token REJECTED '
              '(expired or revoked) — ignoring it, landing on /login',
            );
            break;
          }
          // Never substitute the access token for a missing refresh token —
          // an empty value cleanly routes the refresh logic to logout.
          final refreshToken = DevSeam.current.superLoginRefreshToken;
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
            'written for userId=$userId (${verdict.name})',
          );
      }
      if (seed != SessionSeed.none) {
        debugPrint('SessionSeamBootstrap seeded session: ${seed.name}');
      }

      final mockSeed = _seedMockState(
        seed: seed,
        journey: journey,
        kyc: kyc,
        wallet: wallet,
        client: mockSeedClient,
      );
      final deepLands = DevSeam.current.route.isNotEmpty;
      final hasStateSeed =
          kyc != KycStatusSeed.none || wallet != WalletStateSeed.none;
      if (awaitMockSeed || deepLands || hasStateSeed) {
        await mockSeed;
      } else {
        unawaited(mockSeed);
      }
    } catch (error, stack) {
      debugPrint('SessionSeamBootstrap seed failed ($seed): $error');
      debugPrint('$stack');
    }
  }

  /// One cheap authed probe with a hard timeout. Only a definitive 401/403
  /// (or a locally expired exp) rejects; offline development stays fail-open.
  @visibleForTesting
  static Future<SeamTokenVerdict> verifySeamToken(
    String token, {
    required Uri? Function() resolveBase,
    Dio? client,
    DateTime Function()? clock,
  }) async {
    final exp = jwtExpiry(token);
    final now = (clock ?? DateTime.now)().toUtc();
    if (exp != null && !exp.isAfter(now)) return SeamTokenVerdict.rejected;
    try {
      final base = resolveBase();
      // `.invalid` is the deliberately unroutable dev placeholder — probing it
      // only stalls boot, so treat it as "cannot verify".
      if (base == null || base.host.endsWith('.invalid')) {
        return SeamTokenVerdict.unverified;
      }
      final dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: base.toString(),
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );
      final response = await dio.get<Object?>(
        MockGatewayClient.rewritePath('/v1/users/me'),
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return SeamTokenVerdict.verified;
      if (status == 401 || status == 403) return SeamTokenVerdict.rejected;
      return SeamTokenVerdict.unverified;
    } catch (_) {
      return SeamTokenVerdict.unverified;
    }
  }

  static Future<SeamTokenVerdict> _verifySeamToken(
    String token,
    SharedPreferences prefs,
  ) => verifySeamToken(
    token,
    resolveBase: () {
      try {
        final override = DevBaseUrl.read(prefs);
        return Uri.parse(override ?? MockGatewayClient.mockBaseUrl);
      } catch (_) {
        return null; // transport-policy violation → cannot probe, fail open
      }
    },
  );

  static Future<void> _seedMockState({
    required SessionSeed seed,
    required JourneySeed journey,
    required KycStatusSeed kyc,
    required WalletStateSeed wallet,
    required Dio? client,
  }) async {
    if (journey != JourneySeed.none) {
      await _guardSeed(
        () => _seedJourneyInMock(journey, client),
        'journey ${journey.name}',
      );
    }

    final seamUserId = seed == SessionSeed.customerLoggedIn
        ? customerUserId
        : jeeberUserId;

    if (kyc != KycStatusSeed.none) {
      await _guardSeed(
        () => _seedKycInMock(kyc, seamUserId, client),
        'kyc_status ${kyc.wireValue}',
      );
    }

    if (wallet != WalletStateSeed.none) {
      await _guardSeed(
        () => _seedWalletInMock(wallet, seamUserId, client),
        'wallet_state ${wallet.wireValue}',
      );
    }
  }

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

  static const String _journeySeedPath = '/__mock/seed/journey';

  static const String _kycSeedPath = '/__mock/seed/kyc';

  static const String _walletSeedPath = '/__mock/seed/wallet';

  static const Duration _journeySeedTimeout = Duration(seconds: 10);

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
    await prefs.setBool(BiometricPreferenceRepositoryImpl.kEnabledKey, true);
    await prefs.setString(SharedPrefsPinRepository.kPinKey, '0000');
  }

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

enum SeamTokenVerdict { verified, rejected, unverified }

class SeededAccountStatusGate implements AccountStatusGate {
  SeededAccountStatusGate(SharedPreferences prefs)
    : _blocked =
          kDebugMode &&
          (prefs.getBool(SessionSeamBootstrap.kAccountBlockedKey) ?? false);

  final bool _blocked;

  @override
  bool get isBlocked => _blocked;
}
