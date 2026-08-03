// Render tests for the ReviewRow previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/reviews/presentation/widgets/review_row.dart';

import '../preview_test_harness.dart';

/// The long-comment fixture's body, verbatim. Kept as a constant so the
/// assertion and the preview cannot drift apart by a stray space.
const String _longComment =
    'He arrived almost an hour after the window I picked and did not '
    'answer the two calls I made in between. The package itself was '
    'fine and he was polite at the door, but I had to reschedule the '
    'rest of my afternoon around a delivery that was supposed to take '
    'twenty minutes.';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ReviewRow',
    const <String, Widget Function()>{
      'Five stars · with comment': reviewRowWithComment,
      'Stars only · no comment': reviewRowStarsOnly,
      'Not reportable · half star': reviewRowNotReportable,
      'Long comment · wraps, never clamps': reviewRowLongComment,
      'Arabic reviewer in EN locale': reviewRowArabicReviewer,
    },
    expectedText: const <String, String>{
      'Five stars · with comment': 'Fast and friendly.',
      // No body to pin on — the age is this row's only unique string.
      'Stars only · no comment': '45m ago',
      'Not reportable · half star': 'Took a while to find the building.',
      'Long comment · wraps, never clamps': _longComment,
      'Arabic reviewer in EN locale': 'وصل قبل الموعد وكان لطيفًا جدًا.',
    },
  );

  group('ReviewRow preview specifics', () {
    testWidgets('the D27 report CTA is gated on `reportable`', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, reviewRowWithComment);
      expect(find.text('Report'), findsOneWidget);

      await pumpPreview(tester, reviewRowNotReportable);
      expect(
        find.text('Report'),
        findsNothing,
        reason: 'A row with `reportable: false` must expose no flag button.',
      );
    });

    testWidgets('the report label localizes to Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        reviewRowWithComment,
        locale: const Locale('ar'),
      );

      expect(find.text('إبلاغ'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('a star-only row renders no comment paragraph', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, reviewRowStarsOnly);

      // `body: null` is coerced to '' and OmdsReviewCard drops the text block;
      expect(find.text(''), findsNothing);
      expect(find.text('Fast and friendly.'), findsNothing);
    });

    testWidgets(
      'the reviewer name is printed twice — attribution AND card header',
      (WidgetTester tester) async {
        await pumpPreview(tester, reviewRowWithComment);

        // Documented, not endorsed: `ReviewRow` paints the D58 attribution node
        expect(find.text('Sami'), findsNWidgets(2));
      },
    );
  });
}
