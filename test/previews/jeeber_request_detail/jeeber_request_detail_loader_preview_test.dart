// Render tests for the JeeberRequestDetailLoader previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// The loader is a ROUTER: every preview resolves to one of three screens, so
// "does this preview render ITS OWN state" is literally "did the loader pick
// the right screen". The shared suite below pins that by text; the
// `preview specifics` and `layout ceiling` groups pin the things the canvas
// exposed that the branch tests in
// `test/features/jeeber_request_detail/jeeber_request_detail_loader_test.dart`
// cannot see, because they assert widget TYPES on an 800x600 surface and never
// look at the copy or the geometry:
//
//   * the unavailable fallback prints the RAW UUID while the resolved detail
//     prints `#775EAE` — the same loader, two conventions;
//   * a dead request and a dead network render the same screen, with no retry;
//   * at 200% text on a 390x700 phone that screen does not scroll, and its one
//     CTA is laid out below the viewport.
//
// Both are recorded as DEFECTS, not contracts. If one starts failing because
// the screen was fixed, delete the guard — do not restore the expectation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/friendly_reference.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';

import '../preview_test_harness.dart';

/// The ids the previews are built on — the first is the one the loader's own
/// branch tests use.
const String _requestId = 'e30b7f2e-7914-402d-8dd3-e699e6775eae';
const String _offlineId = '4d1c90ab-5f22-4c17-9d0e-0b6a3f77c145';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _detailTitle = 'Request details';
const String _unavailableTitle = 'Request no longer available';
const String _browseCta = 'Browse other requests';
const String _cachedPickup = 'Souq Waqif pickup';
const String _longDescription =
    '2 kg Turkish coffee, extra fine grind, from the roastery '
    'beside the gold souq — plus 3 boxes of Ceylon tea if they have the '
    'green tin. Please check the roast date before you pay.';

String _noLongerAvailable(String id) => 'Request $id is no longer available.';

/// The dead end's only affordance — the key [JeeberRequestUnavailableScreen]
/// puts on its "Browse other requests" CTA.
const Key _deadEndCta = Key('jeeber-request-unavailable-back-cta');

/// How many pixels a captured layout error overflowed by, or 0 when [error] is
/// not an overflow at all. Read out of the message rather than pinned as a
/// constant: the fact under test is "this does not fit on a phone", and an
/// exact pixel count would break on a font-metric change without meaning
/// anything.
int _overflowPixels(Object? error) {
  if (error == null) return 0;
  final RegExpMatch? match =
      RegExp(r'overflowed by ([\d.]+) pixels').firstMatch('$error');
  if (match == null) return 0;
  return double.parse(match.group(1)!).round();
}

/// Pumps a preview into the 390x700 box its annotation declares, instead of
/// into the 800x600 default test surface. The size is the point: at 800 pt the
/// summary card and the dead end both have room they never have on a phone.
Future<void> _pumpInPhoneBox(
  WidgetTester tester,
  Widget Function() preview, {
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 700);
  addTearDown(tester.view.reset);
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pumpAndSettle();
}

/// Pumps [preview] into a FRESH element tree.
///
/// Two previews in one test cannot simply be pumped one after the other: the
/// canvas wrapper is identical down to the loader itself, so Flutter reuses the
/// [State] — which already resolved — and the second preview silently renders
/// the first one's request. (That reuse is not only a test artifact; see the
/// `requestId` note in `preview specifics`.) Unmounting first forces
/// `initState` to run again.
Future<void> _pumpFresh(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await pumpPreview(tester, preview, locale: locale);
}

