// MB1 ITEM M4 — W1.2, FCM re-registration on login / user-switch.
//
// W1.2 rides MB1 as a PROOF-ONLY rider: the batch budgets 0 writer-minutes
// because the code is already shipped (`app.dart:387` → `notifyLogin()`,
// `device_token_registrar.dart:63-77` → the `(sessionUserId, token)` key that
// replaced the old one-shot `bool _registered` latch). A proof-only rider is
// exactly the kind of claim that gets waved through, so it gets a real
// instrument here rather than a citation.
//
// The defect being pinned (JEBV4-159): the old latch flipped true on the FIRST
// successful register and then short-circuited every later one for the life of
// the process. So after a sign-out+sign-in, a super-login account switch or a
// role switch — all of which re-emit `authenticated` on the SAME live registrar
// — the NEW user was never registered, the push service resolved them to zero
// device tokens, and every targeted push silently no-op'd.
//
// The load-bearing asymmetry, and the reason M4.1 and M4.2 must BOTH hold:
//   * a change of USER (same token) MUST re-register     — else JEBV4-159
//   * a repeat of the SAME (user, token) MUST NOT        — else every
//     `authenticated` emission is a redundant PUT
// A "fix" that simply deletes the dedup passes M4.1 and fails M4.2. That pair
// is the whole test.
//
// NON-CLAIM (GATE.md §3): `suite` evidence. This proves the CLIENT issues the
// register hop under the right conditions. It proves nothing about the gateway
// storing the row, nothing about the push microservice resolving it, and
// nothing about a notification arriving in a shade. MB1's V-2 owns that, and
// its contract is explicit that a registration-row `user_id` flip is a
// PRECONDITION and never the predicate — a row flip proves an upsert, not
// arrival.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/notifications/data/device_token_registrar.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';

import 'mb1_pack_support.dart';

const String _registerPath = '/api/PushNotification/register';

/// Records every PUT the registrar makes. Answers 201, the contract's success
/// code — a non-2xx would leave the dedup key unset and mask a real skip.
class _WirePut extends Fake implements Dio {
  final List<String> paths = <String>[];
  final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];

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
    bodies.add((data! as Map).cast<String, dynamic>());
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
    );
  }
}

/// In-memory keystore. The registrar reads the userId through the real
/// [AuthTokenStore], so switching users is done the way the app does it.
class _MemStore extends Fake implements FlutterSecureStorage {
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

  Future<void> login(AuthTokenStore store, String userId) => store.save(
        accessToken: 'jwt-$userId',
        refreshToken: 'refresh-$userId',
        userId: userId,
      );

