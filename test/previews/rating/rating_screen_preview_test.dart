// Render tests for the RatingScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/rating/presentation/rating_screen.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_star_input.dart';

import '../preview_test_harness.dart';

/// The size every preview in this file declares (`_ratingScreenPhoneBox`). The
/// harness pumps at the `flutter_test` default of 800x600, which is 244 pt
const Size _canvasBox = Size(390, 844);

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'RatingScreen',
    const <String, Widget Function()>{
      'Client rates the jeeber': ratingScreenClientRatesJeeber,
      'Jeeber rates the client': ratingScreenJeeberRatesClient,
      'Deep link · no ratee name': ratingScreenNoRateeName,
      'Long ratee name': ratingScreenLongName,
      'Four stars picked': ratingScreenStarsSelected,
      'Submit failed · silently routed home': ratingScreenSubmitFailed,
    },
    expectedText: const <String, String>{
      // The interpolated ratee, which is the only string that differs between
      'Client rates the jeeber': 'Rate Rami Chidiac',
      'Jeeber rates the client': 'Rate Layla Haddad',
      // The defect, pinned verbatim: the localized template with an empty
      'Deep link · no ratee name': 'Rate ',
      'Long ratee name': 'Rate Abd Al-Rahman Al-Muhandis Al-Trabulsi',
      'Four stars picked': 'Rate Karim Nassar',
      // NOT a string from this screen: a failed submit leaves it entirely.
      'Submit failed · silently routed home': 'Home shell (preview stand-in)',
    },
  );

  // The in-flight sub-state is an indeterminate `CircularProgressIndicator`
  group('RatingScreen previews · Submitting · CTA spinner', () {
    Future<void> pumpSubmitting(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(ratingScreenSubmitting, locale));
      await tester.pump(); // resolve localizations + the nested Router
      await tester.pump(); // the driver's post-frame pick + submit
      // `OmdsLoadingButton` cross-fades its label out over 200 ms.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Submitting · CTA spinner · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSubmitting(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Submitting · CTA spinner renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpSubmitting(tester);

      // Its own ratee...
      expect(find.text('Rate Nour Ghanem'), findsOneWidget);
      // ...the spinner in place of the label...
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit feedback'), findsNothing);
      // ...and it has NOT left the screen, unlike the failed-submit state.
      expect(find.text('Home shell (preview stand-in)'), findsNothing);
    });

    // The defect this preview exists for: `_submitting` gates a second submit
    testWidgets('nothing behind the spinner is disabled', (
      WidgetTester tester,
    ) async {
      // Pumped at the size the preview DECLARES — see [_canvasBox]. At the
      await tester.binding.setSurfaceSize(_canvasBox);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpSubmitting(tester);

      // The star row is still mounted and still wired to a live callback.
      final FeedbackStarInput stars = tester.widget<FeedbackStarInput>(
        find.byType(FeedbackStarInput),
      );
      expect(stars.stars, 4);
      // Four filled, one empty — and the empty one is still tappable.
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pump();
      expect(
        tester.widget<FeedbackStarInput>(find.byType(FeedbackStarInput)).stars,
        5,
        reason: 'the star row accepted a change while the submit was in flight',
      );

      // The comment field is still enabled too.
      expect(tester.widget<OmdsTextField>(find.byType(OmdsTextField)).enabled,
          isTrue);
    });
  });

  group('RatingScreen preview specifics', () {
    // The dead end. `OmdsLoadingButton` is built with `isEnabled` at its `true`
    testWidgets('the CTA is live at zero stars and silently does nothing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, ratingScreenClientRatesJeeber);

      expect(find.byIcon(Icons.star), findsNothing);
      final OmdsLoadingButton cta = tester.widget<OmdsLoadingButton>(
        find.byType(OmdsLoadingButton),
      );
      expect(cta.isEnabled, isTrue, reason: 'the CTA paints as tappable');
      expect(cta.isLoading, isFalse);

      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();

      // Nothing happened: no spinner, no error, no navigation, no hint.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Home shell (preview stand-in)'), findsNothing);
      expect(find.text('Rate Rami Chidiac'), findsOneWidget);
    });

    // The shipped route builds `rateeName` from an OPTIONAL query parameter
    testWidgets('the deep-link default asks for a rating of nobody', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, ratingScreenNoRateeName);

      expect(find.text('Rate '), findsOneWidget);
      // `FeedbackAvatar` falls back to '?' when the name is blank.
      expect(find.text('?'), findsOneWidget);
    });

    // Proves the driver reached `_stars`, which four previews depend on.
    testWidgets('the picked star count really is on screen', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, ratingScreenStarsSelected);

      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      // ...and the footer is byte-identical to the zero-star state: nothing
      expect(find.text('Submit feedback'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // A rejected submit is swallowed by `_onSubmit` and routed home exactly as
    testWidgets('a rejected submit lands where a successful one would', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, ratingScreenSubmitFailed);

      expect(find.text('Home shell (preview stand-in)'), findsOneWidget);
      expect(find.text('Rate Hadi Mansour'), findsNothing);
      expect(find.byType(RatingScreen), findsNothing);
    });
  });
}
