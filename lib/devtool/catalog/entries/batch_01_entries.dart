import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection_container.dart';
import '../catalog_models.dart';

import '../../../features/account_status/domain/account_status.dart';
import '../../../features/account_status/domain/account_status_repository.dart';
import '../../../features/account_status/presentation/account_status_screen.dart';

import '../../../features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import '../../../features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import '../../../features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import '../../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../../features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';

import '../../../features/auth/application/set_password_cubit.dart';
import '../../../features/auth/application/set_password_state.dart';
import '../../../features/auth/domain/auth_repository.dart';
import '../../../features/auth/domain/set_password_policy.dart';
import '../../../features/auth/presentation/set_password_screen.dart';

import '../../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../../features/biometric_auth/application/biometric_lock_state.dart';
import '../../../features/biometric_auth/data/shared_prefs_pin_repository.dart';
import '../../../features/biometric_auth/domain/biometric_gateway.dart';
import '../../../features/biometric_auth/presentation/biometric_lock_screen.dart';
import '../../../features/settings/data/repositories/biometric_preference_repository_impl.dart';

import '../../../features/biometric_login/application/biometric_cubit.dart';
import '../../../features/biometric_login/presentation/biometric_prompt_screen.dart';

List<CatalogEntry> get batch01Entries => <CatalogEntry>[
      _accountStatusEntry,
      _activeDeliveryJeeberEntry,
      _setPasswordEntry,
      _biometricLockEntry,
      _biometricPromptEntry,
    ];


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
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) =>
      throw const ActiveDeliveryException(ActiveDeliveryFailure.network);
}

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
      'Idle',
      (context) => SetPasswordScreen(
        cubitFactory: () => _SeededSetPasswordCubit(const SetPasswordState()),
      ),
    ),
    CatalogState(
      'Submitting',
      (context) => SetPasswordScreen(
        cubitFactory: () => _SeededSetPasswordCubit(
          const SetPasswordState(status: SetPasswordStatus.submitting),
        ),
      ),
    ),
    CatalogState(
      'Validation error — mismatch',
      (context) => SetPasswordScreen(
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
