// Isolated native UI test — VerifyRecoveryCodeScreen (recover-verify, JM-021).
// The screen normally reads the recovery email from the route `extra`; we inject
// the `email` directly so no GoRouter is needed, plus a no-op AuthRepository seam.
// The OTP-entry form (code input + submit + resend) renders in English and Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/presentation/verify_recovery_code_screen.dart';

import '../support/screen_harness.dart';

/// No-op AuthRepository — the verify form only touches it on submit/resend, never
/// at build, so every leg throws to keep the seam honest and timer-free.
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

VerifyRecoveryCodeScreen _verify() => const VerifyRecoveryCodeScreen(
      email: 'nour@example.com',
      authRepository: _NoopAuthRepository(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recover-verify: idle code-entry form (en)', (tester) async {
    await pumpAndShoot(tester, binding, _verify(), 'recover-verify__idle');
  });

  testWidgets('recover-verify: idle code-entry form (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _verify(),
      'recover-verify__ar',
      locale: const Locale('ar'),
    );
  });
}
