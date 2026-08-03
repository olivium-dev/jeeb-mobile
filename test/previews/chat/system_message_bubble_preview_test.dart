import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/system_message_bubble.dart';

import '../preview_test_harness.dart';

/// The bubble keys its root `chat-system-<message id>`. A colla
Key _rowKey(String id) => Key('chat-system-$id');

/// Server copy on the `system` kind, rendered verbatim from `me
const String _serverNoticeEn =
    'Your request expired before a Jeeber accepted it.';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SystemMessageBubble',
    const <String, Widget Function()>{
      'Offer accepted · named': systemMessageBubbleAccepted,
      'Offer accepted · nameless payload': systemMessageBubbleAcceptedNameless,
      'Offer withdrawn · named': systemMessageBubbleRejected,
      'Server notice · verbatim': systemMessageBubbleServerNotice,
      'Long name at 390dp': systemMessageBubbleLongName,
      'Empty + unsupported collapse': systemMessageBubbleCollapsed,
    },
    expectedText: const <String, String>{
      'Offer accepted · named': "Kamal Hajj's offer was accepted",
      'Offer accepted · nameless payload': "'s offer was accepted",
      'Offer withdrawn · named': "Rana's offer was withdrawn",
      'Server notice · verbatim': _serverNoticeEn,
      'Long name at 390dp':
          "Abdulrahman Al-Muhandis Al-Trabulsi's offer was accepted",
      'Empty + unsupported collapse': "Ziad's offer was accepted",
    },
  );

  group('SystemMessageBubble preview specifics', () {
    testWidgets('the named notice uses the payload, not the generic copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, systemMessageBubbleAccepted);

      expect(find.text("Kamal Hajj's offer was accepted"), findsOneWidget);
      expect(find.text('Offer accepted'), findsNothing);
      expect(find.byKey(_rowKey('sys-accepted-1')), findsOneWidget);
    });

    testWidgets('accepted and withdrawn never collapse to the same string', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, systemMessageBubbleRejected);

      expect(find.text("Rana's offer was withdrawn"), findsOneWidget);
      expect(find.textContaining('accepted'), findsNothing);
    });

    testWidgets('a nameless payload takes the NAMED branch — the generic '
        'fallback is unreachable from any wire path', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, systemMessageBubbleAcceptedNameless);

      expect(find.text("'s offer was accepted"), findsOneWidget);
      expect(find.text('Offer accepted'), findsNothing);
    });

    testWidgets('empty and wrong-kind rows occupy zero height', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, systemMessageBubbleCollapsed);

      expect(find.byType(SystemMessageBubble), findsNWidgets(3));
      expect(find.byKey(_rowKey('sys-accepted-4')), findsOneWidget);

      expect(find.byKey(_rowKey('sys-empty')), findsNothing);
      expect(find.byKey(_rowKey('sys-wrong-kind')), findsNothing);
      expect(
        find.text('a text message must never paint as a system chip'),
        findsNothing,
      );
    });

    testWidgets('server `system` copy is passed through UNLOCALIZED', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        systemMessageBubbleServerNotice,
        locale: const Locale('ar'),
      );

      expect(find.text(_serverNoticeEn), findsOneWidget);
    });

    testWidgets('the offer copy DOES localize', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        systemMessageBubbleAccepted,
        locale: const Locale('ar'),
      );

      expect(find.text('تم قبول عرض Kamal Hajj'), findsOneWidget);
      expect(find.text("Kamal Hajj's offer was accepted"), findsNothing);
    });

    testWidgets('the pill centres in both directionalities', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, systemMessageBubbleAccepted);
      expect(
        tester.getCenter(find.text("Kamal Hajj's offer was accepted")).dx,
        closeTo(400, 0.5),
      );

      await pumpPreview(
        tester,
        systemMessageBubbleAccepted,
        locale: const Locale('ar'),
      );
      expect(
        tester.getCenter(find.text('تم قبول عرض Kamal Hajj')).dx,
        closeTo(400, 0.5),
      );
    });

    testWidgets('long copy wraps inside the gutters instead of running past '
        'them', (WidgetTester tester) async {
      await pumpPreview(tester, systemMessageBubbleLongName);

      expect(tester.getSize(find.byType(SystemMessageBubble)).width, 390);

      final double textWidth = tester
          .getSize(
            find.text(
              "Abdulrahman Al-Muhandis Al-Trabulsi's offer was accepted",
            ),
          )
          .width;
      expect(textWidth, lessThanOrEqualTo(390 - 32 - 32));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an Arabic server notice keeps the AMBIENT direction — no '
        'first-strong detection on this kind', (WidgetTester tester) async {
      await pumpPreview(tester, systemMessageBubbleServerNotice);

      final RenderParagraph arabicRow = tester.renderObject<RenderParagraph>(
        find.text('انتهت مهلة الطلب قبل أن يقبله أي جيبر.'),
      );
      expect(arabicRow.textDirection, TextDirection.ltr);
      expect(arabicRow.textAlign, TextAlign.center);
    });

    testWidgets('the long notice grows instead of overflowing at 200% text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: previewCanvas(systemMessageBubbleLongName, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();

      final Size text = tester.getSize(
        find.text("Abdulrahman Al-Muhandis Al-Trabulsi's offer was accepted"),
      );
      expect(text.width, lessThanOrEqualTo(390 - 32 - 32));
      expect(text.height, greaterThan(48));
      expect(tester.takeException(), isNull);
    });
  });
}
