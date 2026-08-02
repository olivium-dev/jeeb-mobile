// Render tests for the WalletActivityListScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/wallet/presentation/wallet_activity_list_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/widgets/wallet_activity_row.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview whose surface actually settles. The two that hold a
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
    testWidgets(
      'Loaded · more to come renders its own state: a settled list that still '
      'ends in the load-more skeleton',
      (WidgetTester tester) async {
        await pumpShimmering(tester, walletActivityListScreenPaged);

        // The page landed: the real rows are up (this is not the loading
        expect(find.byType(WalletActivityRow), findsNWidgets(3));
        expect(
          find.bySemanticsIdentifier('wallet_activity_loading'),
          findsNothing,
        );
        // And the footer skeleton is up anyway, on a list that is not
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
      await pumpPreview(tester, walletActivityListScreenLoaded);

      expect(find.byType(WalletActivityRow), findsNWidgets(3));
      expect(
        find.bySemanticsIdentifier('wallet_activity_load_more'),
        findsNothing,
      );
    });
  });

  // The shared suite pumps at the tester's default 800x600 surface, where this
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
      await pumpPreview(tester, walletActivityListScreenEmpty);

      // `OMDSAppBar` builds its own leading `IconButton(Icons.arrow_back)`
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('wallet-hub (JM-053)'), findsOneWidget);
    });

    testWidgets(
      'an expired session is indistinguishable from an unknown failure',
      (WidgetTester tester) async {
        // `_WalletActivityView._errorCopy` folds `unauthorized` in with
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
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('-1.75'), findsOneWidget);
      // Row 2: neither `ref` nor `ts`. Both sub-lines are behind
      expect(
        find.bySemanticsIdentifier('wallet_activity_row_ldg-bare'),
        findsOneWidget,
      );
      expect(find.text('Ref: '), findsNothing);
    });
  });
}
