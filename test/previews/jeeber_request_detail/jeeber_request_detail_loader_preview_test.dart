// Render tests for the JeeberRequestDetailLoader previews.

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
int _overflowPixels(Object? error) {
  if (error == null) return 0;
  final RegExpMatch? match =
      RegExp(r'overflowed by ([\d.]+) pixels').firstMatch('$error');
  if (match == null) return 0;
  return double.parse(match.group(1)!).round();
}

/// Pumps a preview into the 390x700 box its annotation declares, instead of
/// into the 800x600 default test surface. The size is the point: at 800 pt the
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
/// Two previews in one test cannot simply be pumped one after the other: the
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
        expect(recovering, equals(redirecting));
        expect(recovering.keys, <String>[_detailTitle]);
      },
    );

    testWidgets(
      'FINDING — the dead end prints the RAW uuid, the detail prints #775EAE',
      (WidgetTester tester) async {
        await _pumpFresh(tester, jeeberRequestDetailLoaderRecovered);

        // Resolved: sprint-009 audit §T5 is honoured — short reference, no
        expect(find.text(friendlyReference(_requestId)), findsOneWidget);
        expect(find.text('#775EAE'), findsOneWidget);
        expect(find.textContaining(_requestId), findsNothing);

        await _pumpFresh(tester, jeeberRequestDetailLoaderUnavailable);

        // Same loader, same id, one route later: the raw 36-character UUID is
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
          expect(_overflowPixels(tester.takeException()), greaterThan(0));
          // "Browse other requests" is the ONLY thing on this screen a jeeber
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
      expect(_overflowPixels(tester.takeException()), 0);
      expect(find.byType(Scrollable), findsAtLeastNWidgets(1));
      expect(tester.getRect(find.text('Send your offer')).bottom, lessThan(700));
    });
  });
}
