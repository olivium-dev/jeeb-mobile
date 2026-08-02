// Render tests for the RatingPromptScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// RatingPromptScreen renders the SAME app bar and the SAME two sentences in
// every state — it is a frozen Type-A placeholder with no data axis at all — so
// "did it render" is a weak question here: all six previews would pass a
// render-only check while showing identical content. The suite therefore does
// two extra jobs. The expected strings pin WHICH window each preview simulates
// (the caption the fixture host paints), and the group below measures what the
// screen actually did inside that window. Those measurements are the only
// contract this screen has.
//
// One caveat on the overflow numbers. `flutter test` substitutes the
// `FlutterTest` font, whose glyphs are squares of the font size and therefore
// considerably wider than Inter's, so English wraps more often here than on a
// device and the *threshold* at which the column stops fitting is more
// pessimistic than a phone would show. The claims the suite leans on are the
// font-INDEPENDENT ones: the screen contains no scrollable at all, its 100 pt
// icon does not follow the text scaler, and its app bar takes 56 pt off the
// body before the centred column is measured — so whenever the composition does
// not fit there is nothing that can absorb the shortfall.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/rating_prompt_screen_fixtures.dart';
import 'package:jeeb_mobile/features/deep_link_targets/rating_prompt_screen.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);
const Size _notchedFrame = Size(393, 852);

/// `OmdsEmptyStatePage.iconSize` default — a fixed logical size, not a scaled
/// one.
const double _iconSize = 100;

/// The three strings the screen hardcodes, as string literals rather than ARB
/// lookups.
const String _appBarTitle = 'Rate your Jeeber';
const String _title = 'Rating Prompt coming soon';
const String _subtitle = 'This screen is not yet available.';

