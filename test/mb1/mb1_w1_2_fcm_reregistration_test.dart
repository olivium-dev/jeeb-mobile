import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/notifications/data/device_token_registrar.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';

import 'mb1_source_lens.dart';

/// MB1 member item **W1.2** — FCM re-registration on login / user-switch.
///
/// ## Why this file exists when W1.2 is a "proof-only rider"
///
/// `MB1.md` books W1.2 at **0 writer-minutes** because the code is already
/// shipped (`app.dart:387`, `device_token_registrar.dart`). A rider with no
/// test of its own is a rider a verifier cannot fail *independently*: if the
/// only thing that reds is the whole suite, the gate cannot say WHICH member
/// item broke, and `GATE.md` §8 (revert one commit, not the batch) has nothing
/// to act on.
///
/// So this file is the W1.2 **row of the pack**. It is deliberately narrow: it
/// asserts the one property MB1 leans on — that a **user switch on a live
/// process re-registers the new identity** — and the one wiring fact that makes
/// that property reachable from the app.
///
/// ## The regression it is shaped against (JEBV4-159)
///
/// The predecessor was a one-shot `bool` latch that flipped `true` on the first
/// successful register and then short-circuited every later call for the life
/// of the process. After a sign-out→sign-in or a super-login account switch the
/// NEW user was never registered, the push service resolved them to zero device
/// tokens, and targeted pushes silently no-op'd. Nothing threw; nothing logged
/// an error; the only symptom was a push that never arrived.
///
/// That matters to MB1 specifically because **V-2's user-switch leg** — "user A
/// out, user B in on the same handset; a push addressed to B lands in B's shade
/// and a push addressed to A does NOT" — is unprovable if the switch never
/// registers B in the first place.
///
/// ## What this file can and cannot prove
///
/// `suite` class. It proves the app→gateway **register hop is issued** for the
/// switched-in identity, over a recording [Dio]. It proves **nothing** about
/// arrival: whether the gateway forwards to the push microservice, and whether
/// FCM delivers to a shade, is `device` class and is V-2's row. A green run
/// here with a dead transport looks identical to a green run with a live one.

