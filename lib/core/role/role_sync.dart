import 'package:dio/dio.dart';

import '../../features/customer_profile/data/dio_customer_profile_repository.dart';
import '../../features/customer_profile/domain/customer_profile_repository.dart';
import '../di/injection_container.dart';
import 'role_availability_cubit.dart';
import 'role_cubit.dart';
import 'user_role.dart';

/// DEFECT-C — login→role sync.
///
/// On login / app-resume the app calls [sync], which reads the authenticated
/// user from `GET /v1/users/me` (getMe) and:
///   1. sets the active [UserRole] on [RoleCubit] from the server `active_role`
///      (so a returning dual-role user lands on the surface they were last on,
///      not stuck on the `client` default), persisting it to the SAME
///      `flutter.app.role` pref key the in-app toggle writes; and
///   2. publishes `available_roles` to [RoleAvailabilityCubit] so the UI gates
///      whether the in-app role toggle + driver surface are shown (single-role
///      clients don't see it; dual-role users do).
///
/// Fail-safe: a missing repository (bare widget test / no Dio) or a failed /
/// unauthenticated getMe leaves the persisted role + availability untouched —
/// it never throws and never forces a single-role client into jeeber.
class RoleSync {
  RoleSync({
    required RoleCubit roleCubit,
    required RoleAvailabilityCubit availabilityCubit,
    CustomerProfileRepository? repository,
  })  : _roleCubit = roleCubit,
        _availabilityCubit = availabilityCubit,
        _repository = repository;

  final RoleCubit _roleCubit;
  final RoleAvailabilityCubit _availabilityCubit;
  final CustomerProfileRepository? _repository;

  /// Resolve the getMe-backed repository over the shared [Dio] when no explicit
  /// repository was injected (production path), matching how
  /// `CustomerProfileScreen` self-provides. Returns `null` when DI has no Dio
  /// (bare widget test) so [sync] degrades to a no-op.
  CustomerProfileRepository? _resolveRepository() {
    if (_repository != null) return _repository;
    if (sl.isRegistered<Dio>()) {
      return DioCustomerProfileRepository(sl<Dio>());
    }
    return null;
  }

  /// Fetch getMe and reconcile the local role state with the server. Safe to
  /// call repeatedly (startup + every resume); never throws.
  Future<void> sync() async {
    final repo = _resolveRepository();
    if (repo == null) return;
    try {
      final profile = await repo.fetchProfile();
      _availabilityCubit.setAvailableRoles(profile.availableRoles);

      // Only adopt the server's active role when it is a role the user is
      // actually allowed to act as (defensive: never strand the app on a role
      // not in available_roles). When availableRoles is empty (older gateway)
      // we still trust a present active_role.
      final active = profile.activeRole;
      if (active == null) return;
      final allowed = profile.availableRoles.isEmpty ||
          profile.availableRoles.contains(active);
      if (!allowed) return;

      final role =
          active == 'jeeber' ? UserRole.jeeber : UserRole.client;

      // A single-role client should never be promoted to jeeber by a stray
      // active_role; the dual-role gate above (availableRoles) already permits
      // jeeber only when it is present, so this just maps the value.
      await _roleCubit.setRole(role);
    } on CustomerProfileRepositoryException {
      // Unauthorized / network — keep the persisted role + availability.
    } catch (_) {
      // Any unexpected error: fail-closed to the existing local state.
    }
  }
}
