// Render tests for the ClientLocationScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// Two deviations from the widget-level preview tests in this folder, both
// because the subject is a whole screen rather than a row:
//
//  1. The surface is resized to a phone WIDTH and a very tall height. The
//     harness pumps 800x600 by default, on which this screen's `ListView`
//     builds roughly half its children — the recipient-phone field and the
//     saved-address cards would simply not exist for `find.text`, and the 800pt
//     width is not a layout any customer ever sees. 390pt is the phone the
//     previews are sized for; the height is generous so every child is laid out
//     without scrolling the finder around.
//  2. `Cold load` is the one state whose `expectedText` cannot be unique: it
//     renders exactly one string, the app-bar title, which every other state
//     renders too. The map entry is kept for completeness and the real pinning
//     is done by the dedicated test below, which asserts the three things that
//     are true ONLY of the cold-load state.

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
      // saved-address seed loaded.
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
    // a spinner, and the ABSENCE of every affordance the create step exists
    // for — including the sticky Confirm footer, which `_ConfirmFooter`
    // collapses to `SizedBox.shrink()` while the status is initial/loading.
    testWidgets('cold load is a bare spinner with no create affordances', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationScreenColdLoad);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('What do you need?'), findsNothing);
      expect(find.text('Choose your location'), findsNothing);
      expect(find.text('Confirm location'), findsNothing);
      // …and the app bar is the only thing left, which is the string the
      // harness pins for this state.
      expect(find.text('Location'), findsOneWidget);
    });

    // JM-024 AC2: the saved-addresses ENTRY row is unconditional, and only the
    // selectable CARDS are gated on a non-empty list. That is a deliberate
    // decision (the manager owns its own empty state), so it is pinned rather
    // than reported — but it does mean a customer with zero saved addresses
    // gets a row that looks exactly like a customer with ten.
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
    // the sub-list ONLY. If this ever starts hiding the create affordances,
    // every customer with a flaky connection loses order creation entirely.
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
    // denied there is no real fix, so the current-location option must NOT be
    // confirmable. The old code fell through to `33.8886, 35.4955` here and
    // created a request pinned to downtown Beirut.
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
    // same button is disabled in the fully-healthy state too, because the
    // required "What do you need?" text is empty and no preview can seed it.
    // Pinned so the assertion above is read for what it is, and so the
    // indistinguishable-CTA finding does not quietly get "fixed" by accident.
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
      // interacts with the field.
      expect(find.text('Please describe what you need.'), findsNothing);
    });

    // The label and the subtitle both truncate rather than wrap, so a customer
    // whose saved addresses share a prefix cannot tell two cards apart. Pinned
    // against the intrinsic width so it keeps meaning the same thing if the
    // text theme changes.
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
    // cannot drift. If someone re-points a preview at a local fake, this fails
    // and the catalog stops being the same screen the canvas shows.
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
