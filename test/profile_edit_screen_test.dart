import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_compressor.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/data/profile_photo_store.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/profile_edit_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/settings_fakes.dart';

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

  group('ProfileEditScreen — change avatar (JEBV4-13, was a dead onTap)', () {
    Widget harnessWithSeams(
      SettingsCubit cubit, {
      required StubPhotoPickerService picker,
      required FakeProfilePhotoStore store,
    }) {
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
          home: ProfileEditScreen(photoPicker: picker, photoStore: store),
        ),
      );
    }

    testWidgets(
        'tapping Change avatar opens the source sheet; picking Gallery '
        'persists the photo and saves its path on the profile',
        (tester) async {
      final cubit = newCubit(seed: const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
      ));
      await cubit.load();
      addTearDown(cubit.close);
      final picker = StubPhotoPickerService();
      final store = FakeProfilePhotoStore();

      await tester
          .pumpWidget(harnessWithSeams(cubit, picker: picker, store: store));
      await tester.pumpAndSettle();
      expect(cubit.state.profile.photoUrl, isNull);

      await tester.tap(find.byKey(const Key('profile-edit-change-avatar')));
      await tester.pumpAndSettle();

      // The camera/gallery source sheet is up (localized labels).
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);

      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();

      // The pick went bytes → compress → persist → profile save.
      expect(store.persistCalls, 1);
      expect(cubit.state.profile.photoUrl, store.path);
      // The 2 MB compression ceiling held (stub gallery payload is 3 MB).
      expect(store.lastBytes!.length,
          lessThanOrEqualTo(PhotoCompressor.maxSizeBytes));
      // Name survived the photo-only save.
      expect(cubit.state.profile.name, 'Sami');
    });

    testWidgets('a failed pick surfaces an honest error, not silence',
        (tester) async {
      final cubit = newCubit();
      await cubit.load();
      addTearDown(cubit.close);
      final picker = StubPhotoPickerService(
        galleryFailure: PhotoPickFailure.unavailable,
      );
      final store = FakeProfilePhotoStore();

      await tester
          .pumpWidget(harnessWithSeams(cubit, picker: picker, store: store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-edit-change-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();

      expect(store.persistCalls, 0);
      expect(cubit.state.profile.photoUrl, isNull);
      expect(
        find.text("Couldn't update your photo. Please try again."),
        findsOneWidget,
      );
    });
  });
}
