// Render tests for the ProfileTab previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// ProfileTab has no constructor arguments — its whole state space is the two
// ambient cubits (RoleCubit, LocaleCubit) — so the specifics group below pins
// the two things those cubits actually change: whether the Become-a-Jeeber card
// exists, and which row carries the check.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settings/presentation/widgets/become_jeeber_card.dart';
import 'package:jeeb_mobile/features/shell/tabs/profile_tab.dart';

import '../preview_test_harness.dart';

/// The trailing check inside the row keyed [rowKey], if any.
Finder _checkIn(String rowKey) => find.descendant(
      of: find.byKey(Key(rowKey)),
      matching: find.byIcon(Icons.check),
    );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ProfileTab',
    const <String, Widget Function()>{
      'Client': profileTabClient,
      'Jeeber': profileTabJeeber,
      'Arabic selected': profileTabArabicSelected,
      'Narrow 320': profileTabNarrowPhone,
      'Jeeber narrow · Arabic': profileTabJeeberNarrowArabic,
    },
    expectedText: const <String, String>{
      // Only a client sees the Become-a-Jeeber card at all.
      'Client': 'Become a Jeeber',
      // The card is gone; the Account section below it must survive intact.
      'Jeeber': 'Profile, notifications, addresses, and more',
      // The row the check has to move to.
      'Arabic selected': 'العربية',
      // The CTA that must not be squeezed out of the card's single Row.
      'Narrow 320': 'Start now',
      // The last row of the tab — proof the whole list still lays out at 320.
      'Jeeber narrow · Arabic': 'Settings',
    },
  );

  group('ProfileTab preview specifics', () {
    testWidgets('the Become-a-Jeeber card shows for a client', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileTabClient);

      expect(find.byKey(BecomeJeeberCard.rootKey), findsOneWidget);
      expect(find.byKey(BecomeJeeberCard.ctaKey), findsOneWidget);
    });

    testWidgets('and is gone entirely once the user is a jeeber (T-MOB-027 AC2)',
        (WidgetTester tester) async {
      await pumpPreview(tester, profileTabJeeber);

      expect(find.byKey(BecomeJeeberCard.rootKey), findsNothing);
      expect(find.text('Become a Jeeber'), findsNothing);
      expect(find.text('Start now'), findsNothing);
      // The rest of the tab is untouched by the card collapsing.
      expect(find.byKey(const Key('profile-tab-root')), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
    });

    // One pump per test, deliberately. Two previews pumped into the SAME
    // tester differ only in their cubits' seeds, and the widget trees are
    // structurally identical — so Flutter reuses the BlocProvider element and
    // never re-runs `create`, leaving the first preview's cubits in place.
    // Splitting the assertions is what makes them describe the state named in
    // the test.
    testWidgets('English selection puts the check on the English row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileTabClient);

      expect(_checkIn('settings-row-language-en'), findsOneWidget);
      expect(_checkIn('settings-row-language-ar'), findsNothing);
    });

    testWidgets('Arabic selection moves the check to the Arabic row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileTabArabicSelected);

      expect(_checkIn('settings-row-language-ar'), findsOneWidget);
      expect(_checkIn('settings-row-language-en'), findsNothing);
    });

    testWidgets('the client role puts the check on the Client row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileTabClient);

      expect(_checkIn('settings-row-role-client'), findsOneWidget);
      expect(_checkIn('settings-row-role-jeeber'), findsNothing);
    });

    testWidgets('the jeeber role puts the check on the Jeeber row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileTabJeeber);

      expect(_checkIn('settings-row-role-jeeber'), findsOneWidget);
      expect(_checkIn('settings-row-role-client'), findsNothing);
    });

    testWidgets('the narrow state really is laid out at 320 pt, not at the '
        '800 pt test surface', (WidgetTester tester) async {
      await pumpPreview(tester, profileTabNarrowPhone);

      expect(
        tester.getSize(find.byKey(const Key('profile-tab-root'))).width,
        320,
      );
    });

    testWidgets('the phone states are laid out at 390 pt', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileTabClient);

      expect(
        tester.getSize(find.byKey(const Key('profile-tab-root'))).width,
        390,
      );
    });
  });
}
