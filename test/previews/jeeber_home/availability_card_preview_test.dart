// Render tests for the AvailabilityCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Pinning a DISTINCT string per state matters more than usual here. All five
// previews are the same widget fed the same value object with one field
// changed, and three of them render the same `OMDSSectionCard` chrome under the
// same "Availability" heading — so a suite that only asserted "something
// rendered" would still pass if every fixture collapsed onto one state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_card.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  // The two resting states plus auto-offline. The two in-flight previews cannot
  // settle — see the dedicated group below.
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
      // The switch TITLE, not the subtitle: 'Auto-offline after 8 h idle' also
      // renders in the online in-flight preview, so it could not tell these
      // two states apart.
      'Auto-offline · with idle hint': 'Automatically taken offline',
    },
  );

  // The in-flight previews hold an indeterminate `CircularProgressIndicator`
  // (`OmdsLoadingState`). `pumpAndSettle` — which `pumpPreview` calls — never
  // returns while one is on screen, so these two get the same three assertions
  // the shared suite makes (builds in EN, builds in AR, renders its OWN state)
  // driven by fixed pumps instead.
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
      // The status was OFFLINE when the PUT went out, so the online-only
      // supporting lines stay away. That combination is true of no other
      // preview in this file.
      expect(find.text('3 active deliveries'), findsNothing);
      expect(find.text('Auto-offline after 8 h idle'), findsNothing);
    });

    testWidgets('Toggling · online, 3 deliveries renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpInFlight(tester, availabilityCardTogglingWithDeliveries);

      // Still `online` until the gateway confirms, so the supporting lines
      // ride along with the progress headline.
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
    // The online/offline pair is the whole point of this file: same widget,
    // same box, two different LAYOUTS. If the compact branch ever regressed to
    // the section, every text assertion above would still pass.
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

    // The online track colour comes from the semantic success role, not the
    // theme primary. A fallback to primary is invisible in a text assertion and
    // nearly invisible in the light rendering of the canvas.
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

    // Auto-offline is the ONLY resting state with a subtitle. Losing it would
    // make a system-initiated offline indistinguishable from the Jeeber's own
    // toggle — the §G2 regression the hint was added for.
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

    // The compact branch clamps its copy to two lines and ellipsizes rather
    // than growing. That clamp is what truncates the online copy at 200% text
    // on every phone narrower than ~430 pt (see the preview's doc comment) —
    // pin it so the trade-off cannot be changed by accident in either
    // direction.
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
