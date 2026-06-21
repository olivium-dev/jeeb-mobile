import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_sync.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/session/session_cubit.dart';
import 'package:jeeb_mobile/core/session/session_state.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';

/// Scripted getMe repository for [RoleSync].
class _FakeProfileRepository implements CustomerProfileRepository {
  _FakeProfileRepository(this._result);

  final CustomerProfileViewData _result;

  @override
  Future<CustomerProfileViewData> fetchProfile() async => _result;
}

/// Counts getMe calls so a test can assert how many times [RoleSync.sync]
/// reached the repository (i.e. how many times the trigger fired).
class _CountingProfileRepository implements CustomerProfileRepository {
  _CountingProfileRepository(this._result);

  final CustomerProfileViewData _result;
  int calls = 0;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    calls++;
    return _result;
  }
}

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

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

  // DEFECT-C2: RoleSync.sync must fire on the authenticated session transition
  // (login completion), not only at cold-start (pre-auth) and resume. This
  // group reproduces the exact wiring `JeebApp._wireSessionRoleSync` installs:
  // subscribe to the SessionCubit stream and call sync() on every transition
  // INTO authenticated.
  group('DEFECT-C2: fires on the authenticated session transition', () {
    /// Mirrors `JeebApp._wireSessionRoleSync`: re-runs [RoleSync.sync] whenever
    /// the session transitions to authenticated.
    StreamSubscription<SessionState> wire(SessionCubit session, RoleSync sync) =>
        session.stream.listen((s) {
          if (s.isAuthenticated) sync.sync();
        });

    test('login (session → authenticated) flips a dual-role user to jeeber',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final role = RoleCubit(prefs: prefs, initialRole: UserRole.client);
      final avail = RoleAvailabilityCubit();
      final repo = _CountingProfileRepository(
        const CustomerProfileViewData(
          activeRole: 'jeeber',
          availableRoles: ['client', 'jeeber'],
        ),
      );
      final sync =
          RoleSync(roleCubit: role, availabilityCubit: avail, repository: repo);

      final store = _MockAuthTokenStore();
      when(() => store.accessToken)
          .thenAnswer((_) async => 'mock-jwt-access-token');
      final session = SessionCubit(tokenStore: store);
      final sub = wire(session, sync);

      // Before login: cubit is in the inert `unknown` phase, so the role-sync
      // trigger has NOT fired — the toggle is hidden and the role is the
      // `client` default (exactly the DEFECT-C2 symptom).
      expect(session.state.status, SessionStatus.unknown);
      expect(repo.calls, 0);
      expect(role.state, UserRole.client);
      expect(avail.state.isDualRole, isFalse);

      // OTP-verify / super-login calls session.refresh() → authenticated.
      await session.refresh();
      await pumpEventQueue();

      expect(session.state.isAuthenticated, isTrue);
      expect(repo.calls, 1, reason: 'sync must fire on the auth transition');
      expect(role.state, UserRole.jeeber);
      expect(avail.state.isDualRole, isTrue);

      addTearDown(sub.cancel);
      addTearDown(session.close);
      addTearDown(role.close);
      addTearDown(avail.close);
    });

    test('does NOT re-fire when the state stays authenticated (no spurious sync)',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final role = RoleCubit(prefs: prefs, initialRole: UserRole.client);
      final avail = RoleAvailabilityCubit();
      final repo = _CountingProfileRepository(
        const CustomerProfileViewData(
          activeRole: 'client',
          availableRoles: ['client', 'jeeber'],
        ),
      );
      final sync =
          RoleSync(roleCubit: role, availabilityCubit: avail, repository: repo);

      final store = _MockAuthTokenStore();
      when(() => store.accessToken)
          .thenAnswer((_) async => 'mock-jwt-access-token');
      final session = SessionCubit(tokenStore: store);
      final sub = wire(session, sync);

      await session.refresh(); // unknown → authenticated (fires)
      await pumpEventQueue();
      await session.refresh(); // authenticated → authenticated (no emit, no fire)
      await pumpEventQueue();

      expect(repo.calls, 1, reason: 'only the transition fires, not every refresh');

      addTearDown(sub.cancel);
      addTearDown(session.close);
      addTearDown(role.close);
      addTearDown(avail.close);
    });
  });
}
