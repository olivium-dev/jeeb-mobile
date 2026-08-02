// Render tests for the WalletHubScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state pins a DISTINCT string, which matters more for a screen than for
// a widget: all eight previews are the same screen behind the same app bar,
// differing only in the fake repository, the scripted KYC gate and (once) the
// ambient connectivity. A suite that asserted "the Wallet title rendered" would
// pass with every preview wired to the same fake. Where the state IS a number,
// the pin is that number — the fixtures deliberately give every band a distinct
// amount so `145.00` can only be the healthy wallet.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/wallet/presentation/wallet_hub_screen.dart';

import '../preview_test_harness.dart';

/// The D35 offline guard's copy — a SnackBar that only appears after a tap.
const String _offlineBlocked = 'You’re offline — reconnect to add funds.';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · spinner`, which cannot settle — see the
  // dedicated group below.
  testPreviewsRender(
    'WalletHubScreen',
    const <String, Widget Function()>{
      'Ready to bid · funded': walletHubScreenReadyToBid,
      'Running low · starter credit': walletHubScreenRunningLowWithGift,
      'Empty · KYC pending': walletHubScreenEmptyWithKycPending,
      'All reserved': walletHubScreenEverythingReserved,
      'Ceiling · LBP + every band': walletHubScreenCeilingLbp,
      'Error · load failed': walletHubScreenLoadFailed,
      'Offline · top-up blocked': walletHubScreenOfflineTopUp,
    },
    expectedText: const <String, String>{
      // The available balance. Each band's amount is unique across the
      // fixtures, so the number alone identifies the state.
      'Ready to bid · funded': '145.00',
      // The D42 gift badge — rendered by this fixture and no other.
      'Running low · starter credit': '50.00 USD starter credit',
      // The `empty` affordability body (D43). `0.00` would be ambiguous with a
      // zeroed reserve elsewhere; this copy belongs to one band only.
      'Empty · KYC pending': 'Add funds to start making offers.',
      'All reserved': 'Everything is reserved',
      // Eight digits and no thousands separator — see the section prose.
      'Ceiling · LBP + every band': '89750000.00',
      'Error · load failed': "We couldn't load your wallet. Please try again.",
      'Offline · top-up blocked': '63.00',
    },
  );

  // The loading sub-state is an indeterminate `CircularProgressIndicator`
  // (`OmdsLoadingState`) held open by a read that never lands. `pumpAndSettle`
  // — which `pumpPreview` calls — never returns while one is on screen, so this
  // preview gets the same three assertions the shared suite makes (builds in
  // EN, builds in AR, renders its OWN state) driven by fixed pumps instead.
  group('WalletHubScreen previews · Loading · spinner', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(walletHubScreenLoadingSpinner, locale),
      );
      await tester.pump(); // resolve localizations + the nested Router
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · spinner · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · spinner renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      // The spinner is up...
      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...and neither settled surface is. That combination is true of no
      // other preview in this file.
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_available_balance'),
          findsNothing);
    });

    // The finding this preview exists for. The loading body is the ENTIRE
    // body: no skeleton of the balance line, and — unlike the error state —
    // nothing to press. `WalletHubCubit.load()` also guards on
    // `status != initial`, so a rebuild cannot restart a read that never
    // lands; the screen has no way out of this frame.
    testWidgets('the loading state offers no action at all', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_how_fees_work'), findsNothing);
      expect(find.byType(OmdsPrimaryButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing); // the error retry
    });
  });

  group('WalletHubScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree
    // — `_WalletHubScreenHost` → `Router` → `WalletHubScreen` — differing only
    // in the seams handed to it, so pumping a second preview into the same
    // tester would reuse the first preview's element and with it the first
    // preview's cubit.

    testWidgets('the funded preview shows the JM-053 signature ids', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletHubScreenReadyToBid);

      expect(find.bySemanticsIdentifier('wallet_hub_root'), findsOneWidget);
      expect(find.bySemanticsIdentifier('wallet_available_balance'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('wallet_affordability_card'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('wallet_reserved_now'), findsOneWidget);
      expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('wallet_how_fees_work'), findsOneWidget);
      expect(find.bySemanticsIdentifier('wallet_earnings_row'), findsOneWidget);
      expect(find.bySemanticsIdentifier('wallet_see_all_activity'),
          findsOneWidget);
      // D42: `giftCredit == 0` on this wallet, so the badge is absent — the
      // healthy state is also the "no starter credit" layout.
      expect(find.bySemanticsIdentifier('wallet_gift_badge'), findsNothing);
      // AC7: approved, so no pending banner.
      expect(find.bySemanticsIdentifier('wallet_kyc_pending_banner'),
          findsNothing);
    });

    testWidgets('the gift badge and the "running low" warning coexist (D42/D43)',
        (WidgetTester tester) async {
      await pumpPreview(tester, walletHubScreenRunningLowWithGift);

      // The badge announces 50.00 USD of starter credit...
      expect(find.bySemanticsIdentifier('wallet_gift_badge'), findsOneWidget);
      expect(find.text('50.00 USD starter credit'), findsOneWidget);
      // ...directly above a card telling the jeeber they are running low. Both
      // are true; together they are the most confusing 100 pt on the screen.
      expect(find.text('Running low'), findsOneWidget);
      expect(find.text('Ready to bid'), findsNothing);
    });

    testWidgets('the pending preview stacks the KYC banner above everything', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletHubScreenEmptyWithKycPending);

      expect(find.bySemanticsIdentifier('wallet_kyc_pending_banner'),
          findsOneWidget);
      expect(find.text('Verification in progress'), findsOneWidget);
      // D38/D39: top-up stays available while verification is pending — the
      // banner promises it, so the CTA has to be there.
      expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);
      // The zero wallet: available AND reserved are both 0.
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('0.00 USD'), findsOneWidget);
    });

    testWidgets('all-reserved prints the same number twice and explains it '
        'only in copy', (WidgetTester tester) async {
      await pumpPreview(tester, walletHubScreenEverythingReserved);

      // `wallet_available_balance` says 20.00 and `wallet_reserved_now` says
      // 20.00 USD — the screen never states the relationship between them.
      expect(find.text('20.00'), findsOneWidget);
      expect(find.text('20.00 USD'), findsOneWidget);
      // D43: the meaning is carried by the copy, not by the numbers.
      expect(find.text('Everything is reserved'), findsOneWidget);
    });

    testWidgets('the LBP ceiling renders money with no grouping in either '
        'locale', (WidgetTester tester) async {
      await pumpPreview(tester, walletHubScreenCeilingLbp);

      // `_fmt` is `toStringAsFixed(2)`: no separator, no locale digits.
      expect(find.text('89750000.00'), findsOneWidget);
      expect(find.text('8975000.00 LBP'), findsOneWidget);
      expect(find.text('4500000.00 LBP starter credit'), findsOneWidget);

      // Arabic changes the surrounding copy and mirrors the row, but not one
      // digit of the amount — there is no `NumberFormat` anywhere on this
      // screen.
      await tester.pumpWidget(
        previewCanvas(walletHubScreenCeilingLbp, const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('89750000.00'), findsOneWidget);
      expect(find.text('الرصيد المتاح'), findsOneWidget);
    });

    // DOCUMENTED DEFECT, not a desired behaviour. Every test above runs on the
    // 800x600 default test surface, where this screen fits comfortably; the
    // `size:` a preview declares is honoured by the canvas, not by
    // `previewCanvas`. Pumped at the 390x844 phone the previews actually
    // declare, the LBP wallet does not fit — at 100% text, in both locales.
    //
    // The balance line is `Row(Text(amount), SizedBox, Text(currency))` with no
    // `Flexible` child, and `_fmt` prints `toStringAsFixed(2)`, so an eight-
    // digit LBP amount simply runs off the right edge (6.5 pt) and the gift
    // chip with it (51 pt).
    //
    // When this test starts FAILING, the balance line was made flexible (or the
    // amount formatted) and this test has done its job — delete it.
    testWidgets('the LBP wallet does not fit a 390 pt phone, even at 100% text',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844); // the declared box
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Collect layout errors instead of letting the binding record them, so
      // the test ends clean either way and the assertion is about CONTENT.
      final List<String> errors = <String>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails d) =>
          errors.add(d.exception.toString());
      await tester.pumpWidget(
        previewCanvas(walletHubScreenCeilingLbp, const Locale('en')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      FlutterError.onError = previous;
      tester.takeException();

      expect(
        errors.where((String e) => e.contains('overflowed')),
        isNotEmpty,
        reason: 'The LBP ceiling used to overflow the 390 pt phone at 100% '
            'text. If it no longer does, the balance Row was fixed — delete '
            'this test.',
      );
    });

    testWidgets('the error preview loses the whole body, top-up included', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletHubScreenLoadFailed);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // The hub root and its app bar survive...
      expect(find.bySemanticsIdentifier('wallet_hub_root'), findsOneWidget);
      // ...but the error branch replaces the ENTIRE body, so a jeeber who
      // cannot load a balance also loses the one action that would fix an
      // empty wallet, plus the fees explainer and both cross-wave rows.
      expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_how_fees_work'), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_earnings_row'), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_see_all_activity'),
          findsNothing);
    });

    testWidgets('online: top-up takes the honest wallet-charge-info edge', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletHubScreenReadyToBid);

      await tester.tap(find.bySemanticsIdentifier('wallet_topup_cta'));
      await tester.pumpAndSettle();

      // The preview host's stand-in for the real JM-054 route. This is what
      // makes the canvas tappable — without the local GoRouter the tap throws.
      expect(find.text('wallet-charge-info'), findsOneWidget);
      expect(find.text(_offlineBlocked), findsNothing);
    });

    // The finding the offline preview exists for. `wallet_topup_cta` is a
    // full-strength `OmdsPrimaryButton` whether or not the device is online:
    // the D35 guard lives inside `_onTopUp` and only speaks AFTER the tap.
    testWidgets('offline: the top-up CTA looks live and blocks only on tap', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletHubScreenOfflineTopUp);

      // Nothing on the screen says "offline" before the tap: no banner, no
      // disabled treatment, no inline notice.
      expect(find.text(_offlineBlocked), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);
      expect(find.text('Top up'), findsOneWidget);

      await tester.tap(find.bySemanticsIdentifier('wallet_topup_cta'));
      await tester.pump(); // the SnackBar is scheduled
      await tester.pump(const Duration(milliseconds: 750)); // entrance

      // Only now — and the navigation the same tap performs when online did
      // NOT happen.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_offlineBlocked), findsOneWidget);
      expect(find.text('wallet-charge-info'), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);

      // Run the 4s auto-dismiss timer out so the test ends timer-free — and
      // note what is left behind: the wallet reads exactly as it did before
      // the tap.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(_offlineBlocked), findsNothing);
      expect(find.text('Top up'), findsOneWidget);
    });
  });
}
