import 'package:flutter/widgets.dart';

import '../../../features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import '../../../features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import '../../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../../features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import '../../../features/auth/application/login_cubit.dart';
import '../../../features/auth/application/set_password_cubit.dart';
import '../../../features/auth/application/sign_up_cubit.dart';
import '../../../features/auth/domain/auth_repository.dart';
import '../../../features/auth/presentation/login_screen.dart';
import '../../../features/auth/presentation/recover_password_screen.dart';
import '../../../features/auth/presentation/set_password_screen.dart';
import '../../../features/auth/presentation/sign_up_screen.dart';
import '../../../features/auth/presentation/verify_recovery_code_screen.dart';
import '../../../features/biometric_login/presentation/biometric_prompt_screen.dart';
import '../../../features/cancel_request/data/fake_cancel_request_repository.dart';
import '../../../features/cancel_request/presentation/cancel_request_sheet.dart';
import '../catalog_models.dart';

/// Batch 01 — active_delivery_jeeber, auth, background_gps, biometric_auth,
/// biometric_login, cancel_request.
///
/// SKIPPED (honest partial coverage, per DT-04 DoD §6):
///   * `background_gps` — no `presentation/` folder at all (pure
///     location-capture + upload service, no screen to catalog).
///   * `biometric_auth` (`BiometricLockScreen`) — the screen takes no seam and
///     wires an app-level `BiometricLockCubit` built from
///     `BiometricPreferenceRepositoryImpl` + `SharedPrefsPinRepository`, both
///     of which require a real `SharedPreferences.getInstance()` (platform
///     channel) to even construct — heavier plumbing than a direct local fake
///     can satisfy without touching platform channels.
List<CatalogEntry> get batch01Entries => <CatalogEntry>[
      const CatalogEntry(
        feature: 'active_delivery_jeeber',
        screen: 'ActiveDeliveryJeeberScreen',
        states: [
          CatalogState('In transit — mark-delivered panel', _activeDeliveryInTransit),
          CatalogState('At door — proof captured', _activeDeliveryAtDoor),
          CatalogState('Load error', _activeDeliveryLoadError),
        ],
      ),
      const CatalogEntry(
        feature: 'auth',
        screen: 'LoginScreen',
        states: [
          CatalogState('Empty form', _loginEmpty),
          CatalogState('Populated — ready to submit', _loginPopulated),
        ],
      ),
      const CatalogEntry(
        feature: 'auth',
        screen: 'RecoverPasswordScreen',
        states: [
          CatalogState('Idle — request form', _recoverPasswordIdle),
        ],
      ),
      const CatalogEntry(
        feature: 'auth',
        screen: 'SignUpScreen',
        states: [
          CatalogState('Empty form', _signUpEmpty),
          CatalogState('Populated — strong password', _signUpPopulated),
        ],
      ),
      const CatalogEntry(
        feature: 'auth',
        screen: 'VerifyRecoveryCodeScreen',
        states: [
          CatalogState('Awaiting code entry', _verifyRecoveryCodeAwaiting),
        ],
      ),
      const CatalogEntry(
        feature: 'auth',
        screen: 'SetPasswordScreen',
        states: [
          CatalogState('Recovery mode', _setPasswordRecovery),
          CatalogState('In-app-social mode', _setPasswordInAppSocial),
        ],
      ),
      const CatalogEntry(
        feature: 'biometric_login',
        screen: 'BiometricPromptScreen',
        states: [
          CatalogState('Available — ready to authenticate', _biometricPromptAvailable),
        ],
      ),
      const CatalogEntry(
        feature: 'cancel_request',
        screen: 'CancelRequestSheet',
        states: [
          CatalogState('Idle — confirm or keep', _cancelRequestIdle),
        ],
      ),
    ];

// ─────────────────────────────────────────────────────────────────────────
// active_delivery_jeeber
// ─────────────────────────────────────────────────────────────────────────

const _inTransitDelivery = JeeberDelivery(
  id: 'demo-delivery-001',
  status: JeeberDeliveryStatus.inTransit,
  dropOff: DropOffAddress(
    label: '221B Baker Street',
    lat: 24.7136,
    lng: 46.6753,
    detail: 'Gate 3, next to the pharmacy',
  ),
  clientName: 'Sara Al-Otaibi',
  conversationId: 'conv-demo-001',
  amountText: '18.50 SAR',
  cashNote: 'Customer confirms receipt and pays cash on delivery.',
);

const _atDoorDelivery = JeeberDelivery(
  id: 'demo-delivery-002',
  status: JeeberDeliveryStatus.atDoor,
  dropOff: DropOffAddress(
    label: 'Olaya Business Tower',
    lat: 24.6906,
    lng: 46.6851,
  ),
  clientName: 'Faisal Al-Harbi',
  conversationId: 'conv-demo-002',
  amountText: '32.00 SAR',
  proofPhotoUrl: 'https://picsum.photos/seed/proof-demo/400/300',
);

