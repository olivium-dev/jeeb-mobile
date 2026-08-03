// Render tests for the ClientLocationScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/client_location_screen_fixtures.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 1600);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  testPreviewsRender(
    'ClientLocationScreen',
    const <String, Widget Function()>{
      'Saved addresses · GPS resolved': clientLocationScreenSavedAddresses,
      'New customer · finding GPS': clientLocationScreenNewCustomer,
      'Cold load': clientLocationScreenColdLoad,
      'Saved addresses unavailable': clientLocationScreenSavedAddressesFailed,
      'GPS permission denied': clientLocationScreenGpsDenied,
      'Longest saved address': clientLocationScreenLongestContent,
    },
    expectedText: const <String, String>{
      // The seeded `Home` card's subtitle — present only where the default
      'Saved addresses · GPS resolved': 'Sassine Square, Ashrafieh',
      'New customer · finding GPS': 'Finding your location…',
      'Cold load': 'Location',
      'Saved addresses unavailable':
          'Could not load saved locations. Please try again.',
      'GPS permission denied': 'Location permission needed',
      'Longest saved address': ClientLocationScreenFixtures.longestSavedLabel,
    },
  );

  group('ClientLocationScreen preview specifics', () {
    // What makes the cold-load state itself, rather than "a screen rendered":
    testWidgets('cold load is a bare spinner with no create affordances', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationScreenColdLoad);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('What do you need?'), findsNothing);
      expect(find.text('Choose your location'), findsNothing);
      expect(find.text('Confirm location'), findsNothing);
      // …and the app bar is the only thing left, which is the string the
      expect(find.text('Location'), findsOneWidget);
    });

    // JM-024 AC2: the saved-addresses ENTRY row is unconditional, and only the
    testWidgets('the empty state keeps the entry row and drops the cards', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationScreenNewCustomer);

      expect(find.text('Saved addresses'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Office'), findsNothing);
      // The create affordances are all present — an empty list is not an error.
      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('New Location'), findsOneWidget);
      expect(find.text('Confirm location'), findsOneWidget);
    });

    // LocationSelectState.canConfirm: a failed saved-address read must degrade
    testWidgets('a failed saved-address read does not block the create flow', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationScreenSavedAddressesFailed);

      expect(
        find.text('Could not load saved locations. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('New Location'), findsOneWidget);
      expect(find.text('Confirm location'), findsOneWidget);
    });

    // JEBV4-176 (Q-060) regression guard, made visible: with the permission
    testWidgets('GPS denied offers recovery and cannot be confirmed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationScreenGpsDenied);

      expect(find.text('Location permission needed'), findsOneWidget);
      expect(
        tester
            .widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton))
            .isEnabled,
        isFalse,
      );
    });

    // The disabled Confirm CTA is NOT proof of the GPS gate on its own: the
    testWidgets('the healthy state disables Confirm for the same-looking reason',
        (WidgetTester tester) async {
      await pumpPreview(tester, clientLocationScreenSavedAddresses);

      expect(find.text('Using your current location'), findsOneWidget);
      expect(
        tester
            .widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton))
            .isEnabled,
        isFalse,
        reason: 'GPS resolved, but the description gate is still empty — and '
            'nothing on screen says which of the two is holding it',
      );
      // No inline error either, because `_touched` is false until the customer
      expect(find.text('Please describe what you need.'), findsNothing);
    });

    // The label and the subtitle both truncate rather than wrap, so a customer
    testWidgets('the longest saved address truncates on one line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationScreenLongestContent);

      for (final String copy in <String>[
        ClientLocationScreenFixtures.longestSavedLabel,
        ClientLocationScreenFixtures.longestSavedAddress,
      ]) {
        final Text text = tester.widget<Text>(find.text(copy));
        expect(text.overflow, TextOverflow.ellipsis, reason: copy);

        final RenderParagraph paragraph =
            tester.renderObject<RenderParagraph>(find.text(copy));
        expect(
          paragraph.getMaxIntrinsicWidth(double.infinity),
          greaterThan(paragraph.size.width),
          reason: '$copy wants more width than the card gives it',
        );
      }
    });

    // The seeds are shared with the Screen Catalog entry precisely so the two
    testWidgets('the previews are driven by the shared catalog fixtures', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationScreenSavedAddresses);

      final ClientLocationScreen screen =
          tester.widget<ClientLocationScreen>(find.byType(ClientLocationScreen));
      expect(screen.userId, ClientLocationScreenFixtures.userId);
      expect(screen.repository, same(ClientLocationScreenFixtures.savedAddresses));
      expect(
        screen.currentLocationResolver,
        same(ClientLocationScreenFixtures.gpsResolved),
      );
    });
  });
}
