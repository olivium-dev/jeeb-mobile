// Unit tests for GreetingProfileCubit (P0-X06). Proves the personalized

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';

class _ScriptedRepository implements CustomerProfileRepository {
  _ScriptedRepository({this.profile, this.throws});

  CustomerProfileViewData? profile;
  final CustomerProfileFailure? throws;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    final f = throws;
    if (f != null) throw CustomerProfileRepositoryException(f);
    return profile ?? const CustomerProfileViewData();
  }
}

void main() {
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
      // Failure keeps the generic greeting — never a broken header.
      expect(cubit.state.name, isNull);
      expect(cubit.state.avatarUrl, isNull);
      cubit.close();
    });

    test(
      'profile-changed signal re-pulls getMe so a saved display name lands '
      '(profile-name lane)',
      () async {
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
      },
    );

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

    test('a FAILED load() still ends in `resolved`, never stuck loading',
        () async {
      final cubit = GreetingProfileCubit(
        repository: _ScriptedRepository(throws: CustomerProfileFailure.network),
      );
      await cubit.load();
      expect(cubit.state.status, GreetingProfileStatus.resolved);
      expect(cubit.state.name, isNull);
      await cubit.close();
    });

    test('a refresh does not flip a resolved greeting back to loading',
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
    });

    test('load() with no repository never leaves `idle`', () async {
      final cubit = GreetingProfileCubit();
      await cubit.load();
      expect(cubit.state.status, GreetingProfileStatus.idle);
      expect(cubit.state.isLoading, isFalse);
      await cubit.close();
    });

    test('close() cancels the refresh subscription (no emit-after-close)',
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
    });
  });
}
