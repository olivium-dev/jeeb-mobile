// Render tests for the FeedbackAvatar previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_avatar.dart';

import '../preview_test_harness.dart';

/// WCAG contrast between the initial's ink and the circle it sits on, read off
/// the live render tree rather than off the palette constants — the point is
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
    expectedText: const <String, String>{
      'Named ratee': 'R',
      'No name (route default)': '?',
      // Lam — the first letter of the Arabic fixture, as authored.
      'Arabic name': 'ل',
      'Phone-only synthetic handle': 'J',
      // Bare alef: the maddah (U+0653) of the decomposed first grapheme is gone,
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
      expect(
        tester.getSemantics(find.byKey(FeedbackAvatar.rootKey)).label,
        'We appreciate your feedback\n?',
      );
      handle.dispose();
    });

    // TRIPWIRE, not an endorsement. `FeedbackAvatar._initial` slices by grapheme
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
        expect(find.text('Z'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
      },
    );

    // TRIPWIRE, not an endorsement. `OmdsProfileAvatar` defaults `initialColor`
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
      expect(
        tester.getSize(find.byType(OmdsProfileAvatar)),
        const Size(96, 96),
      );
      expect(tester.getSize(find.text('R')).height, 96.0);
    });
  });
}
