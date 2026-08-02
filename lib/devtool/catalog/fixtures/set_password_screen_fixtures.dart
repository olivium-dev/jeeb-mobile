// Shared dev-only fixtures for `SetPasswordScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_01_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/auth/presentation/set_password_screen.dart`.
//
// The catalog owned a private `_SeededSetPasswordCubit` plus a private
// `_InertAuthRepository` and three inline `SetPasswordState` literals. Copying
// those into the preview section would have given the two surfaces two
// different notions of "the mismatch state", free to drift — and the catalog is
// the one a designer signs off against. Both surfaces now import this file. The
// catalog's three states (`Idle`, `Submitting`, `Validation error — mismatch`)
// are unchanged byte for byte; the extra states below exist only because the
// canvas asks harder questions than the catalog does.
//
// ## Why the states are SEEDED rather than driven
//
// `SetPasswordScreen` does carry a real seam — `cubitFactory` — so nothing here
// needs a production edit. What it does NOT carry is any way to reach the
// interesting states from outside:
//
//   * `submitting` exists only while a real `POST /v1/auth/set-password` future
//     is in flight;
//   * every `failed` state is emitted by `SetPasswordCubit.submit`, which reads
//     the two `TextEditingController`s that live in `_SetPasswordViewState` —
//     private widget state no fixture can reach;
//   * the server failures (`AuthFailure.network`, `.invalidToken`, …) need a
//     repository rigged to throw that exact failure at that exact moment.
//
// [SetPasswordScreenSeededCubit] is a DEV-ONLY subclass that emits one fixed
// state at construction, through the `emit` bloc marks `@protected` (i.e.
// visible to subclasses). It is not a production seam and it adds none: the
// screen still only ever sees a `SetPasswordCubit` come back from its
// `cubitFactory`.
//
// Seeding in the CONSTRUCTOR is also what keeps these fixtures inert. The
// screen's `BlocConsumer.listenWhen` is `p.status != n.status && n.status ==
// succeeded`, and its listener calls `context.goNamed('customer-profile')`. A
// state emitted before any surface subscribes is never seen as a status CHANGE,
// so no seeded state can fire that navigation — which is what lets these
// previews run with no GoRouter above them.
//
// ## Network-free, GetIt-free
//
// [SetPasswordScreenInertAuthRepository] is a local stand-in whose every method
// throws; it is never actually invoked, because every state below is already at
// its destination. It also keeps `SetPasswordScreen._resolveAuthRepository()`
// out of the picture entirely: that method builds a `DioAuthRepository` from
// `resolveGatewayDio()` and is only reached when `cubitFactory` is null
// (`cubitFactory?.call() ?? SetPasswordCubit(...)` short-circuits). So both
// surfaces are network-free BY CONSTRUCTION rather than merely by the
// `CatalogNetworkGuard` their hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:jeeb_mobile/features/auth/application/set_password_cubit.dart';
import 'package:jeeb_mobile/features/auth/application/set_password_state.dart';
import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/domain/set_password_policy.dart';

/// The account every seeded state is setting a password for.
///
/// Never rendered — the screen shows neither the email nor the mode — but the
/// cubit requires one, and a recognisably fake address makes it obvious in a
/// debugger that no real account is in play.
const String setPasswordScreenEmail = 'jeeber@example.com';

/// The optional reset token. In-app-social does not require one (the user is
/// already authenticated, D90); it is carried so the fixture matches the
/// constructor the router uses.
const String setPasswordScreenResetToken = 'demo-reset-token';

