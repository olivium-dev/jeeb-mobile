// Render tests for the GpsPermissionBanner previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/widgets/gps_permission_banner.dart';

import '../preview_test_harness.dart';

/// The two body strings, verbatim from `lib/l10n/app_en.arb`. They are the
/// per-state fingerprints: the boolean the banner takes swaps the body and the
const String _retryBody =
    'Your customer can’t see where you are. Allow location access so Jeeb can '
    'share your position while you’re on the way.';
const String _settingsBody =
    'Your customer can’t see where you are. Open settings and set location '
    'access to “Allow all the time” so Jeeb can share your position while '
    'you’re on the way.';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'GpsPermissionBanner',
    const <String, Widget Function()>{
      'Recoverable denial': gpsPermissionBannerRecoverable,
      'Needs system settings': gpsPermissionBannerNeedsSystemSettings,
      'Small phone 320dp': gpsPermissionBannerSmallPhone,
      'First item in delivery list': gpsPermissionBannerInDeliveryList,
    },
    expectedText: const <String, String>{
      // The CTA labels distinguish the two data states; the body strings
      'Recoverable denial': 'Allow location',
      'Needs system settings': 'Open settings',
      'Small phone 320dp': _settingsBody,
      'First item in delivery list': _retryBody,
    },
  );

  group('GpsPermissionBanner preview specifics', () {
    testWidgets('the recoverable state offers the in-app prompt ONLY', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, gpsPermissionBannerRecoverable);

      expect(find.text('Allow location'), findsOneWidget);
      expect(find.text(_retryBody), findsOneWidget);
      // Sending a recoverable denial to the settings app is a four-screen
      expect(find.text('Open settings'), findsNothing);
      expect(find.text(_settingsBody), findsNothing);
    });

    testWidgets('the permanent denial offers settings ONLY', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, gpsPermissionBannerNeedsSystemSettings);

      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text(_settingsBody), findsOneWidget);
      // A retry here fires a request Android 11+ silently drops — which is the
      expect(find.text('Allow location'), findsNothing);
      expect(find.text(_retryBody), findsNothing);
    });

    testWidgets('mirrors in RTL — the icon keeps the LEADING edge', (
      WidgetTester tester,
    ) async {
      Future<double> iconOffsetFromBandStart(Locale locale) async {
        await pumpPreview(
          tester,
          gpsPermissionBannerNeedsSystemSettings,
          locale: locale,
        );
        final Rect band = tester.getRect(
          find.byKey(GpsPermissionBanner.bannerKey),
        );
        final Rect icon = tester.getRect(
          find.byIcon(Icons.location_off_outlined),
        );
        return icon.center.dx - band.center.dx;
      }

      expect(await iconOffsetFromBandStart(const Locale('en')), isNegative);
      expect(await iconOffsetFromBandStart(const Locale('ar')), isPositive);
    });

    testWidgets(
      'KNOWN DEFECT: the CTA label overflows the band at 200% text',
      (WidgetTester tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pumpPreview(tester, gpsPermissionBannerRecoverable);

        // `OMDSOutlinedButton` lays its label out as the lone non-flex child of
        final Object? error = tester.takeException();
        expect(
          error,
          isFlutterError,
          reason: 'expected the CTA label to overflow at 200% text',
        );
        expect(error.toString(), contains('overflowed'));

        // The rest of the band degrades correctly: the copy reflows and the
        expect(find.text(_retryBody), findsOneWidget);
      },
    );

    testWidgets('the CTA stays independently addressable (Maestro/gestures)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, gpsPermissionBannerInDeliveryList);

      // `explicitChildNodes: true` on the banner is what keeps the button's own
      expect(find.byType(OMDSOutlinedButton), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('active_delivery_gps_permission_cta'),
        findsOneWidget,
      );
    });
  });
}
