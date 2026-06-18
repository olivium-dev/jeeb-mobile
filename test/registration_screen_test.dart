import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_demo_user.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_service.dart';
import 'package:jeeb_mobile/features/registration/domain/lebanon_phone.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';
import 'package:jeeb_mobile/shared/first_run/first_run.dart';

import 'support/sync_app_localizations.dart';

class _MockOtpService extends Mock implements OtpService {}

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
  }) async => const SuperLoginFailure(SuperLoginError.invalidCredentials);
}

const _demoUser = SuperLoginDemoUser(
  userId: '44444444-4444-4444-8444-444444444444',
  name: 'Nour',
  role: 'client',
  passcode: 'demo-nour',
);

void main() {
  late _MockOtpService otp;
  late StreamController<DateTime> ticker;

  setUp(() {
    otp = _MockOtpService();
    ticker = StreamController<DateTime>.broadcast();
  });

  tearDown(() async {
    await ticker.close();
  });

  RegistrationCubit makeCubit() =>
      RegistrationCubit(otpService: otp, tickerFactory: () => ticker.stream);

  testWidgets('phone screen renders the fixed +961 prefix', (tester) async {
    await tester.pumpWidget(
      wrapForTest(RegistrationScreen(cubit: makeCubit())),
    );
    expect(find.byKey(const Key('registration.phonePrefix')), findsOneWidget);
    expect(find.text(LebanonPhone.dialCode), findsOneWidget);
  });

  testWidgets('phone entry surfaces Maestro Semantics ids', (tester) async {
    await tester.pumpWidget(
      wrapForTest(RegistrationScreen(cubit: makeCubit())),
    );
    await tester.pump();

    for (final id in [
      FirstRunSemanticsIds.registrationScreen,
      FirstRunSemanticsIds.registrationHero,
      FirstRunSemanticsIds.registrationHeroLogo,
      FirstRunSemanticsIds.registrationSocialSection,
      FirstRunSemanticsIds.registrationPhoneField,
      FirstRunSemanticsIds.registrationSendCodeButton,
      FirstRunSemanticsIds.superLoginButton,
      FirstRunSemanticsIds.superLoginPlusButton,
    ]) {
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    }
  });

  testWidgets(
    'phone field strips +961 / 0 / separators when user pastes a number',
    (tester) async {
      final cubit = makeCubit();
      await tester.pumpWidget(wrapForTest(RegistrationScreen(cubit: cubit)));
      await tester.enterText(
        find.byKey(const Key('registration.phoneField')),
        '+961 71-123 456',
      );
      await tester.pump();
      expect(cubit.state.phoneInput, '71123456');
      expect(cubit.state.isPhoneReady, isTrue);
    },
  );

  testWidgets('Send code is disabled until 8 digits are typed', (tester) async {
    await tester.pumpWidget(
      wrapForTest(RegistrationScreen(cubit: makeCubit())),
    );
    final disabled = tester.widget<OmdsLoadingButton>(
      find.byKey(const Key('registration.sendCode')),
    );
    expect(disabled.isEnabled, isFalse);

    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();

    final enabled = tester.widget<OmdsLoadingButton>(
      find.byKey(const Key('registration.sendCode')),
    );
    expect(enabled.isEnabled, isTrue);
  });

  testWidgets('tapping Send code navigates to the OTP screen', (tester) async {
    when(
      () => otp.sendCode(any()),
    ).thenAnswer((_) async => OtpSendOutcome.sent);
    await tester.pumpWidget(
      wrapForTest(RegistrationScreen(cubit: makeCubit())),
    );

    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('registration.sendCode')));
    await tester.pumpAndSettle();

    // OTP screen is now on top — its OTP-field key is the unambiguous
    // anchor.
    expect(find.byKey(const Key('registration.otpField')), findsOneWidget);
    expect(find.byKey(const Key('registration.verify')), findsOneWidget);
    verify(() => otp.sendCode('+96171123456')).called(1);
  });

  testWidgets('super-login backdoor is gated behind kDebugMode '
      '(present in debug/test, compiled out of release)', (tester) async {
    await tester.pumpWidget(
      wrapForTest(RegistrationScreen(cubit: makeCubit())),
    );
    await tester.pump();

    // `flutter test` runs under kDebugMode=true, so the dev seam is mounted.
    // The same `if (kDebugMode)` guard removes it entirely from release
    // builds (P0-2 / defect D2) — the super-login entry can never reach a
    // production user.
    expect(kDebugMode, isTrue);
    expect(find.byKey(const Key('registration.superLogin')), findsOneWidget);
  });

  testWidgets(
    'FR-LOGIN: renders the branded hero + welcome heading + or divider '
    '(Rahma/Salehly parity)',
    (tester) async {
      await tester.pumpWidget(
        wrapForTest(RegistrationScreen(cubit: makeCubit())),
      );
      await tester.pump();

      // Branded wordmark hero band (interim register hero, FR-P1-3).
      expect(find.bySemanticsLabel(RegExp('Jeeb')), findsWidgets);
      // Welcome heading promoted above the form.
      expect(find.byKey(const Key('registration.welcome')), findsOneWidget);
      // "social — or — phone" divider between social and the phone block.
      expect(find.byKey(const Key('registration.orDivider')), findsOneWidget);
    },
  );

  testWidgets('D4: exactly ONE "or" divider renders (no duplicate between Google '
      'and the phone field)', (tester) async {
    await tester.pumpWidget(
      wrapForTest(RegistrationScreen(cubit: makeCubit())),
    );
    await tester.pump();

    // The screen owns a single keyed divider. The social section must NOT
    // render its own — that produced the two `content-desc="or"` nodes QA saw.
    expect(find.byKey(const Key('registration.orDivider')), findsOneWidget);
    // The divider label ("or", `registrationSocialDivider`) must appear exactly
    // once — this is the literal QA matched (`content-desc="or"`).
    expect(find.text('or'), findsOneWidget);
  });

  testWidgets('FR-LOGIN: CTA is an OmdsLoadingButton (in-button spinner)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapForTest(RegistrationScreen(cubit: makeCubit())),
    );
    await tester.pump();
    expect(find.byKey(const Key('registration.sendCode')), findsOneWidget);
    expect(
      tester.widget(find.byKey(const Key('registration.sendCode'))),
      isA<OmdsLoadingButton>(),
    );
  });

  testWidgets('FR-LOGIN: register screen lays out RTL under Locale(ar)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapForTest(
        RegistrationScreen(cubit: makeCubit()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    final dir = Directionality.of(
      tester.element(find.byKey(const Key('registration.welcome'))),
    );
    expect(dir, TextDirection.rtl);
    // The Arabic welcome copy renders (value != key, parity-test backed).
    expect(find.text('مرحباً بك في جيب'), findsOneWidget);
  });

  group('Super user login plus (debug-only picker → pre-filled sheet)', () {
    tearDown(() async {
      await sl.reset();
    });

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
      'the "Super user login plus" button is mounted in debug NEXT TO the '
      'original super-login link',
      (tester) async {
        await registerRoster(const [_demoUser]);
        await tester.pumpWidget(
          wrapForTest(RegistrationScreen(cubit: makeCubit())),
        );
        await tester.pump();

        // Both links present — the original is NOT removed.
        expect(kDebugMode, isTrue);
        expect(
          find.byKey(const Key('registration.superLogin')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('registration.superLoginPlus')),
          findsOneWidget,
        );
        // The new button carries the QA addressability id required by the ticket.
        expect(
          find.bySemanticsIdentifier(FirstRunSemanticsIds.superLoginPlusButton),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the plus button lists the (mocked) users; selecting one '
      'opens the super-login sheet pre-filled with submit enabled',
      (tester) async {
        await registerRoster(const [_demoUser]);
        await tester.pumpWidget(
          wrapForTest(RegistrationScreen(cubit: makeCubit())),
        );
        await tester.pump();

        // The plus link sits at the bottom of a scroll view — bring it on-screen
        // (ensureVisible scrolls the nearest Scrollable; scrollUntilVisible is
        // ambiguous here because the tree has more than one Scrollable).
        final plus = find.byKey(const Key('registration.superLoginPlus'));
        await tester.ensureVisible(plus);
        await tester.pump();
        await tester.tap(plus);
        await tester.pump(); // start the picker route
        await tester.pump(const Duration(milliseconds: 350)); // slide-up done
        await tester.pump(); // resolve the roster future

        // Picker lists the mocked user.
        expect(
          find.byKey(const Key('superLoginPlus.pickerList')),
          findsOneWidget,
        );
        expect(find.text('Nour'), findsOneWidget);

        // Select the user → picker pops, sheet opens pre-filled. The picker has no
        // live ticker so pumpAndSettle safely drains its pop transition; the sheet
        // (OmdsLoadingButton live AnimatedSwitcher) is then driven by bare pumps.
        await tester.tap(
          find.byKey(Key('superLoginPlus.user.${_demoUser.userId}')),
        );
        await tester.pumpAndSettle(); // picker pops fully
        await tester.pump(); // microtask resolves → sheet route is pushed
        await tester.pump(const Duration(milliseconds: 400)); // sheet open done

        // The pre-filled sheet is up with submit ENABLED.
        expect(find.byKey(const Key('superLogin.submit')), findsOneWidget);
        expect(
          tester
              .widget<OmdsLoadingButton>(
                find.byKey(const Key('superLogin.submit')),
              )
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
      },
    );
  });
}