/// Records every PUT so a test can count the register hops and read their
/// bodies. Same shape as the fake in `test/device_token_registrar_login_test.dart`.
class _RecordingDio extends Fake implements Dio {
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
    bodies.add(data! as Map<String, dynamic>);
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
  }) async => _data[key];

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
  const registerPath = '/api/PushNotification/register';

  late SharedPreferences prefs;
  late AuthTokenStore tokenStore;
  late _RecordingDio dio;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    tokenStore = AuthTokenStore(storage: _FakeSecureStorage());
    dio = _RecordingDio();
  });

  DeviceTokenRegistrar build(FakePushTransport transport) =>
      DeviceTokenRegistrar(
        dio: dio,
        tokenStore: tokenStore,
        transport: transport,
        prefs: prefs,
        retryInterval: Duration.zero,
        // One attempt: the cold-start poll gives up immediately (no session),
        // so every hop counted below is attributable to a login transition and
        // not to the poll racing it.
        maxAttempts: 1,
      );

  Future<void> signIn(String userId) => tokenStore.save(
    accessToken: 'jwt-$userId',
    refreshToken: 'refresh-$userId',
    userId: userId,
  );

  group('MB1 W1.2 — a user switch on a LIVE process re-registers', () {
    test(
      'A out, B in on the same instance ⇒ TWO register hops, not one',
      () async {
        final registrar = build(FakePushTransport(token: 'fcm-shared-handset'));
        await registrar.start();
        await pumpEventQueue();

        await signIn('user-A');
        await registrar.notifyLogin();
        expect(
          dio.paths,
          <String>[registerPath],
          reason: 'the first login must register A',
        );

        // The account switch. `AuthTokenStore` now resolves a different userId
        // on the SAME live registrar and the SAME FCM token — precisely the
        // shape the old one-shot latch swallowed.
        registrar.notifySignedOut();
        await signIn('user-B');
        await registrar.notifyLogin();

        expect(
          dio.paths,
          <String>[registerPath, registerPath],
          reason:
              'JEBV4-159: a switched-in user that is never registered has '
              'zero device tokens server-side, so every targeted push to B '
              'silently no-ops. MB1 V-2 cannot run its user-switch leg at '
              'all if this hop is missing.',
        );
        expect(dio.bodies.last['fcmToken'], 'fcm-shared-handset');
        expect(dio.bodies.last['deviceId'], isNotEmpty);

        await registrar.dispose();
      },
    );

    test(
      'the switch survives WITHOUT a sign-out (super-login account switch)',
      () async {
        // The super-login sheet re-emits `authenticated` without ever passing
        // through `unauthenticated`, so `notifySignedOut()` never fires. The
        // dedup key must do the work on its own.
        final registrar = build(FakePushTransport(token: 'fcm-superlogin'));
        await registrar.start();
        await pumpEventQueue();

        await signIn('user-A');
        await registrar.notifyLogin();
        await signIn('user-B');
        await registrar.notifyLogin();

        expect(
          dio.paths.length,
          2,
          reason:
              'the dedup key is (userId, token). A key of token ALONE — or a '
              'bool latch — collapses these two logins into one hop and '
              'leaves B unreachable.',
        );

        await registrar.dispose();
      },
    );

    test(
      'NEGATIVE CONTROL for the counter: the SAME identity twice is ONE hop',
      () async {
        // Without this the test above is satisfied by a registrar that fires on
        // every call — which would pass the switch assertion for the wrong
        // reason and re-introduce the duplicate-registration storm the dedup
        // exists to prevent.
        final registrar = build(FakePushTransport(token: 'fcm-idem'));
        await registrar.start();
        await pumpEventQueue();

        await signIn('user-A');
        await registrar.notifyLogin();
        await registrar.notifyLogin();
        await registrar.notifyLogin();

        expect(
          dio.paths.length,
          1,
          reason:
              'a duplicate `authenticated` emission for the SAME (user, token) '
              'must be skipped.',
        );

        await registrar.dispose();
      },
    );

    test('sign-out clears the dedup so the SAME user re-registers', () async {
      // The logout flow fires DELETE /api/PushNotification/device, so the row
      // is gone server-side; an identical-key re-login that was skipped as a
      // "duplicate" would leave the re-logged-in user with zero tokens.
      final registrar = build(FakePushTransport(token: 'fcm-same-user'));
      await registrar.start();
      await pumpEventQueue();

      await signIn('user-A');
      await registrar.notifyLogin();
      registrar.notifySignedOut();
      await registrar.notifyLogin();

      expect(dio.paths.length, 2);

      await registrar.dispose();
    });
  });

  group('MB1 W1.2 — the app-side wiring that makes the above reachable', () {
    test('JeebApp calls notifyLogin() on the AUTHENTICATED arm', () {
      // `MB1.md` cites `lib/app/app.dart:387` by line. Line numbers rot, so the
      // receipt is expressed against comment-stripped source instead: a doc
      // comment naming `notifyLogin` is not a call site, and the pre-run-15
      // tree had exactly that shape.
      final app = MB1Source.strippedLib('lib/app/app.dart');
      expect(
        app,
        contains('notifyLogin()'),
        reason:
            'without this call the registrar only ever fires from its own '
            'bounded cold-start poll, which expires before an interactive '
            'login on a slow device (run-15 root cause).',
      );
      expect(app, contains('notifySignedOut()'));
      expect(
        app.indexOf('isAuthenticated'),
        lessThan(app.indexOf('notifyLogin()')),
        reason: 'the call must sit on the authenticated arm of the session '
            'listener, not on an unconditional path.',
      );
    });

    test(
      'the registrar dedups on (userId, token) — no one-shot bool latch',
      () {
        final src = MB1Source.strippedLib(
          'lib/core/notifications/data/device_token_registrar.dart',
        );
        expect(
          src,
          contains('_lastRegisteredKey'),
          reason: 'the (userId, token) key is the fix.',
        );
        expect(
          RegExp(r'bool\s+_registered\b').hasMatch(src),
          isFalse,
          reason:
              'JEBV4-159 root cause. A bool latch here reds the switch test '
              'above too — this receipt exists so the FAILURE NAMES THE '
              'CAUSE instead of only the symptom.',
        );
        // POSITIVE CONTROL for the regex: it can match a bool field when one
        // is present, so the isFalse above is a measurement, not a typo.
        expect(
          RegExp(r'bool\s+_registered\b').hasMatch('  bool _registered = false;'),
          isTrue,
        );
      },
    );
  });

  group('the non-claim, stated explicitly', () {
    test('no push ARRIVAL is proven here — that is V-2 device class', () {
      // Recorded as an assertion rather than a comment so it cannot quietly
      // stop being true. `_RecordingDio` is a Fake: nothing in this file opens
      // a socket, and `Platform.environment` is never consulted for a host.
      expect(dio, isA<Fake>());
      expect(
        Platform.environment.containsKey('JEEB_PUSH_ARRIVAL_PROVEN'),
        isFalse,
        reason: 'there is no such thing. A suite cannot witness a shade.',
      );
    });
  });
}
