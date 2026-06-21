import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_sync.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';

/// Scripted getMe repository for [RoleSync].
class _FakeProfileRepository implements CustomerProfileRepository {
  _FakeProfileRepository(this._result);

  final CustomerProfileViewData _result;

  @override
  Future<CustomerProfileViewData> fetchProfile() async => _result;
}

class _ThrowingProfileRepository implements CustomerProfileRepository {
  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    throw const CustomerProfileRepositoryException(
      CustomerProfileFailure.unauthorized,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<({RoleCubit role, RoleAvailabilityCubit avail})> harness({
    CustomerProfileRepository? repository,
    UserRole initialRole = UserRole.client,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final role = RoleCubit(prefs: prefs, initialRole: initialRole);
    final avail = RoleAvailabilityCubit();
    final sync = RoleSync(
      roleCubit: role,
      availabilityCubit: avail,
      repository: repository,
    );
    await sync.sync();
    return (role: role, avail: avail);
  }

  test('DEFECT-C: dual-role user active_role=jeeber flips RoleCubit to jeeber',
      () async {
    final h = await harness(
      repository: _FakeProfileRepository(
        const CustomerProfileViewData(
          activeRole: 'jeeber',
          availableRoles: ['client', 'jeeber'],
        ),
      ),
    );
    expect(h.role.state, UserRole.jeeber);
    expect(h.avail.state.isDualRole, isTrue);
    addTearDown(h.role.close);
    addTearDown(h.avail.close);
  });

  test('DEFECT-C: dual-role user active_role=client lands on client + toggle on',
      () async {
    final h = await harness(
      initialRole: UserRole.jeeber, // stale persisted role
      repository: _FakeProfileRepository(
        const CustomerProfileViewData(
          activeRole: 'client',
          availableRoles: ['client', 'jeeber'],
        ),
      ),
    );
    expect(h.role.state, UserRole.client);
    expect(h.avail.state.isDualRole, isTrue);
    addTearDown(h.role.close);
    addTearDown(h.avail.close);
  });

  test('single-role client never gets the toggle and stays client', () async {
    final h = await harness(
      repository: _FakeProfileRepository(
        const CustomerProfileViewData(
          activeRole: 'client',
          availableRoles: ['client'],
        ),
      ),
    );
    expect(h.role.state, UserRole.client);
    expect(h.avail.state.isDualRole, isFalse);
    addTearDown(h.role.close);
    addTearDown(h.avail.close);
  });

  test('active_role not in available_roles is ignored (no stranding)', () async {
    final h = await harness(
      repository: _FakeProfileRepository(
        // Defensive: server says jeeber active but only client is available.
        const CustomerProfileViewData(
          activeRole: 'jeeber',
          availableRoles: ['client'],
        ),
      ),
    );
    expect(h.role.state, UserRole.client);
    addTearDown(h.role.close);
    addTearDown(h.avail.close);
  });

  test('failed getMe keeps the persisted role + empty availability', () async {
    final h = await harness(
      initialRole: UserRole.jeeber,
      repository: _ThrowingProfileRepository(),
    );
    expect(h.role.state, UserRole.jeeber);
    expect(h.avail.state.roles, isEmpty);
    addTearDown(h.role.close);
    addTearDown(h.avail.close);
  });

  test('no repository (no DI) is a safe no-op', () async {
    final h = await harness(initialRole: UserRole.jeeber);
    expect(h.role.state, UserRole.jeeber);
    expect(h.avail.state.roles, isEmpty);
    addTearDown(h.role.close);
    addTearDown(h.avail.close);
  });
}
