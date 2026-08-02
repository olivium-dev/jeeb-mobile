// Render tests for the JeeberRequestUnavailableScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_request_unavailable_screen_fixtures.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';

import '../preview_test_harness.dart';

/// The frames the fixture declares, mirrored here so a preview quietly rewired
/// to a different window fails instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _title = 'Request no longer available';
const String _browseCta = 'Browse other requests';
const String _titleAr = 'الطلب لم يعد متاحًا';
const String _browseCtaAr = 'تصفح الطلبات الأخرى';

String _noLongerAvailable(String id) => 'Request $id is no longer available.';

/// The screen's only forward affordance.
const Key _ctaKey = Key('jeeber-request-unavailable-back-cta');

/// Pumps [preview] into a FRESH element tree.
/// Two previews cannot simply be pumped one after the other: the canvas wrapper
Future<void> _pumpFresh(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await pumpPreview(tester, preview, locale: locale);
}

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
    await _pumpFresh(tester, preview, locale: locale);
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

/// How many pixels a captured layout error overflowed by, or 0 when [error] is
/// not an overflow at all.
int _overflowPixels(Object? error) {
  final RegExpMatch? match =
      RegExp(r'overflowed by ([\d.]+) pixels').firstMatch('$error');
  if (match == null) return 0;
  return double.parse(match.group(1)!).round();
}

Rect _frame(WidgetTester tester) =>
    tester.getRect(find.byType(JeeberRequestUnavailableScreen));

