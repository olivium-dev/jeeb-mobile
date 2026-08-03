import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_card.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'AvailabilityCard',
    const <String, Widget Function()>{
      'Online · compact row': availabilityCardOnline,
      'Offline · full section': availabilityCardOffline,
      'Auto-offline · with idle hint': availabilityCardAutoOffline,
    },
    expectedText: const <String, String>{
      'Online · compact row': "You're online — receiving requests",
      'Offline · full section': "You're offline",
      'Auto-offline · with idle hint': 'Automatically taken offline',
    },
  );

  group('AvailabilityCard previews · in-flight', () {
    Future<void> pumpInFlight(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(preview, locale));
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    const Map<String, Widget Function()> inFlight = <String, Widget Function()>{
      'Toggling · offline → online': availabilityCardToggling,
      'Toggling · online, 3 deliveries': availabilityCardTogglingWithDeliveries,
    };

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry
          in inFlight.entries) {
        testWidgets('${entry.key} · ${locale.languageCode}', (
          WidgetTester tester,
        ) async {
          await pumpInFlight(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('Toggling · offline → online renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpInFlight(tester, availabilityCardToggling);

      expect(find.text('Updating…'), findsOneWidget);
      expect(find.byKey(AvailabilityCard.spinnerKey), findsOneWidget);
      expect(find.text('3 active deliveries'), findsNothing);
      expect(find.text('Auto-offline after 8 h idle'), findsNothing);
    });

    testWidgets('Toggling · online, 3 deliveries renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpInFlight(tester, availabilityCardTogglingWithDeliveries);

      expect(find.text('Updating…'), findsOneWidget);
      expect(find.text('3 active deliveries'), findsOneWidget);
      expect(find.text('Auto-offline after 8 h idle'), findsOneWidget);
    });

    testWidgets('both in-flight previews replace the switch with the spinner', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in inFlight.values) {
        await pumpInFlight(tester, preview);

        expect(find.byKey(AvailabilityCard.spinnerKey), findsOneWidget);
        expect(
          find.byKey(AvailabilityCard.toggleKey),
          findsNothing,
          reason: 'No tappable switch while the PUT is in-flight.',
        );
      }
    });
  });

  group('AvailabilityCard preview specifics', () {
    testWidgets('online is the compact row — no section, no heading', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, availabilityCardOnline);

      expect(find.byType(OMDSSectionCard), findsNothing);
      expect(find.text('Availability'), findsNothing);
      expect(find.byKey(AvailabilityCard.toggleKey), findsOneWidget);
    });

    testWidgets('offline is the full section, switch OFF', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, availabilityCardOffline);

      expect(find.byType(OMDSSectionCard), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
      expect(
        tester
            .widget<OmdsSwitchTile>(find.byKey(AvailabilityCard.toggleKey))
            .value,
        isFalse,
      );
    });

    testWidgets('online track uses the semantic success role', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, availabilityCardOnline);

      final BuildContext context = tester.element(
        find.byKey(AvailabilityCard.rootKey),
      );
      final JeebColorRoles roles = Theme.of(
        context,
      ).extension<JeebColorRoles>()!;

      final OmdsSwitchTile tile = tester.widget<OmdsSwitchTile>(
        find.byKey(AvailabilityCard.toggleKey),
      );
      expect(tile.value, isTrue);
      expect(tile.activeColor, roles.success);
    });

    testWidgets('only auto-offline carries the idle hint at rest', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, availabilityCardAutoOffline);
      expect(find.text('Auto-offline after 8 h idle'), findsOneWidget);

      await pumpPreview(tester, availabilityCardOffline);
      expect(find.text('Auto-offline after 8 h idle'), findsNothing);

      await pumpPreview(tester, availabilityCardOnline);
      expect(find.text('Auto-offline after 8 h idle'), findsNothing);
    });

    testWidgets('the compact online copy is clamped to two lines', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, availabilityCardOnline);

      final DefaultTextStyle defaults = DefaultTextStyle.of(
        tester.element(find.text("You're online — receiving requests")),
      );
      expect(defaults.maxLines, 2);
      expect(defaults.overflow, TextOverflow.ellipsis);
    });
  });
}
