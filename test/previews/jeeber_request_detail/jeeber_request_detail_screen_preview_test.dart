// Render tests for the JeeberRequestDetailScreen previews.

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
      'Phone · pickup label empty (feed degrade)': '#77C145',
      // Window states share a payload with the reference reading by design, so
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
      Future<double> barHeight(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        final Finder buttons = find.byType(OmdsPrimaryButton);
        expect(buttons, findsNWidgets(2));
        expect(tester.getSize(buttons.first).height, _buttonHeight);
        expect(tester.getSize(buttons.last).height, _buttonHeight);
        // The bar is its two buttons plus `EdgeInsets.all(Spacing.xLarge)` —
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
      await pumpPreview(tester, jeeberRequestDetailScreenNoDescription);

      final Finder decline = find.text('Decline request');
      // The 390 × 844 frame is taller than the 800 × 600 test surface, so the
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
