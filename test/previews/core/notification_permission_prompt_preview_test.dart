// Render tests for the NotificationPermissionPrompt previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`: every preview builds in both
// locales, and each one is pinned to a string only IT renders — the widget's
// whole input surface is four strings, so identical copy would mean identical
// states.
//
// Below that, the assertions the canvas can only show a human: that the
// injected actions are really wired, that the card mirrors in Arabic, and that
// the action row overflows once the labels outgrow the card — on a compact
// device, and with the SHIPPED labels at the 200% accessibility ceiling.
//
// One caveat on the overflow numbers. `flutter test` substitutes the
// `FlutterTest` font, whose glyphs are considerably wider than the shipped
// one's, so the *threshold* at which these rows overflow here is more
// pessimistic than on a device — the shipped labels overflow a 390pt card in
// this font at 1.0, and would not on a phone. The claims that do NOT depend on
// the font are the two the suite leans on: doubling the text scale roughly
// doubles a row that already fills most of the card, and — see "the action row
// has no give" — nothing in that row can shrink to absorb either.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/presentation/notification_permission_prompt.dart';
import 'package:jeeb_mobile/previews/core/notification_permission_prompt_preview.dart';

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
/// card to be as narrow as it is on a device — at 800pt wide nothing overflows
/// and the defect is invisible.
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
  setUp(resetNotificationPermissionPromptTaps);

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
      // If someone edits `_defaultBody` and not this test, this is what says so.
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
      // one whose buttons are wired to nothing at all.
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
      // no Flexible, no Wrap and no stacked fallback, so once both labels
      // together outgrow the card's content width the row overflows rather
      // than shrinking. Ordinary product copy on a 320pt phone is enough.
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
      // the text scaler and the card does not. This is the rendering the
      // `EN 200% text` variant of every preview in this file shows.
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
      // of them fail rather than merely looking tight: nothing in the row can
      // absorb a narrower card. Give the same card a roomy 800pt and a real
      // 390pt phone and the primary button is the SAME width in both — so the
      // shortfall is paid entirely in overflow.
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
