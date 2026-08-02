// Render tests for the JeeberRequestDetailScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The suite does two jobs. `testPreviewsRender` pins that each preview renders
// ITS OWN state — by the payload it carries where the payload is what varies,
// and by the caption the fixture host paints where the WINDOW is what varies
// (three states share the G1 request on purpose, so that what changes between
// those cards is only the geometry). The group below then measures what the
// screen actually did inside that window, which is where this screen's real
// contract lives: an `Expanded` scrolling summary over a fixed-height action
// bar, and two CTAs that do not use the same navigation idiom.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_request_detail_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);

/// `OmdsPrimaryButton` pins `height: Sizes.fourXLarge`, and the action bar is
/// `EdgeInsets.all(Spacing.xLarge)` around two of them with `Spacing.small`
/// between: 24 + 48 + 12 + 48 + 24.
const double _buttonHeight = 48;
const double _actionBarPadding = 24;
const double _actionBarHeight = 156;

/// The longest payload's description, as the card must render it: complete,
/// with no truncation (G1).
final String _longestDescription =
    JeeberRequestDetailScreenRequests.longest.description!;

Finder get _summary => find.byKey(const Key('jeeber-request-detail-summary'));

/// The summary's own viewport — the screen's only scrollable.
Finder get _scrollable => find.descendant(
      of: find.byType(JeeberRequestDetailScreen),
      matching: find.byType(Scrollable),
    );

