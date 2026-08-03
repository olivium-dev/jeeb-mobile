// Render tests for the CustomerProfileHeader previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_header.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CustomerProfileHeader',
    const <String, Widget Function()>{
      'Rated + verified': customerProfileHeaderRated,
      'Unrated, no email': customerProfileHeaderUnrated,
      'Cold start (nothing loaded)': customerProfileHeaderColdStart,
      'Phone-only synthetic identity': customerProfileHeaderSyntheticIdentity,
      'Arabic name, Latin email': customerProfileHeaderArabicName,
      'Long name + long email': customerProfileHeaderLongName,
    },
    // One string per state that ONLY that state can produce — the header renders
    expectedText: const <String, String>{
      // The rating summary, not the name: the only string that proves the rated
      'Rated + verified': '4.8 . 42 Reviews',
      'Unrated, no email': 'Nadia Client',
      // The avatar's "?" placeholder — the one glyph unique to the state where
      'Cold start (nothing loaded)': '?',
      'Phone-only synthetic identity': 'jeeb-e1a35ea8a520',
      'Arabic name, Latin email': 'كمال حاج الطرابلسي',
      'Long name + long email': 'Abdulrahman Al-Muhandis Al-Trabulsi',
    },
  );

  group('CustomerProfileHeader preview specifics', () {
    testWidgets('unrated customer keeps the rating chip and drops the email', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileHeaderUnrated);

      // `_Identity` renders the email row only `if (email != null)`, while
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('cold start renders an empty name line, not a placeholder', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileHeaderColdStart);

      // The first frame of the profile tab for every user
      expect(find.text(''), findsOneWidget);
      expect(find.text('No reviews yet'), findsOneWidget);
    });

    // TRIPWIRE, not an endorsement. The header passes `name`/`email` through
    testWidgets('phone-only account still leaks its synthetic identity', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileHeaderSyntheticIdentity);

      expect(find.text('jeeb-e1a35ea8a520'), findsOneWidget);
      expect(
        find.text('phone-only+cb39e21caa82@jeeb.internal'),
        findsOneWidget,
      );
    });

    testWidgets('long name wraps instead of ellipsizing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileHeaderLongName);

      // `_NameText` passes no maxLines/overflow, so the full string is laid out
      final RenderParagraph name = tester.renderObject<RenderParagraph>(
        find.text('Abdulrahman Al-Muhandis Al-Trabulsi'),
      );
      expect(name.maxLines, isNull);
      expect(name.overflow, TextOverflow.clip);
    });
  });
}
