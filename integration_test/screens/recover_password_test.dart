// Isolated native UI test — RecoverPasswordScreen (recover-password, JM-020).
// We use the screen's dedicated `RecoverPasswordScreenForTest` seam to pass a
// no-op AuthRepository (touched only on submit), so the email-entry form renders
// a deterministic idle state without DI. Shot in English and Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/presentation/recover_password_screen.dart';

import '../support/screen_harness.dart';

/// No-op AuthRepository — the recover form only touches it on submit, never at
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

RecoverPasswordScreenForTest _recover() =>
    const RecoverPasswordScreenForTest(repository: _NoopAuthRepository());

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recover-password: idle email-entry form (en)', (tester) async {
    await pumpAndShoot(tester, binding, _recover(), 'recover-password__idle');
  });

  testWidgets('recover-password: idle email-entry form (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _recover(),
      'recover-password__ar',
      locale: const Locale('ar'),
    );
  });
}
