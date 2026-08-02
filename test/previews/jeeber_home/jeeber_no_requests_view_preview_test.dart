// Render tests for the JeeberNoRequestsView previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_card.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/inactivity_warning_banner.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart';

import '../preview_test_harness.dart';

/// The empty state is the one band present in EVERY state of this view — it is
/// what tells the Jeeber the feed is live but quiet rather than broken.
const Key _kEmptyStateKey = Key('jeeber-no-requests-empty-state');

/// The longest-content preview's first row. Declared here so a preview quietly
/// rewired to a short name fails instead of silently losing the one state that
const String _kLongCounterpart = 'Marie-Christine Abou Jaoudé';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Toggle in flight`, which cannot settle — see the
  testPreviewsRender(
    'JeeberNoRequestsView',
    const <String, Widget Function()>{
      'Online · quiet feed': jeeberNoRequestsViewOnline,
      'Offline · full section': jeeberNoRequestsViewOffline,
      'Auto-offline · system flipped': jeeberNoRequestsViewAutoOffline,
      'Idle warning · 30 min to auto-offline': jeeberNoRequestsViewIdleWarning,
      'Active work · longest content': jeeberNoRequestsViewActiveWork,
    },
    expectedText: const <String, String>{
      // The only state with this name on file; the other online states share a
      'Online · quiet feed': 'Hello, Karim',
      'Offline · full section': "You're offline",
      'Auto-offline · system flipped': 'Automatically taken offline',
      'Idle warning · 30 min to auto-offline': 'Still there?',
      'Active work · longest content': '2 active deliveries',
    },
  );

  group('JeeberNoRequestsView previews · Toggle in flight', () {
    // The in-flight card swaps the switch for an indeterminate
    Future<void> pumpInFlight(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(jeeberNoRequestsViewToggleInFlight, locale),
      );
      await tester.pump(); // the banner's canned fetch resolves
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Toggle in flight · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpInFlight(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Toggle in flight renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpInFlight(tester);

      expect(find.text('Updating…'), findsOneWidget);
      expect(find.byKey(AvailabilityCard.spinnerKey), findsOneWidget);
      expect(
        find.byKey(AvailabilityCard.toggleKey),
        findsNothing,
        reason: 'Nothing may be tappable while the toggle PUT is out.',
      );
      // The write being in flight must not blank the rest of the surface.
      expect(find.byKey(_kEmptyStateKey), findsOneWidget);
    });
  });

  group('JeeberNoRequestsView preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    testWidgets('every settleable state keeps the empty state on screen', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        jeeberNoRequestsViewOnline,
        jeeberNoRequestsViewOffline,
        jeeberNoRequestsViewAutoOffline,
        jeeberNoRequestsViewIdleWarning,
        jeeberNoRequestsViewActiveWork,
      ]) {
        await tester.pumpWidget(previewCanvas(preview, const Locale('en')));
        await tester.pumpAndSettle();

        expect(find.byKey(JeeberNoRequestsView.rootKey), findsOneWidget);
        expect(find.byKey(_kEmptyStateKey), findsOneWidget);
        expect(find.text('No requests right now'), findsOneWidget);
      }
    });

    testWidgets('online collapses availability to ONE compact row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberNoRequestsViewOnline);

      expect(find.byKey(AvailabilityCard.toggleKey), findsOneWidget);
      expect(
        find.byType(OMDSSectionCard),
        findsNothing,
        reason: 'The full section is reserved for offline/toggling states.',
      );
      // Nothing else is competing for the band: no warning, no won work.
      expect(find.byKey(InactivityWarningBanner.rootKey), findsNothing);
      expect(find.text('Open chat'), findsNothing);
    });

    testWidgets('offline uses the full section and NO auto-offline hint', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberNoRequestsViewOffline);

      expect(find.byType(OMDSSectionCard), findsOneWidget);
      expect(
        find.text('Auto-offline after 8 h idle'),
        findsNothing,
        reason: 'The idle hint belongs to the auto-offline state only.',
      );
      // No name on file → the generic greeting, never a blank line.
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('auto-offline explains itself with the idle hint', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberNoRequestsViewAutoOffline);

      expect(find.byType(OMDSSectionCard), findsOneWidget);
      expect(find.text('Auto-offline after 8 h idle'), findsOneWidget);
      expect(
        find.text("You're offline"),
        findsNothing,
        reason: 'A system-initiated offline must not read as a self-toggle.',
      );
    });

    testWidgets('the idle warning carries its extend CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberNoRequestsViewIdleWarning);

      expect(find.byKey(InactivityWarningBanner.rootKey), findsOneWidget);
      expect(find.byKey(InactivityWarningBanner.ctaKey), findsOneWidget);
      expect(find.text("I'm still here"), findsOneWidget);
    });

    testWidgets('won work stays reachable: one row + CTA per accepted order', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberNoRequestsViewActiveWork);

      expect(find.text(_kLongCounterpart), findsOneWidget);
      // Two CTAs, not one: the second won order carries no counterpart name,
      expect(find.text('Open chat'), findsNWidgets(2));
      // The band is additive — it must not displace the empty state.
      expect(find.byKey(_kEmptyStateKey), findsOneWidget);
    });
  });
}
