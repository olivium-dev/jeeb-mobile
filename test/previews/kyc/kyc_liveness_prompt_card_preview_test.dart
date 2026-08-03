// Render tests for the KycLivenessPromptCard previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_liveness_prompt_card.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _livenessTitle = 'Quick liveness check';
const String _blink = 'Blink twice while looking at the camera';
const String _smile = 'Smile gently right after the blink';
const String _selfieTitle = 'Take a selfie';
const String _selfieSubtitle =
    'Hold your phone at eye level. '
    'Make sure your face is well-lit and not covered.';
const String _selfieSubtitleAr =
    'ارفع الهاتف لمستوى العين، وتأكد من إضاءة وجهك بشكل جيد ومن عدم إخفائه.';

/// Fixture copy from the two stress previews.
const String _longCueTail = 'Then smile gently, without covering your mouth.';
const String _checklistTurn = 'Turn your head slowly to the left, then back.';

/// WCAG 2.x contrast ratio between two opaque colours.
double _contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The card's own `Container`, i.e. the one carrying the fill under review.
BoxDecoration _cardDecoration(WidgetTester tester) {
  final Container container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(KycLivenessPromptCard),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}

ThemeData _cardTheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(KycLivenessPromptCard)));

/// Pumps a preview into a phone-WIDTH box, the way the canvas renders it.
/// The width is the point — every measurement below is about how a cue wraps
Future<void> _pumpAtPhoneWidth(
  WidgetTester tester,
  Widget Function() preview, {
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        platformBrightness: brightness,
      ),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'KycLivenessPromptCard',
    const <String, Widget Function()>{
      'Wizard default · blink + smile': kycLivenessPromptCardDefault,
      'Single cue · no inter-row gap': kycLivenessPromptCardSingleCue,
      'No cues · title only': kycLivenessPromptCardEmpty,
      'Longest plausible copy · multi-line cue': kycLivenessPromptCardLongCopy,
      'Extended checklist · five cues': kycLivenessPromptCardChecklist,
    },
    expectedText: const <String, String>{
      // The smile cue exists only in the shipping two-cue state.
      'Wizard default · blink + smile': _smile,
      // The single-cue state borrows the selfie step's subtitle, which no other
      'Single cue · no inter-row gap': _selfieSubtitle,
      // The title-only card's whole content — and the reason it does not reuse
      'No cues · title only': _selfieTitle,
      'Longest plausible copy · multi-line cue': _longCueTail,
      'Extended checklist · five cues': _checklistTurn,
    },
  );

  group('KycLivenessPromptCard preview specifics', () {
    testWidgets('the default state is the wizard\'s own two cues, in order', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycLivenessPromptCardDefault);

      expect(find.text(_livenessTitle), findsOneWidget);
      expect(find.byIcon(Icons.remove_red_eye_outlined), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_satisfied_alt_rounded), findsOneWidget);
      // Blink before smile — the cue order is the instruction.
      expect(
        tester.getTopLeft(find.text(_blink)).dy,
        lessThan(tester.getTopLeft(find.text(_smile)).dy),
      );
    });

    testWidgets('one cue renders one row and NO trailing inter-row gap', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, kycLivenessPromptCardSingleCue);

      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
      expect(find.text(_blink), findsNothing);
      expect(find.text(_smile), findsNothing);
      // The `if (i > 0)` guard: below the only cue there must be padding and
      expect(
        tester.getRect(find.byType(KycLivenessPromptCard)).bottom -
            tester.getRect(find.text(_selfieSubtitle)).bottom,
        moreOrLessEquals(Spacing.medium),
      );
    });

    testWidgets('the empty state renders the title and nothing else', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycLivenessPromptCardEmpty);

      expect(find.text(_selfieTitle), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.text(_livenessTitle), findsNothing);
    });

    testWidgets('the AR reading mirrors: the cue icon moves to the trailing '
        'edge and the copy is Arabic', (WidgetTester tester) async {
      await _pumpAtPhoneWidth(
        tester,
        kycLivenessPromptCardSingleCue,
        locale: const Locale('ar'),
      );

      expect(find.text(_selfieSubtitleAr), findsOneWidget);
      expect(find.text(_selfieSubtitle), findsNothing);
      final Element card = tester.element(find.byType(KycLivenessPromptCard));
      expect(Directionality.of(card), TextDirection.rtl);
      // `Row` mirrors and the symmetric `EdgeInsets.all` has no side to get
      expect(
        tester.getRect(find.byIcon(Icons.wb_sunny_outlined)).left,
        greaterThan(tester.getRect(find.text(_selfieSubtitleAr)).right),
      );
    });
  });

  // The defects the previews exposed, held as assertions so they cannot regress
  group('KycLivenessPromptCard layout defects', () {
    testWidgets('an empty list still pays the 12 dp gap under the title', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, kycLivenessPromptCardEmpty);

      final Rect card = tester.getRect(find.byType(KycLivenessPromptCard));
      final Rect title = tester.getRect(find.text(_selfieTitle));
      // `SizedBox(height: Spacing.small)` is emitted before the `for`, not
      expect(
        card.bottom - title.bottom,
        moreOrLessEquals(Spacing.medium + Spacing.small),
        reason: 'the gap that separates the title from cue #1 is emitted even '
            'when there is no cue #1',
      );
      // 20 dp of text in a 64 dp box: chrome dwarfs content.
      expect(card.height, greaterThan(title.height * 3));
    });

    testWidgets('the cue icon never grows with the cue text', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, kycLivenessPromptCardDefault);
      final Size iconAt100 = tester.getSize(
        find.byIcon(Icons.remove_red_eye_outlined),
      );
      final double rowAt100 = tester.getRect(find.text(_blink)).height;

      await _pumpAtPhoneWidth(
        tester,
        kycLivenessPromptCardDefault,
        textScale: 2.0,
      );
      final Size iconAt200 = tester.getSize(
        find.byIcon(Icons.remove_red_eye_outlined),
      );
      final double rowAt200 = tester.getRect(find.text(_blink)).height;

      expect(iconAt100, const Size(Sizes.large, Sizes.large));
      expect(
        iconAt200,
        iconAt100,
        reason: 'Icon(size: Sizes.large) is a raw dp constant, so at the 200% '
            'accessibility ceiling the glyph labelling each cue stays 20 dp '
            'while its text doubles',
      );
      expect(rowAt200, greaterThan(rowAt100 * 1.9));
    });
  });

  // Colour, not geometry — these hold at any text scale and any font.
  group('KycLivenessPromptCard container contrast', () {
    /// WCAG 1.4.11 asks 3:1 of a UI component's boundary against what is
    /// adjacent to it. This card has no border and no elevation, so its fill is
    const double nonTextContrastFloor = 3.0;

    testWidgets('light: the 60% fill is 1.16:1 against the surface', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, kycLivenessPromptCardDefault);

      final ThemeData theme = _cardTheme(tester);
      final Color surface = theme.scaffoldBackgroundColor;
      final Color fill = _cardDecoration(tester).color!;
      final Color composited = Color.alphaBlend(fill, surface);

      expect(fill.a, moreOrLessEquals(0.6, epsilon: 0.001));
      expect(
        _contrastRatio(composited, surface),
        lessThan(1.2),
        reason: 'measured 1.162:1 — #FFDBD1 at 60% over white is #FFE9E3, so '
            'the card has no perceivable edge',
      );
      // The alpha is what spends it: the opaque token was already only 1.288:1,
      expect(
        _contrastRatio(theme.colorScheme.primaryContainer, surface),
        greaterThan(_contrastRatio(composited, surface)),
      );
      expect(
        _contrastRatio(composited, surface),
        lessThan(nonTextContrastFloor),
      );
    });

    testWidgets('dark: same defect, 1.44:1', (WidgetTester tester) async {
      await _pumpAtPhoneWidth(
        tester,
        kycLivenessPromptCardDefault,
        brightness: Brightness.dark,
      );

      final ThemeData theme = _cardTheme(tester);
      final Color surface = theme.scaffoldBackgroundColor;
      final Color composited = Color.alphaBlend(
        _cardDecoration(tester).color!,
        surface,
      );

      expect(theme.brightness, Brightness.dark);
      expect(_contrastRatio(composited, surface), lessThan(1.5));
      expect(
        _contrastRatio(composited, surface),
        lessThan(nonTextContrastFloor),
      );
    });

    testWidgets('the INK is fine in both themes — the fill is the defect', (
      WidgetTester tester,
    ) async {
      for (final Brightness brightness in Brightness.values) {
        await _pumpAtPhoneWidth(
          tester,
          kycLivenessPromptCardDefault,
          brightness: brightness,
        );
        final ThemeData theme = _cardTheme(tester);
        final Color composited = Color.alphaBlend(
          _cardDecoration(tester).color!,
          theme.scaffoldBackgroundColor,
        );
        // app_theme.dart chose the tone-90/tone-10 pair precisely so that
        expect(
          _contrastRatio(theme.colorScheme.onPrimaryContainer, composited),
          greaterThan(7.0),
          reason: '$brightness',
        );
      }
    });
  });
}
