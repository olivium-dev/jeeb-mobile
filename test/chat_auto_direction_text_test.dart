import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/auto_direction_text.dart';

Future<TextDirection> _resolvedDirection(
  WidgetTester tester,
  String content, {
  TextDirection ambient = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    Directionality(textDirection: ambient, child: AutoDirectionText(content)),
  );
  final text = tester.widget<Text>(find.byType(Text));
  return text.textDirection!;
}

void main() {
  group('AutoDirectionText — first-strong direction detection', () {
    testWidgets('Arabic-only content lays out RTL', (tester) async {
      expect(await _resolvedDirection(tester, 'مرحباً'), TextDirection.rtl);
    });

    testWidgets('English-only content lays out LTR', (tester) async {
      expect(await _resolvedDirection(tester, 'Hello'), TextDirection.ltr);
    });

    testWidgets('mixed content uses the FIRST strong character', (
      tester,
    ) async {
      // Arabic word first → RTL paragraph.
      expect(
        await _resolvedDirection(tester, 'مرحباً Hello'),
        TextDirection.rtl,
      );
      // English first → LTR paragraph, even though Arabic follows.
      expect(
        await _resolvedDirection(tester, 'Hello مرحباً'),
        TextDirection.ltr,
      );
    });

    testWidgets(
      'content with only digits / punctuation inherits the ambient direction',
      (tester) async {
        expect(
          await _resolvedDirection(
            tester,
            '123 !@#',
            ambient: TextDirection.ltr,
          ),
          TextDirection.ltr,
        );
        expect(
          await _resolvedDirection(
            tester,
            '123 !@#',
            ambient: TextDirection.rtl,
          ),
          TextDirection.rtl,
        );
      },
    );
  });
}
