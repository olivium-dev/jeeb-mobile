// Render tests for the DeliveryLifecycleBanner previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_lifecycle_banner.dart';

import '../preview_test_harness.dart';

const String _completedCopy = 'Delivered successfully';
const String _cancelledCopy = 'Delivery cancelled';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryLifecycleBanner',
    const <String, Widget Function()>{
      'Completed': deliveryLifecycleBannerCompleted,
      'Cancelled': deliveryLifecycleBannerCancelled,
      'Active · collapsed': deliveryLifecycleBannerActive,
      'Small phone 320dp': deliveryLifecycleBannerSmallPhone,
      'Terminal pair · contrast': deliveryLifecycleBannerTerminalPair,
    },
    expectedText: const <String, String>{
      'Completed': 'Delivery #d-2481',
      'Cancelled': 'Delivery #d-3067',
      'Active · collapsed': 'Delivery #d-4192',
      'Small phone 320dp': 'Delivery #d-5510',
      'Terminal pair · contrast': 'Delivery #d-6733',
    },
  );

  group('DeliveryLifecycleBanner preview specifics', () {
    testWidgets('the active preview paints NO band at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryLifecycleBannerActive);

      // The widget is mounted — the screen always builds it — but it must
      expect(find.byType(DeliveryLifecycleBanner), findsOneWidget);
      expect(find.byKey(DeliveryLifecycleBanner.rootKey), findsNothing);
      expect(find.text(_completedCopy), findsNothing);
      expect(find.text(_cancelledCopy), findsNothing);
      expect(
        tester.getSize(find.byType(DeliveryLifecycleBanner)).height,
        0,
        reason: 'active must occupy zero height inside the stretched Column',
      );
    });

    testWidgets('completed and cancelled paint DIFFERENT semantic roles', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryLifecycleBannerTerminalPair);

      final List<Container> bands = tester
          .widgetList<Container>(find.byKey(DeliveryLifecycleBanner.rootKey))
          .toList();
      expect(bands, hasLength(2));

      final BuildContext context = tester.element(
        find.byType(DeliveryLifecycleBanner).first,
      );
      final Color completedBg = (bands[0].decoration! as BoxDecoration).color!;
      final Color cancelledBg = (bands[1].decoration! as BoxDecoration).color!;

      expect(completedBg, context.jeebRoles.successContainer);
      expect(cancelledBg, Theme.of(context).colorScheme.errorContainer);
      expect(
        completedBg,
        isNot(cancelledBg),
        reason: 'the two terminal states must stay distinguishable',
      );
      expect(
        completedBg,
        isNot(Theme.of(context).colorScheme.tertiaryContainer),
        reason: 'completed was moved OFF the brand tertiary orange onto the '
            'semantic success role; this guards the swap',
      );
    });

    testWidgets('the copy is localized, never hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        deliveryLifecycleBannerTerminalPair,
        locale: const Locale('ar'),
      );

      expect(find.text(_completedCopy), findsNothing);
      expect(find.text(_cancelledCopy), findsNothing);
      expect(find.text('تم التسليم بنجاح'), findsOneWidget);
      expect(find.text('تم إلغاء التوصيلة'), findsOneWidget);
    });

    testWidgets('the band mirrors in RTL — icon takes the trailing edge', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryLifecycleBannerCompleted);
      final double ltrIconX =
          tester.getCenter(find.byIcon(Icons.check_circle_outline)).dx;
      final double ltrTextX = tester.getCenter(find.text(_completedCopy)).dx;
      expect(ltrIconX, lessThan(ltrTextX));

      await pumpPreview(
        tester,
        deliveryLifecycleBannerCompleted,
        locale: const Locale('ar'),
      );
      final double rtlIconX =
          tester.getCenter(find.byIcon(Icons.check_circle_outline)).dx;
      final double rtlTextX = tester.getCenter(find.text('تم التسليم بنجاح')).dx;
      expect(
        rtlIconX,
        greaterThan(rtlTextX),
        reason: 'the Row must flip with Directionality, not stay pinned left',
      );
    });

    testWidgets('at 200% text on a 320 dp phone the band wraps, not overflows',
        (WidgetTester tester) async {
      await pumpPreview(tester, deliveryLifecycleBannerSmallPhone);
      final Size oneX =
          tester.getSize(find.byKey(DeliveryLifecycleBanner.rootKey));

      tester.view.physicalSize = const Size(320 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(tester, deliveryLifecycleBannerSmallPhone);
      final Size twoX =
          tester.getSize(find.byKey(DeliveryLifecycleBanner.rootKey));

      expect(tester.takeException(), isNull);
      expect(
        twoX.width,
        oneX.width,
        reason: 'the band is width-bound by the screen padding at any scale',
      );
      expect(
        twoX.height,
        greaterThan(oneX.height),
        reason: 'the sentence must wrap and push the band taller rather than '
            'clip — the widget calls itself single-line, and at 200% it is not',
      );
    });

    testWidgets('at 200% the icon neither scales nor holds the first line', (
      WidgetTester tester,
    ) async {
      // Records the CURRENT behaviour the 200% rendering of the preview matrix
      tester.view.physicalSize = const Size(320 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(tester, deliveryLifecycleBannerSmallPhone);

      final Rect icon = tester.getRect(
        find.byIcon(Icons.check_circle_outline),
      );
      final Rect text = tester.getRect(find.text(_completedCopy));
      expect(icon.height, 24.0);
      expect(
        icon.center.dy,
        greaterThan(text.top + 24),
        reason: 'the icon floats to the middle of the wrapped block',
      );
      expect(
        text.right,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(DeliveryLifecycleBanner.rootKey)).right,
        ),
        reason: 'wrapping must stay inside the band, never bleed past it',
      );
    });
  });
}