void main() {
  setUpAll(loadPreviewArbs);

  // `Compact · 200% text` is deliberately NOT in this map. It overflows by
  // design-defect (see "the smallest phone at 200% clips" below), and
  // `testPreviewsRender` asserts `takeException() is null` for every state it is
  // given. Rather than weaken that assertion for the other five, that preview
  // gets its own pair of tests further down which pump it in BOTH locales, pin
  // its caption the way `expectedText` would, and assert the overflow instead
  // of tolerating it.
  testPreviewsRender(
    'RatingPromptScreen',
    const <String, Widget Function()>{
      'Phone 390 × 844': ratingPromptScreenPhone,
      'Compact 320 × 568': ratingPromptScreenCompact,
      'Phone · 200% text': ratingPromptScreenPhoneLargeText,
      'Notched · 200% text': ratingPromptScreenNotchedLargeText,
      'Deep-link id · never rendered': ratingPromptScreenUnusedDeepLinkId,
    },
    // Every state names its own window. The screen shows the same app bar and
    // the same two sentences in all six, so without this a preview wired to the
    // wrong window — or six previews accidentally sharing one — would pass
    // unnoticed.
    expectedText: const <String, String>{
      'Phone 390 × 844': 'Phone · 390 × 844 · 100% text',
      'Compact 320 × 568': 'Compact · 320 × 568 · 100% text',
      'Phone · 200% text': 'Phone · 390 × 844 · 200% text',
      'Notched · 200% text': 'Notched · 393 × 852 · inset 59/34 · 200% text',
      'Deep-link id · never rendered':
          'Phone · 390 × 844 · deep-link id DLV-2026-08-02-000914 (never shown)',
    },
  );

  group('RatingPromptScreen preview specifics', () {
    test('every window the fixture publishes has a preview above', () {
      // `RatingPromptScreenWindows.all` is what the Screen Catalog enumerates,
      // so a window added there without a matching `@JeebPreview` would
      // silently exist for the designer and not for the engineer. That is
      // exactly the drift the shared fixture file exists to prevent, so it is
      // asserted rather than trusted.
      expect(
        RatingPromptScreenWindows.all
            .map((RatingPromptScreenWindow w) => w.label)
            .toList(),
        <String>[
          'Phone · 390 × 844 · 100% text',
          'Compact · 320 × 568 · 100% text',
          'Phone · 390 × 844 · 200% text',
          'Compact · 320 × 568 · 200% text',
          'Notched · 393 × 852 · inset 59/34 · 200% text',
          'Phone · 390 × 844 · deep-link id DLV-2026-08-02-000914 (never shown)',
        ],
      );
      expect(
        RatingPromptScreenWindows.all
            .map((RatingPromptScreenWindow w) => w.size)
            .toList(),
        <Size>[
          _phoneFrame,
          _compactFrame,
          _phoneFrame,
          _compactFrame,
          _notchedFrame,
          _phoneFrame,
        ],
      );
      // Exactly one window carries a different deep-link id — the state whose
      // whole job is to show that the id changes nothing.
      expect(
        RatingPromptScreenWindows.all
            .where((RatingPromptScreenWindow w) =>
                w.deliveryId != RatingPromptScreenFixtures.deliveryId)
            .map((RatingPromptScreenWindow w) => w.deliveryId)
            .toList(),
        <String>[RatingPromptScreenFixtures.unusedDeliveryId],
      );
    });

    /// Pumps [preview] and returns the rect of the screen inside its simulated
    /// window, draining any layout exception so the caller decides what to do
    /// with it.
    Future<Rect> frameRect(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
    }) async {
      await pumpPreview(tester, preview, locale: locale);
      final Rect rect = tester.getRect(find.byType(RatingPromptScreen));
      tester.takeException();
      return rect;
    }

    /// Every string the SCREEN itself paints — the app bar title and the two
    /// body sentences. Excludes the fixture's caption, which is painted above
    /// the frame by the preview harness.
    ///
    /// Sorted, because tree order here is a `Scaffold` implementation detail:
    /// it builds its body slot before its app bar slot, so the toolbar title
    /// comes LAST. Sorting keeps these assertions about the copy rather than
    /// about Scaffold's child order.
    List<String> screenStrings(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(RatingPromptScreen),
            matching: find.byType(Text),
          ),
        )
        .map((Text t) => t.data ?? '')
        .toList()
      ..sort();

    /// The three hardcoded strings, in the order [screenStrings] returns them.
    const List<String> allCopy = <String>[_appBarTitle, _title, _subtitle];

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      // state would collapse onto the test surface and the rest of this group
      // would be asserting nothing.
      expect(
        (await frameRect(tester, ratingPromptScreenPhone)).size,
        _phoneFrame,
      );
      expect(
        (await frameRect(tester, ratingPromptScreenCompact)).size,
        _compactFrame,
      );
      expect(
        (await frameRect(tester, ratingPromptScreenPhoneLargeText)).size,
        _phoneFrame,
      );
      expect(
        (await frameRect(tester, ratingPromptScreenCompactLargeText)).size,
        _compactFrame,
      );
      expect(
        (await frameRect(tester, ratingPromptScreenNotchedLargeText)).size,
        _notchedFrame,
      );
      expect(
        (await frameRect(tester, ratingPromptScreenUnusedDeepLinkId)).size,
        _phoneFrame,
      );
    });

    testWidgets('the 200% windows really are scaled and the rest are not', (
      WidgetTester tester,
    ) async {
      // `RatingPromptScreenWindow.textScale` is nullable on purpose: a window
      // that pinned 1.0 would overwrite the `matrix: true` 200% card and label
      // a 100% rendering "EN 200% text". This pins both halves of that.
      Future<double> scale(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        final double s = MediaQuery.textScalerOf(
          tester.element(find.byType(RatingPromptScreen)),
        ).scale(10);
        tester.takeException();
        return s;
      }

      expect(await scale(ratingPromptScreenPhone), 10);
      expect(await scale(ratingPromptScreenCompact), 10);
      expect(await scale(ratingPromptScreenPhoneLargeText), 20);
      expect(await scale(ratingPromptScreenCompactLargeText), 20);
      expect(await scale(ratingPromptScreenNotchedLargeText), 20);
      expect(await scale(ratingPromptScreenUnusedDeepLinkId), 10);
    });

    testWidgets('the screen contains no scrollable of any kind', (
      WidgetTester tester,
    ) async {
      // The structural half of the clipping defect, and the half that does not
      // depend on the test font. The OMDS empty-state page centres a bare
      // `Column(mainAxisSize: min)` — no ListView, no SingleChildScrollView.
      // Whatever does not fit is not merely below the fold, it is unreachable.
      //
      // The fixture host's own two SingleChildScrollViews sit ABOVE the screen,
      // which is why this is scoped to descendants of RatingPromptScreen.
      await pumpPreview(tester, ratingPromptScreenPhone);

      expect(
        find.descendant(
          of: find.byType(RatingPromptScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      // The screen brings its own Scaffold (the OMDS empty-state page returns
      // one), so `jeebPreviewHost`'s wrapper Scaffold nests around a second one.
      // Recorded because the canvas shows the doubled surface and it looks like
      // a bug.
      expect(
        find.descendant(
          of: find.byType(RatingPromptScreen),
          matching: find.byType(Scaffold),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the 100 pt icon does not follow the text scaler', (
      WidgetTester tester,
    ) async {
      // The other font-independent half. The empty-state page passes a fixed
      // `iconSize` of 100, so at the accessibility ceiling the text doubles
      // around an illustration that stays exactly as tall — the column can only
      // grow, never rebalance.
      await pumpPreview(tester, ratingPromptScreenPhone);
      final Size atDefault =
          tester.getSize(find.byIcon(Icons.construction_outlined));

      await pumpPreview(tester, ratingPromptScreenPhoneLargeText);
      final Size atCeiling =
          tester.getSize(find.byIcon(Icons.construction_outlined));

      expect(atDefault, const Size(_iconSize, _iconSize));
      expect(
        atCeiling,
        atDefault,
        reason: 'the icon is a fixed 100 pt: it claims the same share of a '
            '568 pt display whether the user reads at 100% or at 200%',
      );
    });

    testWidgets('the toolbar title stops short of the user text size', (
      WidgetTester tester,
    ) async {
      // `AppBar` clamps its own text scaling (`_kMaxTitleTextScaleFactor`), so
      // at the 200% ceiling the body copy doubles while "Rate your Jeeber"
      // grows by about a third. Pinned because the two halves of the surface
      // then scale at different rates, which is what the `Phone · 200% text`
      // card shows and what a reviewer would otherwise read as a rendering
      // glitch.
      await pumpPreview(tester, ratingPromptScreenPhone);
      final double titleAtDefault =
          tester.getSize(find.text(_appBarTitle)).height;

      await pumpPreview(tester, ratingPromptScreenPhoneLargeText);
      final double titleAtCeiling =
          tester.getSize(find.text(_appBarTitle)).height;

      expect(titleAtCeiling / titleAtDefault, closeTo(1.34, 0.02));
      // The same window, two scalers: the toolbar clamps, the body does not.
      expect(
        MediaQuery.textScalerOf(tester.element(find.text(_appBarTitle)))
            .scale(10),
        closeTo(13.4, 0.2),
      );
      expect(
        MediaQuery.textScalerOf(tester.element(find.text(_subtitle))).scale(10),
        20,
      );
    });

    testWidgets('the deep-link deliveryId is never rendered', (
      WidgetTester tester,
    ) async {
      // The finding this screen has and its sibling placeholder does not. The
      // route `/orders/:id/rate` hands the constructor the id of the delivery
      // the customer is being asked to rate; the surface names no delivery, no
      // jeeber and no order reference. Two states, two different ids, one
      // identical set of strings.
      await pumpPreview(tester, ratingPromptScreenPhone);
      final List<String> withHouseId = screenStrings(tester);

      await pumpPreview(tester, ratingPromptScreenUnusedDeepLinkId);
      final List<String> withOtherId = screenStrings(tester);

      expect(withHouseId, allCopy);
      expect(
        withOtherId,
        withHouseId,
        reason: 'the id the deep link carried changes nothing on screen',
      );
      for (final String id in <String>[
        RatingPromptScreenFixtures.deliveryId,
        RatingPromptScreenFixtures.unusedDeliveryId,
      ]) {
        expect(
          find.descendant(
            of: find.byType(RatingPromptScreen),
            matching: find.textContaining(id),
          ),
          findsNothing,
          reason: '$id reaches the widget and stops there',
        );
      }
      // The id IS on the card — in the caption the fixture paints above the
      // frame. That is the preview harness talking, not the screen, and the
      // contrast is the whole point of the state.
      expect(
        find.textContaining(RatingPromptScreenFixtures.unusedDeliveryId),
        findsOneWidget,
      );
    });

    testWidgets('the app bar consumes the status-bar inset', (
      WidgetTester tester,
    ) async {
      // The one structural difference from the sibling `KycStatusScreen`, which
      // passes `appBar: null` and therefore leaves the top inset to nobody. Here
      // the toolbar grows by the inset and paints its title below the notch.
      //
      // The bottom inset is still nobody's job: no bottom bar occupies that slot
      // and `Scaffold` does not SafeArea its body, so the centred column clears
      // the home indicator only because it is centred and short. Asserted rather
      // than assumed — it stops being true the moment this placeholder grows a
      // third line or a CTA.
      await pumpPreview(tester, ratingPromptScreenPhone);
      final double barWithoutInset = tester.getSize(find.byType(AppBar)).height;

      final Rect frame = await frameRect(
        tester,
        ratingPromptScreenNotchedLargeText,
      );
      final Rect bar = tester.getRect(find.byType(AppBar));
      final Rect column = tester.getRect(
        find.descendant(
          of: find.byType(RatingPromptScreen),
          matching: find.byType(Column),
        ),
      );

      expect(barWithoutInset, kToolbarHeight);
      expect(
        bar.height,
        kToolbarHeight + 59,
        reason: 'AppBar is `primary`, so it SafeAreas its own toolbar',
      );
      expect(tester.takeException(), isNull);
      expect(
        column.top,
        greaterThanOrEqualTo(bar.bottom),
        reason: 'the body starts below the toolbar, notch included',
      );
      expect(
        frame.bottom - column.bottom,
        greaterThan(34),
        reason: 'bottom inset (home indicator) is not consumed by anything',
      );
    });

    testWidgets('on a 390 × 844 phone the whole composition fits', (
      WidgetTester tester,
    ) async {
      // The reference reading, and the reason the state below went unnoticed:
      // in the one window everybody reviews, this screen is exactly as simple
      // as it looks.
      final Rect frame = await frameRect(tester, ratingPromptScreenPhone);
      final Rect column = tester.getRect(
        find.descendant(
          of: find.byType(RatingPromptScreen),
          matching: find.byType(Column),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(column.top, greaterThanOrEqualTo(frame.top));
      expect(column.bottom, lessThanOrEqualTo(frame.bottom));
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'the smallest phone at 200% clips, in ${locale.languageCode}',
        (WidgetTester tester) async {
          // The state that breaks, and the reason `Compact · 200% text` is kept
          // out of `testPreviewsRender` above. The centred column asks for more
          // height than the body has — a body the app bar has already taken
          // 56 pt from — and with no scrollable and no icon that can give way,
          // the ends of the composition are cut off and the user has no gesture
          // that would bring them back.
          //
          // Both locales, because the copy is identical in both (it is
          // hardcoded English) and the padding is symmetric, so the defect is
          // locale-independent — asserted rather than assumed, since "it is
          // only an English problem" is the usual first guess.
          await pumpPreview(
            tester,
            ratingPromptScreenCompactLargeText,
            locale: locale,
          );

          // Pins WHICH window this preview simulates, the same job
          // `expectedText` does for the other five states.
          expect(find.text('Compact · 320 × 568 · 200% text'), findsOneWidget);
          expect(
            tester.takeException().toString(),
            contains('overflowed'),
            reason: 'a Column(mainAxisSize: min) centred in what the 56 pt app '
                'bar left of a 568 pt display, with a fixed 100 pt icon above '
                'two wrapping paragraphs, at the 200% accessibility ceiling',
          );
        },
      );
    }

    testWidgets('the copy is hardcoded English, so Arabic renders English', (
      WidgetTester tester,
    ) async {
      // All three strings are literals in `build`, not `AppLocalizations`
      // lookups, so the AR RTL card of the `Phone 390 × 844` matrix shows
      // English inside a right-to-left layout. Localization is explicitly out
      // of scope for the Type-A placeholder gate (UX rule #7), so this is a
      // record of what a reviewer sees rather than a bug report — if it starts
      // failing, someone localized the screen and it can be deleted.
      await pumpPreview(
        tester,
        ratingPromptScreenPhone,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(tester.element(find.byType(RatingPromptScreen))),
        TextDirection.rtl,
      );
      expect(screenStrings(tester), allCopy);
    });

    testWidgets('the Semantics wrapper announces the copy twice', (
      WidgetTester tester,
    ) async {
      // `Semantics(container: true, label: 'Rating Prompt coming soon. This
      // screen is not yet available.')` wraps a subtree that already publishes
      // both sentences as Text, and does not set `explicitChildNodes`, so the
      // wrapper's label and the Texts MERGE into a single node. A screen reader
      // reads the pair, then reads it again.
      // Disposed inline rather than via `addTearDown`: the framework's
      // end-of-test verification runs BEFORE tear-downs and fails on a live
      // handle.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, ratingPromptScreenPhone);

      // One node covers the whole screen — the wrapper's label and the body
      // Texts collapsed into it — so asking for the title's node returns the
      // merged announcement.
      final SemanticsNode node = tester.getSemantics(find.text(_title));
      final String label = node.label;

      expect(
        _occurrences(label, _title),
        2,
        reason: 'merged label was: $label',
      );
      expect(_occurrences(label, _subtitle), 2);

      handle.dispose();
    });
  });
}

int _occurrences(String haystack, String needle) =>
    needle.isEmpty ? 0 : haystack.split(needle).length - 1;
