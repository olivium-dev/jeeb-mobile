// Render tests for the NotificationRow previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. `testPreviewsRender` pumps each state in BOTH
// locales and pins a string unique to that state — see
// `test/previews/preview_test_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/notifications/presentation/widgets/notification_row.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'NotificationRow',
    const <String, Widget Function()>{
      'Unread · offer': notificationRowUnreadOffer,
      'Read · order update': notificationRowRead,
      'New request · data-only push (G3)': notificationRowNewRequestFallback,
      'Unknown kind · nothing to render': notificationRowBarePayload,
      'Long payload · wraps, never clamps': notificationRowLongContent,
      'Unparseable timestamp · raw passthrough':
          notificationRowUnparsedTimestamp,
    },
    expectedText: const <String, String>{
      'Unread · offer': 'New offer on your request',
      'Read · order update': 'Your order is on the way',
      'New request · data-only push (G3)': 'New request nearby',
      'Unknown kind · nothing to render': 'Notification',
      'Long payload · wraps, never clamps':
          'Abdulrahman Al-Muhandis accepted your offer and is on the way to '
              'the pickup point',
      'Unparseable timestamp · raw passthrough': '18/06/2026 10:00 AM',
    },
  );

  group('NotificationRow preview specifics', () {
    testWidgets('eyebrow is distinct from the title (P0-X08)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationRowUnreadOffer);

      // Category label (derived from `kind`) and payload headline are two
      // different strings — never the same one rendered twice.
      expect(find.text('New offer'), findsOneWidget);
      expect(find.text('New offer on your request'), findsOneWidget);
      expect(find.text('Tap to review.'), findsOneWidget);
    });

    testWidgets('the relative timestamp is pinned, not wall-clock', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationRowUnreadOffer);

      // 2026-06-18T10:00:00Z read at the fixture's 12:00Z.
      expect(find.text('2h ago'), findsOneWidget);
    });

    testWidgets('unread shows the badge, read does not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationRowUnreadOffer);
      expect(
        find.bySemanticsIdentifier('notif_row_notif-001_unread_badge'),
        findsOneWidget,
      );

      await pumpPreview(tester, notificationRowRead);
      expect(
        find.bySemanticsIdentifier('notif_row_notif-005_unread_badge'),
        findsNothing,
      );
    });

    testWidgets('AR mirrors the icon and the unread dot (AC-16 FM1)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        notificationRowUnreadOffer,
        locale: const Locale('ar'),
      );

      final Finder row = find.byType(NotificationRow);
      final Rect rowRect = tester.getRect(row);
      expect(Directionality.of(tester.element(row)), TextDirection.rtl);
      // Leading icon swaps to the trailing (right) half, unread dot to the
      // leading (left) half.
      expect(
        tester.getRect(find.byIcon(Icons.local_offer_outlined)).center.dx,
        greaterThan(rowRect.center.dx),
      );
      expect(
        tester
            .getRect(
              find.bySemanticsIdentifier('notif_row_notif-001_unread_badge'),
            )
            .center
            .dx,
        lessThan(rowRect.center.dx),
      );
      // The eyebrow localizes; the payload title is server copy and does not.
      expect(find.text('عرض جديد'), findsOneWidget);
    });

    testWidgets('G3: a data-only new_request row is never blank', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationRowNewRequestFallback);

      expect(find.text('New request nearby'), findsOneWidget);
      expect(
        find.text('A customer is looking for a jeeber. Tap to view.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'the G3 fallback does NOT cover other kinds — an unknown-kind row with '
      'an empty payload renders the eyebrow alone',
      (WidgetTester tester) async {
        await pumpPreview(tester, notificationRowBarePayload);

        expect(find.text('Notification'), findsOneWidget);
        expect(find.text('New request nearby'), findsNothing);
        // Eyebrow only: no title, no body, no timestamp line.
        expect(find.byType(Text), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('notif_row_notif-unknown_timestamp'),
          findsNothing,
        );
      },
    );
  });
}
