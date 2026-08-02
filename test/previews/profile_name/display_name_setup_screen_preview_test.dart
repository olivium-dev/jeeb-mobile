// Render tests for the DisplayNameSetupScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/display_name_setup_screen_fixtures.dart';
import 'package:jeeb_mobile/features/profile_name/application/display_name_cubit.dart';
import 'package:jeeb_mobile/features/profile_name/presentation/display_name_setup_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

final Finder _field = find.byKey(const Key('profile-name.field'));
final Finder _submit = find.byKey(const Key('profile-name.submit'));
final Finder _skip = find.byKey(const Key('profile-name.skip'));
final Finder _title = find.byKey(const Key('profile-name.title'));

/// `profileNameStepCta` / `profileNameStepSkip` / `profileNameStepError`, EN.
const String _ctaEn = 'Continue';
const String _skipEn = 'Skip for now';
const String _errorEn = 'We couldn’t save your name. Try again, or skip for now.';

/// Big enough that a pinned 390x844 card is never clipped by the tester's
/// default 800x600 desktop surface.
const Size _kPhoneSurface = Size(430, 900);

/// The compact ceiling frame plus room for the dev caption above it.
const Size _kCompactSurface = Size(360, 620);

/// The height the compact ceiling card pins in the tree.
const double _kCompactFrameHeight = 568;

/// Every preview in this file, so the invariants below can be asserted across
/// all of them instead of once per state.
const Map<String, Widget Function()> _kPreviews = <String, Widget Function()>{
  'Idle · nothing typed': displayNameSetupScreenIdle,
  'Saving · PUT in flight': displayNameSetupScreenSaving,
  'Error · PUT rejected': displayNameSetupScreenSaveFailed,
  'Saved · no repository, nothing sent':
      displayNameSetupScreenSavedWithoutRepository,
  'Compact 320x568 · layout ceiling': displayNameSetupScreenCompactCeiling,
};

