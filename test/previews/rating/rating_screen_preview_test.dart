// Render tests for the RatingScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Pinning a DISTINCT string per state matters more for a screen than for a
// widget: all seven previews are the same screen behind the same app bar, and
// five of them differ only in a private `State` field that
// `_RatingScreenDriver` reaches by walking the subtree. A suite that asserted
// "the app bar rendered" would pass with the driver silently doing nothing —
// which is the one failure mode this file exists to catch.
//
// One preview is not in the shared suite and has a group of its own:
// `Submitting · CTA spinner` cannot settle. The groups after it assert the
// defects the previews were written for, because a defect nobody asserts is a
// defect that gets "fixed" by deleting the preview.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/rating/presentation/rating_screen.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_star_input.dart';

import '../preview_test_harness.dart';

/// The size every preview in this file declares (`_ratingScreenPhoneBox`). The
/// harness pumps at the `flutter_test` default of 800x600, which is 244 pt
/// SHORTER than the phone the screen is drawn for — at that height the star row
/// is laid out below the scroll viewport and cannot be tapped at all.
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
      // the two states the Screen Catalog signs off — the title, subtitle,
      // hint and CTA are shared by every state in this file.
      'Client rates the jeeber': 'Rate Rami Chidiac',
      'Jeeber rates the client': 'Rate Layla Haddad',
      // The defect, pinned verbatim: the localized template with an empty
      // interpolation, trailing space and all. If this ever stops matching,
      // either the placeholder gained a fallback (good — delete this preview)
      // or the copy changed under it.
      'Deep link · no ratee name': 'Rate ',
      'Long ratee name': 'Rate Abd Al-Rahman Al-Muhandis Al-Trabulsi',
      'Four stars picked': 'Rate Karim Nassar',
      // NOT a string from this screen: a failed submit leaves it entirely.
      'Submit failed · silently routed home': 'Home shell (preview stand-in)',
    },
  );

  // The in-flight sub-state is an indeterminate `CircularProgressIndicator`
  // (`OmdsButtonLoading` inside `OmdsLoadingButton`) held open by a write that
  // never lands. `pumpAndSettle` — which `pumpPreview` calls — never returns
  // while one is on screen, so this preview gets the same three assertions the
  // shared suite makes (builds in EN, builds in AR, renders its OWN state)
  // driven by fixed pumps instead.
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
    // and nothing else. The rating on screen can still be changed after the
    // value has already gone to the gateway.
    testWidgets('nothing behind the spinner is disabled', (
      WidgetTester tester,
    ) async {
      // Pumped at the size the preview DECLARES — see [_canvasBox]. At the
      // 800x600 default the star row is off the bottom of its own viewport and
      // the tap below would silently miss, making this assertion vacuous
      // instead of false.
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
    // default, so the CTA is fully inked and hit-testable from the first frame,
    // and `_onSubmit` returns immediately while `_stars == 0`. With
    // `PopScope(canPop: false)` and no close X, picking a star is the only exit
    // from this screen — and nothing on it says so.
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
    // (`app_router.dart`), and nothing in `lib/` navigates here, so this is
    // what a deep link without `?name=` renders.
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
      // about the CTA marks the moment its tap stops being a no-op.
      expect(find.text('Submit feedback'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // A rejected submit is swallowed by `_onSubmit` and routed home exactly as
    // a success would be. This screen has no error surface at all, and the user
    // is never told the rating and comment were dropped.
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
