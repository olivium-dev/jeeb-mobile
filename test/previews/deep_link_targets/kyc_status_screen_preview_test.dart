// Render tests for the KycStatusScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/kyc_status_screen_fixtures.dart';
import 'package:jeeb_mobile/features/deep_link_targets/kyc_status_screen.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);
const Size _notchedFrame = Size(393, 852);

/// `JeebEmptyState.defaultIllustrationSize` — a fixed logical size, not a
/// scaled one — and the Ø58 centre slot the `KycStateMark` glyph fills.
const double _illustrationSize = 300;
const double _markSize = 58;

/// The two sentences the screen renders, as ARB lookups in both locales.
const String _title = 'KYC status';
const String _subtitle = 'Your verification status will appear here.';
const String _titleAr = 'حالة التحقق';
const String _subtitleAr = 'ستظهر حالة التحقق هنا.';

/// What the M4 sweep added, and what every geometry claim below rests on.
final Finder _scrollable = find.descendant(
  of: find.byType(KycStatusScreen),
  matching: find.byType(Scrollable),
);

/// The composed illustration block — the screen's only [FittedBox] — and the
/// glyph the screen swaps into radar's broadcast core.
final Finder _illustration = find
    .descendant(
      of: find.byType(KycStatusScreen),
      matching: find.byType(FittedBox),
    )
    .first;
final Finder _mark = find.byIcon(Icons.verified_user_outlined);

/// How much taller than its window the composition is. Zero means it fits.
double _absorbedByScrolling(WidgetTester tester) =>
    tester.state<ScrollableState>(_scrollable).position.maxScrollExtent;

/// Every label in [node]'s subtree, root first — one entry per semantics node,
/// so a sentence carried at two levels shows up as two entries.
List<String> _labelsUnder(SemanticsNode node) {
  final List<String> labels = <String>[node.label];
  node.visitChildren((SemanticsNode child) {
    labels.addAll(_labelsUnder(child));
    return true;
  });
  return labels;
}

