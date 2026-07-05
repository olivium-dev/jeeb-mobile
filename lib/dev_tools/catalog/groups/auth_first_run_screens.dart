import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';
import 'package:jeeb_mobile/features/account_status/presentation/account_status_screen.dart';
import 'package:jeeb_mobile/features/auth/application/login_cubit.dart';
import 'package:jeeb_mobile/features/auth/application/set_password_cubit.dart';
import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/presentation/login_screen.dart';
import 'package:jeeb_mobile/features/auth/presentation/recover_password_screen.dart';
import 'package:jeeb_mobile/features/auth/presentation/set_password_screen.dart';
import 'package:jeeb_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:jeeb_mobile/features/auth/presentation/verify_recovery_code_screen.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/biometric_auth/presentation/biometric_lock_screen.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';

import '../dev_screen_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Auth & First-Run" screens — the onboarding carousel plus the full phone-OTP
// and email auth funnels (register, login, sign-up, password recovery, biometric
// lock, blocked-account status).
//
// Every fake/seam below is ported EXACTLY from the matching
// integration_test/screens/<file>_test.dart, privatised and file-local so
// nothing leaks and there is no import from test/ or integration_test/. Each
// DevScreenState maps 1:1 to a `testWidgets` case (its screenshot suffix → state
// id, its locale → state locale, the widget it pumps → the builder body).
//
// Navigation callbacks are safe no-ops and poll/clock ticks are
// `const Stream.empty()` — the previewed screen is LIVE and interactive, only
// its DATA and navigation are mocked. The dev preview host supplies the Router
// ancestor the back-scope wrappers need.
// ─────────────────────────────────────────────────────────────────────────────

// ── Shared fakes ─────────────────────────────────────────────────────────────

/// No-op [AuthRepository] shared by the login / sign-up / recover / verify /
/// set-password forms. Ported verbatim from each auth screen test: the forms
/// only touch it on submit, never at build, so every leg throws to keep the seam
/// honest and timer-free.
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

/// No-op [OtpService] so the phone-entry [RegistrationCubit] constructs without a
/// real auth-service client or network (ported from the registration test).
class _FakeOtpService implements OtpService {
  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async =>
      OtpSendOutcome.sent;

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) async =>
      OtpVerifyOutcome.verified;
}

/// Serves one fixed blocked-status snapshot so the account-status cubit's cold
/// load settles into the loaded body (ported from the account-status test).
class _StaticAccountStatusRepository implements AccountStatusRepository {
  const _StaticAccountStatusRepository(this._info);

  final AccountStatusInfo _info;

  @override
  Future<AccountStatusInfo> fetchStatus() async => _info;
}

// ── Onboarding preview (async SharedPreferences seam) ────────────────────────

/// Hosts [OnboardingScreen] over real [OnboardingCubit] + [LocaleCubit] built on
/// a live [SharedPreferences] (mirrors the onboarding test, which awaits
/// `getInstance()` before pumping). `onComplete` is a safe no-op so "Get
/// Started" / "Skip" never navigate. The cubits are created once and closed on
/// dispose.
class _OnboardingPreview extends StatefulWidget {
  const _OnboardingPreview({required this.locale});

  final Locale locale;

  @override
  State<_OnboardingPreview> createState() => _OnboardingPreviewState();
}

class _OnboardingPreviewState extends State<_OnboardingPreview> {
  OnboardingCubit? _onboarding;
  LocaleCubit? _locale;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarding = OnboardingCubit(prefs: prefs);
    final locale = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => widget.locale,
    );
    if (!mounted) {
      await onboarding.close();
      await locale.close();
      return;
    }
    setState(() {
      _onboarding = onboarding;
      _locale = locale;
    });
  }

  @override
  void dispose() {
    _onboarding?.close();
    _locale?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = _onboarding;
    final locale = _locale;
    if (onboarding == null || locale == null) {
      return const SizedBox.shrink();
    }
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<OnboardingCubit>.value(value: onboarding),
        BlocProvider<LocaleCubit>.value(value: locale),
      ],
      child: OnboardingScreen(onComplete: () {}),
    );
  }
}

// ── Biometric-lock preview (async SharedPreferences seam) ────────────────────

/// Hosts [BiometricLockScreen] over a real [BiometricLockCubit] wired to inert
/// seams — no keystore, no OS dialog (ported from the biometric-lock test). When
/// [failed] is true, one `authenticate()` is pre-driven; the
/// [UnavailableBiometricGateway] resolves false, surfacing the retry + fallback
/// variant without any native prompt. The cubit is created once and closed on
/// dispose.
class _BiometricLockPreview extends StatefulWidget {
  const _BiometricLockPreview({required this.failed});

  final bool failed;

