// AUTH-02: `setpw_validation_error` printed ONE string for a mismatch, a weak
// password, a dead reset token and a 5xx alike.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/auth/application/set_password_cubit.dart';
import 'package:jeeb_mobile/features/auth/application/set_password_state.dart';
import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/presentation/set_password_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Rejects every `setPassword` with a scripted failure.
class _RejectingAuthRepository implements AuthRepository {
  const _RejectingAuthRepository(this.failure);

  final AuthFailure failure;

  @override
  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  }) async =>
      throw AuthRepositoryException(failure);

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    String? name,
  }) async =>
      throw AuthRepositoryException(failure);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async =>
      throw AuthRepositoryException(failure);

  @override
  Future<RecoveryRequestResult> requestRecovery({required String email}) async =>
      throw AuthRepositoryException(failure);

  @override
  Future<RecoveryVerifyResult> verifyRecovery({
    required String email,
    required String code,
  }) async =>
      throw AuthRepositoryException(failure);
}

/// Rejects with something the [AuthFailure] enum cannot express.
class _ThrowingAuthRepository extends _RejectingAuthRepository {
  const _ThrowingAuthRepository() : super(AuthFailure.unknown);

  @override
  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  }) async =>
      throw const ServerFailure(status: 500);
}

void main() {
  const String valid = 'NewPassword2';

  Future<AppLocalizations> pumpFailure(
    WidgetTester tester,
    AuthRepository repository,
    Locale locale, {
    String confirm = valid,
  }) async {
    late SetPasswordCubit cubit;
    await tester.pumpWidget(
      wrapForTest(
        SetPasswordScreen(
          cubitFactory: () => cubit = SetPasswordCubit(
            repository: repository,
            email: 'a@b.test',
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.bySemanticsIdentifier('setpw_new_field'),
      valid,
    );
    await tester.enterText(
      find.bySemanticsIdentifier('setpw_confirm_field'),
      confirm,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('setpw_submit_cta'));
    await tester.pumpAndSettle();

    expect(cubit.state.status, SetPasswordStatus.failed);
    return AppLocalizations.of(
      tester.element(find.byType(SetPasswordScreen)),
    );
  }

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('a mismatch keeps the validation string ($tag)',
        (tester) async {
      final AppLocalizations l10n = await pumpFailure(
        tester,
        const _RejectingAuthRepository(AuthFailure.network),
        locale,
        confirm: 'DifferentPassword3',
      );
      expect(find.bySemanticsIdentifier('setpw_validation_error'), findsOneWidget);
      expect(find.text(l10n.setpwValidationError), findsOneWidget);
    });

    testWidgets('a network failure prints the network line ($tag)',
        (tester) async {
      final AppLocalizations l10n = await pumpFailure(
        tester,
        const _RejectingAuthRepository(AuthFailure.network),
        locale,
      );
      expect(find.text(l10n.setpwErrorNetwork), findsOneWidget);
      expect(find.text(l10n.setpwValidationError), findsNothing);
    });

    testWidgets('an invalid token prints the token line ($tag)',
        (tester) async {
      final AppLocalizations l10n = await pumpFailure(
        tester,
        const _RejectingAuthRepository(AuthFailure.invalidToken),
        locale,
      );
      expect(find.text(l10n.setpwErrorInvalidToken), findsOneWidget);
    });

    testWidgets('a bad request prints the bad-request line ($tag)',
        (tester) async {
      final AppLocalizations l10n = await pumpFailure(
        tester,
        const _RejectingAuthRepository(AuthFailure.badRequest),
        locale,
      );
      expect(find.text(l10n.setpwErrorBadRequest), findsOneWidget);
    });

    testWidgets('a 5xx prints the shared server body, not a connection line '
        '($tag)', (tester) async {
      final AppLocalizations l10n = await pumpFailure(
        tester,
        const _RejectingAuthRepository(AuthFailure.serverError),
        locale,
      );
      expect(find.text(l10n.errorServerBody), findsOneWidget);
      expect(find.text(l10n.setpwErrorNetwork), findsNothing);
    });
  }

  testWidgets('an unclassified throw carries its AppFailure into the copy',
      (tester) async {
    final AppLocalizations l10n = await pumpFailure(
      tester,
      const _ThrowingAuthRepository(),
      const Locale('en'),
    );
    expect(find.text(l10n.errorServerBody), findsOneWidget);
  });
}
