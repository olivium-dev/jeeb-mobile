// Unit tests for GreetingProfileCubit (P0-X06). Proves the personalized

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';

class _ScriptedRepository implements CustomerProfileRepository {
  _ScriptedRepository({this.profile, this.throws});

  CustomerProfileViewData? profile;
  CustomerProfileFailure? throws;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    final f = throws;
    if (f != null) throw CustomerProfileRepositoryException(f);
    return profile ?? const CustomerProfileViewData();
  }
}

class _CallbackRepository implements CustomerProfileRepository {
  _CallbackRepository(this.read);
  final Future<CustomerProfileViewData> Function() read;
  int calls = 0;

  @override
  Future<CustomerProfileViewData> fetchProfile() {
    calls++;
    return read();
  }
}

void main() {
  test(
    'profile saves during a read coalesce into a fresh identity read',
    () async {
      final pending = Completer<CustomerProfileViewData>();
      final refresh = StreamController<void>.broadcast(sync: true);
      var reads = 0;
      final repo = _CallbackRepository(() {
        reads++;
        return reads == 1
            ? pending.future
            : Future.value(
                const CustomerProfileViewData(
                  name: 'New Name',
                  avatarUrl: 'new.png',
                ),
              );
      });
      final cubit = GreetingProfileCubit(
        repository: repo,
        refreshSignals: refresh.stream,
      );
      addTearDown(cubit.close);
      addTearDown(refresh.close);
      final loading = cubit.load();
      refresh.add(null);
      refresh.add(null);
      expect(repo.calls, 1);
      pending.complete(
        const CustomerProfileViewData(name: 'Old Name', avatarUrl: 'old.png'),
      );
      await loading;
      expect(repo.calls, 2);
      expect(cubit.state.name, 'New Name');
      expect(cubit.state.avatarUrl, 'new.png');
      expect(cubit.state.status, GreetingProfileStatus.resolved);
    },
  );

  test('close discards a queued profile invalidation', () async {
    final pending = Completer<CustomerProfileViewData>();
    final refresh = StreamController<void>.broadcast(sync: true);
    final repo = _CallbackRepository(() => pending.future);
    final cubit = GreetingProfileCubit(
      repository: repo,
      refreshSignals: refresh.stream,
    );
    final loading = cubit.load();
    refresh.add(null);
    await cubit.close();
    pending.complete(const CustomerProfileViewData(name: 'Old Name'));
    await loading;
    expect(repo.calls, 1);
    await refresh.close();
  });

  for (final entry in <CustomerProfileFailure, Type>{
    CustomerProfileFailure.unauthorized: UnauthorizedFailure,
    CustomerProfileFailure.unknown: UnknownFailure,
  }.entries) {
    test('legacy ${entry.key.name} preserves its kind', () async {
      final cubit = GreetingProfileCubit(
        repository: _ScriptedRepository(throws: entry.key),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.failure.runtimeType, entry.value);
    });
  }

  test('classified exception preserves the concrete AppFailure', () async {
    final cubit = GreetingProfileCubit(
      repository: _CallbackRepository(() async {
        throw const CustomerProfileRepositoryException.classified(
          CustomerProfileFailure.unknown,
          appFailure: ServerFailure(status: 503),
        );
      }),
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.failure, const ServerFailure(status: 503));
  });

  test(
    'failed retry transitions loading to resolved and clears failure',
    () async {
      final repo = _ScriptedRepository(throws: CustomerProfileFailure.network);
      final cubit = GreetingProfileCubit(repository: repo);
      addTearDown(cubit.close);
      final states = <GreetingProfileStatus>[];
      final subscription = cubit.stream.listen(
        (state) => states.add(state.status),
      );
      addTearDown(subscription.cancel);
      await cubit.load();
      repo.throws = null;
      repo.profile = const CustomerProfileViewData(name: 'Ahmad');
      await cubit.retryIfFailed();
      await Future<void>.delayed(Duration.zero);
      expect(states, [
        GreetingProfileStatus.loading,
        GreetingProfileStatus.failed,
        GreetingProfileStatus.loading,
        GreetingProfileStatus.resolved,
      ]);
      expect(cubit.state.name, 'Ahmad');
      expect(cubit.state.failure, isNull);
    },
  );

  test('warm failure preserves a named profile already on screen', () async {
    final repo = _ScriptedRepository(
      profile: const CustomerProfileViewData(name: 'Ahmad'),
    );
    final cubit = GreetingProfileCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.load();
    final previous = cubit.state;
    final emitted = <GreetingProfileState>[];
    final subscription = cubit.stream.listen(emitted.add);
    addTearDown(subscription.cancel);
    repo.throws = CustomerProfileFailure.network;
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, previous);
    expect(emitted, isEmpty);
    expect(cubit.state.failure, isNull);
  });

  test('a thrown refresh after a nameless read fails instead of pretending '
      'the nameless greeting still holds', () async {
    final repo = _ScriptedRepository(profile: const CustomerProfileViewData());
    final cubit = GreetingProfileCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.status, GreetingProfileStatus.resolved);
    expect(cubit.state.name, isNull);
    final emitted = <GreetingProfileStatus>[];
    final subscription = cubit.stream.listen((s) => emitted.add(s.status));
    addTearDown(subscription.cancel);
    repo.throws = CustomerProfileFailure.network;
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, GreetingProfileStatus.failed);
    expect(cubit.state.failure, isA<NetworkFailure>());
    expect(emitted, <GreetingProfileStatus>[GreetingProfileStatus.failed]);
  });

  test('a thrown load over a seeded name keeps the person and clears '
      'loading', () async {
    final repo = _ScriptedRepository(throws: CustomerProfileFailure.network);
    final cubit = GreetingProfileCubit(
      repository: repo,
      seed: const GreetingProfileState(name: 'Sami', avatarUrl: 'seed.png'),
    );
    addTearDown(cubit.close);
    final emitted = <GreetingProfileStatus>[];
    final subscription = cubit.stream.listen((s) => emitted.add(s.status));
    addTearDown(subscription.cancel);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, GreetingProfileStatus.resolved);
    expect(cubit.state.name, 'Sami');
    expect(cubit.state.failure, isNull);
    expect(emitted, <GreetingProfileStatus>[
      GreetingProfileStatus.loading,
      GreetingProfileStatus.resolved,
    ]);
  });

  for (final failure in <AppFailure>[
    const NetworkFailure(offline: true),
    const TimeoutFailure(phase: DioExceptionType.receiveTimeout),
    const ServerFailure(status: 503),
  ]) {
    test(
      'reconnect filters ${failure.kind.name}; resume retries failures',
      () async {
        final reconnect = StreamController<void>.broadcast(sync: true);
        final resume = StreamController<void>.broadcast(sync: true);
        final repo = _CallbackRepository(() async => throw failure);
        final cubit = GreetingProfileCubit(
          repository: repo,
          reconnectSignals: reconnect.stream,
          resumeSignals: resume.stream,
        );
        addTearDown(cubit.close);
        addTearDown(reconnect.close);
        addTearDown(resume.close);
        await cubit.load();
        reconnect.add(null);
        await Future<void>.delayed(Duration.zero);
        final connectivity =
            failure is NetworkFailure || failure is TimeoutFailure;
        expect(repo.calls, connectivity ? 2 : 1);
        resume.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(repo.calls, connectivity ? 3 : 2);
      },
    );
  }

  for (final status in [
    GreetingProfileStatus.idle,
    GreetingProfileStatus.resolved,
  ]) {
    test('retryIfFailed is a no-op when ${status.name}', () async {
      final repo = _CallbackRepository(
        () async => const CustomerProfileViewData(),
      );
      final cubit = GreetingProfileCubit(
        repository: repo,
        seed: GreetingProfileState(status: status),
      );
      addTearDown(cubit.close);
      await cubit.retryIfFailed();
      expect(repo.calls, 0);
    });
  }

  test(
    'simultaneous signals share one read; close ignores its late result',
    () async {
      final reconnect = StreamController<void>.broadcast(sync: true);
      final resume = StreamController<void>.broadcast(sync: true);
      final pending = Completer<CustomerProfileViewData>();
      final repo = _CallbackRepository(() => pending.future);
      final cubit = GreetingProfileCubit(
        repository: repo,
        seed: const GreetingProfileState(
          status: GreetingProfileStatus.failed,
          failure: NetworkFailure(),
        ),
        reconnectSignals: reconnect.stream,
        resumeSignals: resume.stream,
      );
      reconnect.add(null);
      resume.add(null);
      expect(repo.calls, 1);
      await cubit.close();
      final previous = cubit.state;
      reconnect.add(null);
      resume.add(null);
      pending.complete(const CustomerProfileViewData(name: 'Too late'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, 1);
      expect(cubit.state, previous);
      await reconnect.close();
      await resume.close();
    },
  );

  group('GreetingProfileCubit', () {
    test('default state is the generic (null) greeting', () {
      final cubit = GreetingProfileCubit();
      expect(cubit.state.name, isNull);
      expect(cubit.state.avatarUrl, isNull);
      cubit.close();
    });

    test('load() with no repository is a no-op (stays on the seed)', () async {
      final cubit = GreetingProfileCubit(
        seed: const GreetingProfileState(name: 'Seed', avatarUrl: 'seed.png'),
      );
      await cubit.load();
      expect(cubit.state.name, 'Seed');
      expect(cubit.state.avatarUrl, 'seed.png');
      cubit.close();
    });

    test('load() populates name + avatar from the live profile', () async {
      final cubit = GreetingProfileCubit(
        repository: _ScriptedRepository(
          profile: const CustomerProfileViewData(
            name: 'Sami Fawaz',
            avatarUrl: 'https://cdn/avatar.png',
          ),
        ),
      );
      await cubit.load();
      expect(cubit.state.name, 'Sami Fawaz');
      expect(cubit.state.avatarUrl, 'https://cdn/avatar.png');
      cubit.close();
    });

    test('load() normalizes blank name/avatar to null', () async {
      final cubit = GreetingProfileCubit(
        repository: _ScriptedRepository(
          profile: const CustomerProfileViewData(name: '  ', avatarUrl: ''),
        ),
      );
      await cubit.load();
      expect(cubit.state.name, isNull);
      expect(cubit.state.avatarUrl, isNull);
      cubit.close();
    });

    test('load() degrades to the seed on a typed repository failure', () async {
      final cubit = GreetingProfileCubit(
        repository: _ScriptedRepository(throws: CustomerProfileFailure.network),
      );
      await cubit.load();
      expect(cubit.state.isFailed, isTrue);
      expect(cubit.state.name, isNull);
      expect(cubit.state.avatarUrl, isNull);
      cubit.close();
    });

    test('profile-changed signal re-pulls getMe so a saved display name lands '
        '(profile-name lane)', () async {
      final repo = _ScriptedRepository(
        profile: const CustomerProfileViewData(),
      );
      final signals = StreamController<void>.broadcast();
      final cubit = GreetingProfileCubit(
        repository: repo,
        refreshSignals: signals.stream,
      );
      await cubit.load();
      expect(cubit.state.name, isNull);

      // Simulate the display-name save: getMe now carries the real name
      repo.profile = const CustomerProfileViewData(name: 'Ahmad');
      signals.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.name, 'Ahmad');
      await cubit.close();
      await signals.close();
    });

    test('load() ends in `resolved` on success', () async {
      final cubit = GreetingProfileCubit(
        repository: _ScriptedRepository(
          profile: const CustomerProfileViewData(name: 'Sami'),
        ),
      );
      final states = <GreetingProfileStatus>[];
      final sub = cubit.stream.listen((s) => states.add(s.status));
      await cubit.load();
      await Future<void>.delayed(Duration.zero);
      expect(states, <GreetingProfileStatus>[
        GreetingProfileStatus.loading,
        GreetingProfileStatus.resolved,
      ]);
      await sub.cancel();
      await cubit.close();
    });

    test(
      'a FAILED cold load ends in failed with the classified failure',
      () async {
        final cubit = GreetingProfileCubit(
          repository: _ScriptedRepository(
            throws: CustomerProfileFailure.network,
          ),
        );
        await cubit.load();
        expect(cubit.state.status, GreetingProfileStatus.failed);
        expect(cubit.state.failure, isA<NetworkFailure>());
        expect(cubit.state.name, isNull);
        await cubit.close();
      },
    );

    test(
      'a refresh does not flip a resolved greeting back to loading',
      () async {
        final repo = _ScriptedRepository(
          profile: const CustomerProfileViewData(name: 'Ahmad'),
        );
        final cubit = GreetingProfileCubit(repository: repo);
        await cubit.load();
        final seen = <GreetingProfileStatus>[];
        final sub = cubit.stream.listen((s) => seen.add(s.status));
        await cubit.load();
        await Future<void>.delayed(Duration.zero);
        expect(seen, isNot(contains(GreetingProfileStatus.loading)));
        await sub.cancel();
        await cubit.close();
      },
    );

    test('load() with no repository never leaves `idle`', () async {
      final cubit = GreetingProfileCubit();
      await cubit.load();
      expect(cubit.state.status, GreetingProfileStatus.idle);
      expect(cubit.state.isLoading, isFalse);
      await cubit.close();
    });

    test(
      'close() cancels the refresh subscription (no emit-after-close)',
      () async {
        final repo = _ScriptedRepository(
          profile: const CustomerProfileViewData(name: 'Ahmad'),
        );
        final signals = StreamController<void>.broadcast();
        final cubit = GreetingProfileCubit(
          repository: repo,
          refreshSignals: signals.stream,
        );
        await cubit.close();
        signals.add(null);
        await Future<void>.delayed(Duration.zero);
        // No throw and the seed state is untouched.
        expect(cubit.state.name, isNull);
        await signals.close();
      },
    );
  });
}
