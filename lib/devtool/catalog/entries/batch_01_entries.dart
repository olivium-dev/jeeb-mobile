import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection_container.dart';
import '../catalog_models.dart';

// ── account_status ──────────────────────────────────────────────────────────
import '../../../features/account_status/domain/account_status.dart';
import '../../../features/account_status/domain/account_status_repository.dart';
import '../../../features/account_status/presentation/account_status_screen.dart';

// ── active_delivery_jeeber ──────────────────────────────────────────────────
import '../../../features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import '../../../features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import '../../../features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import '../../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../../features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';

// ── auth ─────────────────────────────────────────────────────────────────────
import '../../../features/auth/application/login_cubit.dart';
import '../../../features/auth/application/login_state.dart';
import '../../../features/auth/application/recover_password_cubit.dart';
import '../../../features/auth/application/recover_password_state.dart';
import '../../../features/auth/application/set_password_cubit.dart';
import '../../../features/auth/application/set_password_state.dart';
import '../../../features/auth/application/sign_up_cubit.dart';
import '../../../features/auth/application/sign_up_state.dart';
import '../../../features/auth/application/verify_recovery_code_cubit.dart';
import '../../../features/auth/application/verify_recovery_code_state.dart';
import '../../../features/auth/domain/auth_repository.dart';
import '../../../features/auth/domain/set_password_policy.dart';
import '../../../features/auth/presentation/login_screen.dart';
import '../../../features/auth/presentation/recover_password_screen.dart';
import '../../../features/auth/presentation/set_password_screen.dart';
import '../../../features/auth/presentation/sign_up_screen.dart';
import '../../../features/auth/presentation/social_collision_sheet.dart';
import '../../../features/auth/presentation/verify_recovery_code_screen.dart';

// ── biometric_auth ──────────────────────────────────────────────────────────
import '../../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../../features/biometric_auth/application/biometric_lock_state.dart';
import '../../../features/biometric_auth/data/shared_prefs_pin_repository.dart';
import '../../../features/biometric_auth/domain/biometric_gateway.dart';
import '../../../features/biometric_auth/presentation/biometric_lock_screen.dart';
import '../../../features/settings/data/repositories/biometric_preference_repository_impl.dart';

// ── biometric_login ──────────────────────────────────────────────────────────
import '../../../features/biometric_login/application/biometric_cubit.dart';
import '../../../features/biometric_login/presentation/biometric_prompt_screen.dart';

/// Batch 01 — DT-04 screen-catalog entries for: account_status,
/// active_delivery_jeeber, auth, background_gps (SKIPPED — pure service, no
/// UI), biometric_auth, biometric_login.
///
/// Every entry renders the REAL production screen with NO network: either a
/// local fake repository (canned data / typed failures) or a cubit SEEDED
/// directly into the designed state via a private subclass that calls the
/// (protected, subclass-accessible) `emit` in its constructor. Where a screen
/// had no injection seam for its cubit, a MINIMAL ADDITIVE optional
/// constructor param was added (see the batch manifest `seamsAdded`).
List<CatalogEntry> get batch01Entries => <CatalogEntry>[
      _accountStatusEntry,
      _activeDeliveryJeeberEntry,
      _loginEntry,
      _signUpEntry,
      _recoverPasswordEntry,
      _setPasswordEntry,
      _verifyRecoveryCodeEntry,
      _socialCollisionSheetEntry,
      _biometricLockEntry,
      _biometricPromptEntry,
    ];

// ═══════════════════════════════════════════════════════════════════════════
// account_status
// ═══════════════════════════════════════════════════════════════════════════

class _FixedAccountStatusRepository implements AccountStatusRepository {
  const _FixedAccountStatusRepository(this._info);
  final AccountStatusInfo _info;

  @override
  Future<AccountStatusInfo> fetchStatus() async => _info;
}

class _FailingAccountStatusRepository implements AccountStatusRepository {
  const _FailingAccountStatusRepository();

  @override
  Future<AccountStatusInfo> fetchStatus() async =>
      throw const AccountStatusRepositoryException(AccountStatusFailure.network);
}

final CatalogEntry _accountStatusEntry = CatalogEntry(
  feature: 'account_status',
  screen: 'AccountStatusScreen',
  states: [
    CatalogState(
      'Suspended',
      (context) => const AccountStatusScreen(
        repository: _FixedAccountStatusRepository(
          AccountStatusInfo(value: AccountStatusValue.suspended),
        ),
      ),
    ),
    CatalogState(
      'Locked — server reason',
      (context) => const AccountStatusScreen(
        repository: _FixedAccountStatusRepository(
          AccountStatusInfo(
            value: AccountStatusValue.locked,
            reason: 'Security hold pending identity re-verification.',
          ),
        ),
      ),
    ),
    CatalogState(
      'Load failed',
      (context) => const AccountStatusScreen(
        repository: _FailingAccountStatusRepository(),
      ),
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════
// active_delivery_jeeber
// ═══════════════════════════════════════════════════════════════════════════

class _InertActiveDeliveryRepository implements ActiveDeliveryRepository {
  const _InertActiveDeliveryRepository();

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) =>
      throw const ActiveDeliveryException(ActiveDeliveryFailure.network);

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) =>
      throw const ActiveDeliveryException(ActiveDeliveryFailure.network);

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) =>
      throw const ActiveDeliveryException(ActiveDeliveryFailure.network);

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required String filename,
  }) =>
      throw const ActiveDeliveryException(ActiveDeliveryFailure.network);
}

