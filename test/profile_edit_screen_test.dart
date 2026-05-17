import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/data/in_memory_profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/profile_edit_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arb);
  final String _arb;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(locale, _arb);
  }

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _delegate;

void _loadArb() {
  _delegate = _SyncDelegate(File('lib/l10n/app_en.arb').readAsStringSync());
}

Widget _harness(SettingsCubit cubit) {
  return BlocProvider<SettingsCubit>.value(
    value: cubit,
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ProfileEditScreen(),
    ),
  );
}

void main() {
  setUpAll(_loadArb);

  SettingsCubit newCubit({UserProfile? seed}) {
    final repo = InMemoryProfileRepository();
    final cubit = SettingsCubit(
      profileRepository: repo,
      accountService: const FakeAccountService(),
      fallbackPhoneE164: '+96170100200',
    );
    if (seed != null) {
      // The cubit reads from the repo on load(); seed it before load.
      repo.save(seed);
    }
    return cubit;
  }

  group('ProfileEditScreen — read-only phone', () {
    testWidgets('phone row renders the E.164 string from the cubit state',
        (tester) async {
      final cubit = newCubit(seed: const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
      ));
      await cubit.load();
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(find.text('+96170100200'), findsOneWidget);
      // The phone row uses a lock-outline trailing icon to communicate
      // read-only state.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('ProfileEditScreen — name editing', () {
    testWidgets('renders the Save button with the localized label',
        (tester) async {
      final cubit = newCubit();
      await cubit.load();
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
      expect(find.byKey(const Key('profile-edit-save')), findsOneWidget);
    });

    testWidgets('empty name surfaces the required-field error', (tester) async {
      final cubit = newCubit();
      await cubit.load();
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('profile-edit-name')), '   ');
      await tester.tap(find.byKey(const Key('profile-edit-save')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name.'), findsOneWidget);
      expect(cubit.state.profile.name, isNull);
    });

    testWidgets('save persists the trimmed name and snackbars the success',
        (tester) async {
      final cubit = newCubit();
      await cubit.load();
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('profile-edit-name')), '  Sami  ');
      await tester.tap(find.byKey(const Key('profile-edit-save')));
      await tester.pumpAndSettle();

      expect(cubit.state.profile.name, 'Sami');
      expect(find.text('Profile saved.'), findsOneWidget);
    });
  });

  group('ProfileEditScreen — avatar removal', () {
    testWidgets('remove-avatar control is only shown when a photo is set',
        (tester) async {
      final cubit = newCubit(seed: const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
      ));
      await cubit.load();
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-edit-remove-avatar')), findsNothing);
    });
  });
}