/// [previewCanvas] with the real font faces installed on the theme, and an
/// optional text scaler.
Widget _displayNameSetupScreenCanvas(
  Widget Function() preview,
  Locale locale, {
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: jeebPreviewHost(preview()),
  );
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  /// Pumps [preview] on a surface large enough to hold its pinned device box.
  /// The tree is cleared first: two of these previews are the same widget type
  Future<void> pumpOnDevice(
    WidgetTester tester,
    Widget Function() preview, {
    Size surface = _kPhoneSurface,
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpPreview(tester, preview, locale: locale);
  }

  bool fieldEnabled(WidgetTester tester) =>
      tester.widget<OmdsTextField>(_field).enabled;

  OmdsLoadingButton submitButton(WidgetTester tester) =>
      tester.widget<OmdsLoadingButton>(_submit);

  OmdsPrimaryButton skipButton(WidgetTester tester) =>
      tester.widget<OmdsPrimaryButton>(_skip);

  /// The device box the preview pins in the TREE — `size:` boxes the canvas
  /// only, and a render test gets the tester's own surface.
  Rect deviceFrame(WidgetTester tester) =>
      tester.getRect(find.byType(DisplayNameSetupScreen));

  testPreviewsRender(
    'DisplayNameSetupScreen',
    _kPreviews,
    // The dev caption is the only string that separates `idle`, `saved` and the
    expectedText: const <String, String>{
      'Idle · nothing typed': DisplayNameSetupScreenCaptions.idle,
      'Saving · PUT in flight': DisplayNameSetupScreenCaptions.saving,
      'Error · PUT rejected': DisplayNameSetupScreenCaptions.failure,
      'Saved · no repository, nothing sent':
          DisplayNameSetupScreenCaptions.savedWithoutRepository,
      'Compact 320x568 · layout ceiling':
          DisplayNameSetupScreenCaptions.compactCeiling,
    },
  );

  group('DisplayNameSetupScreen previews · what is live in each state', () {
    testWidgets('every state renders the step itself, in both locales', (
      WidgetTester tester,
    ) async {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        for (final MapEntry<String, Widget Function()> entry
            in _kPreviews.entries) {
          await pumpOnDevice(tester, entry.value, locale: locale);
          expect(_title, findsOneWidget, reason: entry.key);
          expect(_field, findsOneWidget, reason: entry.key);
          expect(_submit, findsOneWidget, reason: entry.key);
          expect(_skip, findsOneWidget, reason: entry.key);
        }
      }
    });

    testWidgets('Idle · the CTA is rendered but DEAD, and Skip is the only '
        'live control', (WidgetTester tester) async {
      // `_SubmitButton` gates on `controller.text`, and the controller is
      await pumpOnDevice(tester, displayNameSetupScreenIdle);

      expect(fieldEnabled(tester), isTrue);
      expect(submitButton(tester).isEnabled, isFalse);
      expect(submitButton(tester).isLoading, isFalse);
      expect(skipButton(tester).isEnabled, isTrue);
      expect(find.text(_ctaEn), findsOneWidget);
      expect(find.text(_skipEn), findsOneWidget);
    });

    testWidgets('Saving · the field, the CTA and SKIP are all disabled at once',
        (WidgetTester tester) async {
      // FINDING, pinned so a fix has to come through here: `_NameStepBody`
      await pumpOnDevice(tester, displayNameSetupScreenSaving);

      expect(fieldEnabled(tester), isFalse);
      expect(submitButton(tester).isLoading, isTrue);
      expect(submitButton(tester).isEnabled, isFalse);
      expect(skipButton(tester).isEnabled, isFalse);
      // The label is swapped out for the spinner, so the CTA has no text.
      expect(find.text(_ctaEn), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Error · the form comes straight back — fail-soft', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(tester, displayNameSetupScreenSaveFailed);

      expect(find.text(_errorEn), findsOneWidget);
      // The host nests a second Scaffold around the screen's own — but the root
      expect(find.byType(Scaffold), findsNWidgets(2));
      // Nothing is left disabled by the failure: the user can retype or skip.
      expect(fieldEnabled(tester), isTrue);
      expect(skipButton(tester).isEnabled, isTrue);
      expect(submitButton(tester).isLoading, isFalse);
      expect(find.text(_ctaEn), findsOneWidget);
    });

    testWidgets('Error · the ONLY difference from Idle is a transient snackbar',
        (WidgetTester tester) async {
      // FINDING, characterized: `DisplayNameStatus.failure` changes no pixel of
      await pumpOnDevice(tester, displayNameSetupScreenIdle);
      final bool idleField = fieldEnabled(tester);
      final bool idleSkip = skipButton(tester).isEnabled;
      final bool idleSubmit = submitButton(tester).isEnabled;

      await pumpOnDevice(tester, displayNameSetupScreenSaveFailed);
      expect(fieldEnabled(tester), idleField);
      expect(skipButton(tester).isEnabled, idleSkip);
      expect(submitButton(tester).isEnabled, idleSubmit);
      // Outside the SnackBar, the two states paint the same widget tree.
      expect(
        find.descendant(of: find.byType(SnackBar), matching: find.text(_errorEn)),
        findsOneWidget,
      );
    });

    testWidgets('Saved · renders exactly the Idle form, with no confirmation', (
      WidgetTester tester,
    ) async {
      // FINDING, characterized: `DisplayNameStatus.saved` leaves `isSaving`
      await pumpOnDevice(tester, displayNameSetupScreenSavedWithoutRepository);

      expect(fieldEnabled(tester), isTrue);
      expect(submitButton(tester).isEnabled, isFalse);
      expect(submitButton(tester).isLoading, isFalse);
      expect(skipButton(tester).isEnabled, isTrue);
      expect(find.text(_ctaEn), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('DisplayNameSetupScreen previews · the fixtures', () {
    test('savedWithoutRepository reaches `saved` with NO transport', () {
      // FINDING, pinned on the fixture because it is a production branch, not a
      final DisplayNameCubit cubit =
          DisplayNameSetupScreenPreviewFixtures.savedWithoutRepository();
      addTearDown(cubit.close);

      expect(cubit.state.status, DisplayNameStatus.saved);
    });

    test('`saving()` is already on `saving` the moment it is handed over', () {
      // `submit` emits `saving` before its first `await`, which is what lets a
      final DisplayNameCubit saving =
          DisplayNameSetupScreenPreviewFixtures.saving();
      addTearDown(saving.close);

      expect(saving.state.status, DisplayNameStatus.saving);
    });

    test('`rejecting()` is INERT until something submits on it', () async {
      // FINDING, pinned: the failure state cannot be seeded. `_showSaveError`
      final DisplayNameCubit cubit =
          DisplayNameSetupScreenPreviewFixtures.rejecting();
      addTearDown(cubit.close);

      expect(cubit.state.status, DisplayNameStatus.idle);

      await cubit.submit(DisplayNameSetupScreenPreviewFixtures.submittedName);
      expect(cubit.state.status, DisplayNameStatus.failure);
    });
  });

  group('DisplayNameSetupScreen previews · the 320x568 ceiling', () {
    /// Pumps the ceiling card with the REAL faces and a text scaler.
    Future<void> pumpCeiling(
      WidgetTester tester, {
      double textScale = 1.0,
      Locale locale = const Locale('en'),
    }) async {
      await tester.binding.setSurfaceSize(_kCompactSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _displayNameSetupScreenCanvas(
          displayNameSetupScreenCompactCeiling,
          locale,
          textScale: textScale,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('nothing overflows at 100% or at 200% text, in either locale', (
      WidgetTester tester,
    ) async {
      // The body is a `SingleChildScrollView`, so growth is absorbed by
      for (final double scale in const <double>[1.0, 2.0]) {
        for (final Locale locale in const <Locale>[
          Locale('en'),
          Locale('ar'),
        ]) {
          await pumpCeiling(tester, textScale: scale, locale: locale);
          expect(
            tester.takeException(),
            isNull,
            reason: '320x568 · ${scale}x · ${locale.languageCode}',
          );
          expect(_title, findsOneWidget);
        }
      }
    });

    testWidgets('at 100% the whole step fits above the fold on 320x568', (
      WidgetTester tester,
    ) async {
      await pumpCeiling(tester);

      final Rect frame = deviceFrame(tester);
      expect(frame.height, _kCompactFrameHeight);
      expect(frame.width, 320);
      expect(tester.getRect(_skip).bottom, lessThan(frame.bottom));
    });

    testWidgets('at 200% Skip goes BELOW the fold and is reachable only by '
        'scrolling', (WidgetTester tester) async {
      // Not a defect — the body scrolls — but it is the thing to look at on
      await pumpCeiling(tester, textScale: 2.0);

      final double fold = deviceFrame(tester).bottom;
      expect(tester.getRect(_skip).top, greaterThan(fold));

      expect(find.byType(Scrollable), findsWidgets);
      await tester.ensureVisible(_skip);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_skip).top, lessThan(fold));
    });
  });
}
