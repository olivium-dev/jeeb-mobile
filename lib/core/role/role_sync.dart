import 'package:dio/dio.dart';

import '../../features/customer_profile/data/dio_customer_profile_repository.dart';
import '../../features/customer_profile/domain/customer_profile_repository.dart';
import '../di/injection_container.dart';
import 'role_availability_cubit.dart';
import 'role_cubit.dart';
import 'user_role.dart';

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

  CustomerProfileRepository? _resolveRepository() {
    if (_repository != null) return _repository;
    if (sl.isRegistered<Dio>()) {
      return DioCustomerProfileRepository(sl<Dio>());
    }
    return null;
  }

  bool _inFlight = false;

  Future<void> sync() async {
    if (_inFlight) return;
    final repo = _resolveRepository();
    if (repo == null) return;
    _inFlight = true;
    try {
      final profile = await repo.fetchProfile();
      _availabilityCubit.setAvailableRoles(profile.availableRoles);

      final active = profile.activeRole;
      if (active == null) return;
      final allowed = profile.availableRoles.isEmpty ||
          profile.availableRoles.contains(active);
      if (!allowed) return;

      final role =
          active == 'jeeber' ? UserRole.jeeber : UserRole.client;

      await _roleCubit.setRole(role);
    } on CustomerProfileRepositoryException {
    } catch (_) {
    } finally {
      _inFlight = false;
    }
  }
}
