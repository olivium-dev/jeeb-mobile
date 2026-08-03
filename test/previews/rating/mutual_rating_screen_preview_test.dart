// Render tests for the MutualRatingScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';

import '../preview_test_harness.dart';

/// The star input — present on every `_InputView` state, absent on the
/// `submitting` and `error` states, which replace the whole body.
final Finder _stars = find.byKey(const Key('mutualRating.stars'));

/// `rating_submit_cta`.
final Finder _submit = find.byKey(const Key('mutualRating.submit'));

/// The localized `mutualRatingError` copy, EN.
const String _errorCopy = "Couldn't submit rating. Please try again.";

int _starsOn(WidgetTester tester) =>
    tester.widget<OmdsStarRating>(_stars).rating;

bool _submitEnabled(WidgetTester tester) =>
    tester.widget<OmdsPrimaryButton>(_submit).isEnabled;

int _selectedChips(WidgetTester tester) => tester
    .widgetList<OmdsChip>(find.byType(OmdsChip))
    .where((OmdsChip c) => c.isSelected)
    .length;

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Submitting · in flight`, which cannot settle — see
  testPreviewsRender(
    'MutualRatingScreen',
    const <String, Widget Function()>{
      'Fresh · client rates jeeber': mutualRatingScreenFresh,
      'Fresh · jeeber rates client': mutualRatingScreenJeeberSide,
      'Filled · five stars, every tag': mutualRatingScreenFilled,
      'Error · submit rejected': mutualRatingScreenSubmitFailed,
      'Stale · awaitingOther phase': mutualRatingScreenAwaitingOther,
    },
    expectedText: const <String, String>{
      'Fresh · client rates jeeber': MutualRatingScreenCaptions.fresh,
      'Fresh · jeeber rates client': MutualRatingScreenCaptions.jeeberSide,
      'Filled · five stars, every tag': MutualRatingScreenCaptions.filled,
      'Error · submit rejected': MutualRatingScreenCaptions.submitFailed,
      'Stale · awaitingOther phase': MutualRatingScreenCaptions.awaitingOther,
    },
  );

  group('MutualRatingScreen previews · the state behind the caption', () {
    testWidgets('Fresh — zero stars, no tags, submit DISABLED', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, mutualRatingScreenFresh);

      expect(_stars, findsOneWidget);
      expect(_starsOn(tester), 0);
      expect(_selectedChips(tester), 0);
      // The only thing standing between the user and an empty rating.
      expect(_submitEnabled(tester), isFalse);
    });

    testWidgets('Jeeber side is the fresh state for the other audience', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, mutualRatingScreenJeeberSide);

      expect(_starsOn(tester), 0);
      expect(_submitEnabled(tester), isFalse);
      // `isClient: false` is a wire-level flag: the screen shows no ratee
      expect(find.text('Punctual'), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
    });

    testWidgets('Filled — five stars and all five tags selected', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, mutualRatingScreenFilled);

      expect(_starsOn(tester), 5);
      expect(_selectedChips(tester), 5);
      expect(_submitEnabled(tester), isTrue);
    });

    testWidgets('Error — the body is replaced; no star input survives', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, mutualRatingScreenSubmitFailed);

      expect(find.text(_errorCopy), findsOneWidget);
      // `_ErrorView` replaces the WHOLE body: stars, comment, tags and
      expect(_stars, findsNothing);
      expect(_submit, findsNothing);
    });

    testWidgets('Error — retry against a still-failing repository re-errors '
        'rather than throwing', (WidgetTester tester) async {
      await pumpPreview(tester, mutualRatingScreenSubmitFailed);

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(_errorCopy), findsOneWidget);
    });

    testWidgets('Stale awaitingOther — an already-submitted rating, shown as a '
        're-submittable form', (WidgetTester tester) async {
      await pumpPreview(tester, mutualRatingScreenAwaitingOther);

      // The blind-reveal branch falls through to `_InputView`.
      expect(_stars, findsOneWidget);
      expect(_starsOn(tester), 5);
      expect(_selectedChips(tester), 1);
      expect(_submitEnabled(tester), isTrue);
      // None of the ARB copy written for this phase reaches the screen.
      expect(find.text('Rating submitted!'), findsNothing);
    });
  });

  // `previewCanvas` pumps onto the 800 x 600 test surface, not the `size:` a
  group('MutualRatingScreen previews · measured at 390 x 844', () {
    Future<void> pumpPhone(
      WidgetTester tester,
      Widget Function() preview, {
      required Locale locale,
      required double textScale,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 @3x
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(previewCanvas(preview, locale));
      await tester.pumpAndSettle();
    }

    testWidgets('the quick-tag Wrap never wraps: five full-width bars, no gap',
        (WidgetTester tester) async {
      await pumpPhone(
        tester,
        mutualRatingScreenFresh,
        locale: const Locale('en'),
        textScale: 1,
      );

      final double wrapWidth = tester.getSize(find.byType(Wrap)).width;
      final Finder chips = find.byType(OmdsChip);
      expect(chips, findsNWidgets(5));

      final tops = <double>[];
      for (int i = 0; i < 5; i++) {
        expect(
          tester.getSize(chips.at(i)).width,
          wrapWidth,
          reason: 'chip $i takes the whole content width, so nothing can share '
              'a run with it — `Wrap(spacing:)` buys nothing here',
        );
        tops.add(tester.getTopLeft(chips.at(i)).dy);
      }

      // One chip per run, at 100% text on a stock phone.
      expect(tops.toSet(), hasLength(5));
      // And no `runSpacing`, so the pitch equals the chip height exactly: the
      expect(tops[1] - tops[0], tester.getSize(chips.first).height);
    });

    testWidgets('en at 200% text: the widest chip label still fits', (
      WidgetTester tester,
    ) async {
      await pumpPhone(
        tester,
        mutualRatingScreenFresh,
        locale: const Locale('en'),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('ar at 200% text: the punctuality chip overflows its own chip',
        (WidgetTester tester) async {
      await pumpPhone(
        tester,
        mutualRatingScreenFresh,
        locale: const Locale('ar'),
        textScale: 2,
      );

      // `دقيق بالمواعيد` measures 336 pt inside a 350 pt chip; `OmdsChip`
      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (FlutterError e) => e.message,
          'message',
          contains('overflowed by 12 pixels on the right'),
        ),
      );
    });
  });

  // The in-flight sub-state is an indeterminate `CircularProgressIndicator`
  group('MutualRatingScreen previews · Submitting · in flight', () {
    Future<void> pumpSubmitting(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(mutualRatingScreenSubmitting, locale),
      );
      await tester.pump(); // resolve localizations + the nested Router
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Submitting · in flight · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSubmitting(tester, locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    }

    testWidgets('renders its own state', (WidgetTester tester) async {
      await pumpSubmitting(tester);

      expect(find.text(MutualRatingScreenCaptions.submitting), findsOneWidget);
      // A bare spinner: the body is replaced, and nothing on screen says what
      expect(_stars, findsNothing);
      expect(_submit, findsNothing);
      expect(find.text(_errorCopy), findsNothing);
    });
  });
}
