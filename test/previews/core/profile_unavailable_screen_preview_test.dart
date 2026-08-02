// Render tests for the ProfileUnavailableScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// ProfileUnavailableScreen renders the SAME two strings in every state — it has
// no data axis at all, it IS the error state — so "did it render" is a weak
// question here: all six previews would pass a render-only check while showing
// identical content, and two of them (`Phone 390 × 844` and `Dead end · nothing
// to pop`) are pixel-for-pixel identical BY DESIGN. The suite therefore does two
// extra jobs. The expected strings pin WHICH window each preview simulates (the
// caption the fixture host paints), and the group below measures what the screen
// actually did inside that window — geometry, and whether its one affordance is
// an exit. Those measurements are the only contract this screen has.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/router/profile_unavailable_screen.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/profile_unavailable_screen_fixtures.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);
const Size _notchedFrame = Size(393, 852);

/// The home indicator the notched window simulates.
const double _notchedBottomInset = 34;

/// Pumps [preview] with framework errors intercepted rather than recorded.
///
/// `tester.takeException()` cannot be used to inspect them: once a second error
/// lands the binding collapses both into "Multiple exceptions (2) were
/// detected…", which says nothing about what they were. Taking them at
/// [FlutterError.onError] keeps each one, so the caller can decide which are
/// tolerable — and every error still has to be accounted for, because the
/// handler is restored before any assertion runs.
Future<List<FlutterErrorDetails>> _pumpCatchingErrors(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await pumpPreview(tester, preview, locale: locale);
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Compact · 200% text`, which overflows on purpose —
  // see the dedicated group below.
  testPreviewsRender(
    'ProfileUnavailableScreen',
    const <String, Widget Function()>{
      'Phone 390 × 844': profileUnavailableScreenPhone,
      'Compact 320 × 568': profileUnavailableScreenCompact,
      'Notched 393 × 852 · inset 59/34': profileUnavailableScreenNotched,
      'Phone · 200% text': profileUnavailableScreenLargeText,
      'Dead end · nothing to pop': profileUnavailableScreenStackRoot,
    },
    // Every state names its own window. The screen shows the same icon, the
    // same heading and the same sentence in all six, so without this a preview
    // wired to the wrong window — or five previews accidentally sharing one —
    // would pass unnoticed. `Dead end · nothing to pop` is the case that makes
    // this mandatory rather than tidy: it is the phone window with one fewer
    // page under it, and NOTHING on screen distinguishes the two.
    expectedText: const <String, String>{
      'Phone 390 × 844': 'Phone · 390 × 844 · 100% text',
      'Compact 320 × 568': 'Compact · 320 × 568 · 100% text',
      'Notched 393 × 852 · inset 59/34': 'Notched · 393 × 852 · inset 59/34',
      'Phone · 200% text': 'Phone · 390 × 844 · 200% text',
      'Dead end · nothing to pop':
          'Phone · 390 × 844 · stack root (nothing to pop)',
    },
  );

  group('ProfileUnavailableScreen preview specifics', () {
    Future<Rect> frameRect(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
    }) async {
      await pumpPreview(tester, preview, locale: locale);
      return tester.getRect(find.byType(ProfileUnavailableScreen));
    }

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      // state would collapse onto the test surface and the rest of this group
      // would be asserting nothing.
      expect((await frameRect(tester, profileUnavailableScreenPhone)).size,
          _phoneFrame);
      expect((await frameRect(tester, profileUnavailableScreenCompact)).size,
          _compactFrame);
      expect((await frameRect(tester, profileUnavailableScreenNotched)).size,
          _notchedFrame);
      expect((await frameRect(tester, profileUnavailableScreenLargeText)).size,
          _phoneFrame);
      expect((await frameRect(tester, profileUnavailableScreenStackRoot)).size,
          _phoneFrame);
    });

    testWidgets('the 200% window really is scaled and the rest are not', (
      WidgetTester tester,
    ) async {
      // `ProfileUnavailableScreenWindow.textScale` is nullable on purpose: a
      // window that pinned 1.0 would overwrite the `matrix: true` 200% card on
      // `Phone 390 × 844` and label a 100% rendering "EN 200% text". This pins
      // both halves of that.
      Future<double> scale(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        return MediaQuery.textScalerOf(
          tester.element(find.byType(ProfileUnavailableScreen)),
        ).scale(10);
      }

      expect(await scale(profileUnavailableScreenPhone), 10);
      expect(await scale(profileUnavailableScreenCompact), 10);
      expect(await scale(profileUnavailableScreenNotched), 10);
      expect(await scale(profileUnavailableScreenStackRoot), 10);
      expect(await scale(profileUnavailableScreenLargeText), 20);
    });

    testWidgets('the body never scrolls — there is no viewport inside it', (
      WidgetTester tester,
    ) async {
      // The whole failure mode below rests on this: `Scaffold > Center >
      // OmdsErrorState > Column` with nothing scrollable in the chain, so
      // content that does not fit is clipped rather than reachable. The only
      // Scrollables in the tree are the fixture's own two, outside the screen.
      await pumpPreview(tester, profileUnavailableScreenPhone);

      expect(
        find.descendant(
          of: find.byType(ProfileUnavailableScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });

    testWidgets('at 100% the composition has room to spare on the smallest '
        'phone', (WidgetTester tester) async {
      // The reference measurement, and the reason the 200% state went
      // unnoticed: on the small-phone axis alone this screen is exactly as
      // simple as it looks.
      final Rect frame = await frameRect(tester, profileUnavailableScreenCompact);
      final Rect appBar = tester.getRect(find.byType(AppBar));
      final Rect content = tester.getRect(find.byType(OmdsErrorState));

      expect(content.height, moreOrLessEquals(268, epsilon: 2));
      expect(
        frame.bottom - appBar.bottom - content.height,
        greaterThan(200),
        reason: 'measured 244 pt of slack in a 512 pt body — if this ever drops '
            'near zero the screen has started clipping at the DEFAULT text '
            'size, which is a different and much worse defect',
      );
    });

    testWidgets('at 200% on a 390 pt phone it still fits', (
      WidgetTester tester,
    ) async {
      final Rect frame =
          await frameRect(tester, profileUnavailableScreenLargeText);
      final Rect content = tester.getRect(find.byType(OmdsErrorState));

      expect(content.bottom, lessThan(frame.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 200% on a 320 pt phone the instruction is clipped off the '
        'bottom', (WidgetTester tester) async {
      // The measured defect. `OmdsErrorState` is a `Column(mainAxisSize: min)`
      // inside a `Center` with no scroll view anywhere above it, so the surplus
      // is not reachable by any gesture — it is simply off the display.
      final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
        tester,
        profileUnavailableScreenCompactLargeText,
      );

      expect(
        caught.map((FlutterErrorDetails e) => e.exception.toString()),
        contains(contains('RenderFlex overflowed')),
        reason: 'if this stops overflowing the screen was fixed — replace this '
            'test with the fits-everywhere assertion above',
      );
      expect(caught, hasLength(1), reason: 'one overflow, nothing else');

      final Rect frame = tester.getRect(find.byType(ProfileUnavailableScreen));
      final Finder message = find.textContaining('Please go back');
      final Rect messageRect = tester.getRect(message);

      // The heading is visible; the sentence that tells the user what to do
      // runs past the bottom edge of the display. Measured 424 → 744 against an
      // edge at 600, i.e. 144 of its 320 pt are off-screen.
      expect(messageRect.top, lessThan(frame.bottom));
      expect(
        messageRect.bottom,
        greaterThan(frame.bottom),
        reason: 'the only instruction on the screen must not be the part that '
            'is cut',
      );
      expect(messageRect.bottom - frame.bottom, greaterThan(100));
    });

    testWidgets('the duplicated heading is what spends the missing space', (
      WidgetTester tester,
    ) async {
      // [OMDSAppBar] paints `profileUnavailableTitle` and [OmdsErrorState]
      // paints it again immediately below, so the string is on screen twice in
      // every window.
      await pumpPreview(tester, profileUnavailableScreenPhone);
      expect(find.text('Profile unavailable'), findsNWidgets(2));

      // In the window that ran out of room, the restatement alone is 224 pt of
      // the 512 the body had.
      await _pumpCatchingErrors(
        tester,
        profileUnavailableScreenCompactLargeText,
      );
      final Rect inBody = tester.getRect(
        find.descendant(
          of: find.byType(OmdsErrorState),
          matching: find.text('Profile unavailable'),
        ),
      );
      expect(inBody.height, greaterThan(200));
    });

    testWidgets('the notched insets are handled at both ends', (
      WidgetTester tester,
    ) async {
      // The profile routes are bare top-level GoRoutes — no ShellRoute, no
      // SafeArea — so this is the screen's own arithmetic.
      final Rect frame = await frameRect(tester, profileUnavailableScreenNotched);
      final Rect appBar = tester.getRect(find.byType(AppBar));
      final Rect content = tester.getRect(find.byType(OmdsErrorState));

      // 56 pt of toolbar plus the 59 pt status bar.
      expect(appBar.height, moreOrLessEquals(115, epsilon: 1));
      expect(
        frame.bottom - content.bottom,
        greaterThan(_notchedBottomInset),
        reason: 'a centred body cannot collide with the home indicator, and '
            'this pins that it stays that way',
      );
    });

    // The two navigation states. Each gets its OWN test: pumping a second
    // preview into the same tester reuses the first preview's element, and with
    // it the fixture host's Navigator — which would still be sitting on the
    // page the previous tap navigated to.
    testWidgets('with a parent on the stack the back arrow is a real exit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileUnavailableScreenPhone);
      expect(find.byType(ProfileUnavailableScreen), findsOneWidget);

      // The 390 × 844 frame is taller than the 800 × 600 test surface, so the
      // target has to be scrolled into the hit-testable area first.
      await tester.ensureVisible(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileUnavailableScreen), findsNothing);
      expect(
        find.text(profileUnavailableScreenParentStandInLabel),
        findsOneWidget,
      );
    });

    testWidgets('as the stack root the back arrow does nothing at all', (
      WidgetTester tester,
    ) async {
      // `OMDSAppBar._buildBackButton` defaults to
      // `Navigator.of(context).maybePop()`, which no-ops on a lone page.
      // `app_router.dart` reaches `/profile/customer` by stack-REPLACING
      // `goNamed` from `password_security_screen.dart:132`, and in release the
      // builder falls through to THIS screen when the typed `extra` is absent —
      // so the shipped app can put a user here with no working way out.
      // `RootAwareBackScope` rescues the Android system BACK gesture; nothing
      // rescues the arrow, and iOS has no such gesture.
      await pumpPreview(tester, profileUnavailableScreenStackRoot);

      await tester.ensureVisible(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(
        find.byType(ProfileUnavailableScreen),
        findsOneWidget,
        reason: 'the tap was swallowed: maybePop found nothing to pop',
      );
      expect(
        find.text(profileUnavailableScreenParentStandInLabel),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the arrow is the ONLY control on the screen', (
      WidgetTester tester,
    ) async {
      // [OmdsErrorState] renders a retry button when — and only when — it is
      // given `onRetry`. This screen gives it none, and passes no
      // `onBackPressed` either, so there is exactly one tappable thing here and
      // the test above shows it can be inert.
      await pumpPreview(tester, profileUnavailableScreenStackRoot);

      final Finder inScreen = find.descendant(
        of: find.byType(ProfileUnavailableScreen),
        matching: find.byType(ButtonStyleButton),
      );
      expect(inScreen, findsNothing, reason: 'no retry, no CTA');
      expect(
        find.descendant(
          of: find.byType(ProfileUnavailableScreen),
          matching: find.byType(IconButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Arabic is localized and mirrored, not raw English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        profileUnavailableScreenPhone,
        locale: const Locale('ar'),
      );

      expect(find.text('الملف الشخصي غير متاح'), findsNWidgets(2));
      expect(
        find.text(
          'تعذّر تحميل هذا الملف الشخصي. يُرجى العودة والمحاولة مرة أخرى.',
        ),
        findsOneWidget,
      );
      expect(find.text('Profile unavailable'), findsNothing);
      expect(
        Directionality.of(
          tester.element(find.byType(ProfileUnavailableScreen)),
        ),
        TextDirection.rtl,
      );
    });

    testWidgets('the clipping is not an English-only problem', (
      WidgetTester tester,
    ) async {
      // "It only breaks in English" is the usual first guess, and it is wrong:
      // measured 164 px of overflow in EN and 124 px in AR. Neither locale has
      // a scroll view to fall back on.
      final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
        tester,
        profileUnavailableScreenCompactLargeText,
        locale: const Locale('ar'),
      );

      expect(
        caught.map((FlutterErrorDetails e) => e.exception.toString()),
        contains(contains('RenderFlex overflowed')),
      );
    });
  });
}
