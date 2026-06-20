// Unit tests for GreetingProfileCubit (P0-X06). Proves the personalized
// greeting (name + avatar) is sourced from the live `getMe` profile, and that
// it degrades to the generic (null/empty) greeting on a failed/absent fetch
// rather than surfacing a broken header.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';

class _ScriptedRepository implements CustomerProfileRepository {
  _ScriptedRepository({this.profile, this.throws});

  final CustomerProfileViewData? profile;
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
  });
}
