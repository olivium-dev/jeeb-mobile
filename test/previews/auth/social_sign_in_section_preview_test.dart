// Render tests for the SocialSignInSection previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every state pins a DISTINCT string, and the
// three states whose difference is *which pill is busy* additionally pin the
// pair of labels that is true of no other preview here — otherwise five
// previews of the same two buttons would all pass while showing the same thing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/previews/auth/social_sign_in_section_preview.dart';

import '../preview_test_harness.dart';

/// The label a busy pill collapses to (`SocialSignInSection` swaps the whole
/// text for it while that provider's sheet is open).
const String _busy = '…';
const String _google = 'Continue with Google';
const String _apple = 'Continue with Apple';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Network error · snackbar`, which cannot settle — see
  // the dedicated group below.
  testPreviewsRender(
    'SocialSignInSection',
    const <String, Widget Function()>{
      'Idle · both providers': socialSignInSectionIdle,
      'Google in flight': socialSignInSectionGoogleInFlight,
      'Apple in flight': socialSignInSectionAppleInFlight,
      'Collision · block sheet': socialSignInSectionCollisionSheet,
    },
    expectedText: const <String, String>{
      // The provider that is NOT the one in flight below, so this state cannot
      // be confused with either busy rendering.
      'Idle · both providers': _apple,
      // Only the busy pill collapses to the ellipsis.
      'Google in flight': _busy,
      // Apple is the busy one here, so Google is the label still on screen.
      'Apple in flight': _google,
      // Sheet copy, pushed through the real listener — no other preview has it.
      'Collision · block sheet': 'You already have an account',
    },
  );

  // The error path ends in a `SnackBar`, whose 4s auto-dismiss Timer is still
  // pending when `pumpAndSettle` returns (the entrance animation finishes long
  // before the timer fires), and a pending timer fails the test at teardown.
  // So this preview gets the same three assertions the shared suite makes —
  // builds in EN, builds in AR, renders its OWN state — driven by fixed pumps,
  // then drains the timer.
  group('SocialSignInSection previews · Network error · snackbar', () {
    Future<void> pumpSnackbar(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(socialSignInSectionNetworkErrorSnackbar, locale),
      );
      await tester.pump(); // localizations + the post-frame signInWith
      await tester.pump(); // the cubit's failed emit reaches the listener
      await tester.pump(const Duration(milliseconds: 750)); // snackbar entrance
    }

    /// Runs the 4s auto-dismiss timer out so the test ends timer-free.
    Future<void> drain(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Network error · snackbar · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSnackbar(tester, locale: locale);

        expect(tester.takeException(), isNull);
        await drain(tester);
      });
    }

    testWidgets('Network error · snackbar renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpSnackbar(tester);

      // The network copy specifically — not the generic fallback that
      // cancelled/unknown map to.
      expect(
        find.text("Couldn't reach Jeeb. Check your connection and try again."),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      await drain(tester);
    });

    testWidgets('the row is left re-armed once the error is shown', (
      WidgetTester tester,
    ) async {
      await pumpSnackbar(tester);

      // `clearError()` in the listener drops the cubit back to idle, so both
      // pills carry their labels again — a failure must never strand the row
      // in its busy rendering.
      expect(find.text(_google), findsOneWidget);
      expect(find.text(_apple), findsOneWidget);
      expect(find.text(_busy), findsNothing);
      await drain(tester);
    });
  });

  group('SocialSignInSection preview specifics', () {
    testWidgets('idle offers both providers and nothing is busy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInSectionIdle);

      expect(find.text(_google), findsOneWidget);
      expect(find.text(_apple), findsOneWidget);
      expect(find.text(_busy), findsNothing);
    });

    // One preview per test, deliberately: pumping a second preview into the
    // same tester UPDATES the tree instead of rebuilding it, and `BlocProvider`
    // holds on to the cubit it already created — so a second `pumpPreview` here
    // would silently re-assert the first preview's state.
    testWidgets('Google in flight collapses only the Google pill', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInSectionGoogleInFlight);

      expect(find.text(_google), findsNothing);
      expect(find.text(_apple), findsOneWidget);
      expect(find.text(_busy), findsOneWidget);
    });

    testWidgets('Apple in flight collapses only the Apple pill', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInSectionAppleInFlight);

      // Exactly the other way round from the Google case. That pair of
      // assertions is what tells the two busy previews apart; the ellipsis
      // alone would not.
      expect(find.text(_apple), findsNothing);
      expect(find.text(_google), findsOneWidget);
      expect(find.text(_busy), findsOneWidget);
    });

    testWidgets('a sign-in in flight disables the OTHER provider too', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, socialSignInSectionGoogleInFlight);

      // `isEnabled: !state.isBusy` — one native sheet at a time. The cubit
      // ignores a second tap anyway, but the row must not advertise a live
      // target while it does.
      for (final String id in const <String>[
        'login_social_google',
        'login_social_apple',
      ]) {
        expect(
          tester.getSemantics(find.bySemanticsIdentifier(id)),
          isSemantics(identifier: id, isButton: true, isEnabled: false),
          reason: '$id must read as disabled while a sign-in is in flight',
        );
      }
      handle.dispose();
    });

    testWidgets('the collision preview pushes the REAL modal sheet', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInSectionCollisionSheet);

      // Pushed by the section's own listener via `showSocialCollisionSheet`,
      // not hand-placed: this is the only preview that covers D22's entry
      // point, and a sheet-shaped frame is the proof.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('You already have an account'), findsOneWidget);
    });

    testWidgets('dismissing the collision sheet re-arms the buttons (JM-019)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInSectionCollisionSheet);

      await tester.tap(
        find.byKey(const Key('registration.socialCollisionDismiss')),
      );
      await tester.pumpAndSettle();

      // `acknowledgeCollision()` ran: the sheet is gone and it does not
      // re-fire on the next rebuild, which is the bug it was written around.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('You already have an account'), findsNothing);
      expect(find.text(_google), findsOneWidget);
      expect(find.text(_apple), findsOneWidget);
    });

    testWidgets('the bare previews carry no sheet and no snackbar', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInSectionIdle);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
