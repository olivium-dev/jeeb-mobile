// Render tests for the RatingPromptScreen previews.

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
      await pumpPreview(tester, ratingPromptScreenPhone);

      expect(
        find.descendant(
          of: find.byType(RatingPromptScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      // The screen brings its own Scaffold (the OMDS empty-state page returns
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
      expect(
        find.textContaining(RatingPromptScreenFixtures.unusedDeliveryId),
        findsOneWidget,
      );
    });

    testWidgets('the app bar consumes the status-bar inset', (
      WidgetTester tester,
    ) async {
      // The one structural difference from the sibling `KycStatusScreen`, which
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
          await pumpPreview(
            tester,
            ratingPromptScreenCompactLargeText,
            locale: locale,
          );

          // Pins WHICH window this preview simulates, the same job
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
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, ratingPromptScreenPhone);

      // One node covers the whole screen — the wrapper's label and the body
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