  @override
  State<_BiometricLockPreview> createState() => _BiometricLockPreviewState();
}

class _BiometricLockPreviewState extends State<_BiometricLockPreview> {
  BiometricLockCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = BiometricLockCubit(
      preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
      gateway: const UnavailableBiometricGateway(),
      pinRepository: SharedPrefsPinRepository(prefs: prefs),
    );
    if (widget.failed) {
      await cubit.authenticate();
    }
    if (!mounted) {
      await cubit.close();
      return;
    }
    setState(() => _cubit = cubit);
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider<BiometricLockCubit>.value(
      value: cubit,
      child: const BiometricLockScreen(),
    );
  }
}

// ── Screen builders (synchronous seams) ──────────────────────────────────────

/// Live phone-entry [RegistrationScreen] over the fake OTP service and an empty
/// ticker (no resend/lockout countdown timer) — mirrors the registration test.
Widget _registrationScreen() => RegistrationScreen(
      cubit: RegistrationCubit(
        otpService: _FakeOtpService(),
        tickerFactory: () => const Stream<DateTime>.empty(),
      ),
    );

/// Live [LoginScreen] over the no-op auth repo; [biometricEnrolled] flips the
/// D23 biometric affordance on (mirrors the login test). Navigation is a no-op.
Widget _loginScreen({bool biometricEnrolled = false}) => LoginScreen(
      loginCubit: LoginCubit(repository: const _NoopAuthRepository()),
      biometricEnrolledOverride: biometricEnrolled,
      onLoggedIn: () {},
    );

/// Live create-account [SignUpScreen] over the no-op auth repo.
Widget _signUpScreen() => const SignUpScreen(repository: _NoopAuthRepository());

/// Live email-entry [RecoverPasswordScreenForTest] over the no-op auth repo.
Widget _recoverPasswordScreen() =>
    const RecoverPasswordScreenForTest(repository: _NoopAuthRepository());

/// Live code-entry [VerifyRecoveryCodeScreen] with the recovery email injected
/// (no route `extra` needed) and the no-op auth repo.
Widget _verifyRecoveryScreen() => const VerifyRecoveryCodeScreen(
      email: 'nour@example.com',
      authRepository: _NoopAuthRepository(),
    );

/// Live [SetPasswordScreen] for the given [mode] over a [SetPasswordCubit] on
/// the no-op auth repo (mode only changes post-success navigation).
Widget _setPasswordScreen(SetPasswordMode mode) => SetPasswordScreen(
      mode: mode,
      cubitFactory: () => SetPasswordCubit(
        repository: const _NoopAuthRepository(),
        email: 'nour@example.com',
      ),
    );

/// Live blocked-body [AccountStatusScreen] over a static repo serving [info].
Widget _accountStatusScreen(AccountStatusInfo info) =>
    AccountStatusScreen(repository: _StaticAccountStatusRepository(info));

// ── Catalog entries (sorted by title) ────────────────────────────────────────

