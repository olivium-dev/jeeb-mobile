// Isolated native UI test — SignUpScreen (sign-up, JM-008). The screen owns its
// own SignUpCubit (built from the injected repository) and a scoped SocialAuthCubit,
// so we inject a no-op AuthRepository and pump it directly. The email-first form
// (name / email / password + strength hint + social row) renders regardless of
// the email-auth feature flag; we shoot the idle form in English and Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/presentation/sign_up_screen.dart';

import '../support/screen_harness.dart';

/// No-op AuthRepository — the sign-up form only touches it on submit, never at
/// build, so every leg throws to keep the seam honest and timer-free.
class _NoopAuthRepository implements AuthRepository {
  const _NoopAuthRepository();

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    String? name,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<RecoveryRequestResult> requestRecovery({required String email}) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<RecoveryVerifyResult> verifyRecovery({
    required String email,
    required String code,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);
}

SignUpScreen _signUp() => const SignUpScreen(repository: _NoopAuthRepository());

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign-up: idle create-account form (en)', (tester) async {
    await pumpAndShoot(tester, binding, _signUp(), 'sign-up__idle');
  });

  testWidgets('sign-up: idle create-account form (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _signUp(),
      'sign-up__ar',
      locale: const Locale('ar'),
    );
  });
}