/// Seeds [ActiveDeliveryCubit] directly into a designed state — the screen's
/// `cubit` constructor seam means `loadDelivery()` is never invoked, so the
/// (unreachable) [_InertActiveDeliveryRepository] never fires.
class _SeededActiveDeliveryCubit extends ActiveDeliveryCubit {
  _SeededActiveDeliveryCubit(ActiveDeliveryState seed)
      : super(
          repository: const _InertActiveDeliveryRepository(),
          deliveryId: 'demo-delivery-01',
        ) {
    emit(seed);
  }
}

JeeberDelivery _demoDelivery({
  required JeeberDeliveryStatus status,
  String? proofPhotoUrl,
}) =>
    JeeberDelivery(
      id: 'demo-delivery-01',
      status: status,
      dropOff: const DropOffAddress(
        label: '221B Olaya Street',
        lat: 24.6877,
        lng: 46.6857,
        detail: 'Gate 3, near the blue door',
      ),
      clientName: 'Sara Al-Otaibi',
      conversationId: 'demo-conversation-01',
      amountText: '\$42.00',
      cashNote: 'Customer confirms receipt and pays cash on delivery.',
      proofPhotoUrl: proofPhotoUrl,
    );

final CatalogEntry _activeDeliveryJeeberEntry = CatalogEntry(
  feature: 'active_delivery_jeeber',
  screen: 'ActiveDeliveryJeeberScreen',
  states: [
    CatalogState(
      'In transit — mark delivered',
      (context) => ActiveDeliveryJeeberScreen(
        deliveryId: 'demo-delivery-01',
        onOpenChat: () {},
        cubit: _SeededActiveDeliveryCubit(
          ActiveDeliveryState(
            mode: ActiveDeliveryMode.ready,
            delivery: _demoDelivery(status: JeeberDeliveryStatus.inTransit),
          ),
        ),
      ),
    ),
    CatalogState(
      'At door — recipient OTP required',
      (context) => ActiveDeliveryJeeberScreen(
        deliveryId: 'demo-delivery-01',
        onOpenChat: () {},
        cubit: _SeededActiveDeliveryCubit(
          ActiveDeliveryState(
            mode: ActiveDeliveryMode.ready,
            delivery: _demoDelivery(status: JeeberDeliveryStatus.atDoor),
            otpRequired: true,
          ),
        ),
      ),
    ),
    CatalogState(
      'Delivered — completed',
      (context) => ActiveDeliveryJeeberScreen(
        deliveryId: 'demo-delivery-01',
        onOpenChat: () {},
        cubit: _SeededActiveDeliveryCubit(
          ActiveDeliveryState(
            mode: ActiveDeliveryMode.ready,
            delivery: _demoDelivery(
              status: JeeberDeliveryStatus.done,
              proofPhotoUrl: 'https://example.com/proof.jpg',
            ),
          ),
        ),
      ),
    ),
    CatalogState(
      'Load failed',
      (context) => ActiveDeliveryJeeberScreen(
        deliveryId: 'demo-delivery-01',
        onOpenChat: () {},
        cubit: _SeededActiveDeliveryCubit(
          const ActiveDeliveryState(
            mode: ActiveDeliveryMode.error,
            errorMessage: 'Unable to load delivery',
          ),
        ),
      ),
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════
// auth — shared inert repository (never actually invoked; every entry below
// seeds its cubit's state directly).
// ═══════════════════════════════════════════════════════════════════════════

class _InertAuthRepository implements AuthRepository {
  const _InertAuthRepository();

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

// ── login ────────────────────────────────────────────────────────────────────

class _SeededLoginCubit extends LoginCubit {
  _SeededLoginCubit(LoginState seed)
      : super(repository: const _InertAuthRepository()) {
    emit(seed);
  }
}

final CatalogEntry _loginEntry = CatalogEntry(
  feature: 'auth',
  screen: 'LoginScreen',
  states: [
    CatalogState(
      'Idle',
      (context) => LoginScreen(
        loginCubit: _SeededLoginCubit(const LoginState()),
        biometricEnrolledOverride: false,
      ),
    ),
    CatalogState(
      'Biometric affordance (D23)',
      (context) => LoginScreen(
        loginCubit: _SeededLoginCubit(const LoginState()),
        biometricEnrolledOverride: true,
      ),
    ),
    CatalogState(
      'Submitting',
      (context) => LoginScreen(
        loginCubit: _SeededLoginCubit(
          const LoginState(
            status: LoginStatus.submitting,
            email: 'jeeber@example.com',
            password: 'secret123',
          ),
        ),
        biometricEnrolledOverride: false,
      ),
    ),
  ],
);

// ── sign-up ──────────────────────────────────────────────────────────────────

class _SeededSignUpCubit extends SignUpCubit {
  _SeededSignUpCubit(SignUpState seed)
      : super(repository: const _InertAuthRepository()) {
    emit(seed);
  }
}

final CatalogEntry _signUpEntry = CatalogEntry(
  feature: 'auth',
  screen: 'SignUpScreen',
  states: [
    CatalogState(
      'Idle — empty form',
      (context) => SignUpScreen(
        cubitFactory: (repo) => _SeededSignUpCubit(const SignUpState()),
      ),
    ),
    CatalogState(
      'Strong password entered',
      (context) => SignUpScreen(
        cubitFactory: (repo) => _SeededSignUpCubit(
          const SignUpState(
            name: 'Layla Ahmed',
            email: 'layla@example.com',
            password: 'Str0ngPass!23',
          ),
        ),
      ),
    ),
    CatalogState(
      'Submitting',
      (context) => SignUpScreen(
        cubitFactory: (repo) => _SeededSignUpCubit(
          const SignUpState(
            name: 'Layla Ahmed',
            email: 'layla@example.com',
            password: 'Str0ngPass!23',
            status: SignUpStatus.submitting,
          ),
        ),
      ),
    ),
  ],
);

// ── recover-password ─────────────────────────────────────────────────────────

class _SeededRecoverPasswordCubit extends RecoverPasswordCubit {
  _SeededRecoverPasswordCubit(RecoverPasswordState seed)
      : super(repository: const _InertAuthRepository()) {
    emit(seed);
  }
}

final CatalogEntry _recoverPasswordEntry = CatalogEntry(
  feature: 'auth',
  screen: 'RecoverPasswordScreen',
  states: [
    CatalogState(
      'Idle',
      (context) => RecoverPasswordScreen(
        cubit: _SeededRecoverPasswordCubit(const RecoverPasswordState()),
      ),
    ),
    CatalogState(
      'Submitting',
      (context) => RecoverPasswordScreen(
        cubit: _SeededRecoverPasswordCubit(
          const RecoverPasswordState(
            status: RecoverPasswordStatus.submitting,
            email: 'jeeber@example.com',
          ),
        ),
      ),
    ),
    CatalogState(
      'Failed (network)',
      (context) => RecoverPasswordScreen(
        cubit: _SeededRecoverPasswordCubit(
          const RecoverPasswordState(
            status: RecoverPasswordStatus.failed,
            email: 'jeeber@example.com',
            error: AuthFailure.network,
          ),
        ),
      ),
    ),
  ],
);

// ── set-password ─────────────────────────────────────────────────────────────

class _SeededSetPasswordCubit extends SetPasswordCubit {
  _SeededSetPasswordCubit(SetPasswordState seed)
      : super(
          repository: const _InertAuthRepository(),
          email: 'jeeber@example.com',
          resetToken: 'demo-reset-token',
        ) {
    emit(seed);
  }
}

final CatalogEntry _setPasswordEntry = CatalogEntry(
  feature: 'auth',
  screen: 'SetPasswordScreen',
  states: [
    CatalogState(
      'Idle (recovery mode)',
      (context) => SetPasswordScreen(
        mode: SetPasswordMode.recovery,
        cubitFactory: () => _SeededSetPasswordCubit(const SetPasswordState()),
      ),
    ),
    CatalogState(
      'Submitting',
      (context) => SetPasswordScreen(
        mode: SetPasswordMode.recovery,
        cubitFactory: () => _SeededSetPasswordCubit(
          const SetPasswordState(status: SetPasswordStatus.submitting),
        ),
      ),
    ),
    CatalogState(
      'Validation error — mismatch',
      (context) => SetPasswordScreen(
        mode: SetPasswordMode.recovery,
        cubitFactory: () => _SeededSetPasswordCubit(
          const SetPasswordState(
            status: SetPasswordStatus.failed,
            validation: SetPasswordValidation.mismatch,
          ),
        ),
      ),
    ),
  ],
);

// ── verify-recovery-code ──────────────────────────────────────────────────────

class _SeededVerifyRecoveryCodeCubit extends VerifyRecoveryCodeCubit {
  _SeededVerifyRecoveryCodeCubit(VerifyRecoveryCodeState seed)
      : super(authRepository: const _InertAuthRepository(), email: seed.email) {
    emit(seed);
  }
}

final CatalogEntry _verifyRecoveryCodeEntry = CatalogEntry(
  feature: 'auth',
  screen: 'VerifyRecoveryCodeScreen',
  states: [
    CatalogState(
      'Idle — code entry',
      (context) => VerifyRecoveryCodeScreen(
        cubit: _SeededVerifyRecoveryCodeCubit(
          const VerifyRecoveryCodeState(email: 'jeeber@example.com'),
        ),
      ),
    ),
    CatalogState(
      'Error — invalid/expired code',
      (context) => VerifyRecoveryCodeScreen(
        cubit: _SeededVerifyRecoveryCodeCubit(
          const VerifyRecoveryCodeState(
            email: 'jeeber@example.com',
            code: '123456',
            error: VerifyRecoveryCodeError.invalidOrExpired,
          ),
        ),
      ),
    ),
    CatalogState(
      'Resending',
      (context) => VerifyRecoveryCodeScreen(
        cubit: _SeededVerifyRecoveryCodeCubit(
          const VerifyRecoveryCodeState(
            email: 'jeeber@example.com',
            isResending: true,
          ),
        ),
      ),
    ),
  ],
);

// ── social-collision-prompt (sheet, no cubit) ────────────────────────────────

final CatalogEntry _socialCollisionSheetEntry = CatalogEntry(
  feature: 'auth',
  screen: 'SocialCollisionSheet',
  states: [
    CatalogState(
      'Collision prompt',
      (context) => Scaffold(
        body: SocialCollisionSheet(
          email: 'jeeber@example.com',
          onContinue: () {},
          onUseOtherEmail: () {},
        ),
      ),
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════
// biometric_auth
// ═══════════════════════════════════════════════════════════════════════════

/// Seeds [BiometricLockCubit] directly. The gateway/pin-repository
/// dependencies are never called (the seeded state is emitted immediately in
/// the constructor); [SharedPreferences] is local device storage already
/// registered in DI by the time the catalog runs inside the live app — not a
/// network call.
class _SeededBiometricLockCubit extends BiometricLockCubit {
  _SeededBiometricLockCubit(BiometricLockState seed)
      : super(
          preference:
              BiometricPreferenceRepositoryImpl(prefs: sl<SharedPreferences>()),
          gateway: const UnavailableBiometricGateway(),
          pinRepository: SharedPrefsPinRepository(prefs: sl<SharedPreferences>()),
        ) {
    emit(seed);
  }
}

final CatalogEntry _biometricLockEntry = CatalogEntry(
  feature: 'biometric_auth',
  screen: 'BiometricLockScreen',
  states: [
    CatalogState(
      'Awaiting authentication',
      (context) => BlocProvider<BiometricLockCubit>.value(
        value: _SeededBiometricLockCubit(
          const BiometricLockState(phase: BiometricLockPhase.locked),
        ),
        child: const BiometricLockScreen(),
      ),
    ),
    CatalogState(
      'Prompting',
      (context) => BlocProvider<BiometricLockCubit>.value(
        value: _SeededBiometricLockCubit(
          const BiometricLockState(
            phase: BiometricLockPhase.locked,
            prompt: BiometricPromptStatus.prompting,
          ),
        ),
        child: const BiometricLockScreen(),
      ),
    ),
    CatalogState(
      'Failed attempt — retry',
      (context) => BlocProvider<BiometricLockCubit>.value(
        value: _SeededBiometricLockCubit(
          const BiometricLockState(
            phase: BiometricLockPhase.locked,
            prompt: BiometricPromptStatus.failed,
          ),
        ),
        child: const BiometricLockScreen(),
      ),
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════
// biometric_login
// ═══════════════════════════════════════════════════════════════════════════

class _SeededBiometricCubit extends BiometricCubit {
  _SeededBiometricCubit(BiometricState seed) {
    emit(seed);
  }
}

final CatalogEntry _biometricPromptEntry = CatalogEntry(
  feature: 'biometric_login',
  screen: 'BiometricPromptScreen',
  states: [
    CatalogState(
      'Checking',
      (context) => BiometricPromptScreen(
        cubit: _SeededBiometricCubit(BiometricState.checking),
      ),
    ),
    CatalogState(
      'Available',
      (context) => BiometricPromptScreen(
        cubit: _SeededBiometricCubit(BiometricState.available),
      ),
    ),
    CatalogState(
      'Unavailable',
      (context) => BiometricPromptScreen(
        cubit: _SeededBiometricCubit(BiometricState.unavailable),
      ),
    ),
    CatalogState(
      'Failed',
      (context) => BiometricPromptScreen(
        cubit: _SeededBiometricCubit(BiometricState.failed),
      ),
    ),
  ],
);