/// Local fake — never touches the network. [fetchDelivery] returns the seeded
/// [_delivery] snapshot, or throws [_fetchError] when seeded (Load-error
/// state). [transition]/[uploadProofPhoto] are not exercised by the cataloged
/// states (they're only reachable from a user tap), but are implemented so the
/// interface is fully satisfied.
class _FakeActiveDeliveryRepository implements ActiveDeliveryRepository {
  const _FakeActiveDeliveryRepository(this._delivery, {this.fetchError});

  final JeeberDelivery _delivery;
  final ActiveDeliveryException? fetchError;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    final err = fetchError;
    if (err != null) throw err;
    return _delivery;
  }

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async =>
      to;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required String filename,
  }) async =>
      'https://picsum.photos/seed/$filename/400/300';
}

Widget _activeDeliveryInTransit(BuildContext _) => ActiveDeliveryJeeberScreen(
      deliveryId: _inTransitDelivery.id,
      onOpenChat: () {},
      repository: const _FakeActiveDeliveryRepository(_inTransitDelivery),
    );

Widget _activeDeliveryAtDoor(BuildContext _) => ActiveDeliveryJeeberScreen(
      deliveryId: _atDoorDelivery.id,
      onOpenChat: () {},
      repository: const _FakeActiveDeliveryRepository(_atDoorDelivery),
    );

Widget _activeDeliveryLoadError(BuildContext _) => ActiveDeliveryJeeberScreen(
      deliveryId: _inTransitDelivery.id,
      onOpenChat: () {},
      repository: const _FakeActiveDeliveryRepository(
        _inTransitDelivery,
        fetchError: ActiveDeliveryException(ActiveDeliveryFailure.network),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────
// auth
// ─────────────────────────────────────────────────────────────────────────

/// Local fake — never touches the network. All auth legs resolve immediately
/// with a canned session/result; none of the cataloged (idle/populated) states
/// trigger a submit, so these bodies are exercised only if a future state adds
/// one.
class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    String? name,
  }) async =>
      const AuthSession(userId: 'user-demo-001', email: 'demo@example.com');

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async =>
      const AuthSession(userId: 'user-demo-001', email: 'demo@example.com');

  @override
  Future<RecoveryRequestResult> requestRecovery({required String email}) async =>
      const RecoveryRequestResult(expiresInSeconds: 300);

  @override
  Future<RecoveryVerifyResult> verifyRecovery({
    required String email,
    required String code,
  }) async =>
      const RecoveryVerifyResult(
        resetToken: 'reset-token-demo',
        expiresInSeconds: 300,
      );

  @override
  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  }) async =>
      const AuthSession(userId: 'user-demo-001', email: 'demo@example.com');
}

Widget _recoverPasswordIdle(BuildContext _) =>
    const RecoverPasswordScreenForTest(repository: _FakeAuthRepository());

Widget _verifyRecoveryCodeAwaiting(BuildContext _) =>
    const VerifyRecoveryCodeScreen(
      email: 'sara@example.com',
      authRepository: _FakeAuthRepository(),
    );

Widget _loginEmpty(BuildContext _) => LoginScreen(
      loginCubit: LoginCubit(repository: const _FakeAuthRepository()),
    );

Widget _loginPopulated(BuildContext _) {
  final cubit = LoginCubit(repository: const _FakeAuthRepository())
    ..emailChanged('jeeber@example.com')
    ..passwordChanged('Sup3rSecret!');
  return LoginScreen(loginCubit: cubit);
}

Widget _signUpEmpty(BuildContext _) =>
    const SignUpScreen(repository: _FakeAuthRepository());

Widget _signUpPopulated(BuildContext _) => SignUpScreen(
      repository: const _FakeAuthRepository(),
      cubitFactory: (repository) => SignUpCubit(repository: repository)
        ..nameChanged('Ali Hassan')
        ..emailChanged('ali@example.com')
        ..passwordChanged('Str0ngP@ssw0rd!'),
    );

Widget _setPasswordRecovery(BuildContext _) => SetPasswordScreen(
      mode: SetPasswordMode.recovery,
      email: 'sara@example.com',
      cubitFactory: () => SetPasswordCubit(
        repository: const _FakeAuthRepository(),
        email: 'sara@example.com',
        resetToken: 'reset-token-demo',
      ),
    );

Widget _setPasswordInAppSocial(BuildContext _) => SetPasswordScreen(
      mode: SetPasswordMode.inAppSocial,
      email: 'sara@example.com',
      cubitFactory: () => SetPasswordCubit(
        repository: const _FakeAuthRepository(),
        email: 'sara@example.com',
      ),
    );

// ─────────────────────────────────────────────────────────────────────────
// biometric_login
// ─────────────────────────────────────────────────────────────────────────

Widget _biometricPromptAvailable(BuildContext _) =>
    const BiometricPromptScreen();

// ─────────────────────────────────────────────────────────────────────────
// cancel_request
// ─────────────────────────────────────────────────────────────────────────

Widget _cancelRequestIdle(BuildContext _) => CancelRequestSheet(
      requestId: 'demo-request-001',
      repository: FakeCancelRequestRepository(),
    );