/// Every `Text` [preview] renders, keyed by its string and valued by its rect —
/// enough to say "these two states are the same frame".
Future<Map<String, Rect>> _frameOf(
  WidgetTester tester,
  Widget Function() preview,
) async {
  await _pumpFresh(tester, preview);
  return <String, Rect>{
    for (final Element element in find.byType(Text).evaluate())
      (element.widget as Text).data ?? '':
          tester.getRect(find.byWidget(element.widget)),
  };
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberRequestDetailLoader',
    const <String, Widget Function()>{
      'Feed-row tap · cached payload': jeeberRequestDetailLoaderCacheHit,
      'Push tap · recovering by id': jeeberRequestDetailLoaderRecovering,
      'Push tap · recovered': jeeberRequestDetailLoaderRecovered,
      'Feed miss · no longer available': jeeberRequestDetailLoaderUnavailable,
      'Feed offline · same dead end': jeeberRequestDetailLoaderOffline,
      'Accepted · redirecting': jeeberRequestDetailLoaderRedirecting,
    },
    // One distinct string per state, except the two that CANNOT differ: the
    // redirect branch deliberately holds the same loading scaffold up while
    // the route swap happens, and that scaffold renders exactly one string.
    // They are told apart in `preview specifics` instead.
    expectedText: <String, String>{
      'Feed-row tap · cached payload': _cachedPickup,
      'Push tap · recovering by id': _detailTitle,
      'Push tap · recovered': _longDescription,
      'Feed miss · no longer available': _noLongerAvailable(_requestId),
      'Feed offline · same dead end': _noLongerAvailable(_offlineId),
      'Accepted · redirecting': _detailTitle,
    },
  );

  group('JeeberRequestDetailLoader preview specifics', () {
    testWidgets('the cache hit resolves on the FIRST frame — no spinner', (
      WidgetTester tester,
    ) async {
      // No `pumpAndSettle`: the point is that nothing has to resolve.
      await tester.pumpWidget(
        previewCanvas(jeeberRequestDetailLoaderCacheHit, const Locale('en')),
      );
      await tester.pump();

      expect(find.byType(JeeberRequestDetailScreen), findsOneWidget);
      expect(find.byType(JeeberRequestDetailLoadingView), findsNothing);
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
      expect(find.text(_cachedPickup), findsOneWidget);
    });

    testWidgets('the in-flight state is the loading scaffold, not the dead end', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberRequestDetailLoaderRecovering);

      // The run-20 defect, held: while the by-id read is in flight the jeeber
      // must NOT be told the request is unavailable.
      expect(find.byType(JeeberRequestDetailLoadingView), findsOneWidget);
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
      expect(find.byType(JeeberRequestDetailScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the accepted probe redirects instead of dead-ending', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberRequestDetailLoaderRedirecting);

      // run-22: an accepted request misses the pending-scoped feed, and the
      // loader must hold the loading scaffold up for the route swap rather
      // than fall through to "Request unavailable".
      expect(find.byType(JeeberRequestDetailLoadingView), findsOneWidget);
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
    });

    testWidgets(
      'FINDING — "recovering" and "redirecting" are the SAME frame',
      (WidgetTester tester) async {
        final Map<String, Rect> recovering =
            await _frameOf(tester, jeeberRequestDetailLoaderRecovering);
        final Map<String, Rect> redirecting =
            await _frameOf(tester, jeeberRequestDetailLoaderRedirecting);

        // Still fetching, and about to jump to a delivery you already own,
        // render identically: one app-bar title and a spinner. `requestId` is
        // taken by the loading scaffold and never rendered, so there is not
        // even a reference on screen to tell the two apart.
        expect(recovering, equals(redirecting));
        expect(recovering.keys, <String>[_detailTitle]);
      },
    );

    testWidgets(
      'FINDING — the dead end prints the RAW uuid, the detail prints #775EAE',
      (WidgetTester tester) async {
        await _pumpFresh(tester, jeeberRequestDetailLoaderRecovered);

        // Resolved: sprint-009 audit §T5 is honoured — short reference, no
        // UUID anywhere on screen.
        expect(find.text(friendlyReference(_requestId)), findsOneWidget);
        expect(find.text('#775EAE'), findsOneWidget);
        expect(find.textContaining(_requestId), findsNothing);

        await _pumpFresh(tester, jeeberRequestDetailLoaderUnavailable);

        // Same loader, same id, one route later: the raw 36-character UUID is
        // interpolated straight into the subtitle.
        expect(find.textContaining(_requestId), findsOneWidget);
        expect(find.text(friendlyReference(_requestId)), findsNothing);
      },
    );

    testWidgets(
      'FINDING — a dead request and a dead network are the same screen',
      (WidgetTester tester) async {
        for (final Widget Function() preview in <Widget Function()>[
          jeeberRequestDetailLoaderUnavailable,
          jeeberRequestDetailLoaderOffline,
        ]) {
          await _pumpFresh(tester, preview);

          // `_recover` swallows the fetch error, so "expired" and "offline"
          // land on identical copy — and the only affordance is a CTA that
          // makes the same failing read again. No retry, no offline notice.
          expect(find.byType(JeeberRequestUnavailableScreen), findsOneWidget);
          expect(find.text(_unavailableTitle), findsNWidgets(2));
          expect(find.text(_browseCta), findsOneWidget);
          expect(find.textContaining('offline'), findsNothing);
        }
      },
    );

    testWidgets('localizes: no English chrome leaks into the AR reading', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeeberRequestDetailLoaderRecovered,
        locale: const Locale('ar'),
      );

      expect(find.text(_detailTitle), findsNothing);
      expect(find.text('تفاصيل الطلب'), findsOneWidget);
      expect(find.text('ما يقوله العميل'), findsOneWidget);
      // The client's own text is NOT translated — it is user content, and it
      // stays LTR inside the mirrored layout.
      expect(find.text(_longDescription), findsOneWidget);
      final Element description = tester.element(find.text(_longDescription));
      expect(Directionality.of(description), TextDirection.rtl);
    });
  });

  // What the 390x700 box exposed that the 800x600 default surface hides.
  group('JeeberRequestDetailLoader layout ceiling (390x700)', () {
    testWidgets('the dead end fits a phone at 100% text (the control)', (
      WidgetTester tester,
    ) async {
      await _pumpInPhoneBox(tester, jeeberRequestDetailLoaderUnavailable);

      expect(_overflowPixels(tester.takeException()), 0);
      // Measured: the CTA sits at y 540–588 in a 700 dp viewport.
      expect(tester.getRect(find.byKey(_deadEndCta)).bottom, lessThan(700));
    });

    testWidgets('FINDING — nothing on the dead end scrolls', (
      WidgetTester tester,
    ) async {
      await _pumpInPhoneBox(tester, jeeberRequestDetailLoaderUnavailable);

      // A bare centred Column: anything that outgrows the viewport is off the
      // screen rather than scrolled to. The resolved detail, reached through
      // the same loader, wraps its summary in a SingleChildScrollView.
      expect(find.byType(Scrollable), findsNothing);
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'FINDING — at 200% text the dead end has NO reachable affordance '
        '(${locale.languageCode})',
        (WidgetTester tester) async {
          await _pumpInPhoneBox(
            tester,
            jeeberRequestDetailLoaderUnavailable,
            textScale: 2.0,
            locale: locale,
          );

          // Measured: 240 dp of overflow in EN, 72 dp in AR. Part of that is
          // the raw 36-character UUID this subtitle interpolates — at 200% it
          // is several lines of text that `#775EAE` would not be.
          expect(_overflowPixels(tester.takeException()), greaterThan(0));
          // "Browse other requests" is the ONLY thing on this screen a jeeber
          // can act on, and it is laid out entirely below the viewport
          // (y 872 in EN, y 704 in AR) with nothing to scroll it back.
          expect(
            tester.getRect(find.byKey(_deadEndCta)).top,
            greaterThan(700),
            reason: 'the CTA is the whole forward path off this screen',
          );
        },
      );
    }

    testWidgets('the resolved detail survives 200% text — it scrolls', (
      WidgetTester tester,
    ) async {
      await _pumpInPhoneBox(
        tester,
        jeeberRequestDetailLoaderRecovered,
        textScale: 2.0,
      );

      // The contrast that makes the dead end a defect rather than a house
      // style: the same loader's resolved branch puts its summary in a scroll
      // view and pins the action bar, so the longest plausible request still
      // leaves "Send your offer" on screen (measured: y 568–616).
      expect(_overflowPixels(tester.takeException()), 0);
      expect(find.byType(Scrollable), findsAtLeastNWidgets(1));
      expect(tester.getRect(find.text('Send your offer')).bottom, lessThan(700));
    });
  });
}
