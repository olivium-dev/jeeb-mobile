import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/auth/application/set_password_cubit.dart';
import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/presentation/set_password_screen.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_result.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cancellation_screen.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cubit/cancellation_cubit.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _RejectedToken implements AuthRepository {
  _RejectedToken(this.failure);
  final AuthFailure failure;
  int attempts = 0;
  @override
  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  }) async {
    attempts++;
    throw AuthRepositoryException(failure);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RejectedCancellation implements CancellationRepository {
  _RejectedCancellation(this.failure);
  final CancellationFailure failure;
  int attempts = 0;
  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async {
    attempts++;
    throw CancellationException(null, failure);
  }
}

Widget _routeHarness(Widget screen, Locale locale, {bool standalone = false}) {
  final router = GoRouter(
    initialLocation: standalone ? '/edit' : '/base/edit',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME_DESTINATION')),
      ),
      GoRoute(path: '/edit', builder: (_, _) => screen),
      GoRoute(
        path: '/base',
        builder: (_, _) => const Scaffold(body: Text('BACK_DESTINATION')),
        routes: [GoRoute(path: 'edit', builder: (_, _) => screen)],
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, _) => const Scaffold(body: Text('SETTINGS_DESTINATION')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(
    theme: AppTheme.midnight(),
    routerConfig: router,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final failure in [
      AuthFailure.invalidToken,
      AuthFailure.invalidRecoveryCode,
      AuthFailure.invalidCredentials,
    ]) {
      testWidgets(
        'rejected token cannot be edited into a retry: $failure ${locale.languageCode}',
        (tester) async {
          useReduceMotion(tester);
          final repo = _RejectedToken(failure);
          late SetPasswordCubit cubit;
          await tester.pumpWidget(
            _routeHarness(
              SetPasswordScreen(
                cubitFactory: () => cubit = SetPasswordCubit(
                  repository: repo,
                  email: 'fixture@example.test',
                  resetToken: 'rejected-token',
                ),
              ),
              locale,
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.bySemanticsIdentifier('setpw_new_field'),
            'ValidPassword2',
          );
          await tester.enterText(
            find.bySemanticsIdentifier('setpw_confirm_field'),
            'ValidPassword2',
          );
          await tester.tap(find.bySemanticsIdentifier('setpw_submit_cta'));
          await tester.pumpAndSettle();
          expect(repo.attempts, 1);
          expect(cubit.state.requiresExit, isTrue);
          cubit.acknowledgeError();
          await cubit.submit(
            newPassword: 'AnotherPassword3',
            confirmPassword: 'AnotherPassword3',
          );
          await tester.pumpAndSettle();
          expect(repo.attempts, 1);
          expect(cubit.state.failure, failure);
          expect(find.bySemanticsIdentifier('setpw_submit_cta'), findsNothing);
          expect(
            find.bySemanticsIdentifier('setpw_validation_error'),
            findsOneWidget,
          );
          expect(
            find.text(
              locale.languageCode == 'ar'
                  ? 'ما قبلنا التفويض. ارجع لتكمّل.'
                  : 'Authorization was rejected. Go back to continue.',
            ),
            findsOneWidget,
          );
          await tester.tap(find.bySemanticsIdentifier('setpw_exit_cta'));
          await tester.pumpAndSettle();
          expect(find.text('SETTINGS_DESTINATION'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final failure in [
      CancellationFailure.notAParty,
      CancellationFailure.forbidden,
      CancellationFailure.tooLate,
    ]) {
      for (final standalone in [false, true]) {
        testWidgets(
          'terminal cancellation has exit not repeat write: $failure ${locale.languageCode} standalone=$standalone',
          (tester) async {
            useReduceMotion(tester);
            final repo = _RejectedCancellation(failure);
            await tester.pumpWidget(
              _routeHarness(
                CancellationScreen(
                  deliveryId: 'delivery-fixture',
                  isJeeber: false,
                  repository: repo,
                  initialReason: 'changed_mind',
                ),
                locale,
                standalone: standalone,
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.bySemanticsIdentifier('cancellation_submit_cta'),
            );
            await tester.pumpAndSettle();
            final exit = find.bySemanticsIdentifier('cancellation_exit_cta');
            expect(exit, findsOneWidget);
            final cubit = tester.element(exit).read<CancellationCubit>();
            expect(repo.attempts, 1);
            expect(cubit.state.isTerminalRefusal, isTrue);
            cubit.reset();
            await cubit.submit(
              deliveryId: 'delivery-fixture',
              reason: 'other',
              otherDetails: 'Changed reason',
            );
            expect(repo.attempts, 1);
            expect(cubit.state.isTerminalRefusal, isTrue);
            expect(
              find.bySemanticsIdentifier('cancellation_submit_cta'),
              findsNothing,
            );
            await tester.tap(exit);
            await tester.pumpAndSettle();
            expect(
              find.text(standalone ? 'HOME_DESTINATION' : 'BACK_DESTINATION'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    for (final failure in [
      AuthFailure.network,
      AuthFailure.serverError,
      AuthFailure.rateLimited,
      AuthFailure.badRequest,
      AuthFailure.unknown,
    ]) {
      testWidgets(
        'repairable password failure permits a real retry: $failure ${locale.languageCode}',
        (tester) async {
          useReduceMotion(tester);
          final repo = _RejectedToken(failure);
          late SetPasswordCubit cubit;
          await tester.pumpWidget(
            _routeHarness(
              SetPasswordScreen(
                cubitFactory: () => cubit = SetPasswordCubit(
                  repository: repo,
                  email: 'fixture@example.test',
                ),
              ),
              locale,
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.bySemanticsIdentifier('setpw_new_field'),
            'ValidPassword2',
          );
          await tester.enterText(
            find.bySemanticsIdentifier('setpw_confirm_field'),
            'ValidPassword2',
          );
          final submit = find.bySemanticsIdentifier('setpw_submit_cta');
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(repo.attempts, 1);
          expect(cubit.state.requiresExit, isFalse);
          expect(cubit.state.failure, failure);
          expect(find.bySemanticsIdentifier('setpw_exit_cta'), findsNothing);
          await tester.enterText(
            find.bySemanticsIdentifier('setpw_new_field'),
            'AnotherPassword3',
          );
          await tester.enterText(
            find.bySemanticsIdentifier('setpw_confirm_field'),
            'AnotherPassword3',
          );
          await tester.pumpAndSettle();
          expect(cubit.state.failure, isNull);
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(repo.attempts, 2);
          expect(cubit.state.failure, failure);
          expect(cubit.state.requiresExit, isFalse);
          expect(
            find.bySemanticsIdentifier('setpw_validation_error'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final failure in [
      CancellationFailure.network,
      CancellationFailure.timeout,
      CancellationFailure.reasonRequired,
      CancellationFailure.rateLimited,
      CancellationFailure.server,
      CancellationFailure.unknown,
    ]) {
      testWidgets(
        'repairable cancellation failure permits a real retry: $failure ${locale.languageCode}',
        (tester) async {
          useReduceMotion(tester);
          final repo = _RejectedCancellation(failure);
          await tester.pumpWidget(
            _routeHarness(
              CancellationScreen(
                deliveryId: 'delivery-fixture',
                isJeeber: false,
                repository: repo,
                initialReason: 'changed_mind',
              ),
              locale,
            ),
          );
          await tester.pumpAndSettle();
          final submit = find.bySemanticsIdentifier('cancellation_submit_cta');
          await tester.tap(submit);
          await tester.pumpAndSettle();
          final cubit = tester.element(submit).read<CancellationCubit>();
          expect(repo.attempts, 1);
          expect(cubit.state.isTerminalRefusal, isFalse);
          expect(
            find.bySemanticsIdentifier('cancellation_exit_cta'),
            findsNothing,
          );
          expect(
            find.bySemanticsIdentifier('cancellation_error_note'),
            findsOneWidget,
          );
          cubit.reset();
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsIdentifier('cancellation_error_note'),
            findsNothing,
          );
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(repo.attempts, 2);
          expect(cubit.state.isTerminalRefusal, isFalse);
          expect(
            find.bySemanticsIdentifier('cancellation_error_note'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