void main() {
  setUpAll(loadPreviewArbs);

  // `Compact · 200% text` is deliberately NOT in this map. It overflows by
  testPreviewsRender(
    'KycStatusScreen',
    const <String, Widget Function()>{
      'Phone 390 × 844': kycStatusScreenPhone,
      'Compact 320 × 568': kycStatusScreenCompact,
      'Phone · 200% text': kycStatusScreenPhoneLargeText,
      'Notched · 200% text': kycStatusScreenNotchedLargeText,
    },
    // Every state names its own window. The screen shows the same icon and the
    expectedText: const <String, String>{
      'Phone 390 × 844': 'Phone · 390 × 844 · 100% text',
      'Compact 320 × 568': 'Compact · 320 × 568 · 100% text',
      'Phone · 200% text': 'Phone · 390 × 844 · 200% text',
      'Notched · 200% text': 'Notched · 393 × 852 · inset 59/34 · 200% text',
    },
  );

  group('KycStatusScreen preview specifics', () {
    test('every window the fixture publishes has a preview above', () {
      // `KycStatusScreenWindows.all` is what the Screen Catalog enumerates, so
      expect(
        KycStatusScreenWindows.all
            .map((KycStatusScreenWindow w) => w.label)
            .toList(),
        <String>[
          'Phone · 390 × 844 · 100% text',
          'Compact · 320 × 568 · 100% text',
          'Phone · 390 × 844 · 200% text',
          'Compact · 320 × 568 · 200% text',
          'Notched · 393 × 852 · inset 59/34 · 200% text',
        ],
      );
      expect(
        KycStatusScreenWindows.all
            .map((KycStatusScreenWindow w) => w.size)
            .toList(),
        <Size>[
          _phoneFrame,
          _compactFrame,
          _phoneFrame,
          _compactFrame,
          _notchedFrame,
        ],
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
      final Rect rect = tester.getRect(find.byType(KycStatusScreen));
      tester.takeException();
      return rect;
    }

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      expect(
        (await frameRect(tester, kycStatusScreenPhone)).size,
        _phoneFrame,
      );
      expect(
        (await frameRect(tester, kycStatusScreenCompact)).size,
        _compactFrame,
      );
      expect(
        (await frameRect(tester, kycStatusScreenPhoneLargeText)).size,
        _phoneFrame,
      );
      expect(
        (await frameRect(tester, kycStatusScreenCompactLargeText)).size,
        _compactFrame,
      );
      expect(
        (await frameRect(tester, kycStatusScreenNotchedLargeText)).size,
        _notchedFrame,
      );
    });

    testWidgets('the 200% windows really are scaled and the rest are not', (
      WidgetTester tester,
    ) async {
      // `KycStatusScreenWindow.textScale` is nullable on purpose: a window that
      Future<double> scale(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        final double s = MediaQuery.textScalerOf(
          tester.element(find.byType(KycStatusScreen)),
        ).scale(10);
        tester.takeException();
        return s;
      }

      expect(await scale(kycStatusScreenPhone), 10);
      expect(await scale(kycStatusScreenCompact), 10);
      expect(await scale(kycStatusScreenPhoneLargeText), 20);
      expect(await scale(kycStatusScreenCompactLargeText), 20);
      expect(await scale(kycStatusScreenNotchedLargeText), 20);
    });

    testWidgets('the screen body scrolls, and still brings its own Scaffold', (
      WidgetTester tester,
    ) async {
      // The structural half of the clipping defect, and the half the M4 sweep
      await pumpPreview(tester, kycStatusScreenPhone);

      expect(_scrollable, findsOneWidget);
      expect(
        tester.state<ScrollableState>(_scrollable).position.axis,
        Axis.vertical,
      );
      // The screen still brings its own Scaffold, so it is a whole screen and
      expect(
        find.descendant(
          of: find.byType(KycStatusScreen),
          matching: find.byType(Scaffold),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'the illustration YIELDS its width to the text scaler (D4), floored at '
      'the 1.6x clamp',
      (WidgetTester tester) async {
        await pumpPreview(tester, kycStatusScreenPhone);
        final Size artAtDefault = tester.getSize(_illustration);
        final Size markAtDefault = tester.getSize(_mark);

        await pumpPreview(tester, kycStatusScreenPhoneLargeText);

        expect(artAtDefault, const Size(_illustrationSize, _illustrationSize));
        expect(markAtDefault, const Size(_markSize, _markSize));
        // D4: scaled text reclaims art space instead of running off the fold.
        // The divisor is clamped at 1.6, so 300 -> 187.5 and the mark, which
        // scales with the FittedBox viewBox, follows in proportion.
        expect(
          tester.getSize(_illustration).width,
          closeTo(_illustrationSize / 1.6, 0.5),
          reason: 'the art must give way to the reader, not hold 300 pt',
        );
        // The mark keeps its 58 pt slot INSIDE the viewBox; the FittedBox is
        // what shrinks it on screen, so its local box is unchanged.
        expect(tester.getSize(_mark), markAtDefault);
      },
    );

    testWidgets('on a 390 × 844 phone the whole composition fits', (
      WidgetTester tester,
    ) async {
      // The reference reading, and the reason the state below went unnoticed:
      final Rect frame = await frameRect(tester, kycStatusScreenPhone);
      final Rect column = tester.getRect(
        find.descendant(
          of: find.byType(KycStatusScreen),
          matching: find.byType(Column),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(column.top, greaterThanOrEqualTo(frame.top));
      expect(column.bottom, lessThanOrEqualTo(frame.bottom));
    });

    testWidgets('a notched phone at 200% still clears the system chrome', (
      WidgetTester tester,
    ) async {
      // `appBar: null` means nothing consumes the 59 pt status bar, and
      final Rect frame = await frameRect(
        tester,
        kycStatusScreenNotchedLargeText,
      );
      final Rect column = tester.getRect(
        find.descendant(
          of: find.byType(KycStatusScreen),
          matching: find.byType(Column),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        column.top - frame.top,
        greaterThan(59),
        reason: 'top inset (status bar) is not consumed by anything',
      );
      expect(
        frame.bottom - column.bottom,
        greaterThan(34),
        reason: 'bottom inset (home indicator) is not consumed by anything',
      );
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'the smallest phone at 200% scrolls instead of clipping, in '
        '${locale.languageCode}',
        (WidgetTester tester) async {
          // The state that used to break, and the reason `Compact · 200% text`
          await pumpPreview(
            tester,
            kycStatusScreenCompactLargeText,
            locale: locale,
          );

          // Pins WHICH window this preview simulates, the same job
          expect(find.text('Compact · 320 × 568 · 200% text'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(
            _absorbedByScrolling(tester),
            greaterThan(0),
            reason: 'the composition is still taller than a 320 × 568 display '
                'at the 200% accessibility ceiling: the scroll view is what '
                'keeps the bottom of it reachable',
          );
        },
      );
    }

    testWidgets('the copy is localized, so Arabic renders Arabic', (
      WidgetTester tester,
    ) async {
      // Both sentences are `AppLocalizations` lookups now, not string literals
      await pumpPreview(
        tester,
        kycStatusScreenPhone,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(tester.element(find.byType(KycStatusScreen))),
        TextDirection.rtl,
      );
      expect(find.text(_titleAr), findsOneWidget);
      expect(find.text(_subtitleAr), findsOneWidget);
      expect(find.text(_title), findsNothing);
      expect(find.text(_subtitle), findsNothing);
    });

    testWidgets('the screen announces its copy once, not once per tree level', (
      WidgetTester tester,
    ) async {
      // STILL OPEN: `semanticLabel` restates the two sentences the block's own
      // explicit child nodes already carry, so each is in the tree twice.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, kycStatusScreenPhone);

      final List<String> labels = _labelsUnder(
        tester.getSemantics(
          find.bySemanticsIdentifier('deep_link_kyc_status_root'),
        ),
      );

      expect(
        labels.where((String label) => label.contains(_title)).length,
        1,
        reason: 'labels in the block subtree were: $labels',
      );
      expect(
        labels.where((String label) => label.contains(_subtitle)).length,
        1,
      );

      handle.dispose();
    });
  });
}
