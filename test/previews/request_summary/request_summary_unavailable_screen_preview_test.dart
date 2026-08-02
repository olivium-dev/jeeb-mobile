// Render tests for the RequestSummaryUnavailableScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/request_summary_unavailable_screen_fixtures.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_unavailable_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);
const Size _notchedFrame = Size(393, 852);

/// The surface `flutter_test` pumps onto, which is what the catalog form — the
/// one state that pins no window of its own — is measured against.
const Size _testSurface = Size(800, 600);

/// The home indicator the notched window simulates.
const double _notchedBottomInset = 34;

/// The screen's own body copy, in both shipped locales.
const String _bodyEn =
    'No request draft available. Start a new request to continue.';
const String _bodyAr = 'لا يوجد مسودة طلب متاحة. ابدأ طلبًا جديدًا للمتابعة.';

/// The app-bar title — which is ALSO `requestSummaryTitle`, the populated
/// screen's title. See the dedicated test below.
const String _titleEn = 'Review & submit';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'RequestSummaryUnavailableScreen',
    const <String, Widget Function()>{
      'Phone 390 × 844': requestSummaryUnavailableScreenPhone,
      'Compact 320 × 568': requestSummaryUnavailableScreenCompact,
      'Notched 393 × 852 · inset 59/34': requestSummaryUnavailableScreenNotched,
      'Phone · 200% text': requestSummaryUnavailableScreenLargeText,
      'Compact · 200% text': requestSummaryUnavailableScreenCompactLargeText,
      'Cold deep link · nothing to pop': requestSummaryUnavailableScreenDeepLink,
      'Catalog state · Unavailable':
          requestSummaryUnavailableScreenCatalogState,
    },
    // Every framed state names its own window; the catalog state has no caption
    expectedText: const <String, String>{
      'Phone 390 × 844': 'Phone · 390 × 844 · 100% text',
      'Compact 320 × 568': 'Compact · 320 × 568 · 100% text',
      'Notched 393 × 852 · inset 59/34': 'Notched · 393 × 852 · inset 59/34',
      'Phone · 200% text': 'Phone · 390 × 844 · 200% text',
      'Compact · 200% text': 'Compact · 320 × 568 · 200% text',
      'Cold deep link · nothing to pop':
          'Phone · 390 × 844 · cold deep link (nothing to pop)',
      'Catalog state · Unavailable': _bodyEn,
    },
  );

  group('RequestSummaryUnavailableScreen preview specifics', () {
    Future<Rect> frameRect(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
    }) async {
      await pumpPreview(tester, preview, locale: locale);
      return tester.getRect(find.byType(RequestSummaryUnavailableScreen));
    }

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      expect((await frameRect(tester, requestSummaryUnavailableScreenPhone)).size,
          _phoneFrame);
      expect(
          (await frameRect(tester, requestSummaryUnavailableScreenCompact)).size,
          _compactFrame);
      expect(
          (await frameRect(tester, requestSummaryUnavailableScreenNotched)).size,
          _notchedFrame);
      expect(
          (await frameRect(tester, requestSummaryUnavailableScreenLargeText))
              .size,
          _phoneFrame);
      expect(
          (await frameRect(
                  tester, requestSummaryUnavailableScreenCompactLargeText))
              .size,
          _compactFrame);
      expect(
          (await frameRect(tester, requestSummaryUnavailableScreenDeepLink)).size,
          _phoneFrame);

      // The catalog form pins nothing on purpose — the device IS the window —
      expect(
          (await frameRect(tester, requestSummaryUnavailableScreenCatalogState))
              .size,
          _testSurface);
    });

    testWidgets('the 200% windows really are scaled and the rest are not', (
      WidgetTester tester,
    ) async {
      // `RequestSummaryUnavailableScreenWindow.textScale` is nullable on
      Future<double> scale(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        return MediaQuery.textScalerOf(
          tester.element(find.byType(RequestSummaryUnavailableScreen)),
        ).scale(10);
      }

      expect(await scale(requestSummaryUnavailableScreenPhone), 10);
      expect(await scale(requestSummaryUnavailableScreenCompact), 10);
      expect(await scale(requestSummaryUnavailableScreenNotched), 10);
      expect(await scale(requestSummaryUnavailableScreenDeepLink), 10);
      expect(await scale(requestSummaryUnavailableScreenCatalogState), 10);
      expect(await scale(requestSummaryUnavailableScreenLargeText), 20);
      expect(await scale(requestSummaryUnavailableScreenCompactLargeText), 20);
    });

    testWidgets('the body never scrolls — there is no viewport inside it', (
      WidgetTester tester,
    ) async {
      // Everything the window states measure rests on this: `Scaffold > Center >
      await pumpPreview(tester, requestSummaryUnavailableScreenPhone);

      expect(
        find.descendant(
          of: find.byType(RequestSummaryUnavailableScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });

    testWidgets('at 100% the composition has room to spare on the smallest '
        'phone', (WidgetTester tester) async {
      // The reference measurement for the window axis, and the reason the state
      final Rect frame =
          await frameRect(tester, requestSummaryUnavailableScreenCompact);
      final Rect appBar = tester.getRect(find.byType(AppBar));
      final Rect content = tester.getRect(find.byType(OmdsErrorState));

      expect(
        frame.bottom - appBar.bottom - content.height,
        greaterThan(200),
        reason: 'measured 312 pt of slack in a 512 pt body — if this ever drops '
            'near zero the screen has started clipping at the DEFAULT text '
            'size, which is a different and much worse defect',
      );
    });

    testWidgets('at 200% on the smallest phone it fits — by 16 pt', (
      WidgetTester tester,
    ) async {
      // The near miss, and the ratchet on it. Measured in EN: 480 pt of content
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        final Rect frame = await frameRect(
          tester,
          requestSummaryUnavailableScreenCompactLargeText,
          locale: locale,
        );
        final Rect appBar = tester.getRect(find.byType(AppBar));
        final Rect content = tester.getRect(find.byType(OmdsErrorState));

        expect(
          content.bottom,
          lessThan(frame.bottom),
          reason: 'clipped off the bottom in ${locale.languageCode} — the '
              'body has ${frame.bottom - appBar.bottom} pt and the '
              'composition now needs ${content.height} pt',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('in English the header is the SAME string as the screen it '
        'replaces — and in Arabic it is not', (WidgetTester tester) async {
      // `requestSummaryUnavailableTitle` and `requestSummaryTitle` are both
      await pumpPreview(tester, requestSummaryUnavailableScreenPhone);
      final AppLocalizations en = AppLocalizations.of(
        tester.element(find.byType(RequestSummaryUnavailableScreen)),
      );

      expect(en.requestSummaryUnavailableTitle, _titleEn);
      expect(
        en.requestSummaryUnavailableTitle,
        en.requestSummaryTitle,
        reason: 'the empty-state header is indistinguishable from the '
            'populated review screen',
      );
      expect(find.text(_titleEn), findsOneWidget);

      await pumpPreview(
        tester,
        requestSummaryUnavailableScreenPhone,
        locale: const Locale('ar'),
      );
      final AppLocalizations ar = AppLocalizations.of(
        tester.element(find.byType(RequestSummaryUnavailableScreen)),
      );

      expect(
        ar.requestSummaryUnavailableTitle,
        isNot(ar.requestSummaryTitle),
        reason: 'AR distinguishes the two screens; EN does not',
      );
    });

    // The two navigation states. Each gets its OWN test: pumping a second
    testWidgets('with a parent on the stack the back arrow is a real exit', (
      WidgetTester tester,
    ) async {
      // The Android process-death-restore case: `context.push` put a page
      await pumpPreview(tester, requestSummaryUnavailableScreenPhone);
      expect(find.byType(RequestSummaryUnavailableScreen), findsOneWidget);

      // The 390 × 844 frame is taller than the 800 × 600 test surface, so the
      await tester.ensureVisible(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(RequestSummaryUnavailableScreen), findsNothing);
      expect(
        find.text(requestSummaryUnavailableScreenParentStandInLabel),
        findsOneWidget,
      );
    });

    testWidgets('on a cold deep link the back arrow does nothing at all', (
      WidgetTester tester,
    ) async {
      // `OMDSAppBar._buildBackButton` defaults to
      await pumpPreview(tester, requestSummaryUnavailableScreenDeepLink);

      await tester.ensureVisible(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(
        find.byType(RequestSummaryUnavailableScreen),
        findsOneWidget,
        reason: 'the tap was swallowed: maybePop found nothing to pop',
      );
      expect(
        find.text(requestSummaryUnavailableScreenParentStandInLabel),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the arrow is the ONLY control, though the copy promises a '
        'CTA', (WidgetTester tester) async {
      // [OmdsErrorState] renders a button when — and only when — it is given
      await pumpPreview(tester, requestSummaryUnavailableScreenDeepLink);

      expect(find.text(_bodyEn), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RequestSummaryUnavailableScreen),
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
        reason: 'no CTA to start the new request the copy asks for',
      );
      expect(
        find.descendant(
          of: find.byType(RequestSummaryUnavailableScreen),
          matching: find.byType(IconButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the notched insets are handled at both ends', (
      WidgetTester tester,
    ) async {
      // `/request-summary` is a bare top-level GoRoute — no ShellRoute, no
      final Rect frame =
          await frameRect(tester, requestSummaryUnavailableScreenNotched);
      final Rect appBar = tester.getRect(find.byType(AppBar));
      final Rect content = tester.getRect(find.byType(OmdsErrorState));

      // 56 pt of toolbar plus the 59 pt status bar.
      expect(appBar.height, moreOrLessEquals(115, epsilon: 1));
      // Measured 278 pt of clearance against a 34 pt home indicator.
      expect(
        frame.bottom - content.bottom,
        greaterThan(_notchedBottomInset),
        reason: 'a centred body cannot collide with the home indicator, and '
            'this pins that it stays that way',
      );
    });

    testWidgets('Arabic is localized and mirrored, not raw English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        requestSummaryUnavailableScreenPhone,
        locale: const Locale('ar'),
      );

      expect(find.text('المراجعة والإرسال'), findsOneWidget);
      expect(find.text(_bodyAr), findsOneWidget);
      expect(find.text(_titleEn), findsNothing);
      expect(find.text(_bodyEn), findsNothing);
      expect(
        Directionality.of(
          tester.element(find.byType(RequestSummaryUnavailableScreen)),
        ),
        TextDirection.rtl,
      );
    });

    testWidgets('the catalog state renders bare — no frame, no local Navigator',
        (WidgetTester tester) async {
      // What `batch_10_entries.dart` mounts. The extraction must not have
      await pumpPreview(tester, requestSummaryUnavailableScreenCatalogState);

      expect(find.byType(RequestSummaryUnavailableScreen), findsOneWidget);
      expect(find.text(_bodyEn), findsOneWidget);
      // Only the harness MaterialApp's root Navigator; a framed state adds a
      expect(find.byType(Navigator), findsOneWidget);
      expect(
        find.text(RequestSummaryUnavailableScreenWindows.phone.label),
        findsNothing,
        reason: 'the catalog form paints no caption — the device is the frame',
      );

      await pumpPreview(tester, requestSummaryUnavailableScreenPhone);
      expect(find.byType(Navigator), findsNWidgets(2));
    });
  });
}
