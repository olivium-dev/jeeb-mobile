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

/// `OmdsEmptyStatePage.iconSize` default — a fixed logical size, not a scaled
/// one.
const double _iconSize = 100;

/// The two sentences the screen hardcodes, as string literals rather than ARB
/// lookups.
const String _title = 'KYC Status coming soon';
const String _subtitle = 'This screen is not yet available.';

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

    testWidgets('the screen contains no scrollable of any kind', (
      WidgetTester tester,
    ) async {
      // The structural half of the clipping defect, and the half that does not
      await pumpPreview(tester, kycStatusScreenPhone);

      expect(
        find.descendant(
          of: find.byType(KycStatusScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      // The screen brings its own Scaffold (OmdsEmptyStatePage returns one), so
      expect(
        find.descendant(
          of: find.byType(KycStatusScreen),
          matching: find.byType(Scaffold),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the 100 pt icon does not follow the text scaler', (
      WidgetTester tester,
    ) async {
      // The other font-independent half. `OmdsEmptyStatePage` passes a fixed
      await pumpPreview(tester, kycStatusScreenPhone);
      final Size atDefault =
          tester.getSize(find.byIcon(Icons.construction_outlined));

      await pumpPreview(tester, kycStatusScreenPhoneLargeText);
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
        'the smallest phone at 200% clips, in ${locale.languageCode}',
        (WidgetTester tester) async {
          // The state that breaks, and the reason `Compact · 200% text` is kept
          await pumpPreview(
            tester,
            kycStatusScreenCompactLargeText,
            locale: locale,
          );

          // Pins WHICH window this preview simulates, the same job
          expect(find.text('Compact · 320 × 568 · 200% text'), findsOneWidget);
          expect(
            tester.takeException().toString(),
            contains('overflowed'),
            reason: 'a Column(mainAxisSize: min) inside a Center, with a fixed '
                '100 pt icon above two wrapping paragraphs, on a 320 × 568 '
                'display at the 200% accessibility ceiling',
          );
        },
      );
    }

    testWidgets('the copy is hardcoded English, so Arabic renders English', (
      WidgetTester tester,
    ) async {
      // Both sentences are string literals in `build`, not `AppLocalizations`
      await pumpPreview(
        tester,
        kycStatusScreenPhone,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(tester.element(find.byType(KycStatusScreen))),
        TextDirection.rtl,
      );
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_subtitle), findsOneWidget);
    });

    testWidgets('the Semantics wrapper announces the copy twice', (
      WidgetTester tester,
    ) async {
      // `Semantics(container: true, label: 'KYC Status coming soon. This screen
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, kycStatusScreenPhone);

      // One node covers the whole screen — the wrapper's label and both Texts
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
