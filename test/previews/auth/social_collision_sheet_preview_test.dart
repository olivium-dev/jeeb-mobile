// Render tests for the SocialCollisionSheet previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// This widget makes the "does each preview render its OWN state?" question
// harder than usual: it takes no arguments and its copy is three fixed strings,
// so all four previews contain the same words and a pinned string alone cannot
// tell them apart. Each state therefore pins a DIFFERENT one of those strings,
// and the specifics group below pins the property that actually defines the
// state — the width it was squeezed to, the text scale it was rendered at, and
// whether it went through the real `showSocialCollisionSheet` route.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/auth/social/social_collision_sheet.dart';

import '../preview_test_harness.dart';

const String _title = 'You already have an account';
const String _body = 'This email is already registered with a different '
    'sign-in method. Please sign in the way you did the first time.';
const String _dismiss = 'Got it';

/// The dismiss CTA, keyed by production code.
final Finder _cta = find.byKey(
  const Key('registration.socialCollisionDismiss'),
);

/// Bottom inset the presented preview injects — a phone's home indicator.
const double _homeIndicator = 34;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SocialCollisionSheet',
    const <String, Widget Function()>{
      'Block prompt · phone width': socialCollisionSheetDefault,
      'Narrowest phone · 320dp': socialCollisionSheetNarrowPhone,
      'Text at 200% · phone window': socialCollisionSheetLargeText,
      'Presented over the sign-in screen': socialCollisionSheetPresented,
    },
    expectedText: const <String, String>{
      // The headline, which is what the block prompt is judged on.
      'Block prompt · phone width': _title,
      // The longest string, and the one whose wrapping the 320dp state exists
      // to show.
      'Narrowest phone · 320dp': _body,
      // At 200% the only question is whether the CTA survives to the bottom of
      // the sheet, so that is what this state pins.
      'Text at 200% · phone window': _dismiss,
      // The stand-in page under the sheet — no other preview has a page at all.
      'Presented over the sign-in screen': socialCollisionSheetHostLabel,
    },
  );

  group('SocialCollisionSheet preview specifics', () {
    // One preview per test, deliberately: pumping a second preview into the
    // same tester UPDATES the tree instead of rebuilding it, so a second
    // `pumpPreview` here could silently re-measure the first preview.

    testWidgets('the baseline is the phone-width body, no route', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialCollisionSheetDefault);

      expect(tester.getSize(find.byType(SocialCollisionSheet)).width, 390);
      // Built directly, so there is no sheet frame and no scrim — that is what
      // separates the three body previews from the presented one.
      expect(find.byType(BottomSheet), findsNothing);
      // Icon, headline, body, CTA is the whole widget: each string once.
      for (final String text in const <String>[_title, _body, _dismiss]) {
        expect(find.text(text), findsOneWidget);
      }
      // Two lines of headline at 390dp — the number the narrow state is read
      // against.
      expect(tester.getSize(find.text(_title)).height, 56);
    });

    testWidgets('the narrow state really is 320dp, and the headline grows', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialCollisionSheetNarrowPhone);

      expect(tester.getSize(find.byType(SocialCollisionSheet)).width, 320);
      // 280dp of text column takes the headline from two lines to three. This
      // is the assertion that tells this preview apart from the 390dp one,
      // where the identical string is 56dp tall.
      expect(
        tester.getSize(find.text(_title)).height,
        greaterThan(56),
        reason: 'the headline should take a third line at 320dp',
      );
    });

    testWidgets('at 200% the CTA falls below the bottom of a phone screen', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialCollisionSheetLargeText);

      final MediaQueryData mq = MediaQuery.of(
        tester.element(find.byType(SocialCollisionSheet)),
      );
      expect(mq.textScaler.scale(14), 28);

      // The sheet has no scroll fallback — `isScrollControlled: true` raises
      // the route's height ceiling, it does not make a `Column` scroll — so at
      // 200% the body is taller than the screen it is presented on and the
      // bottom of it is unreachable. Both numbers are the finding, not a
      // preview artifact; the preview clips instead of striping so the outcome
      // is visible in the canvas.
      final Rect sheet = tester.getRect(find.byType(SocialCollisionSheet));
      expect(
        sheet.height,
        greaterThan(socialCollisionSheetPhoneWindow),
        reason: 'the 200% body no longer fits a 390x844 phone',
      );
      expect(
        tester.getRect(_cta).bottom - sheet.top,
        greaterThan(socialCollisionSheetPhoneWindow),
        reason: 'the dismiss CTA is off the bottom of the screen at 200%',
      );
    });

    testWidgets('the presented state goes through the real sheet route', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialCollisionSheetPresented);

      // Pushed by `showSocialCollisionSheet`, not hand-placed: a sheet-shaped
      // frame over the stand-in page is the proof.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(socialCollisionSheetHostLabel), findsOneWidget);
      expect(find.text(_title), findsOneWidget);
    });

    testWidgets('the presented CTA clears the home indicator', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialCollisionSheetPresented);

      // `showModalBottomSheet` strips only the TOP padding, so the phone's
      // bottom inset reaches the sheet and its own `SafeArea` is what keeps the
      // CTA off the home indicator. Drop that SafeArea and this fails.
      final Element sheetContext = tester.element(
        find.byType(SocialCollisionSheet),
      );
      expect(MediaQuery.of(sheetContext).padding.bottom, _homeIndicator);
      expect(
        tester.getRect(find.byType(SocialCollisionSheet)).bottom -
            tester.getRect(_cta).bottom,
        greaterThanOrEqualTo(_homeIndicator),
      );
    });

    testWidgets('dismissing the presented sheet leaves the page behind', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialCollisionSheetPresented);

      await tester.tap(_cta);
      await tester.pumpAndSettle();

      // The CTA pops the sheet — this is what `SocialSignInSection` awaits
      // before calling `acknowledgeCollision` to re-arm its buttons (JM-019).
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(_title), findsNothing);
      expect(find.text(socialCollisionSheetHostLabel), findsOneWidget);
    });
  });
}
