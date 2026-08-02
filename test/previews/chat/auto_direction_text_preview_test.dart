// Render tests for the AutoDirectionText previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// `test/chat_auto_direction_text_test.dart` owns the detection rule as data.
// This file owns the previews: that each one still renders ITS OWN string, and
// that the four behaviours the preview docs claim — content-wins for strong
// text, ambient-wins for neutral text, and the pinned-strip clamp — are the
// behaviours a reviewer opening the canvas will actually be looking at.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/auto_direction_text.dart';

import '../preview_test_harness.dart';

/// The direction the previewed widget actually resolved, read off the [Text] it
/// builds rather than off the ambient [Directionality].
TextDirection _resolvedDirection(WidgetTester tester) {
  final Text text = tester.widget<Text>(
    find.descendant(
      of: find.byType(AutoDirectionText),
      matching: find.byType(Text),
    ),
  );
  return text.textDirection!;
}

Future<TextDirection> _directionIn(
  WidgetTester tester,
  Widget Function() preview,
  String languageCode,
) async {
  await pumpPreview(tester, preview, locale: Locale(languageCode));
  return _resolvedDirection(tester);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'AutoDirectionText',
    const <String, Widget Function()>{
      'English message': autoDirectionTextEnglish,
      'Arabic message': autoDirectionTextArabic,
      'Mixed: Arabic first': autoDirectionTextMixedArabicFirst,
      'Mixed: English first': autoDirectionTextMixedEnglishFirst,
      'Digits only, no strong character': autoDirectionTextNeutralOnly,
      'Unlisted LTR script (Amharic)': autoDirectionTextUnlistedScript,
      'Long Arabic, clamped to 2 lines': autoDirectionTextClampedLongArabic,
    },
    expectedText: const <String, String>{
      'English message': 'On my way, five minutes out',
      'Arabic message': 'انا في الطريق اليك خمس دقائق',
      'Mixed: Arabic first': 'مرحبا الطلب جاهز عند Spinneys',
      'Mixed: English first': 'Pickup from مخبز الرحمة, Hamra',
      'Digits only, no strong character': '+961 3 000 077',
      'Unlisted LTR script (Amharic)': 'ሰላም በመንገድ ላይ ነኝ',
      'Long Arabic, clamped to 2 lines':
          'ارجو احضار كيسين من الخبز العربي وعلبة لبن كبيرة وزجاجة زيت زيتون من '
              'دكان ابو خليل في شارع الحمرا والدفع عند الاستلام نقدا',
    },
  );

  group('AutoDirectionText preview specifics', () {
    testWidgets('strong content beats the UI language, both ways', (
      WidgetTester tester,
    ) async {
      // Arabic message stays RTL inside an English UI...
      expect(
        await _directionIn(tester, autoDirectionTextArabic, 'en'),
        TextDirection.rtl,
      );
      // ...and an English message stays LTR inside an Arabic UI.
      expect(
        await _directionIn(tester, autoDirectionTextEnglish, 'ar'),
        TextDirection.ltr,
      );
    });

    testWidgets('mixed content takes the FIRST strong character', (
      WidgetTester tester,
    ) async {
      // Same two languages in each string; only the order differs.
      expect(
        await _directionIn(tester, autoDirectionTextMixedArabicFirst, 'en'),
        TextDirection.rtl,
      );
      expect(
        await _directionIn(tester, autoDirectionTextMixedEnglishFirst, 'ar'),
        TextDirection.ltr,
      );
    });

    testWidgets('neutral-only content is handed to the UI language', (
      WidgetTester tester,
    ) async {
      // A phone number has no strong character, so the same string lays out
      // LTR for an English user and RTL for an Arabic one. Pinned as the
      // widget's current behaviour, not as the desired one — see the preview
      // doc for why RTL reorders the digit groups.
      expect(
        await _directionIn(tester, autoDirectionTextNeutralOnly, 'en'),
        TextDirection.ltr,
      );
      expect(
        await _directionIn(tester, autoDirectionTextNeutralOnly, 'ar'),
        TextDirection.rtl,
      );
    });

    testWidgets('an unlisted LTR script falls into the neutral branch', (
      WidgetTester tester,
    ) async {
      // Amharic is strong LTR in Unicode but outside `_isStrongLtr`'s ranges,
      // so it inherits the UI direction and flips with the app language. If
      // this ever starts returning ltr for both locales, the range list grew
      // and this expectation should be tightened, not deleted.
      expect(
        await _directionIn(tester, autoDirectionTextUnlistedScript, 'en'),
        TextDirection.ltr,
      );
      expect(
        await _directionIn(tester, autoDirectionTextUnlistedScript, 'ar'),
        TextDirection.rtl,
      );
    });

    testWidgets('the long description preview really is clamped', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, autoDirectionTextClampedLongArabic);

      final Text text = tester.widget<Text>(
        find.descendant(
          of: find.byType(AutoDirectionText),
          matching: find.byType(Text),
        ),
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.textDirection, TextDirection.rtl);
    });
  });
}