/// An [AuthRepository] that cannot reach anything.
///
/// Every method throws, and none is ever called: the seeded states are already
/// terminal. It exists so the cubit can be constructed without DI.
class SetPasswordScreenInertAuthRepository implements AuthRepository {
  /// Const so the fixtures can share one instance.
  const SetPasswordScreenInertAuthRepository();

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

/// A [SetPasswordCubit] that starts in [seed] instead of the default idle
/// state. DEV-ONLY — see the note at the top of this file.
class SetPasswordScreenSeededCubit extends SetPasswordCubit {
  /// Emits [seed] immediately, before any surface has subscribed.
  SetPasswordScreenSeededCubit(SetPasswordState seed)
      : super(
          repository: const SetPasswordScreenInertAuthRepository(),
          email: setPasswordScreenEmail,
          resetToken: setPasswordScreenResetToken,
        ) {
    emit(seed);
  }
}

/// The state every user lands in: both fields empty and masked, no error, the
/// CTA live. Also the catalog's `Idle`.
const SetPasswordState setPasswordScreenIdleState = SetPasswordState();

/// `POST /v1/auth/set-password` in flight. Also the catalog's `Submitting`.
const SetPasswordState setPasswordScreenSubmittingState = SetPasswordState(
  status: SetPasswordStatus.submitting,
);

/// New and confirm differ. Also the catalog's `Validation error — mismatch`.
const SetPasswordState setPasswordScreenMismatchState = SetPasswordState(
  status: SetPasswordStatus.failed,
  validation: SetPasswordValidation.mismatch,
);

/// The password is below the strength floor ([SetPasswordPolicy]: 8 chars, a
/// letter and a digit). A different cause from the mismatch above, and — see
/// the preview section — the same picture.
const SetPasswordState setPasswordScreenWeakState = SetPasswordState(
  status: SetPasswordStatus.failed,
  validation: SetPasswordValidation.weak,
);

/// One or both fields are blank — what the idle screen emits when the CTA is
/// tapped before anything is typed. `SetPasswordPolicy.validate` checks
/// emptiness FIRST, so this is the most common failure on the screen.
const SetPasswordState setPasswordScreenEmptyFieldsState = SetPasswordState(
  status: SetPasswordStatus.failed,
  validation: SetPasswordValidation.empty,
);

/// The request never reached the gateway (`AuthFailure.network`).
///
/// `validation` is null here — `SetPasswordCubit.submit` clears it on the
/// server-failure path — so this is the ONLY discriminator the screen is given
/// between "you typed it wrong" and "we could not ask".
const SetPasswordState setPasswordScreenNetworkFailureState = SetPasswordState(
  status: SetPasswordStatus.failed,
  failure: AuthFailure.network,
);

/// 401 `invalid_token` — the reset token was rejected. Retrying cannot fix it;
/// only leaving the screen can.
const SetPasswordState setPasswordScreenInvalidTokenState = SetPasswordState(
  status: SetPasswordStatus.failed,
  failure: AuthFailure.invalidToken,
);

/// Both eye toggles flipped: the only cubit-driven visual on this screen other
/// than the error node.
///
/// The typed characters are NOT part of this state — they live in
/// `_SetPasswordViewState`'s controllers — so what this fixture shows is the
/// two `visibility_off` icons, not revealed text.
const SetPasswordState setPasswordScreenRevealedState = SetPasswordState(
  newObscured: false,
  confirmObscured: false,
);

/// Both fields empty and masked, nothing submitted. Catalog: `Idle`.
SetPasswordCubit setPasswordScreenIdleCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenIdleState);

/// The submit is in flight. Catalog: `Submitting`.
SetPasswordCubit setPasswordScreenSubmittingCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenSubmittingState);

/// New != confirm. Catalog: `Validation error — mismatch`.
SetPasswordCubit setPasswordScreenMismatchCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenMismatchState);

/// Below the strength floor.
SetPasswordCubit setPasswordScreenWeakCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenWeakState);

/// Submitted with a blank field.
SetPasswordCubit setPasswordScreenEmptyFieldsCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenEmptyFieldsState);

/// The gateway was never reached.
SetPasswordCubit setPasswordScreenNetworkFailureCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenNetworkFailureState);

/// The reset token was rejected (401).
SetPasswordCubit setPasswordScreenInvalidTokenCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenInvalidTokenState);

/// Both visibility toggles flipped to "shown".
SetPasswordCubit setPasswordScreenRevealedCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenRevealedState);
