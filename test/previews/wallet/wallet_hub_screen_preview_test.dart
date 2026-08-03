import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/wallet/presentation/wallet_hub_screen.dart';

import '../preview_test_harness.dart';

/// The D35 offline guard's copy — a SnackBar that only appears 
const String _offlineBlocked = 'You’re offline — reconnect to add funds.';

void main() {
  setUpAll(loadPreviewArbs);

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
      'Ready to bid · funded': '145.00',
      'Running low · starter credit': '50.00 USD starter credit',
      'Empty · KYC pending': 'Add funds to start making offers.',
      'All reserved': 'Everything is reserved',
      'Ceiling · LBP + every band': '89750000.00',
      'Error · load failed': "We couldn't load your wallet. Please try again.",
      'Offline · top-up blocked': '63.00',
    },
  );

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

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_available_balance'),
          findsNothing);
    });

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
      expect(find.bySemanticsIdentifier('wallet_gift_badge'), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_kyc_pending_banner'),
          findsNothing);
    });

    testWidgets('the gift badge and the "running low" warning coexist (D42/D43)',
        (WidgetTester tester) async {
      await pumpPreview(tester, walletHubScreenRunningLowWithGift);

      expect(find.bySemanticsIdentifier('wallet_gift_badge'), findsOneWidget);
      expect(find.text('50.00 USD starter credit'), findsOneWidget);
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
      expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('0.00 USD'), findsOneWidget);
    });

    testWidgets('all-reserved prints the same number twice and explains it '
        'only in copy', (WidgetTester tester) async {
      await pumpPreview(tester, walletHubScreenEverythingReserved);

      expect(find.text('20.00'), findsOneWidget);
      expect(find.text('20.00 USD'), findsOneWidget);
      expect(find.text('Everything is reserved'), findsOneWidget);
    });

    testWidgets('the LBP ceiling renders money with no grouping in either '
        'locale', (WidgetTester tester) async {
      await pumpPreview(tester, walletHubScreenCeilingLbp);

      expect(find.text('89750000.00'), findsOneWidget);
      expect(find.text('8975000.00 LBP'), findsOneWidget);
      expect(find.text('4500000.00 LBP starter credit'), findsOneWidget);

      await tester.pumpWidget(
        previewCanvas(walletHubScreenCeilingLbp, const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('89750000.00'), findsOneWidget);
      expect(find.text('الرصيد المتاح'), findsOneWidget);
    });

    testWidgets('the LBP wallet does not fit a 390 pt phone, even at 100% text',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844); // the declared box
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
      expect(find.bySemanticsIdentifier('wallet_hub_root'), findsOneWidget);
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

      expect(find.text('wallet-charge-info'), findsOneWidget);
      expect(find.text(_offlineBlocked), findsNothing);
    });

    testWidgets('offline: the top-up CTA looks live and blocks only on tap', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletHubScreenOfflineTopUp);

      expect(find.text(_offlineBlocked), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);
      expect(find.text('Top up'), findsOneWidget);

      await tester.tap(find.bySemanticsIdentifier('wallet_topup_cta'));
      await tester.pump(); // the SnackBar is scheduled
      await tester.pump(const Duration(milliseconds: 750)); // entrance

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_offlineBlocked), findsOneWidget);
      expect(find.text('wallet-charge-info'), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(_offlineBlocked), findsNothing);
      expect(find.text('Top up'), findsOneWidget);
    });
  });
}
