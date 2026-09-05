import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_sync.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/session/session_cubit.dart';
import 'package:jeeb_mobile/core/session/session_state.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';

import 'support/test_jwt.dart';

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

/// Throws the CLASSIFIED exception the Dio repository raises, so the failure
/// the UI renders is the transport's own.
class _ClassifiedThrowingProfileRepository
    implements CustomerProfileRepository {
  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    throw const CustomerProfileRepositoryException.classified(
      CustomerProfileFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }
}

/// Holds the read open so the LOADING rung is observable.
class _PendingProfileRepository implements CustomerProfileRepository {
  final Completer<CustomerProfileViewData> completer =
      Completer<CustomerProfileViewData>();

  @override
  Future<CustomerProfileViewData> fetchProfile() => completer.future;
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

  test(
    'DEFECT-C: dual-role user active_role=jeeber flips RoleCubit to jeeber',
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
    },
  );

  test(
    'DEFECT-C: dual-role user active_role=client lands on client + toggle on',
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
    },
  );

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

  test(
    'active_role not in available_roles is ignored (no stranding)',
    () async {
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
    },
  );

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

  // F2/F3: a swallowed getMe failure made "gateway down" indistinguishable
  // from "not a jeeber", and the shell invited an approved jeeber to register.
  group('F2/F3: the capability read publishes its own state', () {
    test('a successful sync resolves', () async {
      final h = await harness(
        repository: _FakeProfileRepository(
          const CustomerProfileViewData(
            activeRole: 'jeeber',
            availableRoles: ['client', 'jeeber'],
          ),
        ),
      );
      expect(h.avail.state.status, RoleAvailabilityStatus.resolved);
      expect(h.avail.state.failure, isNull);
      addTearDown(h.role.close);
      addTearDown(h.avail.close);
    });

    test('a throwing repository emits failed and leaves roles untouched',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final role = RoleCubit(prefs: prefs, initialRole: UserRole.jeeber);
      final avail = RoleAvailabilityCubit(
        const RoleAvailability(
          roles: ['client', 'jeeber'],
          status: RoleAvailabilityStatus.resolved,
        ),
      );
      final sync = RoleSync(
        roleCubit: role,
        availabilityCubit: avail,
        repository: _ThrowingProfileRepository(),
      );

      await sync.sync();

      expect(avail.state.status, RoleAvailabilityStatus.failed);
      expect(avail.state.failure, isA<UnauthorizedFailure>());
      expect(avail.state.roles, ['client', 'jeeber']);
      expect(role.state, UserRole.jeeber);
      addTearDown(role.close);
      addTearDown(avail.close);
    });

    test('a classified exception carries its own AppFailure through', () async {
      final prefs = await SharedPreferences.getInstance();
      final role = RoleCubit(prefs: prefs);
      final avail = RoleAvailabilityCubit();
      final sync = RoleSync(
        roleCubit: role,
        availabilityCubit: avail,
        repository: _ClassifiedThrowingProfileRepository(),
      );

      await sync.sync();

      expect(avail.state.status, RoleAvailabilityStatus.failed);
      expect(avail.state.failure, const NetworkFailure(offline: true));
      addTearDown(role.close);
      addTearDown(avail.close);
    });

    test('the read is LOADING while it is in flight', () async {
      final prefs = await SharedPreferences.getInstance();
      final role = RoleCubit(prefs: prefs);
      final avail = RoleAvailabilityCubit();
      final repo = _PendingProfileRepository();
      final sync = RoleSync(
        roleCubit: role,
        availabilityCubit: avail,
        repository: repo,
      );

      final pending = sync.sync();
      await pumpEventQueue();
      expect(avail.state.status, RoleAvailabilityStatus.loading);

      repo.completer.complete(
        const CustomerProfileViewData(
          activeRole: 'client',
          availableRoles: ['client'],
        ),
      );
      await pending;
      expect(avail.state.status, RoleAvailabilityStatus.resolved);
      addTearDown(role.close);
      addTearDown(avail.close);
    });

    test('RoleSync hydrates the cached roles for the SAME account', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        RoleAvailabilityCubit.availableRolesPrefKey: <String>[
          'client',
          'jeeber',
        ],
        RoleAvailabilityCubit.availableRolesOwnerPrefKey: 'karim',
      });
      final prefs = await SharedPreferences.getInstance();
      final role = RoleCubit(prefs: prefs);
      final avail = RoleAvailabilityCubit(
        const RoleAvailability(),
        prefs,
        () async => 'karim',
      );

      RoleSync(roleCubit: role, availabilityCubit: avail);
      await Future<void>.delayed(Duration.zero);

      expect(avail.state.roles, ['client', 'jeeber']);
      expect(avail.state.status, RoleAvailabilityStatus.unknown);
      addTearDown(role.close);
      addTearDown(avail.close);
    });

    test('a cache stamped for ANOTHER account is never hydrated', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        RoleAvailabilityCubit.availableRolesPrefKey: <String>[
          'client',
          'jeeber',
        ],
        RoleAvailabilityCubit.availableRolesOwnerPrefKey: 'karim',
      });
      final prefs = await SharedPreferences.getInstance();
      final role = RoleCubit(prefs: prefs);
      final avail = RoleAvailabilityCubit(
        const RoleAvailability(),
        prefs,
        () async => 'fresh-client',
      );

      RoleSync(roleCubit: role, availabilityCubit: avail);
      await Future<void>.delayed(Duration.zero);

      expect(avail.state.roles, isEmpty,
          reason: 'a Super-Login switch must not inherit jeeber tabs');
      addTearDown(role.close);
      addTearDown(avail.close);
    });

    test('an UNSTAMPED legacy cache is never hydrated', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        RoleAvailabilityCubit.availableRolesPrefKey: <String>['client'],
      });
      final prefs = await SharedPreferences.getInstance();
      final avail = RoleAvailabilityCubit(
        const RoleAvailability(),
        prefs,
        () async => 'karim',
      );

      await avail.hydrate();

      expect(avail.state.roles, isEmpty);
      addTearDown(avail.close);
    });

    test('a resolved read stamps the cache with the signed-in user', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final avail = RoleAvailabilityCubit(
        const RoleAvailability(),
        prefs,
        () async => 'karim',
      );

      avail.setAvailableRoles(const <String>['client', 'jeeber']);
      await Future<void>.delayed(Duration.zero);

      expect(
        prefs.getString(RoleAvailabilityCubit.availableRolesOwnerPrefKey),
        'karim',
      );
      addTearDown(avail.close);
    });

    test('the cubit re-runs the sync through the attached refresher', () async {
      final prefs = await SharedPreferences.getInstance();
      final role = RoleCubit(prefs: prefs);
      final avail = RoleAvailabilityCubit();
      final repo = _CountingProfileRepository(
        const CustomerProfileViewData(
          activeRole: 'client',
          availableRoles: ['client'],
        ),
      );
      RoleSync(roleCubit: role, availabilityCubit: avail, repository: repo);

      expect(avail.canRefresh, isTrue);
      await avail.refresh();

      expect(repo.calls, 1);
      expect(avail.state.status, RoleAvailabilityStatus.resolved);
      addTearDown(role.close);
      addTearDown(avail.close);
    });
  });

  // DEFECT-C2: RoleSync.sync must fire on the authenticated session transition
  group('DEFECT-C2: fires on the authenticated session transition', () {
    /// Mirrors `JeebApp._wireSessionRoleSync`: re-runs [RoleSync.sync] whenever
    /// the session transitions to authenticated.
    StreamSubscription<SessionState> wire(
      SessionCubit session,
      RoleSync sync,
    ) => session.stream.listen((s) {
      if (s.isAuthenticated) sync.sync();
    });

    test(
      'login (session → authenticated) flips a dual-role user to jeeber',
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
        final sync = RoleSync(
          roleCubit: role,
          availabilityCubit: avail,
          repository: repo,
        );

        final store = _MockAuthTokenStore();
        when(() => store.accessToken).thenAnswer((_) async => validTestJwt);
        final session = SessionCubit(tokenStore: store);
        final sub = wire(session, sync);

        // Before login: cubit is in the inert `unknown` phase, so the role-sync
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
      },
    );

    test(
      'does NOT re-fire when the state stays authenticated (no spurious sync)',
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
        final sync = RoleSync(
          roleCubit: role,
          availabilityCubit: avail,
          repository: repo,
        );

        final store = _MockAuthTokenStore();
        when(() => store.accessToken).thenAnswer((_) async => validTestJwt);
        final session = SessionCubit(tokenStore: store);
        final sub = wire(session, sync);

        await session.refresh(); // unknown → authenticated (fires)
        await pumpEventQueue();
        await session
            .refresh(); // authenticated → authenticated (no emit, no fire)
        await pumpEventQueue();

        expect(
          repo.calls,
          1,
          reason: 'only the transition fires, not every refresh',
        );

        addTearDown(sub.cancel);
        addTearDown(session.close);
        addTearDown(role.close);
        addTearDown(avail.close);
      },
    );
  });
}
