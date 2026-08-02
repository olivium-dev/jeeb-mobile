// Render tests for the WalletActivityListScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state pins a DISTINCT string, which matters more for a screen than for
// a widget: all seven previews are the same screen behind the same app bar,
// differing only in the fake repository they are constructed with. A suite that
// asserted "the app bar rendered" would pass with every preview wired to the
// same fake.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/wallet/presentation/wallet_activity_list_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/widgets/wallet_activity_row.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview whose surface actually settles. The two that hold a
  // `Shimmer` — `Loading · first page` and `Loaded · more to come` — get their
  // own groups below, because an infinitely repeating animation means
  // `pumpAndSettle` never returns.
  testPreviewsRender(
    'WalletActivityListScreen',
    const <String, Widget Function()>{
      'Loaded · mixed ledger': walletActivityListScreenLoaded,
      'Empty · no activity yet': walletActivityListScreenEmpty,
      'Error · offline': walletActivityListScreenOffline,
      'Error · session expired': walletActivityListScreenSessionExpired,
      'Loaded · worst page': walletActivityListScreenWorstPage,
    },
    expectedText: const <String, String>{
      // The gift row's reference. `Wallet activity` (the app bar title) or
      // `Top up` would not do — the title is shared by every state and the
      // top-up type label also appears on the worst page.
      'Loaded · mixed ledger': 'Ref: gift-kyc-001',
      'Empty · no activity yet': 'No activity yet',
      // The ONLY failure with copy of its own...
      'Error · offline': 'No connection. Check your network and try again.',
      // ...and the string every other failure collapses to.
      'Error · session expired': 'Could not load your activity.',
      'Loaded · worst page':
          'Ref: off-2026-06-18-beirut-hamra-b42-3f-abdulrahman-almuhandis-0091',
    },
  );

  // `OmdsListItemShimmer` wraps its placeholder in `Shimmer.fromColors`, whose
  // controller `repeat()`s forever, so `pumpAndSettle` — which `pumpPreview`
  // calls — times out on any preview that shows one. These two get the same
  // three assertions the shared suite makes (builds in EN, builds in AR,
  // renders its OWN state) driven by fixed pumps instead.
  Future<void> pumpShimmering(
    WidgetTester tester,
    Widget Function() preview, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(previewCanvas(preview, locale));
    await tester.pump(); // resolve localizations + the nested Router
    await tester.pump(); // let the cubit's first emit land
    await tester.pump(const Duration(milliseconds: 16)); // one shimmer frame
  }

  group('WalletActivityListScreen previews · Loading · first page', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · first page · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpShimmering(
          tester,
          walletActivityListScreenLoading,
          locale: locale,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · first page renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpShimmering(tester, walletActivityListScreenLoading);

      // The D73 skeleton state is up...
      expect(
        find.bySemanticsIdentifier('wallet_activity_loading'),
        findsOneWidget,
      );
      // ...and none of the three settled surfaces is. That combination is true
      // of no other preview in this file.
      expect(find.byType(WalletActivityRow), findsNothing);
      expect(
        find.bySemanticsIdentifier('wallet_activity_empty'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('wallet_activity_error'),
        findsNothing,
      );
    });
  });

  group('WalletActivityListScreen previews · Loaded · more to come', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loaded · more to come · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpShimmering(
          tester,
          walletActivityListScreenPaged,
          locale: locale,
        );

        expect(tester.takeException(), isNull);
      });
    }

    // The finding this preview exists for. `showFooter` is
    // `loadingMore || loadMoreError || hasMore`, and the `hasMore` branch falls
    // through to the SAME `wallet_activity_load_more` shimmer the in-flight
    // branch renders. Nothing is loading here — the page landed, `loadingMore`
    // is false, and `loadMore()` is only ever called from the scroll listener —
    // yet the list still ends in an animating skeleton row.
    testWidgets(
      'Loaded · more to come renders its own state: a settled list that still '
      'ends in the load-more skeleton',
      (WidgetTester tester) async {
        await pumpShimmering(tester, walletActivityListScreenPaged);

        // The page landed: the real rows are up (this is not the loading
        // state, which has no rows at all).
        expect(find.byType(WalletActivityRow), findsNWidgets(3));
        expect(
          find.bySemanticsIdentifier('wallet_activity_loading'),
          findsNothing,
        );
        // And the footer skeleton is up anyway, on a list that is not
        // fetching anything.
        expect(
          find.bySemanticsIdentifier('wallet_activity_load_more'),
          findsOneWidget,
        );
        // Not the failed-page footer either — that one is text + a retry.
        expect(find.text('Could not load more.'), findsNothing);
      },
    );

    testWidgets('the same ledger WITHOUT a further page has no footer', (
      WidgetTester tester,
    ) async {
      // The control for the assertion above: identical rows, `totalPages: 1`.
      // If this ever also renders the skeleton, the footer is not keyed on
      // `hasMore` at all.
      await pumpPreview(tester, walletActivityListScreenLoaded);

      expect(find.byType(WalletActivityRow), findsNWidgets(3));
      expect(
        find.bySemanticsIdentifier('wallet_activity_load_more'),
        findsNothing,
      );
    });
  });

  // The shared suite pumps at the tester's default 800x600 surface, where this
  // screen has 410 pt of slack it does not have on a phone. These pump each
  // preview at the box its `@JeebPreview(size:)` declares, which is the only
  // way the declared size stays honest — and at the text scales the canvas
  // matrix renders, which is where the screen actually breaks.
  group('WalletActivityListScreen previews · at the declared canvas box', () {
    /// A real device rather than the test default: [Size] in logical pixels at
    /// dpr 1, so `physicalSize` is the box the preview declares.
    Future<void> pumpAtBox(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
      double textScale = 1.0,
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(previewCanvas(preview, locale));
      await tester.pumpAndSettle();
    }

    const Map<String, Widget Function()> settled = <String, Widget Function()>{
      'Loaded · mixed ledger': walletActivityListScreenLoaded,
      'Empty · no activity yet': walletActivityListScreenEmpty,
      'Error · offline': walletActivityListScreenOffline,
      'Error · session expired': walletActivityListScreenSessionExpired,
      'Loaded · worst page': walletActivityListScreenWorstPage,
    };

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry
          in settled.entries) {
        testWidgets('${entry.key} · ${locale.languageCode} · 390x844', (
          WidgetTester tester,
        ) async {
          await pumpAtBox(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    // The error body is the one surface here with no scroll fallback — a
    // `Center` → `Column` holding a 64 pt icon, a wrapped message and the retry
    // CTA. It clears 200% text on a phone AND on a 320x568 compact device
    // today, which is worth pinning: the next string that grows is the one that
    // clips, and nothing about the widget would tell you.
    for (final double scale in const <double>[1.5, 2.0]) {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        testWidgets(
          'Error · session expired fits a 320x568 device at '
          '${(scale * 100).round()}% text · ${locale.languageCode}',
          (WidgetTester tester) async {
            await pumpAtBox(
              tester,
              walletActivityListScreenSessionExpired,
              locale: locale,
              textScale: scale,
              size: const Size(320, 568),
            );

            expect(tester.takeException(), isNull);
            // Still whole: the message and the CTA are both on screen, not
            // pushed off the bottom of an unscrollable column.
            expect(
              find.bySemanticsIdentifier('wallet_activity_error'),
              findsOneWidget,
            );
            expect(
              find.bySemanticsIdentifier('wallet_activity_retry_cta'),
              findsOneWidget,
            );
          },
        );
      }
    }

    // KNOWN DEFECT, pinned deliberately — see the section header in
    // `wallet_activity_list_screen.dart`.
    //
    // `WalletActivityRow` puts the signed amount OUTSIDE its `Expanded`, so the
    // amount takes its intrinsic width first and the row grows past the
    // viewport instead of the text column yielding. The mixed ledger's widest
    // amount is `+50.00 USD` — nothing pathological — and it still overflows
    // at 200% text on the 390x844 box these previews declare, and at 150% on a
    // 320 pt device.
    //
    // These two tests assert the CURRENT behaviour. When the row is fixed they
    // fail; that is the signal to delete them, not to widen them.
    testWidgets('KNOWN: the plain ledger overflows at 200% text on a phone', (
      WidgetTester tester,
    ) async {
      await pumpAtBox(tester, walletActivityListScreenLoaded, textScale: 2.0);

      final Object? exception = tester.takeException();
      expect(exception, isFlutterError);
      expect(
        exception.toString(),
        contains('overflowed by 3.0 pixels on the right'),
      );
    });

    testWidgets('KNOWN: on a 320 pt device it already overflows at 150%', (
      WidgetTester tester,
    ) async {
      await pumpAtBox(
        tester,
        walletActivityListScreenLoaded,
        textScale: 1.5,
        size: const Size(320, 568),
      );

      expect(tester.takeException(), isFlutterError);
    });

    // The control: at 100% the same ledger is clean on both devices, so the
    // two assertions above are about text scale and not about the fixture.
    for (final Size size in const <Size>[Size(390, 844), Size(320, 568)]) {
      testWidgets('the plain ledger is clean at 100% on ${size.width.round()}pt',
          (WidgetTester tester) async {
        await pumpAtBox(tester, walletActivityListScreenLoaded, size: size);

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('WalletActivityListScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree
    // — `_WalletActivityListScreenHost` → `Router` → `WalletActivityListScreen`
    // — differing only in the repository handed to it, so pumping a second
    // preview into the same tester would reuse the first preview's element and
    // with it the first preview's cubit.

    testWidgets('the loaded preview shows the JM-055 signature ids', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletActivityListScreenLoaded);

      expect(
        find.bySemanticsIdentifier('wallet_activity_root'),
        findsOneWidget,
      );
      // The per-row dynamic id, on the shared fixture ledger.
      for (final String id in const <String>['ldg-1', 'ldg-2', 'ldg-3']) {
        expect(
          find.bySemanticsIdentifier('wallet_activity_row_$id'),
          findsOneWidget,
        );
      }
    });

    testWidgets('a row tap reaches transaction-detail with the row id', (
      WidgetTester tester,
    ) async {
      // Proves the preview host is honest to tap in: the screen's
      // `pushNamed('transaction-detail')` needs a Router, and a preview without
      // one would throw here instead of navigating.
      await pumpPreview(tester, walletActivityListScreenLoaded);

      await tester.tap(
        find.descendant(
          of: find.byType(WalletActivityRow).first,
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('transaction-detail: ldg-1'), findsOneWidget);
    });

    testWidgets('the back arrow lands on the wallet hub, not a black surface', (
      WidgetTester tester,
    ) async {
      // The deep-link entry the screen's back handler was written for: nothing
      // to pop, so `canPop()` is false and it must `go('/')` rather than pop
      // the last page off an empty Navigator.
      await pumpPreview(tester, walletActivityListScreenEmpty);

      // `OMDSAppBar` builds its own leading `IconButton(Icons.arrow_back)`
      // rather than a `BackButton`, so that is what there is to tap.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('wallet-hub (JM-053)'), findsOneWidget);
    });

    testWidgets(
      'an expired session is indistinguishable from an unknown failure',
      (WidgetTester tester) async {
        // `_WalletActivityView._errorCopy` folds `unauthorized` in with
        // `unknown` and `null`, so the one failure a user could act on (sign in
        // again) reads exactly like the one they cannot, and the only
        // affordance offered is a Retry of the same unauthorized call.
        await pumpPreview(tester, walletActivityListScreenSessionExpired);

        expect(find.text('Could not load your activity.'), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('wallet_activity_retry_cta'),
          findsOneWidget,
        );
        // Nothing points at re-authentication anywhere on the surface.
        expect(find.textContaining('sign in'), findsNothing);
        expect(find.textContaining('Sign in'), findsNothing);
      },
    );

    testWidgets('the worst page renders its awkward rows, not just its first', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletActivityListScreenWorstPage);

      // Row 1: a `type` this build does not know → the generic label, and no
      // `currency` → a bare number in a ledger of USD.
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('-1.75'), findsOneWidget);
      // Row 2: neither `ref` nor `ts`. Both sub-lines are behind
      // `isNotEmpty` guards, so the row collapses to a label and a number.
      expect(
        find.bySemanticsIdentifier('wallet_activity_row_ldg-bare'),
        findsOneWidget,
      );
      expect(find.text('Ref: '), findsNothing);
    });
  });
}
