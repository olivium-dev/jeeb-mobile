import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_cubit.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_sheet.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_state.dart';

import 'support/sync_app_localizations.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

/// Fake service whose result is set per test.
class _FakeSuperLoginService implements SuperLoginService {
  SuperLoginResult result = const SuperLoginFailure(SuperLoginError.unknown);
  String? lastUserId;
  String? lastPasscode;

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async {
    lastUserId = userId;
    lastPasscode = passcode;
    return result;
  }
}

const _session = SuperLoginSession(
  userId: 'super-user-001',
  accessToken: 'real-access-token',
  refreshToken: 'real-refresh-token',
);

void main() {
  late _FakeSuperLoginService service;
  late _MockAuthTokenStore tokenStore;

  setUp(() {
    service = _FakeSuperLoginService();
    tokenStore = _MockAuthTokenStore();
    when(() => tokenStore.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {});
  });

  SuperLoginCubit makeCubit() =>
      SuperLoginCubit(service: service, tokenStore: tokenStore);

  // Host that opens the sheet with an injected cubit (no DI needed).
  Widget host(SuperLoginCubit cubit) => wrapForTest(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () => showSuperLoginSheet(context, cubit: cubit),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> openSheet(WidgetTester tester, SuperLoginCubit cubit) async {
    await tester.pumpWidget(host(cubit));
    await tester.tap(find.byKey(const Key('open')));
    // pump() not pumpAndSettle() — OmdsLoadingButton has a live AnimatedSwitcher.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('SuperLoginCubit (FR-P0-4)', () {
    test('on success persists the REAL server tokens (never mock-jwt-*)',
        () async {
      service.result = const SuperLoginSuccess(_session);
      final cubit = makeCubit();

      await cubit.submit(userId: 'super-user-001', passcode: 's3cret');

      expect(cubit.state.status, SuperLoginStatus.success);
      final captured = verify(() => tokenStore.save(
            accessToken: captureAny(named: 'accessToken'),
            refreshToken: captureAny(named: 'refreshToken'),
            userId: captureAny(named: 'userId'),
          )).captured;
      expect(captured[0], 'real-access-token');
      expect(captured[0], isNot(contains('mock-jwt')));
      expect(captured[1], 'real-refresh-token');
      expect(captured[2], 'super-user-001');
    });

    test('on invalid credentials emits error and persists NO token', () async {
      service.result =
          const SuperLoginFailure(SuperLoginError.invalidCredentials);
      final cubit = makeCubit();

      await cubit.submit(userId: 'x', passcode: 'wrong');

      expect(cubit.state.status, SuperLoginStatus.error);
      expect(cubit.state.error, SuperLoginError.invalidCredentials);
      verifyNever(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          ));
    });

    test('empty passcode is rejected client-side without hitting the service',
        () async {
      final cubit = makeCubit();
      await cubit.submit(userId: 'x', passcode: '');
      expect(cubit.state.status, SuperLoginStatus.error);
      expect(service.lastPasscode, isNull); // service never called
    });
  });

  group('Super-login sheet widget (FR-P0-4)', () {
    testWidgets('renders OMDS credential fields + submit, all keyed',
        (tester) async {
      await openSheet(tester, makeCubit());

      expect(find.byKey(const Key('superLogin.title')), findsOneWidget);
      expect(find.byKey(const Key('superLogin.userId')), findsOneWidget);
      expect(find.byKey(const Key('superLogin.passcode')), findsOneWidget);
      expect(find.byKey(const Key('superLogin.submit')), findsOneWidget);
      // OMDS components, not raw widgets.
      expect(tester.widget(find.byKey(const Key('superLogin.userId'))),
          isA<OmdsTextField>());
      expect(tester.widget(find.byKey(const Key('superLogin.passcode'))),
          isA<OMDSPasswordTextField>());
      expect(tester.widget(find.byKey(const Key('superLogin.submit'))),
          isA<OmdsLoadingButton>());
    });

    testWidgets('submit is disabled until both fields are non-empty',
        (tester) async {
      await openSheet(tester, makeCubit());

      OmdsLoadingButton submit() => tester.widget<OmdsLoadingButton>(
            find.byKey(const Key('superLogin.submit')),
          );
      expect(submit().isEnabled, isFalse);

      await tester.enterText(
          find.byKey(const Key('superLogin.userId')), 'super-user-001');
      await tester.pump();
      expect(submit().isEnabled, isFalse); // passcode still empty

      await tester.enterText(
          find.byKey(const Key('superLogin.passcode')), 's3cret');
      await tester.pump();
      expect(submit().isEnabled, isTrue);
    });

    testWidgets('happy path: valid credential pops the sheet with success',
        (tester) async {
      service.result = const SuperLoginSuccess(_session);
      await openSheet(tester, makeCubit());

      await tester.enterText(
          find.byKey(const Key('superLogin.userId')), 'super-user-001');
      await tester.enterText(
          find.byKey(const Key('superLogin.passcode')), 's3cret');
      await tester.pump();
      await tester.tap(find.byKey(const Key('superLogin.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sheet dismissed on success.
      expect(find.byKey(const Key('superLogin.submit')), findsNothing);
      expect(service.lastUserId, 'super-user-001');
      expect(service.lastPasscode, 's3cret');
    });

    testWidgets('negative path (DEF-2): bad credential surfaces the error '
        'INLINE under the passcode field, sheet stays open', (tester) async {
      service.result =
          const SuperLoginFailure(SuperLoginError.invalidCredentials);
      await openSheet(tester, makeCubit());

      await tester.enterText(
          find.byKey(const Key('superLogin.userId')), 'x');
      await tester.enterText(
          find.byKey(const Key('superLogin.passcode')), 'wrong');
      await tester.pump();
      await tester.tap(find.byKey(const Key('superLogin.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sheet still open, localized error surfaced INLINE (not a transient
      // snackbar) — the 401 ProblemDetails is now visible to the user.
      expect(find.byKey(const Key('superLogin.submit')), findsOneWidget);
      expect(
        find.text('Invalid user id or passcode. Please try again.'),
        findsOneWidget,
      );
      // The message is wired into the passcode field's OMDS errorText slot,
      // so it lives inside the passcode field's subtree (inline), not in a
      // ScaffoldMessenger overlay.
      expect(
        find.descendant(
          of: find.byKey(const Key('superLogin.passcode')),
          matching:
              find.text('Invalid user id or passcode. Please try again.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('DEF-2: the inline error clears as soon as the user edits '
        'a field', (tester) async {
      service.result =
          const SuperLoginFailure(SuperLoginError.invalidCredentials);
      await openSheet(tester, makeCubit());

      await tester.enterText(
          find.byKey(const Key('superLogin.userId')), 'x');
      await tester.enterText(
          find.byKey(const Key('superLogin.passcode')), 'wrong');
      await tester.pump();
      await tester.tap(find.byKey(const Key('superLogin.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Invalid user id or passcode. Please try again.'),
        findsOneWidget,
      );

      // User starts correcting the passcode → error must disappear.
      await tester.enterText(
          find.byKey(const Key('superLogin.passcode')), 'wrong2');
      await tester.pump();
      expect(
        find.text('Invalid user id or passcode. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('renders RTL with Arabic copy under Locale(ar)',
        (tester) async {
      await tester.pumpWidget(wrapForTest(
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              key: const Key('open'),
              onPressed: () =>
                  showSuperLoginSheet(context, cubit: makeCubit()),
              child: const Text('open'),
            ),
          ),
        ),
        locale: const Locale('ar'),
      ));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dir = Directionality.of(
        tester.element(find.byKey(const Key('superLogin.title'))),
      );
      expect(dir, TextDirection.rtl);
      expect(find.text('تسجيل دخول المستخدم الخارق'), findsOneWidget);
    });
  });

  group('Super-login sheet pre-fill (Super user login plus)', () {
    // Host that opens the sheet pre-filled with explicit initial values.
    Widget prefilledHost(
      SuperLoginCubit cubit, {
      String? initialUserId,
      String? initialPasscode,
    }) =>
        wrapForTest(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showSuperLoginSheet(
                    context,
                    cubit: cubit,
                    initialUserId: initialUserId,
                    initialPasscode: initialPasscode,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

    Future<void> openPrefilled(
      WidgetTester tester,
      SuperLoginCubit cubit, {
      String? initialUserId,
      String? initialPasscode,
    }) async {
      await tester.pumpWidget(prefilledHost(
        cubit,
        initialUserId: initialUserId,
        initialPasscode: initialPasscode,
      ));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets(
        'pre-fills both controllers AND enables submit immediately '
        '(picker happy path)', (tester) async {
      await openPrefilled(
        tester,
        makeCubit(),
        initialUserId: '22222222-2222-4222-8222-222222222222',
        initialPasscode: 'demo-kamal',
      );

      // Both fields arrive populated.
      expect(
        tester
            .widget<OmdsTextField>(find.byKey(const Key('superLogin.userId')))
            .controller!
            .text,
        '22222222-2222-4222-8222-222222222222',
      );
      expect(
        tester
            .widget<OMDSPasswordTextField>(
                find.byKey(const Key('superLogin.passcode')))
            .controller
            .text,
        'demo-kamal',
      );
      // FAIL-WITHOUT: without the initState _computeCanSubmit() call the button
      // would be disabled despite both fields being non-empty.
      expect(
        tester
            .widget<OmdsLoadingButton>(find.byKey(const Key('superLogin.submit')))
            .isEnabled,
        isTrue,
        reason: 'a pre-filled sheet must open submit-ready',
      );
    });

    testWidgets(
        'a pre-filled sheet submits the SAME credentials to the service '
        '(no client-side edit needed)', (tester) async {
      service.result = const SuperLoginSuccess(_session);
      final cubit = makeCubit();
      await openPrefilled(
        tester,
        cubit,
        initialUserId: '44444444-4444-4444-8444-444444444444',
        initialPasscode: 'demo-nour',
      );

      await tester.tap(find.byKey(const Key('superLogin.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(service.lastUserId, '44444444-4444-4444-8444-444444444444');
      expect(service.lastPasscode, 'demo-nour');
      // Sheet popped on success.
      expect(find.byKey(const Key('superLogin.submit')), findsNothing);
    });

    testWidgets(
        'no pre-fill (direct open) keeps fields empty + submit disabled '
        '(backward-compat: the original behaviour)', (tester) async {
      await openPrefilled(tester, makeCubit());

      expect(
        tester
            .widget<OmdsTextField>(find.byKey(const Key('superLogin.userId')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<OmdsLoadingButton>(find.byKey(const Key('superLogin.submit')))
            .isEnabled,
        isFalse,
      );
    });
  });
}
