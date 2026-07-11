import '../../features/settings/domain/role_switch_repository.dart';
import 'role_availability_cubit.dart';
import 'role_cubit.dart';
import 'user_role.dart';

/// Outcome of [JeeberRoleActivator.activate].
enum JeeberActivationOutcome {
  /// The switch succeeded: a jeeber-capable token was re-minted and the local
  /// role state now points at the Jeeber surface.
  activated,

  /// The gateway returned 403 — the KYC approval gate is not (yet) satisfied
  /// server-side. Local state is left untouched.
  kycGated,

  /// A network / transport failure. Local state is left untouched.
  failed,
}

/// Promotes an approved jeeber onto the Jeeber surface — the ACTIVE counterpart
/// to [RoleSync]'s passive login/resume reconciliation.
///
/// ## Root cause it fixes (on-device jeeber E2E vs MSI)
/// After a jeeber's KYC is approved the app never called
/// `POST /v1/users/me/role/switch`, so:
///   1. the [AuthTokenStore] bearer stayed **client-scoped** and every jeeber
///      route (`/v1/availability`, earnings) returned `403 forbidden-capability`
///      — the jeeber home showed "Couldn't load your availability"; and
///   2. the additive shell never lit up the Jeeber surface, because it keys the
///      live jeeber bodies + landing tab off `available_roles`
///      ([RoleAvailabilityCubit]), which never gained `jeeber`.
///
/// The gateway persists `roleGranted=true` on approval but does **not** flip the
/// `/v1/users/me` projection's `active_role` (it stays `client`), so a passive
/// [RoleSync] — which only adopts the server's `active_role` — can never promote
/// the user either. The reliable "just became a jeeber" signal is the KYC status
/// turning `approved`; that is where [activate] is fired.
///
/// [activate] performs the switch (whereupon [DioRoleSwitchRepository] adopts the
/// re-minted, jeeber-capable JWT pair), then reconciles local state so the shell
/// lands on the Jeeber surface and `/v1/availability` loads — letting the jeeber
/// go online. It never throws: a network failure is reported as
/// [JeeberActivationOutcome.failed] and the caller keeps the existing state.
class JeeberRoleActivator {
  JeeberRoleActivator({
    required RoleSwitchRepository roleSwitch,
    required RoleCubit roleCubit,
    required RoleAvailabilityCubit availabilityCubit,
  })  : _roleSwitch = roleSwitch,
        _roleCubit = roleCubit,
        _availabilityCubit = availabilityCubit;

  final RoleSwitchRepository _roleSwitch;
  final RoleCubit _roleCubit;
  final RoleAvailabilityCubit _availabilityCubit;

  /// Switch to the jeeber role and, on success, reconcile local role state.
  ///
  /// Idempotent server-side (re-switching an already-granted jeeber just
  /// re-mints the token). Safe to call more than once.
  Future<JeeberActivationOutcome> activate() async {
    try {
      final result = await _roleSwitch.switchRole('jeeber');
      if (result == RoleSwitchResult.kycGated) {
        // Server still gating (projection lag / not actually approved). Leave
        // local state as-is — never strand the user on a half-switched surface.
        return JeeberActivationOutcome.kycGated;
      }
      // The switch re-minted a jeeber-capable token (the 403 fix). Reconcile
      // local state so the additive shell shows + lands on the live Jeeber
      // surface and the dual-role settings toggle appears.
      _availabilityCubit.setAvailableRoles(_withBothRoles());
      await _roleCubit.setRole(UserRole.jeeber);
      return JeeberActivationOutcome.activated;
    } on RoleSwitchException {
      return JeeberActivationOutcome.failed;
    }
  }

  /// The user's `available_roles` after approval: still a client, now also a
  /// jeeber. Merged onto whatever getMe already published so a later
  /// [RoleSync] refresh stays consistent, order-stable, and de-duped.
  List<String> _withBothRoles() {
    final roles = <String>[..._availabilityCubit.state.roles];
    if (!roles.contains('client')) roles.add('client');
    if (!roles.contains('jeeber')) roles.add('jeeber');
    return roles;
  }
}
