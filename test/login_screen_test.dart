import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/auth/presentation/login_screen.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_demo_user.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_service.dart';

import 'support/sync_app_localizations.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

/// Fake roster service registered into `sl` so the screen's picker resolves it.
class _FakeDemoUserService implements SuperLoginDemoUserService {
  _FakeDemoUserService(this.users);
  final List<SuperLoginDemoUser> users;
  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() async => users;
}

/// Fake super-login service so the pre-filled sheet's DI-built cubit resolves.
class _FakeSuperLoginService implements SuperLoginService {
  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async =>
      const SuperLoginFailure(SuperLoginError.invalidCredentials);
}

const _demoUser = SuperLoginDemoUser(
  userId: '44444444-4444-4444-8444-444444444444',
  name: 'Nour',
  role: 'customer',
  availableRoles: ['customer'],
);

void main() {
  tearDown(() async {
    await sl.reset();
  });

  testWidgets(
      'P1 MOVE: the LOGIN screen now mounts BOTH super-login entry points '
      '(gated behind kDebugMode, compiled out of release)', (tester) async {
    await tester.pumpWidget(wrapForTest(const LoginScreen()));
    await tester.pump();

    // `flutter test` runs under kDebugMode=true, so the relocated dev seam is
    // mounted on the login screen. The same `if (kDebugMode)` guard removes it
    // from release (FR-P0-4 / defect D2) — it can never reach a production user.
    expect(kDebugMode, isTrue);
    expect(find.byKey(const Key('login.superLogin')), findsOneWidget);
    expect(find.byKey(const Key('login.superLoginPlus')), findsOneWidget);
    // QA addressability ids are preserved across the move.
    expect(find.bySemanticsIdentifier('_super_login_link'), findsOneWidget);
    expect(find.bySemanticsIdentifier('super_login_plus_button'), findsOneWidget);
  });

  group('Super user login plus on the login screen (picker → pre-filled sheet)',
      () {
    Future<void> registerRoster(List<SuperLoginDemoUser> users) async {
      await sl.reset();
      sl.registerLazySingleton<SuperLoginDemoUserService>(
        () => _FakeDemoUserService(users),
      );
      // The pre-filled sheet builds its cubit from DI, so these must resolve.
      sl.registerLazySingleton<SuperLoginService>(
        () => _FakeSuperLoginService(),
      );
      sl.registerLazySingleton<AuthTokenStore>(() => _MockAuthTokenStore());
    }

    testWidgets(
        'the plain "Super user login" link is present NEXT TO the plus link',
        (tester) async {
      await registerRoster(const [_demoUser]);
      await tester.pumpWidget(wrapForTest(const LoginScreen()));
      await tester.pump();

      expect(kDebugMode, isTrue);
      expect(find.byKey(const Key('login.superLogin')), findsOneWidget);
      expect(find.byKey(const Key('login.superLoginPlus')), findsOneWidget);
    });

    testWidgets(
        'tapping the plus link lists the (mocked) users; selecting one opens '
        'the super-login sheet pre-filled with submit enabled', (tester) async {
      await registerRoster(const [_demoUser]);
      await tester.pumpWidget(wrapForTest(const LoginScreen()));
      await tester.pump();

      final plus = find.byKey(const Key('login.superLoginPlus'));
      await tester.ensureVisible(plus);
      await tester.pump();
      await tester.tap(plus);
      await tester.pump(); // start the picker route
      await tester.pump(const Duration(milliseconds: 350)); // slide-up done
      await tester.pump(); // resolve the roster future

      // Picker lists the mocked user.
      expect(find.byKey(const Key('superLoginPlus.pickerList')), findsOneWidget);
      expect(find.text('Nour'), findsOneWidget);

      // Select the user → picker pops, sheet opens pre-filled submit-ready.
      await tester
          .tap(find.byKey(Key('superLoginPlus.user.${_demoUser.userId}')));
      await tester.pumpAndSettle(); // picker pops fully
      await tester.pump(); // microtask resolves → sheet route is pushed
      await tester.pump(const Duration(milliseconds: 400)); // sheet open done

      expect(find.byKey(const Key('superLogin.submit')), findsOneWidget);
      expect(
        tester
            .widget<OmdsLoadingButton>(find.byKey(const Key('superLogin.submit')))
            .isEnabled,
        isTrue,
        reason: 'picking a user must open the sheet submit-ready',
      );
      expect(
        tester
            .widget<OmdsTextField>(find.byKey(const Key('superLogin.userId')))
            .controller!
            .text,
        _demoUser.userId,
      );
    });
  });
}