void main() {
  setUpAll(loadPreviewArbs);

  setUp(jeeberRequestUnavailableScreenResetTaps);

  // Every preview except the two 200%-text states, which overflow on purpose —
  testPreviewsRender(
    'JeeberRequestUnavailableScreen',
    const <String, Widget Function()>{
      'Phone · short id': jeeberRequestUnavailableScreenPhoneShortId,
      'Cold push tap · raw UUID': jeeberRequestUnavailableScreenPushDeadEnd,
      'Compact 320 × 568': jeeberRequestUnavailableScreenCompact,
      'Blank id': jeeberRequestUnavailableScreenBlankId,
    },
    // Each state names itself. `Cold push tap` and `Compact` are handed the
    expectedText: const <String, String>{
      'Phone · short id': 'Phone · short id (req-404)',
      'Cold push tap · raw UUID': 'Cold push tap · raw UUID · nothing to pop',
      'Compact 320 × 568': 'Compact 320 × 568 · raw UUID',
      'Blank id': 'Phone · blank id from the router fallback',
    },
  );

  group('JeeberRequestUnavailableScreen preview specifics', () {
    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      await _pumpFresh(tester, jeeberRequestUnavailableScreenPhoneShortId);
      expect(_frame(tester).size, _phoneFrame);

      await _pumpFresh(tester, jeeberRequestUnavailableScreenCompact);
      expect(_frame(tester).size, _compactFrame);

      await _pumpCatchingErrors(
        tester,
        jeeberRequestUnavailableScreenCompactLargeText,
      );
      expect(_frame(tester).size, _compactFrame);
    });

    testWidgets('only the 200% windows are scaled', (WidgetTester tester) async {
      // `JeeberRequestUnavailableScreenWindow.textScale` is nullable on
      Future<double> scale(Widget Function() preview) async {
        await _pumpCatchingErrors(tester, preview);
        return MediaQuery.textScalerOf(
          tester.element(find.byType(JeeberRequestUnavailableScreen)),
        ).scale(10);
      }

      expect(await scale(jeeberRequestUnavailableScreenPhoneShortId), 10);
      expect(await scale(jeeberRequestUnavailableScreenPushDeadEnd), 10);
      expect(await scale(jeeberRequestUnavailableScreenCompact), 10);
      expect(await scale(jeeberRequestUnavailableScreenBlankId), 10);
      expect(await scale(jeeberRequestUnavailableScreenLargeText), 20);
      expect(await scale(jeeberRequestUnavailableScreenCompactLargeText), 20);
    });

    testWidgets('each state renders the id it was handed', (
      WidgetTester tester,
    ) async {
      // The screen's only content axis. The catalog's short id and the id the
      await _pumpFresh(tester, jeeberRequestUnavailableScreenPhoneShortId);
      expect(find.text(_noLongerAvailable('req-404')), findsOneWidget);

      await _pumpFresh(tester, jeeberRequestUnavailableScreenPushDeadEnd);
      expect(
        find.text(
          _noLongerAvailable(JeeberRequestUnavailableScreenIds.push),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the CTA is wired — tapping it fires onBack', (
      WidgetTester tester,
    ) async {
      // A dead end whose only forward affordance does nothing reviews nothing.
      await _pumpFresh(tester, jeeberRequestUnavailableScreenPhoneShortId);
      expect(jeeberRequestUnavailableScreenBrowseTaps, 0);

      await tester.ensureVisible(find.byKey(_ctaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_ctaKey));
      await tester.pumpAndSettle();

      expect(jeeberRequestUnavailableScreenBrowseTaps, 1);
    });

    testWidgets('FINDING — a cold push tap has no back arrow at all', (
      WidgetTester tester,
    ) async {
      // `OMDSAppBar` is constructed without `showBackButton`, which DEFAULTS TO
      await _pumpFresh(tester, jeeberRequestUnavailableScreenPushDeadEnd);

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(
        find.descendant(
          of: find.byType(JeeberRequestUnavailableScreen),
          matching: find.byType(IconButton),
        ),
        findsNothing,
        reason: 'no arrow, no actions: the CTA is the whole exit',
      );

      // The contrast: the same screen, one page deeper on the stack.
      await _pumpFresh(tester, jeeberRequestUnavailableScreenPhoneShortId);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
      expect(find.text(jeeberRequestUnavailableScreenParentLabel), findsOneWidget);
    });

    testWidgets('FINDING — the blank-id fallback renders a double space', (
      WidgetTester tester,
    ) async {
      // `app_router.dart:1284` is `state.pathParameters['id'] ?? ''`, and the
      await _pumpFresh(tester, jeeberRequestUnavailableScreenBlankId);

      expect(find.text('Request  is no longer available.'), findsOneWidget);
      expect(find.text('Request is no longer available.'), findsNothing);
    });

    testWidgets('FINDING — the raw UUID is printed in full', (
      WidgetTester tester,
    ) async {
      // The sibling screen this same loader routes to shortens the id to
      await _pumpFresh(tester, jeeberRequestUnavailableScreenPushDeadEnd);

      expect(
        find.textContaining(JeeberRequestUnavailableScreenIds.push),
        findsOneWidget,
      );
      expect(find.textContaining('#775EAE'), findsNothing);
    });

    testWidgets('Arabic is localized and mirrored, not raw English', (
      WidgetTester tester,
    ) async {
      await _pumpFresh(
        tester,
        jeeberRequestUnavailableScreenPushDeadEnd,
        locale: const Locale('ar'),
      );

      // App bar + empty-state title share the localized key, so the title is
      expect(find.text(_titleAr), findsNWidgets(2));
      expect(find.text(_browseCtaAr), findsOneWidget);
      expect(find.text(_title), findsNothing);
      expect(find.text(_browseCta), findsNothing);
      expect(
        Directionality.of(
          tester.element(find.byType(JeeberRequestUnavailableScreen)),
        ),
        TextDirection.rtl,
      );
    });
  });

  // What the pinned device frames exposed that a bare 800 × 600 pump hides.
  group('JeeberRequestUnavailableScreen layout ceiling', () {
    testWidgets('the body never scrolls — there is no viewport inside it', (
      WidgetTester tester,
    ) async {
      // Everything below rests on this: `Scaffold > SafeArea > Center > Column`
      await _pumpFresh(tester, jeeberRequestUnavailableScreenPhoneShortId);

      expect(
        find.descendant(
          of: find.byType(JeeberRequestUnavailableScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });

    testWidgets('at 100% both windows fit, with the CTA on screen (control)', (
      WidgetTester tester,
    ) async {
      // The reason the states below went unnoticed: on the width axis alone
      for (final Widget Function() preview in <Widget Function()>[
        jeeberRequestUnavailableScreenPhoneShortId,
        jeeberRequestUnavailableScreenCompact,
      ]) {
        final List<FlutterErrorDetails> caught =
            await _pumpCatchingErrors(tester, preview);
        expect(caught, isEmpty);
        expect(
          tester.getRect(find.byKey(_ctaKey)).bottom,
          lessThan(_frame(tester).bottom),
        );
      }
    });

    testWidgets(
      'FINDING — at 200% text on an ORDINARY phone the CTA is below the '
      'viewport (en)',
      (WidgetTester tester) async {
        // Not just the smallest display: 390 × 844, the reference device.
        final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
          tester,
          jeeberRequestUnavailableScreenLargeText,
        );

        expect(
          caught.map((FlutterErrorDetails e) => e.exception.toString()),
          contains(contains('RenderFlex overflowed')),
          reason: 'if this stops overflowing the screen was fixed — replace '
              'this test with the fits-everywhere assertion above',
        );
        expect(_overflowPixels(caught.single.exception), greaterThan(0));
        expect(
          tester.getRect(find.byKey(_ctaKey)).top,
          greaterThan(_frame(tester).bottom),
          reason: 'the CTA is the whole forward path off this screen',
        );
      },
    );

    testWidgets(
      'the same window in AR still fits — the ceiling is locale-dependent',
      (WidgetTester tester) async {
        // Recorded so the finding above is not overstated: the Arabic copy is
        final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
          tester,
          jeeberRequestUnavailableScreenLargeText,
          locale: const Locale('ar'),
        );

        expect(caught, isEmpty);
        expect(
          tester.getRect(find.byKey(_ctaKey)).bottom,
          lessThan(_frame(tester).bottom),
        );
      },
    );

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'FINDING — on the smallest phone at 200% there is NO reachable '
        'affordance at all (${locale.languageCode})',
        (WidgetTester tester) async {
          // The worst case the app supports, and the one a cold push tap can
          final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
            tester,
            jeeberRequestUnavailableScreenCompactLargeText,
            locale: locale,
          );

          expect(_overflowPixels(caught.single.exception), greaterThan(0));
          expect(
            tester.getRect(find.byKey(_ctaKey)).top,
            greaterThan(_frame(tester).bottom),
          );
          expect(find.byIcon(Icons.arrow_back), findsNothing);
        },
      );
    }

    testWidgets(
      'FINDING — at 200% the CTA label is clipped inside its fixed-height pill',
      (WidgetTester tester) async {
        // Independent of the overflow above, and it bites even where the CTA
        await _pumpCatchingErrors(tester, jeeberRequestUnavailableScreenPhoneShortId);
        final RenderParagraph atDefault =
            tester.renderObject<RenderParagraph>(find.text(_browseCta));
        expect(
          atDefault.getMinIntrinsicHeight(atDefault.size.width),
          lessThanOrEqualTo(atDefault.size.height),
          reason: 'at 100% the label fits, which is why this is invisible '
              'until someone raises the text size',
        );

        await _pumpCatchingErrors(tester, jeeberRequestUnavailableScreenLargeText);
        final RenderParagraph scaled =
            tester.renderObject<RenderParagraph>(find.text(_browseCta));

        expect(scaled.size.height, 48, reason: 'the pill never grew');
        expect(
          scaled.getMinIntrinsicHeight(scaled.size.width),
          greaterThan(scaled.size.height * 2),
          reason: 'the label needs more than twice the height it was given',
        );
      },
    );

    testWidgets(
      'FINDING — the duplicated title is what spends the missing space',
      (WidgetTester tester) async {
        // The title is rendered twice by design (app bar + `OmdsEmptyState`),
        await _pumpCatchingErrors(tester, jeeberRequestUnavailableScreenLargeText);

        final Rect inBody = tester.getRect(
          find.descendant(
            of: find.byKey(const Key('jeeber-request-unavailable-state')),
            matching: find.text(_title),
          ),
        );
        expect(inBody.height, greaterThan(300));
      },
    );
  });

  // The previews and the Screen Catalog now read one fixture file. This group
  group('the extracted fixtures still drive the Screen Catalog', () {
    testWidgets('the cataloged state renders, bare, on the shared id', (
      WidgetTester tester,
    ) async {
      final CatalogEntry entry = kScreenCatalog.singleWhere(
        (CatalogEntry e) =>
            e.feature == 'jeeber_request_detail' &&
            e.screen == 'JeeberRequestUnavailableScreen',
      );
      final CatalogState state = entry.states.single;
      expect(
        state.label,
        JeeberRequestUnavailableScreenFixtures.catalogDefault.label,
        reason: 'the label a designer signs off against comes from the fixture',
      );

      await tester.pumpWidget(
        previewCanvas(() => Builder(builder: state.builder), const Locale('en')),
      );
      await tester.pumpAndSettle();

      // The same id `Phone · short id` shows in the canvas — one source of
      expect(
        find.text(
          _noLongerAvailable(JeeberRequestUnavailableScreenIds.catalog),
        ),
        findsOneWidget,
      );
      // `window: null` — no simulated frame and no caption strip. On a device
      expect(find.text(_title), findsNWidgets(2));
      expect(find.byType(SingleChildScrollView), findsNothing);
      // `parentOnStack: null` — no local Navigator, so the catalog's own route
      expect(find.text(jeeberRequestUnavailableScreenParentLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
