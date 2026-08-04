// M3-23 per-element Midnight assertions for ProfileEditScreen.
//
// Goldens are evidence, not gates (02-STUDY-NOTES, wave-C fixup): the shared
// comparator tolerates 5% pixel diff, so mounting a field or re-inking a label
// can leave every golden green. Each ruling this row landed is read back off
// the built widget here, plus a regression guard for the blank-name defect the
// loading frame fixed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/profile_edit_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/settings_fakes.dart';
import '../../support/sync_app_localizations.dart';

const Key _kNameField = Key('profile-edit-name');
const Key _kRemoveAvatar = Key('profile-edit-remove-avatar');

const UserProfile _named = UserProfile(
  phoneE164: '+96170100200',
  name: 'Maya Haddad',
);

const UserProfile _withPhoto = UserProfile(
  phoneE164: '+96170100200',
  name: 'Maya Haddad',
  photoUrl: 'https://example.invalid/a.png',
);

/// A profile read the test resolves by hand — the only way to hold the screen
/// on the frame the live route really mounts in.
class _GatedProfileRepository implements ProfileRepository {
  _GatedProfileRepository(this._profile);

  final UserProfile _profile;
  final Completer<UserProfile?> _gate = Completer<UserProfile?>();

  void release() => _gate.complete(_profile);

  @override
  Future<UserProfile?> load() => _gate.future;

  @override
  Future<void> save(UserProfile profile) async {}

  @override
  Future<void> clear() async {}
}

Widget _harness(SettingsCubit cubit) {
  return BlocProvider<SettingsCubit>.value(
    value: cubit,
    child: MaterialApp(
      theme: AppTheme.midnight(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const ProfileEditScreen(),
    ),
  );
}

void main() {
  SettingsCubit cubitOver(ProfileRepository repo) {
    final cubit = SettingsCubit(
      profileRepository: repo,
      accountService: const FakeAccountService(),
      fallbackPhoneE164: '+96170100200',
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<SettingsCubit> loaded([UserProfile profile = _named]) async {
    final repo = InMemoryProfileRepository();
    await repo.save(profile);
    final cubit = cubitOver(repo);
    await cubit.load();
    return cubit;
  }

  testWidgets('mounts R22 field: content, glow topEnd, no wash, decor still',
      (tester) async {
    await tester.pumpWidget(_harness(await loaded()));
    await tester.pumpAndSettle();

    final field =
        tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));
    // Carried from the parent (settings_screen.dart) so the push does not drop
    // the glow: R22's only radial is `480x380 at 88% -6%`.
    expect(field.variant, JeebFieldVariant.content);
    expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
    // R22 declares zero periwinkle.
    expect(field.washPlacement, isNull);
    // R22 is board-still.
    expect(field.animateDecor, isFalse);
  });

  testWidgets('the scaffold is transparent so the field is what paints',
      (tester) async {
    await tester.pumpWidget(_harness(await loaded()));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(JeebMidnightField),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, Colors.transparent);
  });

  testWidgets('remove-avatar is danger-SOFT, never full-strength error',
      (tester) async {
    await tester.pumpWidget(_harness(await loaded(_withPhoto)));
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(_kRemoveAvatar));
    final scheme = Theme.of(context).colorScheme;
    final button = tester.widget<TextButton>(find.byKey(_kRemoveAvatar));
    final ink = button.style!.foregroundColor!.resolve(<WidgetState>{});

    // R22's docked footer ruling: destructive text is #FF7B7B.
    expect(ink, scheme.onErrorContainer);
    // The neutral periwinkle it used to read as, and the harsher ink reserved
    // for strokes and glyphs.
    expect(ink, isNot(scheme.onSurfaceVariant));
    expect(ink, isNot(scheme.error));
  });

  testWidgets('a locally-picked avatar holds the disc while it decodes',
      (tester) async {
    await tester.pumpWidget(
      _harness(await loaded(const UserProfile(
        phoneE164: '+96170100200',
        name: 'Maya Haddad',
        photoUrl: '/var/mobile/does-not-exist/avatar.jpg',
      ))),
    );
    await tester.pump();

    // Without the frameBuilder the decode window painted an empty hole where
    // the Ø96 hero disc belongs.
    expect(find.byType(JeebAvatar), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
  });

  group('cold read (the blank-name defect)', () {
    testWidgets('while loading the form is withheld for the radar frame',
        (tester) async {
      final repo = _GatedProfileRepository(_named);
      final cubit = cubitOver(repo);
      unawaited(cubit.load());

      await tester.pumpWidget(_harness(cubit));
      await tester.pump();

      final state =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(state.status, JeebEmptyStateStatus.loading);
      expect(state.medallions, isEmpty);
      expect(state.identifier, ProfileEditScreen.loadingIdentifier);
      // The form and its docked Save must not be reachable behind the read.
      expect(find.byKey(_kNameField), findsNothing);
      expect(find.byKey(const Key('profile-edit-save')), findsNothing);

      repo.release();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'REGRESSION: a name that lands after mount reaches the name field',
        (tester) async {
      final repo = _GatedProfileRepository(_named);
      final cubit = cubitOver(repo);
      unawaited(cubit.load());

      await tester.pumpWidget(_harness(cubit));
      await tester.pump();

      repo.release();
      await tester.pumpAndSettle();

      // Before M3-23 the controller was seeded once, in initState, from the
      // still-empty profile — so this field stayed blank on the live route.
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(_kNameField),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, 'Maya Haddad');
    });

    testWidgets('a late load does not clobber what the user already typed',
        (tester) async {
      final repo = _GatedProfileRepository(_named);
      final cubit = cubitOver(repo);
      unawaited(cubit.load());

      await tester.pumpWidget(_harness(cubit));
      await tester.pump();
      repo.release();
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(_kNameField), 'Nour');
      await tester.pumpAndSettle();
      // A second emit (the save banner) must not re-seed.
      await cubit.saveProfile(name: 'Nour');
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(_kNameField),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, 'Nour');
    });
  });
}