  ({DeviceTokenRegistrar registrar, _WirePut dio, AuthTokenStore store})
      harness({String token = 'fcm-same-token'}) {
    final store = AuthTokenStore(storage: _MemStore());
    final dio = _WirePut();
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: store,
      transport: FakePushTransport(token: token),
      prefs: prefs,
      retryInterval: Duration.zero,
      maxAttempts: 1,
    );
    return (registrar: registrar, dio: dio, store: store);
  }

  group('M4.a — the asymmetry that IS the fix', () {
    test('M4.1 USER SWITCH: same handset, same FCM token, user A out / user B '
        'in -> TWO registers', () async {
      final h = harness();
      addTearDown(h.registrar.dispose);

      await login(h.store, 'user-A');
      await h.registrar.notifyLogin();
      expect(h.dio.paths, <String>[_registerPath],
          reason: 'DENOMINATOR: user A registered at all');

      // The switch. Nothing else changes — same process, same live registrar,
      // same FCM token. Only the authenticated identity moved.
      await login(h.store, 'user-B');
      await h.registrar.notifyLogin();

      expect(h.dio.paths, <String>[_registerPath, _registerPath],
          reason: 'JEBV4-159: the old one-shot latch swallowed this second '
              'register, leaving user B with ZERO server-side device tokens '
              'and every targeted push silently no-op\'ing');
      expect(h.dio.bodies.map((b) => b['fcmToken']).toSet(),
          <String>{'fcm-same-token'},
          reason: 'the TOKEN never changed — it is the USER that re-keys the '
              'dedup. A token-only key reproduces the bug exactly.');
      expect(h.dio.bodies.map((b) => b['deviceId']).toSet(), hasLength(1),
          reason: 'one install, one stable device id across the switch');
    });

    test('M4.2 DEDUP HOLDS: a duplicate authenticated emission for the SAME '
        '(user, token) does NOT re-register', () async {
      // The control that stops "delete the latch" from passing M4.1. Session
      // cubits re-emit; without this the app PUTs on every emission.
      final h = harness();
      addTearDown(h.registrar.dispose);

      await login(h.store, 'user-A');
      await h.registrar.notifyLogin();
      await h.registrar.notifyLogin();
      await h.registrar.notifyLogin();

      expect(h.dio.paths, hasLength(1),
          reason: 'three identical emissions, one register');
    });

    test('M4.3 SIGN-OUT resets the dedup, so the SAME user re-registers',
        () async {
      // Logout fires DELETE /api/PushNotification/device server-side. Without
      // the reset the next same-user login computes an identical key, is
      // skipped as a duplicate, and the re-logged-in user has no token row.
      final h = harness();
      addTearDown(h.registrar.dispose);

      await login(h.store, 'user-A');
      await h.registrar.notifyLogin();
      expect(h.dio.paths, hasLength(1));

      h.registrar.notifySignedOut();
      await h.registrar.notifyLogin();

      expect(h.dio.paths, hasLength(2),
          reason: 'the server row was deleted at logout; an identical-key skip '
              'here leaves the user unreachable');
    });

    test('M4.4 TOKEN ROTATION re-registers under the same user', () async {
      final h = harness(token: 'fcm-old');
      addTearDown(h.registrar.dispose);

      await login(h.store, 'user-A');
      await h.registrar.notifyLogin();
      expect(h.dio.bodies.single['fcmToken'], 'fcm-old');

      // A reinstall / restore-from-backup rotates the token under one identity.
      // The registrar's own refresh stream is the production path; driving the
      // same state change through a second registrar keeps this test about the
      // KEY rather than about stream plumbing.
      final rotated = DeviceTokenRegistrar(
        dio: h.dio,
        tokenStore: h.store,
        transport: FakePushTransport(token: 'fcm-new'),
        prefs: prefs,
        retryInterval: Duration.zero,
        maxAttempts: 1,
      );
      addTearDown(rotated.dispose);
      await rotated.notifyLogin();

      expect(h.dio.bodies.map((b) => b['fcmToken']).toList(),
          <String>['fcm-old', 'fcm-new']);
    });

    test('M4.5 no session yet -> no register (never attribute a token to '
        'nobody)', () async {
      final h = harness();
      addTearDown(h.registrar.dispose);

      await h.registrar.notifyLogin();
      expect(h.dio.paths, isEmpty);

      // POS CONTROL: the same registrar DOES register once a session exists,
      // so the empty above is a guard and not a dead harness.
      await login(h.store, 'user-A');
      await h.registrar.notifyLogin();
      expect(h.dio.paths, hasLength(1));
    });
  });

  group('M4.b — the app-level seam (STATIC evidence, labelled as such)', () {
    // GATE.md §3: `static` can never prove the code runs. What it CAN prove is
    // that the two calls sit in the correct BRANCHES — the failure mode where
    // both are present but transposed passes any "contains" check and reds
    // here.
    test('app.dart calls notifyLogin on authenticated and notifySignedOut on '
        'unauthenticated — in that order, in those branches', () {
      final src = readSource('lib/app/app.dart');

      final authIdx = src.indexOf('if (state.isAuthenticated)');
      final unauthIdx = src.indexOf('else if (state.isUnauthenticated)');
      expect(authIdx, greaterThan(-1),
          reason: 'the session listener JeebApp wires is gone or renamed');
      expect(unauthIdx, greaterThan(authIdx));

      final authenticatedBranch = src.substring(authIdx, unauthIdx);
      final unauthenticatedBranch = src.substring(unauthIdx);

      expect(authenticatedBranch, contains('notifyLogin()'),
          reason: 'every transition into authenticated must re-arm device-'
              'token registration (app.dart:387)');
      expect(authenticatedBranch, isNot(contains('notifySignedOut()')));
      expect(
        unauthenticatedBranch.substring(
          0,
          // Bound the window so a later unrelated mention cannot satisfy it.
          unauthenticatedBranch.length.clamp(0, 1200),
        ),
        contains('notifySignedOut()'),
        reason: 'sign-out must clear the (user, token) dedup',
      );
    });

    test('the dedup key is composed of BOTH the user and the token', () {
      final src =
          readSource('lib/core/notifications/data/device_token_registrar.dart');
      expect(src, contains('_key(String? userId, String token)'),
          reason: 'a token-only key is the JEBV4-159 defect');
      // The one-shot latch must not come back as a FIELD. It is still named in
      // the file's doc comment — deliberately, dated as history, which is this
      // programme's T9 doctrine and the opposite of a defect — so a bare
      // `contains('bool _registered')` reds on the very paragraph that records
      // the fix. Match a declaration on a non-comment line instead.
      final declarations = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .where((l) => RegExp(r'^\s*bool\s+_registered\b').hasMatch(l))
          .toList();
      expect(declarations, isEmpty,
          reason: 'the one-shot latch is back as a field: $declarations');

      // POS CONTROL for that matcher: it DOES find the real field declarations
      // in this file, so the empty result above is a measurement.
      final anyBoolField = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .where((l) => RegExp(r'^\s*bool\s+_\w+').hasMatch(l))
          .toList();
      expect(anyBoolField, isNotEmpty,
          reason: 'the declaration matcher found no bool field at all in this '
              'file, so its "no _registered" answer proves nothing');

      // And the historical record of the latch is retained, not erased.
      expect(src, contains('_registered'),
          reason: 'T9 doctrine: the superseded latch is named in the doc '
              'comment so the next reader knows what the (user, token) key '
              'replaced. Deleting that paragraph loses the reason.');
      expect(src, contains(_registerPath));
    });
  });
}
