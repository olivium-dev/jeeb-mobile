// Isolated native UI test — ProfileEditScreen (settings-profile, T-mobile-031).
// The screen reads the screen-wide SettingsCubit at initState (name seed +
// read-only phone row), so we seed an in-memory ProfileRepository through the
// cubit and pump it via BlocProvider.value — mirroring the widget test's
// `newCubit(seed:...)` seam. Covers a seeded profile, the no-name placeholder,
// and Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/profile_edit_screen.dart';

import '../support/screen_harness.dart';

/// In-memory [ProfileRepository] (mirrors the widget test's zero-network double).
class _InMemoryProfileRepository implements ProfileRepository {
  _InMemoryProfileRepository([this._profile]);
  UserProfile? _profile;

  @override
  Future<UserProfile?> load() async => _profile;

  @override
  Future<void> save(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> clear() async {
    _profile = null;
  }
}

/// No-network [AccountService] the cubit needs but this surface never invokes.
class _FakeAccountService implements AccountService {
  const _FakeAccountService();

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async =>
      AccountActionOutcome.success;

  @override
  Future<AccountActionOutcome> signOut() async => AccountActionOutcome.success;
}

Future<SettingsCubit> _loadedCubit({UserProfile? seed}) async {
  final cubit = SettingsCubit(
    profileRepository: _InMemoryProfileRepository(seed),
    accountService: const _FakeAccountService(),
    fallbackPhoneE164: '+96170100200',
  );
  await cubit.load();
  return cubit;
}

Widget _screen(SettingsCubit cubit) => BlocProvider<SettingsCubit>.value(
      value: cubit,
      child: const ProfileEditScreen(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings-profile: seeded name + read-only phone (en)',
      (tester) async {
    final cubit = await _loadedCubit(
      seed: const UserProfile(phoneE164: '+96170100200', name: 'Sami'),
    );
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'settings-profile__idle',
    );
  });

  testWidgets('settings-profile: no name yet, placeholder avatar (en)',
      (tester) async {
    final cubit = await _loadedCubit();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'settings-profile__empty',
    );
  });

  testWidgets('settings-profile: seeded name (ar)', (tester) async {
    final cubit = await _loadedCubit(
      seed: const UserProfile(phoneE164: '+96170100200', name: 'سامي'),
    );
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'settings-profile__ar',
      locale: const Locale('ar'),
    );
  });
}
