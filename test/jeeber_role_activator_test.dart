import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/role/jeeber_role_activator.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/settings/domain/role_switch_repository.dart';

/// Scripted [RoleSwitchRepository] recording the requested role so a test can
/// assert the switch was actually attempted (and to which role).
class _FakeRoleSwitchRepository implements RoleSwitchRepository {
  _FakeRoleSwitchRepository({this.result = RoleSwitchResult.success});

  final RoleSwitchResult result;
  final List<String> switched = <String>[];

  @override
  Future<RoleSwitchResult> switchRole(String role) async {
    switched.add(role);
    return result;
  }
}

class _ThrowingRoleSwitchRepository implements RoleSwitchRepository {
  @override
  Future<RoleSwitchResult> switchRole(String role) async {
    throw const RoleSwitchException('network down');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<({RoleCubit role, RoleAvailabilityCubit avail})> harness({
    UserRole initialRole = UserRole.client,
    List<String> initialRoles = const <String>[],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final role = RoleCubit(prefs: prefs, initialRole: initialRole);
    final avail = initialRoles.isEmpty
        ? RoleAvailabilityCubit()
        : RoleAvailabilityCubit(RoleAvailability(roles: initialRoles));
    addTearDown(role.close);
    addTearDown(avail.close);
    return (role: role, avail: avail);
  }

  test(
      'activated: POSTs role/switch to jeeber and flips RoleCubit + '
      'availability to the Jeeber surface', () async {
    final h = await harness();
    final repo = _FakeRoleSwitchRepository();
    final activator = JeeberRoleActivator(
      roleSwitch: repo,
      roleCubit: h.role,
      availabilityCubit: h.avail,
    );

    final outcome = await activator.activate();

    expect(outcome, JeeberActivationOutcome.activated);
    expect(repo.switched, <String>['jeeber'],
        reason: 'the re-mint POST /v1/users/me/role/switch must fire');
    expect(h.role.state, UserRole.jeeber,
        reason: 'the shell must render the Jeeber tab-set');
    expect(h.avail.state.roles, containsAll(<String>['client', 'jeeber']));
    expect(h.avail.state.isDualRole, isTrue,
        reason: 'available_roles must light up the live jeeber bodies + toggle');
  });

  test('kycGated (403): leaves the local role + availability untouched',
      () async {
    final h = await harness(initialRoles: const <String>['client']);
    final activator = JeeberRoleActivator(
      roleSwitch:
          _FakeRoleSwitchRepository(result: RoleSwitchResult.kycGated),
      roleCubit: h.role,
      availabilityCubit: h.avail,
    );

    final outcome = await activator.activate();

    expect(outcome, JeeberActivationOutcome.kycGated);
    expect(h.role.state, UserRole.client,
        reason: 'never strand the user on a half-switched surface');
    expect(h.avail.state.roles, const <String>['client']);
  });

  test('failed (network): reports failure, never throws, keeps local state',
      () async {
    final h = await harness();
    final activator = JeeberRoleActivator(
      roleSwitch: _ThrowingRoleSwitchRepository(),
      roleCubit: h.role,
      availabilityCubit: h.avail,
    );

    final outcome = await activator.activate();

    expect(outcome, JeeberActivationOutcome.failed);
    expect(h.role.state, UserRole.client);
    expect(h.avail.state.roles, isEmpty);
  });

  test('merges jeeber onto an existing client-only availability without dup',
      () async {
    final h = await harness(initialRoles: const <String>['client']);
    final activator = JeeberRoleActivator(
      roleSwitch: _FakeRoleSwitchRepository(),
      roleCubit: h.role,
      availabilityCubit: h.avail,
    );

    await activator.activate();

    expect(h.avail.state.roles, const <String>['client', 'jeeber']);
  });
}