double _maxScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(_scrollable).position.maxScrollExtent;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberRequestDetailScreen',
    const <String, Widget Function()>{
      'Phone · description present (G1)': jeeberRequestDetailScreenFullRequest,
      'Phone · no description (legacy payload)':
          jeeberRequestDetailScreenNoDescription,
      'Phone · longest payload': jeeberRequestDetailScreenLongest,
      'Phone · pickup label empty (feed degrade)':
          jeeberRequestDetailScreenUnlabelledPickup,
      'Compact 320 × 568': jeeberRequestDetailScreenCompact,
      'Phone · EN 200% · longest payload': jeeberRequestDetailScreenLargeText,
      'Compact 320 × 568 · EN 200%':
          jeeberRequestDetailScreenCompactLargeText,
    },
    expectedText: <String, String>{
      // Payload states are pinned by their own content.
      'Phone · description present (G1)':
          '1 kilo potato, water gallon, coffee blend',
      'Phone · no description (legacy payload)': 'Achrafieh, Beirut',
      'Phone · longest payload': _longestDescription,
      // The degraded payload has no description and no pickup label, so the
      // reference is the only thing on the card that identifies it.
      'Phone · pickup label empty (feed degrade)': '#77C145',
      // Window states share a payload with the reference reading by design, so
      // they are pinned by the caption the fixture host paints instead.
      'Compact 320 × 568':
          'Compact · 320 × 568 · no insets · description present (G1)',
      'Phone · EN 200% · longest payload':
          'Phone · 390 × 844 · 200% text · longest payload',
      'Compact 320 × 568 · EN 200%':
          'Compact · 320 × 568 · 200% text · description present (G1)',
    },
  );

  group('JeeberRequestDetailScreen preview specifics', () {
    setUp(jeeberRequestDetailScreenResetDeclines);

    Future<Rect> frameRect(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
    }) async {
      await pumpPreview(tester, preview, locale: locale);
      return tester.getRect(find.byType(JeeberRequestDetailScreen));
    }

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      // state would collapse onto the test surface and the rest of this group
      // would be asserting nothing.
      expect(
        (await frameRect(tester, jeeberRequestDetailScreenFullRequest)).size,
        _phoneFrame,
      );
      expect(
        (await frameRect(tester, jeeberRequestDetailScreenLongest)).size,
        _phoneFrame,
      );
      expect(
        (await frameRect(tester, jeeberRequestDetailScreenCompact)).size,
        _compactFrame,
      );
      expect(
        (await frameRect(tester, jeeberRequestDetailScreenLargeText)).size,
        _phoneFrame,
      );
      expect(
        (await frameRect(tester, jeeberRequestDetailScreenCompactLargeText))
            .size,
        _compactFrame,
      );
    });

    testWidgets('only the 200% windows are scaled', (
      WidgetTester tester,
    ) async {
      // `JeeberRequestDetailScreenWindow.textScale` is nullable on purpose: a
      // window that pinned 1.0 would overwrite the `matrix: true` 200% card on
      // the two matrixed states and label a 100% rendering "EN 200% text".
      Future<double> scale(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        return MediaQuery.textScalerOf(
          tester.element(find.byType(JeeberRequestDetailScreen)),
        ).scale(10);
      }

      expect(await scale(jeeberRequestDetailScreenFullRequest), 10);
      expect(await scale(jeeberRequestDetailScreenCompact), 10);
      expect(await scale(jeeberRequestDetailScreenLargeText), 20);
      expect(await scale(jeeberRequestDetailScreenCompactLargeText), 20);
    });

    testWidgets('the description row is trim-guarded; the pickup row is not', (
      WidgetTester tester,
    ) async {
      // The defect this state exists for. `description` disappears entirely
      // when blank, so the card degrades cleanly — but `shortLabel` is rendered
      // unguarded, and an empty one is a documented feed outcome
      // (`DioRequestFeedRepository._parseRequest` degrades a `pickup`-less item
      // into `RequestLocation(label: '')` rather than dropping it). The result
      // is a labelled row with a blank value, which reads as a rendering fault
      // rather than as missing data.
      await pumpPreview(tester, jeeberRequestDetailScreenUnlabelledPickup);

      // The description half of the same card: gone, not blank.
      expect(find.text('What the client says'), findsNothing);

      final List<String?> summaryTexts = tester
          .widgetList<Text>(
            find.descendant(of: _summary, matching: find.byType(Text)),
          )
          .map((Text t) => t.data)
          .toList();

      expect(summaryTexts, contains('Pickup'));
      expect(
        summaryTexts,
        contains(''),
        reason: 'the pickup row renders an empty value instead of hiding '
            'itself or substituting a placeholder',
      );
      expect(summaryTexts, contains('#77C145'));
    });

    testWidgets('a UUID is shortened but a `req-` id is passed through', (
      WidgetTester tester,
    ) async {
      // Two jeebers on two requests can therefore see two different KINDS of
      // reference — `friendlyReference` treats `req-101` as already human.
      await pumpPreview(tester, jeeberRequestDetailScreenLongest);
      expect(find.text('#775EAE'), findsOneWidget);
      expect(
        find.text(JeeberRequestDetailScreenRequests.longest.id),
        findsNothing,
      );

      await pumpPreview(tester, jeeberRequestDetailScreenFullRequest);
      expect(find.text('req-101'), findsOneWidget);
    });

    testWidgets('the longest description renders in full and scrolls', (
      WidgetTester tester,
    ) async {
      // G1: the jeeber must read the ENTIRE request before offering, so the
      // description Text carries no `maxLines`. What keeps that from
      // overflowing is the summary's own viewport.
      await pumpPreview(tester, jeeberRequestDetailScreenLongest);

      final Finder description = find.text(_longestDescription);
      expect(tester.widget<Text>(description).maxLines, isNull);
      expect(
        find.descendant(
          of: find.byType(JeeberRequestDetailScreen),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the action bar is a fixed 156 dp at every text scale', (
      WidgetTester tester,
    ) async {
      // This is what saves the layout at 200% — and the same fact is why the
      // touch targets and label boxes do not grow for a user who asked for
      // bigger text.
      Future<double> barHeight(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        final Finder buttons = find.byType(OmdsPrimaryButton);
        expect(buttons, findsNWidgets(2));
        expect(tester.getSize(buttons.first).height, _buttonHeight);
        expect(tester.getSize(buttons.last).height, _buttonHeight);
        // The bar is its two buttons plus `EdgeInsets.all(Spacing.xLarge)` —
        // measured from the buttons so the device's own insets cannot inflate
        // it.
        return tester.getRect(buttons.last).bottom -
            tester.getRect(buttons.first).top +
            2 * _actionBarPadding;
      }

      expect(await barHeight(jeeberRequestDetailScreenFullRequest),
          _actionBarHeight);
      expect(await barHeight(jeeberRequestDetailScreenLargeText),
          _actionBarHeight);
      expect(await barHeight(jeeberRequestDetailScreenCompactLargeText),
          _actionBarHeight);
    });

    testWidgets('the bar sits above the home indicator, not under it', (
      WidgetTester tester,
    ) async {
      // The screen wraps its body in a `SafeArea`, so on the reference phone
      // the fixed bar claims 156 + 34 = 190 dp of the 844 — worth knowing
      // before reading the two 200% states, where that 190 dp is the budget the
      // summary does NOT get.
      final Rect frame = await frameRect(
        tester,
        jeeberRequestDetailScreenFullRequest,
      );

      expect(
        frame.bottom - tester.getRect(find.byType(OmdsPrimaryButton).last).bottom,
        _actionBarPadding + 34,
      );
    });

    testWidgets('the fixed chrome takes a third of the display before any '
        'content is measured', (WidgetTester tester) async {
      // The app bar and the action bar are both fixed, so what the summary gets
      // is a constant per device — 551 dp of 844 on the phone (103 dp app bar +
      // 156 dp bar + the 34 dp home indicator its SafeArea clears), 356 dp of
      // 568 on the floor (56 + 156, no insets). Every length judgement in the
      // previews is relative to these two numbers.
      Rect frame = await frameRect(tester, jeeberRequestDetailScreenFullRequest);
      expect(tester.getRect(find.byType(AppBar)).height, 103);
      expect(tester.getRect(_scrollable).height, 551);
      expect(frame.height, 844);

      frame = await frameRect(tester, jeeberRequestDetailScreenCompact);
      expect(tester.getRect(find.byType(AppBar)).height, 56);
      expect(tester.getRect(_scrollable).height, 356);
      expect(frame.height, 568);
    });

    testWidgets('the ordinary request fits the phone and does NOT fit the '
        '320 dp floor', (WidgetTester tester) async {
      // Same payload, two devices. On the phone the three-row card has 285 dp
      // to spare; on the floor it is 394 dp of card in a 356 dp viewport, so
      // the request REFERENCE — the last row — starts below the fold at default
      // text, with nothing on the screen to say so.
      //
      // (Measured under `flutter_test`, which draws every glyph as a square of
      // the font size, so the same rows wrap onto fewer lines in Inter. Treat
      // the dp counts as an upper bound; the structural point — a fixed 156 dp
      // bar against a 568 dp display — is font-independent.)
      await pumpPreview(tester, jeeberRequestDetailScreenFullRequest);
      expect(_maxScroll(tester), 0);

      await pumpPreview(tester, jeeberRequestDetailScreenCompact);
      expect(_maxScroll(tester), greaterThan(0));
      expect(
        tester.getRect(find.text('req-101')).bottom,
        greaterThan(tester.getRect(_scrollable).bottom),
        reason: 'the reference row is the half that goes below the fold',
      );
    });

    testWidgets('at 200% the client text alone is several screenfuls', (
      WidgetTester tester,
    ) async {
      // The thing the jeeber is being asked to price is the description, and at
      // the accessibility ceiling it measures 2208 dp against a 551 dp viewport
      // — four screenfuls — while the CTAs that act on it stay at 48 dp.
      await pumpPreview(tester, jeeberRequestDetailScreenLargeText);

      final double viewport = tester.getRect(_scrollable).height;
      expect(
        tester.getRect(find.text(_longestDescription)).height,
        greaterThan(3 * viewport),
      );
      expect(tester.getSize(find.byType(OmdsPrimaryButton).first).height,
          _buttonHeight);
    });

    testWidgets('at both ceilings the summary gives way and nothing is clipped',
        (WidgetTester tester) async {
      // The `Expanded` summary absorbs everything the fixed bar does not take,
      // so the 200% states scroll rather than overflow. If this ever starts
      // throwing, the bar has outgrown the smallest body the app supports.
      for (final Widget Function() preview in <Widget Function()>[
        jeeberRequestDetailScreenLargeText,
        jeeberRequestDetailScreenCompactLargeText,
      ]) {
        final Rect frame = await frameRect(tester, preview);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.byType(OmdsPrimaryButton).last).bottom,
          lessThanOrEqualTo(frame.bottom),
          reason: 'both CTAs must stay on the display at the accessibility '
              'ceiling',
        );
      }
    });

    testWidgets('Decline fires on the first tap, with nothing in between', (
      WidgetTester tester,
    ) async {
      // A button wired to `() {}` looks exactly like one wired to nothing, so
      // the previews wire the real callback to a recorder. What that shows is
      // the affordance itself: one tap on a destructive action, no confirmation
      // sheet, no undo, and the id goes straight out to the route.
      await pumpPreview(tester, jeeberRequestDetailScreenNoDescription);

      final Finder decline = find.text('Decline request');
      // The 390 × 844 frame is taller than the 800 × 600 test surface, so the
      // target has to be scrolled into the hit-testable area first.
      await tester.ensureVisible(decline);
      await tester.pumpAndSettle();
      await tester.tap(decline);
      await tester.pumpAndSettle();

      expect(jeeberRequestDetailScreenDeclines, <String>['req-102']);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the offer CTA is not a declared seam — it needs a GoRouter', (
      WidgetTester tester,
    ) async {
      // The asymmetry worth reviewing: `onDeclined` is an injected callback,
      // but the PRIMARY action hardcodes
      // `context.pushNamed('jeeber-offer-submission')`, which the screen's own
      // API never mentions. Nothing can host this screen — preview canvas,
      // widget test, or any future embedding — without also mounting a
      // GoRouter that owns that route name.
      await pumpPreview(tester, jeeberRequestDetailScreenFullRequest);

      final Finder offer = find.text('Send your offer');
      await tester.ensureVisible(offer);
      await tester.pumpAndSettle();

      Object? thrown;
      try {
        await tester.tap(offer);
        await tester.pump();
      } on Object catch (error) {
        thrown = error;
      }
      thrown ??= tester.takeException();

      expect(
        thrown.toString(),
        contains('GoRouter'),
        reason: 'if this stops throwing, the offer CTA became injectable — '
            'update the preview prose, which says it is not',
      );
      expect(jeeberRequestDetailScreenDeclines, isEmpty);
    });

    testWidgets('the screen offers exactly two actions — no report affordance',
        (WidgetTester tester) async {
      // `reportService` is required by the constructor, resolved from GetIt in
      // `app_router.dart:1312`, threaded through the loader — and never read.
      // There is no prohibited-item control anywhere on this surface, which is
      // what makes the dependency dead weight rather than a missing wire.
      await pumpPreview(tester, jeeberRequestDetailScreenFullRequest);

      final Finder inScreen = find.descendant(
        of: find.byType(JeeberRequestDetailScreen),
        matching: find.byType(OmdsPrimaryButton),
      );
      expect(inScreen, findsNWidgets(2));
      expect(
        find.descendant(
          of: _summary,
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
    });

    testWidgets('Arabic mirrors the rows and keeps the client text LTR-safe', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeeberRequestDetailScreenFullRequest,
        locale: const Locale('ar'),
      );

      // Localized labels, not raw English.
      expect(find.text('ما يقوله العميل'), findsOneWidget);
      expect(find.text('نقطة الاستلام'), findsOneWidget);
      expect(find.text('مرجع الطلب'), findsOneWidget);
      expect(find.text('Pickup'), findsNothing);

      // The client's own text is user content and is NOT translated.
      expect(
        find.text('1 kilo potato, water gallon, coffee blend'),
        findsOneWidget,
      );
      expect(
        Directionality.of(
          tester.element(find.byType(JeeberRequestDetailScreen)),
        ),
        TextDirection.rtl,
      );
    });
  });
}
