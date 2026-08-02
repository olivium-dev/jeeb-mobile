import '../catalog_models.dart';

// ── account_status ──────────────────────────────────────────────────────────
import '../../../features/account_status/presentation/account_status_screen.dart';
import '../fixtures/account_status_screen_fixtures.dart';

// ── active_delivery_jeeber ──────────────────────────────────────────────────
import '../../../features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import '../fixtures/active_delivery_jeeber_screen_fixtures.dart';

// ── auth ─────────────────────────────────────────────────────────────────────
// The hidden email/password funnel entries (login / sign-up / recover /
// verify-recovery / social-collision) were removed with that funnel in
// JEBV4-199. Only the set-password screen survives (JM-061 password-security),
// and its fixtures are shared with that screen's widget-preview section.
import '../../../features/auth/presentation/set_password_screen.dart';
import '../fixtures/set_password_screen_fixtures.dart';

// ── biometric_auth ──────────────────────────────────────────────────────────
import '../../../features/biometric_auth/presentation/biometric_lock_screen.dart';
import '../fixtures/biometric_lock_screen_fixtures.dart';

// ── biometric_login ──────────────────────────────────────────────────────────
import '../../../features/biometric_login/presentation/biometric_prompt_screen.dart';
import '../fixtures/biometric_prompt_screen_fixtures.dart';

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
      _setPasswordEntry,
      _biometricLockEntry,
      _biometricPromptEntry,
    ];

// ═══════════════════════════════════════════════════════════════════════════
// account_status
// ═══════════════════════════════════════════════════════════════════════════

// The two fakes and the two `AccountStatusInfo` literals these states were
// built from now live in `../fixtures/account_status_screen_fixtures.dart`
// (values unchanged), so this entry and the JEEB PREVIEWS section at the bottom
// of `lib/features/account_status/presentation/account_status_screen.dart`
// cannot drift apart.

final CatalogEntry _accountStatusEntry = CatalogEntry(
  feature: 'account_status',
  screen: 'AccountStatusScreen',
  states: [
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
    CatalogState(
      'Load failed',
      (context) => const AccountStatusScreen(
        repository: AccountStatusScreenFailingRepository(),
      ),
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════
// active_delivery_jeeber
// ═══════════════════════════════════════════════════════════════════════════

/// The four designed states below used to be seeded by a private
/// `_InertActiveDeliveryRepository` + `_SeededActiveDeliveryCubit` +
/// `_demoDelivery` declared in this file, over four inline
/// `ActiveDeliveryState` literals. They now come from
/// `lib/devtool/catalog/fixtures/active_delivery_jeeber_screen_fixtures.dart`,
/// shared verbatim with the JEEB PREVIEWS section at the bottom of
/// `lib/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart`,
/// so the catalog and the canvas cannot drift into two different notions of
/// "the at-door state".
///
/// Nothing about these states changed — same inert repository (never actually
/// invoked; the `cubit:` seam means `loadDelivery()` never runs), same seeding
/// technique (a dev-only `ActiveDeliveryCubit` subclass that emits in its
/// constructor, no production seam), same demo delivery, same four states.
/// The fixtures file carries several MORE states (loading, the GPS-permission
/// park, the three unsuccessful terminals, the optimistic-completion frame,
/// the layout ceiling) which the previews exercise and this entry does not.
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
  ],
);

// ═══════════════════════════════════════════════════════════════════════════
// auth — set-password
// ═══════════════════════════════════════════════════════════════════════════

/// The three designed states below used to be seeded by a private
/// `_SeededSetPasswordCubit` + a private `_InertAuthRepository` declared in this
/// file, over three inline `SetPasswordState` literals. They now come from
/// `lib/devtool/catalog/fixtures/set_password_screen_fixtures.dart`, shared
/// verbatim with the preview section at the bottom of
/// `lib/features/auth/presentation/set_password_screen.dart`, so the catalog and
/// the canvas cannot drift into two different notions of "the mismatch state".
///
/// Nothing about these states changed — same inert repository (never actually
/// invoked; every state is seeded directly), same seeding technique (a dev-only
/// `SetPasswordCubit` subclass that emits in its constructor, no production
/// seam), same three states.
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

// ═══════════════════════════════════════════════════════════════════════════
// biometric_auth
// ═══════════════════════════════════════════════════════════════════════════

// The private `_SeededBiometricLockCubit` that used to live here moved to
// `../fixtures/biometric_lock_screen_fixtures.dart` as
// `BiometricLockScreenSeededCubit`, together with one named factory per state.
// The three states below are unchanged — they now read from the same fixtures
// the JEEB PREVIEWS section at the bottom of
// `lib/features/biometric_auth/presentation/biometric_lock_screen.dart`
// renders, so the catalog and the canvas cannot drift into two different
// notions of "the failed state".
//
// Two things about the states changed, both of which the old comment here was
// wrong to be comfortable with:
//
//  * The seed no longer reaches into GetIt for `sl<SharedPreferences>()`. Local
//    device storage is not a network call, but it IS a DI graph and a platform
//    channel, so the designed state could only ever be built from inside the
//    running app. The fixture answers both repositories from an in-memory map.
//  * The states are hosted through [BiometricLockScreenPreviewHost], which
//    mounts a local `GoRouter` carrying the app's biometric-gate redirects. The
//    bare `BlocProvider` used before left the screen's two exits wired to the
//    REAL app router: `biometric_unlock_use_password_link` calls
//    `context.goNamed('register')`, so a designer tapping it navigated the whole
//    app out of Dev Tool. It also means the success path is now reviewable at
//    all — the screen does not navigate on unlock, the gate does.

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

// ═══════════════════════════════════════════════════════════════════════════
// biometric_login
// ═══════════════════════════════════════════════════════════════════════════

// The private `_SeededBiometricCubit` that used to live here moved to
// `../fixtures/biometric_prompt_screen_fixtures.dart` as
// `BiometricPromptScreenSeededCubit`, together with one named factory per
// state. The four states below are unchanged — they now read from the same
// file as the JEEB PREVIEWS section at the bottom of
// `lib/features/biometric_login/presentation/biometric_prompt_screen.dart`, so
// this designer-facing entry and the engineer-facing canvas cannot drift apart.
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
