import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/dev_seam/session_seam_bootstrap.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A spy [AuthTokenStore] that starts holding a REAL (OTP) login and records
/// every clear/save so a test can prove whether the dev seam clobbered it.
class _SpyTokenStore implements AuthTokenStore {
  _SpyTokenStore({this.storedAccess, this.storedUserId});

  String? storedAccess;
  String? storedRefresh;
  String? storedUserId;
  int clears = 0;
  int saves = 0;

  @override
  Future<String?> get accessToken async => storedAccess;
  @override
  Future<String?> get refreshToken async => storedRefresh;
  @override
  Future<String?> get userId async => storedUserId;
  @override
  Future<bool> get hasToken async => storedAccess != null;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    saves++;
    storedAccess = accessToken;
    storedRefresh = refreshToken;
    storedUserId = userId;
  }

  @override
  Future<void> clear() async {
    clears++;
    storedAccess = null;
    storedRefresh = null;
    storedUserId = null;
  }
}

/// JEBV4-272 — the production kill-switch that stops the persistent
/// `/data/local/tmp/jeeb-dev-seam.json` device-file seed (`super_login_plus`)
/// from CLEARING the real OTP login and re-seeding a stale user (kamal,
/// `c23efd76…`) on every cold start. A production build passes
/// `--dart-define=JEEB_DISABLE_DEV_SEAM=true`; these tests drive the same gate
/// via the `@visibleForTesting` override (a compile-time const can't be toggled
/// at runtime).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SessionSeamBootstrap.debugSeamDisabledOverride = null;
    DevSeam.debugReset();
  });

  Future<SharedPreferences> freshPrefs() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return SharedPreferences.getInstance();
  }

  DevSeamConfig superLoginPlusSeed() => const DevSeamConfig(
        sessionSeed: SessionSeed.superLoginPlus,
        superLoginToken: 'seed-jwt-for-kamal',
        superLoginUserId: 'c23efd76-6fa4-40cf-814c-116f67ea5e95',
        superLoginRole: 'jeeber',
      );

  test(
      'kill-switch ON: a super_login_plus device-file seed is a NO-OP — the '
      'real persisted OTP login survives force-relaunch (never cleared, never '
      'overwritten by the seed user)', () async {
    if (!kDebugMode) return; // the seam is release-inert anyway
    SessionSeamBootstrap.debugSeamDisabledOverride = true;
    DevSeam.debugOverride(superLoginPlusSeed());
    final prefs = await freshPrefs();
    final tokens = _SpyTokenStore(
      storedAccess: 'real-otp-access-jwt',
      storedUserId: 'real-otp-user-999',
    );

    await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);

    expect(tokens.clears, 0, reason: 'the real login must never be cleared');
    expect(tokens.saves, 0, reason: 'the seed must never overwrite the login');
    expect(await tokens.accessToken, 'real-otp-access-jwt');
    expect(await tokens.userId, 'real-otp-user-999',
        reason: 'the app must relaunch as the CORRECT logged-in user');
  });

  test(
      'kill-switch OFF (default/absent): the seam still seeds normally, so '
      'dev/staging QA + CI behaviour is unchanged (this is the pre-fix '
      'clobber that the production kill-switch disables)', () async {
    if (!kDebugMode) return;
    SessionSeamBootstrap.debugSeamDisabledOverride = null; // explicit default
    DevSeam.debugOverride(superLoginPlusSeed());
    final prefs = await freshPrefs();
    final tokens = _SpyTokenStore(
      storedAccess: 'real-otp-access-jwt',
      storedUserId: 'real-otp-user-999',
    );

    await SessionSeamBootstrap.seed(prefs: prefs, tokenStore: tokens);

    // Default behaviour is preserved: the seam runs, clears the store, and
    // writes the seed user — exactly why a production build must disable it.
    expect(tokens.clears, greaterThan(0));
    expect(await tokens.accessToken, 'seed-jwt-for-kamal');
    expect(await tokens.userId, 'c23efd76-6fa4-40cf-814c-116f67ea5e95');
  });
}
