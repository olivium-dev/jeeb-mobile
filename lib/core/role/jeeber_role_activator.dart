import '../../features/settings/domain/role_switch_repository.dart';
import 'role_availability_cubit.dart';
import 'role_cubit.dart';
import 'user_role.dart';

enum JeeberActivationOutcome {
  activated,

  kycGated,

  failed,
}

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

  Future<JeeberActivationOutcome> activate() async {
    try {
      final result = await _roleSwitch.switchRole('jeeber');
      if (result == RoleSwitchResult.kycGated) {
        return JeeberActivationOutcome.kycGated;
      }
      _availabilityCubit.setAvailableRoles(_withBothRoles());
      await _roleCubit.setRole(UserRole.jeeber);
      return JeeberActivationOutcome.activated;
    } on RoleSwitchException {
      return JeeberActivationOutcome.failed;
    }
  }

  List<String> _withBothRoles() {
    final roles = <String>[..._availabilityCubit.state.roles];
    if (!roles.contains('client')) roles.add('client');
    if (!roles.contains('jeeber')) roles.add('jeeber');
    return roles;
  }
}
