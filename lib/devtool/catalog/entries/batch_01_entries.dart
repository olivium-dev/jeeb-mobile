import '../catalog_models.dart';

import '../../../features/account_status/presentation/account_status_screen.dart';
import '../fixtures/account_status_screen_fixtures.dart';

import '../../../features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import '../fixtures/active_delivery_jeeber_screen_fixtures.dart';

import '../../../features/auth/presentation/set_password_screen.dart';
import '../fixtures/set_password_screen_fixtures.dart';

import '../../../features/biometric_auth/presentation/biometric_lock_screen.dart';
import '../fixtures/biometric_lock_screen_fixtures.dart';

import '../../../features/biometric_login/presentation/biometric_prompt_screen.dart';
import '../fixtures/biometric_prompt_screen_fixtures.dart';

List<CatalogEntry> get batch01Entries => <CatalogEntry>[
      _accountStatusEntry,
      _activeDeliveryJeeberEntry,
      _setPasswordEntry,
      _biometricLockEntry,
      _biometricPromptEntry,
    ];

final CatalogEntry _accountStatusEntry = CatalogEntry(
  feature: 'account_status',
  screen: 'AccountStatusScreen',
  states: [
    CatalogState(
      'Checking status',
      (context) => const AccountStatusScreen(
        repository: AccountStatusScreenPendingRepository(),
      ),
    ),
    CatalogState(
      'Suspended',
      (context) => const AccountStatusScreen(
        repository: AccountStatusScreenFakeRepository(
          accountStatusScreenSuspended,
        ),
      ),
    ),
    CatalogState(
      'Locked — server reason',
      (context) => const AccountStatusScreen(
        repository: AccountStatusScreenFakeRepository(
          accountStatusScreenLockedWithReason,
        ),
      ),
    ),
    // The layout ceiling: free server text long enough to scroll the band.
    CatalogState(
      'Locked — long server reason',
      (context) => const AccountStatusScreen(
        repository: AccountStatusScreenFakeRepository(
          accountStatusScreenLockedLongReason,
        ),
      ),
    ),
    CatalogState(
      'Load failed',
      (context) => const AccountStatusScreen(
        repository: AccountStatusScreenFailingRepository(),
      ),
    ),
  ],
);

final CatalogEntry _activeDeliveryJeeberEntry = CatalogEntry(
  feature: 'active_delivery_jeeber',
  screen: 'ActiveDeliveryJeeberScreen',
  states: [
    CatalogState(
      'In transit — mark delivered',
      (context) => ActiveDeliveryJeeberScreen(
        deliveryId: ActiveDeliveryJeeberScreenFixtures.deliveryId,
        onOpenChat: () {},
        cubit: ActiveDeliveryJeeberScreenSeededCubit(
          ActiveDeliveryJeeberScreenFixtures.inTransit,
        ),
      ),
    ),
    CatalogState(
      'At door — recipient OTP required',
      (context) => ActiveDeliveryJeeberScreen(
        deliveryId: ActiveDeliveryJeeberScreenFixtures.deliveryId,
        onOpenChat: () {},
        cubit: ActiveDeliveryJeeberScreenSeededCubit(
          ActiveDeliveryJeeberScreenFixtures.atDoorOtpRequired,
        ),
      ),
    ),
    CatalogState(
      'Delivered — completed',
      (context) => ActiveDeliveryJeeberScreen(
        deliveryId: ActiveDeliveryJeeberScreenFixtures.deliveryId,
        onOpenChat: () {},
        cubit: ActiveDeliveryJeeberScreenSeededCubit(
          ActiveDeliveryJeeberScreenFixtures.completed,
        ),
      ),
    ),
    CatalogState(
      'Load failed',
      (context) => ActiveDeliveryJeeberScreen(
        deliveryId: ActiveDeliveryJeeberScreenFixtures.deliveryId,
        onOpenChat: () {},
        cubit: ActiveDeliveryJeeberScreenSeededCubit(
          ActiveDeliveryJeeberScreenFixtures.loadFailed,
        ),
      ),
    ),
    CatalogState(
      'Proof photo — uploading',
      (context) => ActiveDeliveryJeeberScreen(
        deliveryId: ActiveDeliveryJeeberScreenFixtures.deliveryId,
        onOpenChat: () {},
        cubit: ActiveDeliveryJeeberScreenSeededCubit(
          ActiveDeliveryJeeberScreenFixtures.proofPhotoUploading,
        ),
      ),
    ),
  ],
);

final CatalogEntry _setPasswordEntry = CatalogEntry(
  feature: 'auth',
  screen: 'SetPasswordScreen',
  states: [
    CatalogState(
      'Idle',
      (context) =>
          const SetPasswordScreen(cubitFactory: setPasswordScreenIdleCubit),
    ),
    CatalogState(
      'Submitting',
      (context) => const SetPasswordScreen(
        cubitFactory: setPasswordScreenSubmittingCubit,
      ),
    ),
    CatalogState(
      'Validation error — mismatch',
      (context) =>
          const SetPasswordScreen(cubitFactory: setPasswordScreenMismatchCubit),
    ),
  ],
);

/// Hosts through [BiometricLockScreenPreviewHost] + local GoRouter (avoids
/// real app navigation). Fixture uses in-memory storage (not SharedPreferences).
final CatalogEntry _biometricLockEntry = CatalogEntry(
  feature: 'biometric_auth',
  screen: 'BiometricLockScreen',
  states: [
    CatalogState(
      'Awaiting authentication',
      (context) => const BiometricLockScreenPreviewHost(
        create: biometricLockScreenLockedCubit,
        screen: BiometricLockScreen(),
      ),
    ),
    CatalogState(
      'Prompting',
      (context) => const BiometricLockScreenPreviewHost(
        create: biometricLockScreenPromptingCubit,
        screen: BiometricLockScreen(),
      ),
    ),
    CatalogState(
      'Failed attempt — retry',
      (context) => const BiometricLockScreenPreviewHost(
        create: biometricLockScreenFailedCubit,
        screen: BiometricLockScreen(),
      ),
    ),
  ],
);

final CatalogEntry _biometricPromptEntry = CatalogEntry(
  feature: 'biometric_login',
  screen: 'BiometricPromptScreen',
  states: [
    CatalogState(
      'Checking',
      (context) => BiometricPromptScreen(
        cubit: biometricPromptScreenCheckingCubit(),
      ),
    ),
    CatalogState(
      'Available',
      (context) => BiometricPromptScreen(
        cubit: biometricPromptScreenAvailableCubit(),
      ),
    ),
    CatalogState(
      'Unavailable',
      (context) => BiometricPromptScreen(
        cubit: biometricPromptScreenUnavailableCubit(),
      ),
    ),
    CatalogState(
      'Failed',
      (context) => BiometricPromptScreen(
        cubit: biometricPromptScreenFailedCubit(),
      ),
    ),
  ],
);
