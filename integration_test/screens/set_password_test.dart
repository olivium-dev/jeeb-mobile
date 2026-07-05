// Isolated native UI test — SetPasswordScreen (set-password, JM-022, D90 dual
// exit). The screen owns its own BlocProvider; we inject a SetPasswordCubit over a
// no-op AuthRepository via the `cubitFactory` seam so the new/confirm-password
// form renders deterministically without DI. `mode` only changes the post-success
// navigation, so we cover both modes (recovery / in-app-social) plus Arabic; all
// render the same form chrome.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/auth/application/set_password_cubit.dart';
import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/presentation/set_password_screen.dart';

import '../support/screen_harness.dart';

/// No-op AuthRepository — the set-password form only touches it on submit, never
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

SetPasswordScreen _setPassword(SetPasswordMode mode) => SetPasswordScreen(
      mode: mode,
      cubitFactory: () => SetPasswordCubit(
        repository: const _NoopAuthRepository(),
        email: 'nour@example.com',
      ),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('set-password: recovery mode form (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _setPassword(SetPasswordMode.recovery),
      'set-password__recovery',
    );
  });

  testWidgets('set-password: in-app-social mode form (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _setPassword(SetPasswordMode.inAppSocial),
      'set-password__in-app-social',
    );
  });

  testWidgets('set-password: recovery mode form (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _setPassword(SetPasswordMode.recovery),
      'set-password__ar',
      locale: const Locale('ar'),
    );
  });
}
