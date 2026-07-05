// Isolated native UI test — LoginScreen (login, JM-007). The screen owns its own
// BlocProviders (login + social) and resolves its seams; we inject a LoginCubit
// over a no-op AuthRepository plus a biometric-enrolled override so the form
// renders a deterministic idle state without touching DI. `emailPasswordAuthEnabled`
// defaults false (AppConfig), so the honest phone-OTP primary CTA is the surfaced
// form; the biometric variant flips the D23 affordance on.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/auth/application/login_cubit.dart';
import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/presentation/login_screen.dart';

import '../support/screen_harness.dart';

/// No-op AuthRepository — the login form only touches it on submit, never at
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

LoginScreen _login({bool biometricEnrolled = false}) => LoginScreen(
      loginCubit: LoginCubit(repository: const _NoopAuthRepository()),
      biometricEnrolledOverride: biometricEnrolled,
      onLoggedIn: () {},
    );

/// LoginScreen wraps its body in a RootAwareBackScope → BackButtonListener,
/// which asserts a parent Router, so it must be pumped inside a GoRouter (via
/// pumpRouterAndShoot) rather than the plain-MaterialApp harness.
GoRouter _router({bool biometricEnrolled = false}) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => _login(biometricEnrolled: biometricEnrolled),
        ),
      ],
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login: idle sign-in form (en)', (tester) async {
    await pumpRouterAndShoot(tester, binding, _router(), 'login__idle');
  });

  testWidgets('login: biometric affordance visible (en)', (tester) async {
    await pumpRouterAndShoot(
      tester,
      binding,
      _router(biometricEnrolled: true),
      'login__biometric',
    );
  });

  testWidgets('login: idle sign-in form (ar)', (tester) async {
    await pumpRouterAndShoot(
      tester,
      binding,
      _router(),
      'login__ar',
      locale: const Locale('ar'),
    );
  });
}
