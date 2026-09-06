// UX-24: the cubit collapsed lockout / not-enrolled / no-hardware into one
// retryable "failed", and the screen kept offering a Retry the OS refuses.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/biometric_lock_screen_fixtures.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_state.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/biometric_auth/presentation/biometric_lock_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _harness(BiometricLockCubit cubit, {Locale locale = const Locale('en')}) {
  final GoRouter router = GoRouter(
    initialLocation: '/lock',
    routes: <RouteBase>[
      GoRoute(path: '/lock', builder: (_, _) => const BiometricLockScreen()),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (_, _) => const Scaffold(body: Text('register')),
      ),
    ],
  );
  return BlocProvider<BiometricLockCubit>.value(
    value: cubit,
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  group('the cubit carries the OS refusal', () {
    Future<BiometricLockCubit> afterAuthenticate(
      BiometricFailure failure,
    ) async {
      final BiometricLockCubit cubit = biometricLockScreenCubitOver(
        BiometricLockScreenThrowingGateway(failure),
        pin: '1234',
      );
      await cubit.authenticate();
      return cubit;
    }

    for (final BiometricFailure failure in BiometricFailure.values) {
      test('a thrown ${failure.name} reaches the state', () async {
        final BiometricLockCubit cubit = await afterAuthenticate(failure);
        expect(cubit.state.hasFailed, isTrue);
        expect(cubit.state.failure, failure);
        await cubit.close();
      });
    }

    test('a declined attempt still fails with NO failure kind', () async {
      final BiometricLockCubit cubit = BiometricLockScreenSeededCubit(
        const BiometricLockState(phase: BiometricLockPhase.locked),
        gateway: BiometricLockScreenFakeGateway(succeeds: false),
      );
      await cubit.authenticate();
      expect(cubit.state.hasFailed, isTrue);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.isTerminalFailure, isFalse);
      await cubit.close();
    });

    test('unknown is retryable; the other four are terminal', () {
      expect(
        const BiometricLockState(failure: BiometricFailure.unknown)
            .isTerminalFailure,
        isFalse,
      );
      for (final BiometricFailure failure in <BiometricFailure>[
        BiometricFailure.lockedOut,
        BiometricFailure.notEnrolled,
        BiometricFailure.unavailable,
        BiometricFailure.noDeviceCredential,
      ]) {
        expect(
          BiometricLockState(failure: failure).isTerminalFailure,
          isTrue,
          reason: failure.name,
        );
      }
    });
  });

  group('the screen', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      final String tag = locale.languageCode;

      testWidgets('lockout prints its own line and kills Retry ($tag)',
          (tester) async {
        final BiometricLockCubit cubit = biometricLockScreenLockedOutCubit();
        addTearDown(cubit.close);
        await tester.pumpWidget(_harness(cubit, locale: locale));
        await tester.pumpAndSettle();

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(BiometricLockScreen)),
        );
        expect(find.text(l10n.biometricLockedOut), findsOneWidget);
        expect(find.text(l10n.biometricLockFailure), findsNothing);

        final JeebCtaButton retry = tester.widget<JeebCtaButton>(
          find.descendant(
            of: find.bySemanticsIdentifier(
              'biometric_unlock_authenticate_cta',
            ),
            matching: find.byType(JeebCtaButton),
          ),
        );
        expect(retry.isEnabled, isFalse);

        final JeebCtaButton fallback = tester.widget<JeebCtaButton>(
          find.descendant(
            of: find.bySemanticsIdentifier(
              'biometric_unlock_use_password_link',
            ),
            matching: find.byType(JeebCtaButton),
          ),
        );
        expect(fallback.variant, JeebCtaVariant.primary);
      });

      testWidgets('not-enrolled prints its own line ($tag)', (tester) async {
        final BiometricLockCubit cubit = biometricLockScreenNotEnrolledCubit();
        addTearDown(cubit.close);
        await tester.pumpWidget(_harness(cubit, locale: locale));
        await tester.pumpAndSettle();

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(BiometricLockScreen)),
        );
        expect(find.text(l10n.biometricNotEnrolled), findsOneWidget);
      });
    }

    testWidgets('a plain decline keeps the retryable pill', (tester) async {
      final BiometricLockCubit cubit = biometricLockScreenFailedCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(BiometricLockScreen)),
      );
      expect(find.text(l10n.biometricLockFailure), findsOneWidget);

      final JeebCtaButton retry = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('biometric_unlock_authenticate_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(retry.isEnabled, isTrue);
    });
  });
}
