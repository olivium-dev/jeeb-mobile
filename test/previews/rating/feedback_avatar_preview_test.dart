// Render tests for the FeedbackAvatar previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_avatar.dart';
import 'package:jeeb_mobile/previews/rating/feedback_avatar_preview.dart';

import '../preview_test_harness.dart';

/// WCAG contrast between the initial's ink and the circle it sits on, read off
/// the live render tree rather than off the palette constants — the point is
/// what this widget actually paints.
double _initialContrast(WidgetTester tester) {
  final Text initial = tester.widget<Text>(find.text('R'));
  final Container circle = tester.widget<Container>(
    find.ancestor(of: find.text('R'), matching: find.byType(Container)).first,
  );
  final double ink = initial.style!.color!.computeLuminance();
  final double fill = (circle.decoration! as BoxDecoration).color!
      .computeLuminance();
  final double lighter = ink > fill ? ink : fill;
  final double darker = ink > fill ? fill : ink;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'FeedbackAvatar',
    const <String, Widget Function()>{
      'Named ratee': feedbackAvatarNamed,
      'No name (route default)': feedbackAvatarNoName,
      'Arabic name': feedbackAvatarArabicName,
      'Phone-only synthetic handle': feedbackAvatarSyntheticHandle,
      'Decomposed first letter': feedbackAvatarDecomposedName,
      'Empty avatar URL': feedbackAvatarEmptyUrl,
    },
    // The avatar renders exactly one glyph, so the glyph IS the state. Every
    // fixture name was chosen to start with a different letter for this reason:
    // two states sharing an initial could swap places unnoticed, which is the
    // failure this map exists to catch.
    expectedText: const <String, String>{
      'Named ratee': 'R',
      'No name (route default)': '?',
      // Lam — the first letter of the Arabic fixture, as authored.
      'Arabic name': 'ل',
      'Phone-only synthetic handle': 'J',
      // Bare alef: the maddah (U+0653) of the decomposed first grapheme is gone,
      // sliced off by `initial[0]`. See the tripwire test below.
      'Decomposed first letter': 'ا',
      'Empty avatar URL': 'Z',
    },
  );

  group('FeedbackAvatar preview specifics', () {
    testWidgets('shows the uppercased initial and nothing else of the name', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackAvatarNamed);

      expect(find.text('R'), findsOneWidget);
      expect(find.textContaining('Chidiac'), findsNothing);
    });

    testWidgets('an empty name announces the localized title, not silence', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, feedbackAvatarNoName);

      // `name.isEmpty ? l10n.feedbackScreenTitle : name` is the only localized
      // string in the widget, and the only thing a screen reader gets when the
      // `?name=` deep-link parameter is missing. Note what the node actually
      // carries: the label, then the decorative '?' glyph merged in from the
      // child Text, because nothing excludes it from semantics.
      expect(
        tester.getSemantics(find.byKey(FeedbackAvatar.rootKey)).label,
        'We appreciate your feedback\n?',
      );
      handle.dispose();
    });

    // TRIPWIRE, not an endorsement. `FeedbackAvatar._initial` slices by grapheme
    // (`characters.first`) and `OmdsProfileAvatar._buildPlaceholder` re-slices
    // the result by UTF-16 code unit (`initial[0]`), so only the first code unit
    // of a multi-code-unit letter survives. Here that drops the maddah and turns
    // a decomposed alef-with-maddah into a plain alef. If this test starts
    // failing, the two widgets were reconciled — expect the full grapheme
    // instead.
    testWidgets('a decomposed first letter loses its combining mark', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackAvatarDecomposedName);

      expect(find.text('\u0627\u0653'), findsNothing);
      expect(find.text('ا'), findsOneWidget);
    });

    testWidgets(
      'an empty avatar URL takes the initial path, not the image path',
      (WidgetTester tester) async {
        await pumpPreview(tester, feedbackAvatarEmptyUrl);

        // `OmdsProfileAvatar` short-circuits on `profilePicUrl!.isEmpty` before
        // `OmdsCachedImage` is built. If that check is ever dropped, this state
        // becomes the one preview that reaches the network.
        expect(find.text('Z'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
      },
    );

    // TRIPWIRE, not an endorsement. `OmdsProfileAvatar` defaults `initialColor`
    // to a hardcoded `Colors.white` and `FeedbackAvatar` overrides nothing, so
    // the initial is painted white on `colorScheme.primaryContainer`. The b02
    // tone-pair correction moved that role from the saturated #D73B00 (white
    // ink: 4.65:1) to the M3 tone-90 #FFDBD1, and white on #FFDBD1 measures
    // 1.29:1 — far under the 3:1 WCAG floor for large text, in the light theme
    // that is both the default and the only one this screen ships in. The dark
    // scheme's generated primaryContainer (#3C4279) is fine at 9.34:1, which is
    // why the EN light rendering of the previews is the one that shows it. If
    // this test starts failing, the avatar was finally given an on-container
    // ink — replace the numbers with the new ones.
    testWidgets('paints the initial white on primaryContainer (1.29:1 light)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackAvatarNamed);
      expect(_initialContrast(tester), closeTo(1.29, 0.01));

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpPreview(tester, feedbackAvatarNamed);
      expect(_initialContrast(tester), closeTo(9.34, 0.01));
    });

    testWidgets('the initial scales with text size; the circle does not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackAvatarNamed);
      expect(
        tester.getSize(find.byType(OmdsProfileAvatar)),
        const Size(96, 96),
      );
      expect(tester.getSize(find.text('R')).height, lessThan(60));

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, feedbackAvatarNamed);

      // The circle is a hard 96 dp (`Sizes.tenXLarge`) but the initial is a
      // plain `fontSize: size / 2.5` with no `TextScaler` clamp, so at the
      // accessibility ceiling the 110 dp line box is squeezed into the 96 dp the
      // circle can give it and paints over the edge. The two sizes being equal
      // IS the overflow: the glyph has exactly nothing left.
      expect(
        tester.getSize(find.byType(OmdsProfileAvatar)),
        const Size(96, 96),
      );
      expect(tester.getSize(find.text('R')).height, 96.0);
    });
  });
}
