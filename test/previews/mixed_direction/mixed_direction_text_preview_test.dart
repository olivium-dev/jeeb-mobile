// Render tests for the MixedDirectionText previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Every state pins a DISTINCT string, because all six previews are one line of
// body copy in the same box and would otherwise be told apart by nothing at all
// — a suite that only asked "did something render?" would pass on six copies of
// the English baseline.
//
// The group at the bottom is what the shared harness cannot see. The harness
// asserts that each preview BUILDS and shows its own text; it cannot assert the
// one thing this widget actually does, which is choose a [TextDirection]. Those
// tests read the direction off the [Directionality] the widget wraps its [Text]
// in — including the case where the choice is wrong (see `leading digit`), so
// that a future fix fails here loudly instead of silently changing the copy a
// courier reads.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/mixed_direction/presentation/mixed_direction_text.dart';

import '../preview_test_harness.dart';

/// The long note as the preview concatenates it.
const String _longArabicNote =
    'الرجاء التوصيل إلى مبنى الأمين، الطابق الرابع، شارع الحمرا، بيروت، '
    'والاتصال بي قبل الوصول بعشر دقائق';

/// The direction of the [Directionality] the widget wraps [text] in — the
/// nearest such ancestor, which is the one `MixedDirectionText.build` creates.
TextDirection _directionOf(WidgetTester tester, String text) {
  final Finder directionality = find.ancestor(
    of: find.text(text),
    matching: find.byType(Directionality),
  );
  expect(directionality, findsWidgets);
  return tester.widget<Directionality>(directionality.first).textDirection;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'MixedDirectionText',
    const <String, Widget Function()>{
      'English (LTR)': mixedDirectionTextEnglish,
      'Arabic (RTL)': mixedDirectionTextArabic,
      'Arabic name in an English frame': mixedDirectionTextArabicNameInEnglish,
      'Leading digit · LTR misfire': mixedDirectionTextLeadingDigit,
      'Long Arabic note · clamped to 2 lines': mixedDirectionTextLongArabicNote,
      'Leading whitespace (crash boundary)': mixedDirectionTextLeadingWhitespace,
    },
    expectedText: const <String, String>{
      'English (LTR)': 'Pickup from Spinneys, Hamra',
      'Arabic (RTL)': 'توصيل من محل الحلويات في الأشرفية',
      'Arabic name in an English frame': 'Rate محمد الحلبي',
      'Leading digit · LTR misfire': '2 boxes - توصيل سريع',
      'Long Arabic note · clamped to 2 lines': _longArabicNote,
      'Leading whitespace (crash boundary)': '  توصيل من الأشرفية',
    },
  );

  group('MixedDirectionText preview specifics', () {
    testWidgets('an Arabic-first note lays out RTL', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, mixedDirectionTextArabic);

      expect(
        _directionOf(tester, 'توصيل من محل الحلويات في الأشرفية'),
        TextDirection.rtl,
      );
    });

    testWidgets('direction comes from the text, never from the app locale', (
      WidgetTester tester,
    ) async {
      // Same preview, Arabic app locale: the surrounding app has mirrored, and
      // this English line must NOT follow it. The widget never reads
      // `Directionality.of(context)`, and this is the assertion that keeps it
      // that way.
      await pumpPreview(
        tester,
        mixedDirectionTextEnglish,
        locale: const Locale('ar'),
      );

      expect(
        _directionOf(tester, 'Pickup from Spinneys, Hamra'),
        TextDirection.ltr,
      );
    });

    testWidgets('an Arabic name inside an English frame stays LTR', (
      WidgetTester tester,
    ) async {
      // The frame decides, not the name — "Rate …" opens with `R`. The Arabic
      // run is reordered by the Unicode bidi algorithm inside the LTR
      // paragraph, which is what the rating screen depends on.
      await pumpPreview(tester, mixedDirectionTextArabicNameInEnglish);

      expect(_directionOf(tester, 'Rate محمد الحلبي'), TextDirection.ltr);
    });

    testWidgets('KNOWN MISFIRE · a leading digit forces a mostly-Arabic note '
        'to LTR', (WidgetTester tester) async {
      // `detectDirection` reads exactly one character, so `2` outvotes three
      // Arabic words. Asserted as-is rather than as the desired behaviour: this
      // is the state the preview shows a reviewer, and a fix must change both.
      await pumpPreview(tester, mixedDirectionTextLeadingDigit);

      expect(_directionOf(tester, '2 boxes - توصيل سريع'), TextDirection.ltr);
    });

    testWidgets('leading whitespace is trimmed for detection but kept in the '
        'rendered text', (WidgetTester tester) async {
      await pumpPreview(tester, mixedDirectionTextLeadingWhitespace);

      expect(_directionOf(tester, '  توصيل من الأشرفية'), TextDirection.rtl);
      // The spaces survive into the Text — trimming happens in the detector
      // only, so under RTL they indent the line from the right edge.
      expect(find.text('توصيل من الأشرفية'), findsNothing);
    });

    testWidgets('the long note is clamped to two lines with an ellipsis', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, mixedDirectionTextLongArabicNote);

      final Text note = tester.widget<Text>(find.text(_longArabicNote));
      expect(note.maxLines, 2);
      expect(note.overflow, TextOverflow.ellipsis);
      expect(_directionOf(tester, _longArabicNote), TextDirection.rtl);
    });
  });
}