final List<DevScreenEntry> authFirstRunScreens = <DevScreenEntry>[
  // Account Status
  DevScreenEntry(
    id: 'account-status',
    title: 'Account Status',
    group: 'Auth & First-Run',
    keywords: const <String>[
      'blocked',
      'suspended',
      'locked',
      'banned',
      'sign out',
      'support',
      'JM-066',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'suspended-en',
        label: 'Suspended (EN)',
        locale: const Locale('en'),
        builder: (_) => _accountStatusScreen(
          const AccountStatusInfo(value: AccountStatusValue.suspended),
        ),
      ),
      DevScreenState(
        id: 'locked-en',
        label: 'Locked (EN)',
        locale: const Locale('en'),
        builder: (_) => _accountStatusScreen(
          const AccountStatusInfo(value: AccountStatusValue.locked),
        ),
      ),
      DevScreenState(
        id: 'suspended-ar',
        label: 'Suspended (AR)',
        locale: const Locale('ar'),
        builder: (_) => _accountStatusScreen(
          const AccountStatusInfo(value: AccountStatusValue.suspended),
        ),
      ),
    ],
  ),

  // Biometric Lock
  DevScreenEntry(
    id: 'biometric-lock',
    title: 'Biometric Lock',
    group: 'Auth & First-Run',
    keywords: const <String>[
      'biometric',
      'unlock',
      'face id',
      'touch id',
      'fingerprint',
      'app lock',
      'pin',
      'JM-005',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Locked Idle (EN)',
        locale: const Locale('en'),
        builder: (_) => const _BiometricLockPreview(failed: false),
      ),
      DevScreenState(
        id: 'failed-en',
        label: 'Failed Attempt (EN)',
        locale: const Locale('en'),
        builder: (_) => const _BiometricLockPreview(failed: true),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'Locked Idle (AR)',
        locale: const Locale('ar'),
        builder: (_) => const _BiometricLockPreview(failed: false),
      ),
    ],
  ),

  // Login
  DevScreenEntry(
    id: 'login',
    title: 'Login',
    group: 'Auth & First-Run',
    keywords: const <String>[
      'sign in',
      'log in',
      'email',
      'password',
      'biometric',
      'JM-007',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Idle Sign-In (EN)',
        locale: const Locale('en'),
        builder: (_) => _loginScreen(),
      ),
      DevScreenState(
        id: 'biometric-en',
        label: 'Biometric Affordance (EN)',
        locale: const Locale('en'),
        builder: (_) => _loginScreen(biometricEnrolled: true),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'Idle Sign-In (AR)',
        locale: const Locale('ar'),
        builder: (_) => _loginScreen(),
      ),
    ],
  ),

  // Onboarding
  DevScreenEntry(
    id: 'onboarding',
    title: 'Onboarding',
    group: 'Auth & First-Run',
    keywords: const <String>[
      'walkthrough',
      'intro',
      'carousel',
      'first launch',
      'welcome',
      'slides',
      'JM-010',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'First Slide (EN)',
        locale: const Locale('en'),
        builder: (_) => const _OnboardingPreview(locale: Locale('en')),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'First Slide (AR)',
        locale: const Locale('ar'),
        builder: (_) => const _OnboardingPreview(locale: Locale('ar')),
      ),
    ],
  ),

  // Recover Password
  DevScreenEntry(
    id: 'recover-password',
    title: 'Recover Password',
    group: 'Auth & First-Run',
    keywords: const <String>[
      'forgot password',
      'reset',
      'recovery',
      'email',
      'JM-020',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Email Entry (EN)',
        locale: const Locale('en'),
        builder: (_) => _recoverPasswordScreen(),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'Email Entry (AR)',
        locale: const Locale('ar'),
        builder: (_) => _recoverPasswordScreen(),
      ),
    ],
  ),

  // Registration (Phone)
  DevScreenEntry(
    id: 'register',
    title: 'Registration (Phone)',
    group: 'Auth & First-Run',
    keywords: const <String>[
      'register',
      'phone',
      'otp',
      'send code',
      'signup',
      'phone number',
      '+961',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'phone-entry-en',
        label: 'Phone Entry (EN)',
        locale: const Locale('en'),
        builder: (_) => _registrationScreen(),
      ),
      DevScreenState(
        id: 'phone-entry-ar',
        label: 'Phone Entry (AR)',
        locale: const Locale('ar'),
        builder: (_) => _registrationScreen(),
      ),
    ],
  ),

  // Set Password
  DevScreenEntry(
    id: 'set-password',
    title: 'Set Password',
    group: 'Auth & First-Run',
    keywords: const <String>[
      'new password',
      'confirm password',
      'reset',
      'recovery',
      'social',
      'JM-022',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'recovery-en',
        label: 'Recovery Mode (EN)',
        locale: const Locale('en'),
        builder: (_) => _setPasswordScreen(SetPasswordMode.recovery),
      ),
      DevScreenState(
        id: 'in-app-social-en',
        label: 'In-App Social Mode (EN)',
        locale: const Locale('en'),
        builder: (_) => _setPasswordScreen(SetPasswordMode.inAppSocial),
      ),
      DevScreenState(
        id: 'recovery-ar',
        label: 'Recovery Mode (AR)',
        locale: const Locale('ar'),
        builder: (_) => _setPasswordScreen(SetPasswordMode.recovery),
      ),
    ],
  ),

  // Sign Up
  DevScreenEntry(
    id: 'sign-up',
    title: 'Sign Up',
    group: 'Auth & First-Run',
    keywords: const <String>[
      'create account',
      'register',
      'email',
      'password',
      'name',
      'JM-008',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Create Account (EN)',
        locale: const Locale('en'),
        builder: (_) => _signUpScreen(),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'Create Account (AR)',
        locale: const Locale('ar'),
        builder: (_) => _signUpScreen(),
      ),
    ],
  ),

  // Verify Recovery Code
  DevScreenEntry(
    id: 'recover-verify',
    title: 'Verify Recovery Code',
    group: 'Auth & First-Run',
    keywords: const <String>[
      'otp',
      'verify code',
      'recovery',
      'reset',
      'resend',
      'JM-021',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Code Entry (EN)',
        locale: const Locale('en'),
        builder: (_) => _verifyRecoveryScreen(),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'Code Entry (AR)',
        locale: const Locale('ar'),
        builder: (_) => _verifyRecoveryScreen(),
      ),
    ],
  ),
];
