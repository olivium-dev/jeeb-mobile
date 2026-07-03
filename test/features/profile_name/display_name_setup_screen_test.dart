// Widget tests for DisplayNameSetupScreen (profile-name lane, post-OTP
// display-name onboarding step). Proves:
//   - the step renders localized copy with the CTA gated on a non-empty name;
//   - the SKIP path resolves the step WITHOUT any PUT (optional-but-encouraged
//     — registration is never hard-blocked);
//   - the SUBMIT path PUTs the trimmed name and then resolves the step;
//   - a failed PUT keeps the user on the step (retry) with skip still live —
//     fail-soft, never a block;
//   - the Arabic locale renders the step RTL with the ar copy.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';
import 'package:jeeb_mobile/features/profile_name/presentation/display_name_setup_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

class _RecordingRepository implements DisplayNameRepository {
  _RecordingRepository({this.throws = false});

  final bool throws;
  final List<String> submitted = <String>[];

  @override
  Future<void> submitDisplayName(String name) async {
    if (throws) {
      throw const DisplayNameRepositoryException(DisplayNameFailure.network);
    }
    submitted.add(name);
  }
}

Widget _harness({
  required VoidCallback onDone,
  required DisplayNameRepository repository,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: DisplayNameSetupScreen(onDone: onDone, repository: repository),
  );
}

void main() {
  setUpAll(_loadArbs);

  group('DisplayNameSetupScreen (profile-name onboarding step)', () {
    testWidgets('renders localized copy with the CTA gated on input',
        (tester) async {
      await tester.pumpWidget(
        _harness(onDone: () {}, repository: _RecordingRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('What should we call you?'), findsOneWidget);
      expect(find.byKey(const Key('profile-name.field')), findsOneWidget);
      expect(find.byKey(const Key('profile-name.skip')), findsOneWidget);
      // Continue is rendered but does nothing while the field is empty.
      expect(find.byKey(const Key('profile-name.submit')), findsOneWidget);
    });

    testWidgets('skip path resolves the step WITHOUT any PUT', (tester) async {
      final repo = _RecordingRepository();
      var done = 0;
      await tester.pumpWidget(
        _harness(onDone: () => done++, repository: repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-name.skip')));
      await tester.pumpAndSettle();

      expect(done, 1, reason: 'skip must resolve the step exactly once');
      expect(repo.submitted, isEmpty,
          reason: 'skipping must never submit a name');
    });

    testWidgets('submit path PUTs the trimmed name then resolves the step',
        (tester) async {
      final repo = _RecordingRepository();
      var done = 0;
      await tester.pumpWidget(
        _harness(onDone: () => done++, repository: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile-name.field')),
        '  Ahmad ',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-name.submit')));
      await tester.pumpAndSettle();

      expect(repo.submitted, ['Ahmad']);
      expect(done, 1);
    });

    testWidgets(
        'failed PUT keeps the step on screen with skip still available '
        '(fail-soft, never a block)', (tester) async {
      final repo = _RecordingRepository(throws: true);
      var done = 0;
      await tester.pumpWidget(
        _harness(onDone: () => done++, repository: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile-name.field')),
        'Ahmad',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-name.submit')));
      await tester.pumpAndSettle();

      // Still on the step (not resolved), the error copy is surfaced, and the
      // skip exit still works.
      expect(done, 0);
      expect(
        find.text('We couldn’t save your name. Try again, or skip for now.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('profile-name.skip')));
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('arabic locale renders the ar copy under RTL', (tester) async {
      await tester.pumpWidget(
        _harness(
          onDone: () {},
          repository: _RecordingRepository(),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ماذا نناديك؟'), findsOneWidget);
      expect(find.text('التخطي الآن'), findsOneWidget);
      final context =
          tester.element(find.byKey(const Key('profile-name.title')));
      expect(Directionality.of(context), TextDirection.rtl,
          reason: 'the ar locale must lay the step out RTL');
    });
  });
}
