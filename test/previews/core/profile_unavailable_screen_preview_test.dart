// Render tests for the ProfileUnavailableScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/router/profile_unavailable_screen.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
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
/// `tester.takeException()` cannot be used to inspect them: once a second error
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

    /// How far the screen's own viewport can travel — the preview host adds
    /// two more, so the finder is scoped to the screen.
    double scrollExtent(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ProfileUnavailableScreen),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .maxScrollExtent;

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
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

    // M3-41: the OMDS panel became `JeebEmptyState`, and the viewport that
    // used to be missing is what closed the compact-200% clipping defect.
    testWidgets('the body scrolls — the viewport is above the block, never '
        'inside it', (WidgetTester tester) async {
      await pumpPreview(tester, profileUnavailableScreenPhone);

      expect(
        find.descendant(
          of: find.byType(ProfileUnavailableScreen),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(JeebEmptyState),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });

    testWidgets('at 100% the composition has room to spare on the smallest '
        'phone', (WidgetTester tester) async {
      // The reference measurement: if this slack ever drops near zero the
      // screen has started scrolling at the DEFAULT text size.
      final Rect frame = await frameRect(tester, profileUnavailableScreenCompact);
      final Rect bar = tester.getRect(find.byType(JeebTopBar));
      final Rect content = tester.getRect(find.byType(JeebEmptyState));

      expect(
        frame.bottom - bar.bottom - content.height,
        greaterThan(40),
        reason: 'measured 68 pt — the drawn E4 box is much taller than the '
            'OMDS glyph it replaced, so the slack shrank from 244; if it ever '
            'vanishes the screen has started scrolling at the DEFAULT size',
      );
      expect(scrollExtent(tester), 0, reason: 'nothing to scroll at 1.0x');
    });

    // The measured defect, now fixed: the OMDS `Column(mainAxisSize: min)`
    // overflowed by >100 pt here and cut the only sentence on the screen.
    for (final (String label, Widget Function() preview) in <
        (String, Widget Function())>[
      ('390 pt', profileUnavailableScreenLargeText),
      ('320 pt', profileUnavailableScreenCompactLargeText),
    ]) {
      testWidgets('at 200% on a $label phone it scrolls instead of clipping '
          'the instruction', (WidgetTester tester) async {
        final List<FlutterErrorDetails> caught =
            await _pumpCatchingErrors(tester, preview);

        expect(caught, isEmpty, reason: 'no RenderFlex overflow anywhere');
        expect(scrollExtent(tester), greaterThan(0),
            reason: 'the block outgrew the viewport and the viewport took it');
        expect(find.textContaining('Please go back'), findsOneWidget,
            reason: 'the only instruction on the screen is still built, and '
                'now reachable');
      });
    }

    testWidgets('the heading prints ONCE — the bar no longer restates it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileUnavailableScreenPhone);

      expect(find.text('Profile unavailable'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(JeebEmptyState),
          matching: find.text('Profile unavailable'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<JeebTopBar>(find.byType(JeebTopBar)).title, isNull);
    });

    testWidgets('the notched insets are handled at both ends', (
      WidgetTester tester,
    ) async {
      // The profile routes are bare top-level GoRoutes — no ShellRoute, no
      final Rect frame = await frameRect(tester, profileUnavailableScreenNotched);
      final Rect bar = tester.getRect(find.byType(JeebTopBar));
      final Rect content = tester.getRect(find.byType(JeebEmptyState));

      expect(
        bar.top,
        greaterThanOrEqualTo(frame.top + 59),
        reason: 'SafeArea clears the 59 pt status bar the window simulates',
      );
      expect(
        frame.bottom - content.bottom,
        greaterThan(_notchedBottomInset),
        reason: 'a centred body cannot collide with the home indicator, and '
            'this pins that it stays that way',
      );
    });

    // The two navigation states. Each gets its OWN test: pumping a second
    testWidgets('with a parent on the stack the back arrow is a real exit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileUnavailableScreenPhone);
      expect(find.byType(ProfileUnavailableScreen), findsOneWidget);

      // The 390 × 844 frame is taller than the 800 × 600 test surface, so the
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
      // No destination exists for a "retry", so `JeebEmptyState.action` stays
      // unmounted — a CTA with nowhere to go is worse than an absent one.
      await pumpPreview(tester, profileUnavailableScreenStackRoot);

      expect(
        find.descendant(
          of: find.byType(ProfileUnavailableScreen),
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
        reason: 'no retry, no CTA',
      );
      expect(
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState)).action,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byType(ProfileUnavailableScreen),
          matching: find.byIcon(Icons.arrow_back),
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

      expect(find.text('الملف الشخصي غير متاح'), findsOneWidget);
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

    testWidgets('and the fix is not an English-only fix either', (
      WidgetTester tester,
    ) async {
      // Arabic sets longer than English here, so it was the worse of the two
      // overflows; it must clear the same bar.
      final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
        tester,
        profileUnavailableScreenCompactLargeText,
        locale: const Locale('ar'),
      );

      expect(caught, isEmpty);
    });
  });
}
