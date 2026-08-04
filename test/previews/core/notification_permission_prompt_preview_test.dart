// Render tests for the NotificationPermissionPrompt previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/presentation/notification_permission_prompt.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Shipped defaults (390pt)': notificationPermissionPromptDefault,
  'After a denial (settings deep-link)': notificationPermissionPromptAfterDenial,
  'Arabic copy (320pt)': notificationPermissionPromptArabicCopy,
  'Long copy (wraps, card grows)': notificationPermissionPromptLongCopy,
  'Long action labels (row overflows)':
      notificationPermissionPromptLongActionLabels,
};

final Finder _card = find.byType(NotificationPermissionPrompt);
final Finder _enable = find.byKey(const Key('notif_perm_enable'));
final Finder _dismiss = find.byKey(const Key('notif_perm_dismiss'));

/// Pumps [preview] on a real phone-sized viewport instead of the 800x600 test
/// surface, optionally at a raised text scale. Both overflow tests need the
Future<void> _pumpOnPhone(
  WidgetTester tester,
  Widget Function() preview, {
  double width = 390,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadPreviewArbs);
  setUp(notificationPermissionPromptResetTaps);

  testPreviewsRender(
    'NotificationPermissionPrompt',
    _previews,
    expectedText: const <String, String>{
      'Shipped defaults (390pt)': 'Turn on notifications',
      'After a denial (settings deep-link)': 'Notifications are off',
      'Arabic copy (320pt)': 'فعّل الإشعارات',
      'Long copy (wraps, card grows)':
          'Turn on delivery and chat notifications for this account',
      'Long action labels (row overflows)': 'Stay in the loop',
    },
  );

  group('NotificationPermissionPrompt preview specifics', () {
    testWidgets('the default preview really uses the shipped defaults', (
      WidgetTester tester,
    ) async {
      // Built with no copy arguments, so this is the copy a caller gets today.
      await pumpPreview(tester, notificationPermissionPromptDefault);

      expect(find.text('Turn on notifications'), findsOneWidget);
      expect(
        find.text(
          'Get delivery updates and chat messages the moment they happen, '
          'even when the app is closed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Enable notifications'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('both actions are really live', (WidgetTester tester) async {
      // A priming card whose buttons are wired to `() {}` looks identical to
      await pumpPreview(tester, notificationPermissionPromptDefault);

      await tester.tap(_enable);
      await tester.pump();
      expect(notificationPermissionPromptTaps['enable'], 1);
      expect(notificationPermissionPromptTaps['dismiss'], 0);

      await tester.tap(_dismiss);
      await tester.pump();
      expect(notificationPermissionPromptTaps['dismiss'], 1);
      expect(notificationPermissionPromptTaps['enable'], 1);
    });

    testWidgets('the card mirrors in Arabic', (WidgetTester tester) async {
      await pumpPreview(tester, notificationPermissionPromptArabicCopy);
      Rect card = tester.getRect(_card);
      expect(
        tester.getRect(_enable).right,
        lessThan(card.right),
        reason: 'LTR: the primary action sits at the trailing (right) end',
      );
      expect(tester.getRect(_enable).left,
          greaterThan(tester.getRect(_dismiss).left));

      await pumpPreview(
        tester,
        notificationPermissionPromptArabicCopy,
        locale: const Locale('ar'),
      );
      card = tester.getRect(_card);
      expect(
        tester.getRect(_enable).left,
        lessThan(tester.getRect(_dismiss).left),
        reason: 'AR: the primary action must move to the leading (left) end',
      );
      expect(tester.getRect(_enable).left, greaterThanOrEqualTo(card.left));
    });

    testWidgets('long copy grows the card instead of clipping it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationPermissionPromptDefault);
      final double defaultHeight = tester.getSize(_card).height;

      await pumpPreview(tester, notificationPermissionPromptLongCopy);
      final double longHeight = tester.getSize(_card).height;

      expect(
        longHeight,
        greaterThan(defaultHeight),
        reason: 'the body sets no maxLines, so the card must grow',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('long action labels overflow the row on a compact device', (
      WidgetTester tester,
    ) async {
      // `_PromptActions` is a bare Row of two intrinsically-sized buttons with
      await _pumpOnPhone(
        tester,
        notificationPermissionPromptLongActionLabels,
        width: 320,
      );

      expect(
        tester.takeException().toString(),
        contains('overflowed'),
        reason: 'the action row cannot absorb its own labels',
      );
    });

    testWidgets('the SHIPPED labels overflow at the 200% ceiling', (
      WidgetTester tester,
    ) async {
      // The same defect, reached without touching the copy: the buttons follow
      await _pumpOnPhone(
        tester,
        notificationPermissionPromptDefault,
        textScale: 2.0,
      );

      expect(
        tester.takeException().toString(),
        contains('overflowed'),
        reason: 'default copy on a 390pt phone at the accessibility ceiling',
      );
    });

    testWidgets('the action row has no give — it overflows, never shrinks', (
      WidgetTester tester,
    ) async {
      // The font-independent half of the two tests above, and the reason both
      await _pumpOnPhone(tester, notificationPermissionPromptDefault,
          width: 800);
      final double roomy = tester.getSize(_enable).width;
      expect(tester.takeException(), isNull);

      await _pumpOnPhone(tester, notificationPermissionPromptDefault,
          width: 390);
      final double cramped = tester.getSize(_enable).width;

      expect(
        cramped,
        roomy,
        reason: 'OmdsPrimaryButton sizes to its label and the Row wraps it in '
            'neither Flexible nor Expanded, so a narrower card takes nothing '
            'off the button',
      );
      expect(tester.takeException().toString(), contains('overflowed'));
    });
  });
}
