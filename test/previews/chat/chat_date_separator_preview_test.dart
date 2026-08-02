// Render tests for the ChatDateSeparator previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_date_separator.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ChatDateSeparator',
    const <String, Widget Function()>{
      'Today': chatDateSeparatorToday,
      'Yesterday': chatDateSeparatorYesterday,
      'Older date': chatDateSeparatorOlderDate,
      'Longest date label': chatDateSeparatorLongestLabel,
      'Epoch anchor (1970)': chatDateSeparatorEpochAnchor,
      'UTC instant, not localized': chatDateSeparatorUtcInstant,
    },
    expectedText: const <String, String>{
      'Today': 'Today',
      'Yesterday': 'Yesterday',
      'Older date': 'March 8, 2026',
      'Longest date label': 'September 28, 2025',
      'Epoch anchor (1970)': 'January 1, 1970',
      'UTC instant, not localized': 'December 31, 2024',
    },
  );

  group('ChatDateSeparator preview specifics', () {
    testWidgets('relative days beat the formatter', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatDateSeparatorToday);
      expect(find.text('Today'), findsOneWidget);

      await pumpPreview(tester, chatDateSeparatorYesterday);
      expect(find.text('Yesterday'), findsOneWidget);
      // A formatted date here would mean the same-day comparison broke.
      expect(find.textContaining(','), findsNothing);
    });

    testWidgets('older dates localize in Arabic, not just in English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        chatDateSeparatorOlderDate,
        locale: const Locale('ar'),
      );

      // The DateFormat branch is the one label that is not an ARB string, so
      expect(find.text('March 8, 2026'), findsNothing);
      expect(find.textContaining('مارس'), findsOneWidget);
    });

    testWidgets('relative labels translate', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        chatDateSeparatorToday,
        locale: const Locale('ar'),
      );

      expect(find.text('اليوم'), findsOneWidget);
    });

    testWidgets('is announced as a date, not as decoration', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, chatDateSeparatorOlderDate);

      // Matched loosely on purpose. The widget wraps the chip in `Semantics`
      expect(
        find.bySemanticsLabel(RegExp('March 8, 2026')),
        findsOneWidget,
        reason: 'the chip is a date announcement, not decoration',
      );
      handle.dispose();
    });
  });
}
