// Super-login ⇄ real-login (OTP) post-auth PARITY.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/notifications/data/device_token_registrar.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/session/session_cubit.dart';
import 'package:jeeb_mobile/core/session/session_state.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_cubit.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_sheet.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_state.dart';

import 'support/sync_app_localizations.dart';

const _registerPath = '/api/PushNotification/register';

/// Real gateway-minted session shape (never a client mint).
const _session = SuperLoginSession(
  userId: 'super-user-001',
  accessToken: 'real-access-token',
  refreshToken: 'real-refresh-token',
);

/// Records every register PUT so a test can assert the app → gateway hop fired
/// exactly once. Mirrors the RecordingDio in the registrar tests.
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

/// In-memory secure storage so a REAL [AuthTokenStore] can be shared by the
/// super-login cubit (writes), the session gate (reads token), and the
/// registrar (reads userId) — one keystore, exactly like production.
class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

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
}

class _FakeSuperLoginService implements SuperLoginService {
  SuperLoginResult result = const SuperLoginSuccess(_session);

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async =>
      result;
}

void main() {
  late _FakeSecureStorage storage;
  late AuthTokenStore tokenStore;
  late SessionCubit session;

  setUp(() {
    storage = _FakeSecureStorage();
    tokenStore = AuthTokenStore(storage: storage);
    session = SessionCubit(tokenStore: tokenStore);
  });

  tearDown(() async {
    await session.close();
  });

  SuperLoginCubit makeCubit() => SuperLoginCubit(
        service: _FakeSuperLoginService(),
        tokenStore: tokenStore,
      );

  // ── Link 1: the sheet establishes the session on super-login success ──────
  group('Link 1 — super-login success drives the shared session gate', () {
    Widget host(SuperLoginCubit cubit, {SessionCubit? sessionArg}) =>
        wrapForTest(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showSuperLoginSheet(
                    context,
                    cubit: cubit,
                    session: sessionArg,
                    initialUserId: 'super-user-001',
                    initialPasscode: 's3cret',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

    testWidgets(
        'success refreshes the owned SessionCubit → the gate stream emits '
        'unauthenticated → authenticated (real-login establishment)',
        (tester) async {
      final emitted = <SessionStatus>[];
      final sub = session.stream.listen((s) => emitted.add(s.status));
      addTearDown(sub.cancel);

      await tester.pumpWidget(host(makeCubit(), sessionArg: session));
      // Cold gate: no token yet → unauthenticated (like app.dart's boot refresh).
      await session.refresh();
      await tester.pump();

      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Pre-filled sheet opens submit-ready; tap the CTA. Fixed pumps only —
      await tester.tap(find.byKey(const Key('superLogin.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // The owned session-gate stream went unauthenticated → authenticated,
      expect(
        emitted,
        containsAllInOrder(<SessionStatus>[
          SessionStatus.unauthenticated,
          SessionStatus.authenticated,
        ]),
        reason: 'super-login success must push an authenticated transition onto '
            'the owned session-gate stream — the real-login establishment.',
      );
      expect(session.state.isAuthenticated, isTrue);
      // Real gateway tokens on the keystore (never a client mint).
      expect(await tokenStore.accessToken, 'real-access-token');
      expect(await tokenStore.userId, 'super-user-001');
      // Sheet popped on success (unchanged UX contract).
      expect(find.byKey(const Key('superLogin.submit')), findsNothing);
    });

    testWidgets(
        'FAIL-WITHOUT: with no SessionCubit wired the sheet still pops but the '
        'gate never emits authenticated (proves the sheet-driven refresh is '
        'what makes establishment intrinsic to super-login)', (tester) async {
      final emitted = <SessionStatus>[];
      final sub = session.stream.listen((s) => emitted.add(s.status));
      addTearDown(sub.cancel);

      await tester.pumpWidget(host(makeCubit(), sessionArg: null));
      await session.refresh();
      await tester.pump();
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('superLogin.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(emitted, <SessionStatus>[SessionStatus.unauthenticated],
          reason: 'without the sheet-driven refresh, no authenticated emission');
      expect(find.byKey(const Key('superLogin.submit')), findsNothing);
    });
  });

  // ── Link 2: the authenticated emission triggers device registration ───────
  test(
      'Link 2 — a real SuperLoginCubit success + session refresh drives the '
      'app.dart-shaped gate listener → DeviceTokenRegistrar.notifyLogin() fires '
      'PUT /api/PushNotification/register once (no client mint)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final dio = _RecordingDio();
    final transport = FakePushTransport(token: 'fcm-parity-token');
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: Duration.zero,
      maxAttempts: 1,
    );
    addTearDown(() async {
      await registrar.dispose();
      await transport.dispose();
    });

    // Mirror app.dart `_wireSessionRoleSync`: on every transition INTO the
    Future<void>? pendingRegistration;
    final sub = session.stream.listen((state) {
      if (state.isAuthenticated) {
        pendingRegistration = registrar.notifyLogin();
      }
    });
    addTearDown(sub.cancel);

    // Cold gate: unauthenticated before login.
    await session.refresh();
    expect(session.state.isAuthenticated, isFalse);

    // Real super-login success: the cubit persists the REAL gateway tokens.
    final cubit = makeCubit();
    addTearDown(cubit.close);
    await cubit.submit(userId: 'super-user-001', passcode: 's3cret');
    expect(cubit.state.status, SuperLoginStatus.success);

    // The sheet's establishment step (source change): refresh the owned gate.
    await session.refresh();
    // Let the stream deliver the authenticated event to the gate listener.
    await Future<void>.delayed(Duration.zero);
    await pendingRegistration;

    // The authenticated emission fired notifyLogin() → exactly one register PUT.
    expect(dio.paths, <String>[_registerPath]);
    expect(dio.bodies.single['fcmToken'], 'fcm-parity-token');
    expect(dio.bodies.single['deviceId'], isNotEmpty);
    // Identity is server-derived from the bearer; the body carries no userId,
    expect(dio.bodies.single.containsKey('userId'), isFalse);
    expect(await tokenStore.accessToken, 'real-access-token');
    expect(await tokenStore.userId, 'super-user-001');
  });
}
