// LR-05: `load()` had no try/catch and no failed status, so a throwing
// ProfileRepository hung the screen on `isLoading: true` forever.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/application/settings_state.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/settings_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/settings_fakes.dart';
import '../../support/sync_app_localizations.dart';

class _ThrowingProfileRepository implements ProfileRepository {
  _ThrowingProfileRepository(this.failure);

  final AppFailure failure;
  int loads = 0;

  @override
  Future<UserProfile?> load() async {
    loads++;
    throw failure;
  }

  @override
  Future<void> save(UserProfile profile) async => throw failure;

  @override
  Future<void> clear() async {}
}

/// Serves one good local read, then throws — the warm-refresh failure shape.
class _ThenThrowsProfileRepository implements ProfileRepository {
  _ThenThrowsProfileRepository(this.profile);

  final UserProfile profile;
  int loads = 0;

  @override
  Future<UserProfile?> load() async {
    loads++;
    if (loads == 1) return profile;
    throw const NetworkFailure();
  }

  @override
  Future<void> save(UserProfile p) async {}

  @override
  Future<void> clear() async {}
}

SettingsCubit _cubit(ProfileRepository repo) => SettingsCubit(
      profileRepository: repo,
      accountService: const FakeAccountService(),
      fallbackPhoneE164: '+96170100200',
    );

Future<void> _pump(
  WidgetTester tester,
  SettingsCubit cubit, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    wrapForTest(SettingsScreen(cubit: cubit), locale: locale),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a throwing local read lands on failed + carries the failure',
      () async {
    final cubit = _cubit(_ThrowingProfileRepository(const ServerFailure(status: 500)));
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, SettingsStatus.failed);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, isA<ServerFailure>());
  });

  testWidgets('the failed rung renders settings_error with a retry',
      (tester) async {
    final repo = _ThrowingProfileRepository(const ServerFailure(status: 500));
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();

    await _pump(tester, cubit);

    expect(find.bySemanticsIdentifier('settings_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('settings_retry_cta'), findsOneWidget);

    await tester.tap(find.bySemanticsIdentifier('settings_retry_cta'));
    await tester.pumpAndSettle();

    expect(repo.loads, 2);
  });

  testWidgets('an expired session gets the EXIT act, never an inert Retry',
      (tester) async {
    final cubit = _cubit(_ThrowingProfileRepository(const UnauthorizedFailure()));
    addTearDown(cubit.close);
    await cubit.load();

    await _pump(tester, cubit);

    expect(find.bySemanticsIdentifier('settings_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('settings_retry_cta'), findsNothing);
    expect(find.bySemanticsIdentifier('settings_exit_cta'), findsOneWidget);
  });

  testWidgets('AR renders the same rung and identifiers', (tester) async {
    final cubit = _cubit(_ThrowingProfileRepository(const NetworkFailure()));
    addTearDown(cubit.close);
    await cubit.load();

    await _pump(tester, cubit, locale: const Locale('ar'));

    expect(find.bySemanticsIdentifier('settings_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('settings_retry_cta'), findsOneWidget);
  });

  test('refresh() from LOADED never flips back to the loading rung', () async {
    final repo = _ThenThrowsProfileRepository(
      const UserProfile(phoneE164: '+96170100200', name: 'Rami'),
    );
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.status, SettingsStatus.loaded);

    final statuses = <SettingsStatus>[];
    final sub = cubit.stream.listen((s) => statuses.add(s.status));
    await cubit.refresh();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(
      statuses.contains(SettingsStatus.loading),
      isFalse,
      reason: 'R6: refresh never blanks a loaded screen',
    );
    expect(cubit.state.status, SettingsStatus.loaded);
    expect(cubit.state.profile.name, 'Rami');
    expect(cubit.state.refreshError, isA<NetworkFailure>());
    expect(repo.loads, 2);
  });

  test('load() from LOADED still shows the cold loading rung', () async {
    final repo = _ThenThrowsProfileRepository(
      const UserProfile(phoneE164: '+96170100200'),
    );
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.load();

    final statuses = <SettingsStatus>[];
    final sub = cubit.stream.listen((s) => statuses.add(s.status));
    await cubit.load();
    await sub.cancel();

    expect(statuses.contains(SettingsStatus.loading), isTrue);
    expect(cubit.state.status, SettingsStatus.failed);
  });

  testWidgets('the cold rung is settings_loading', (tester) async {
    final cubit = _cubit(InMemoryProfileRepository());
    addTearDown(cubit.close);

    await _pump(tester, cubit);

    expect(find.bySemanticsIdentifier('settings_loading'), findsOneWidget);
  });
}
