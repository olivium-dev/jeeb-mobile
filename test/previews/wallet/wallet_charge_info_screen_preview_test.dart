// Render tests for the WalletChargeInfoScreen previews.

import 'package:flutter/material.dart';
// `RenderParagraph.textSize` — the laid-out text box, which is what exposes the
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/wallet_charge_info_screen_fixtures.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_charge_info_screen.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'WalletChargeInfoScreen',
    const <String, Widget Function()>{
      'Standalone · back → wallet-hub': walletChargeInfoScreenStandalone,
      'Pushed by a + Top up caller': walletChargeInfoScreenPushedFromTopUp,
      'Compact 320x568': walletChargeInfoScreenCompact,
      'EN · 200% text': walletChargeInfoScreenLargeText,
      'AR · 200% text': walletChargeInfoScreenArabicLargeText,
    },
    expectedText: const <String, String>{
      'Standalone · back → wallet-hub':
          'Go to any authorized Jeeb store near you.',
      'Pushed by a + Top up caller':
          'Give the cashier your phone number or ID.',
      'Compact 320x568': 'Pay the amount you want to add in cash.',
      'EN · 200% text': 'Your wallet balance updates automatically once the '
          'store confirms — there is no in-app payment.',
      // The one state the shared suite can genuinely discriminate: the AR
      'AR · 200% text': 'توجّه إلى أي متجر معتمد من جيب قريب منك.',
    },
  );

  group('WalletChargeInfoScreen preview specifics', () {
    /// Pumps [preview] with the surface set to the canvas box the preview's
    /// `@JeebPreview` declares, so the render test sees what the canvas draws.
    Future<void> pumpOnDevice(
      WidgetTester tester,
      Widget Function() preview,
      Size box, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.binding.setSurfaceSize(box);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPreview(tester, preview, locale: locale);
    }

    // ── Navigation state ──────────────────────────────────────────────────

    testWidgets('standalone · nothing to pop, so back goes to wallet-hub', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        walletChargeInfoScreenStandalone,
        walletChargeInfoScreenPhoneBox,
      );

      expect(find.bySemanticsIdentifier('charge_info_root'), findsOneWidget);
      expect(find.text(walletChargeInfoScreenWalletHubLabel), findsNothing);

      await tester.tap(find.text('Back to wallet'));
      await tester.pumpAndSettle();

      expect(find.text(walletChargeInfoScreenWalletHubLabel), findsOneWidget);
      expect(find.text(walletChargeInfoScreenCallerLabel), findsNothing);
    });

    testWidgets('pushed · back pops to the caller, NOT to the wallet', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        walletChargeInfoScreenPushedFromTopUp,
        walletChargeInfoScreenPhoneBox,
      );

      // Same button, same label...
      expect(find.text('Back to wallet'), findsOneWidget);

      await tester.tap(find.text('Back to wallet'));
      await tester.pumpAndSettle();

      // ...different destination. The CTA says "Back to wallet" and lands on
      expect(find.text(walletChargeInfoScreenCallerLabel), findsOneWidget);
      expect(find.text(walletChargeInfoScreenWalletHubLabel), findsNothing);
    });

    testWidgets('the app bar arrow shares the CTA destination contract', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        walletChargeInfoScreenStandalone,
        walletChargeInfoScreenPhoneBox,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text(walletChargeInfoScreenWalletHubLabel), findsOneWidget);
    });

    // ── Layout state ──────────────────────────────────────────────────────

    testWidgets('phone 390x844 · everything fits, CTA included', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        walletChargeInfoScreenStandalone,
        walletChargeInfoScreenPhoneBox,
      );

      // The baseline the other two layout cards are read against: on a
      final ScrollableState scrollable = tester.state(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, 0);
      expect(find.byType(OmdsPrimaryButton), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(OmdsPrimaryButton)).dy,
        lessThan(walletChargeInfoScreenPhoneBox.height),
      );
      // At 100% the step digit still fits inside its fixed 24 pt badge — the
      final RenderParagraph digit = tester.renderObject<RenderParagraph>(
        find.text('1'),
      );
      expect(digit.textSize.height, lessThanOrEqualTo(24));
    });

    testWidgets('compact 320x568 · the way out is already below the fold', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        walletChargeInfoScreenCompact,
        walletChargeInfoScreenCompactBox,
      );

      // All three steps and both notes are up, and the page LOOKS finished...
      expect(
        find.bySemanticsIdentifier('charge_info_store_step'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('charge_info_fee_note'), findsOneWidget);
      // ...but on the smallest supported phone, at NORMAL text size, the CTA
      final ScrollableState scrollable = tester.state(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(find.byType(OmdsPrimaryButton), findsNothing);

      await tester.scrollUntilVisible(
        find.bySemanticsIdentifier('charge_info_back_cta'),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.byType(OmdsPrimaryButton), findsOneWidget);
    });

    testWidgets('200% text · the step digit outgrows its 24 pt badge', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        walletChargeInfoScreenLargeText,
        walletChargeInfoScreenPhoneBox,
      );

      // The badge is a fixed `Sizes.xLarge` square...
      final Finder badge = find.ancestor(
        of: find.text('1'),
        matching: find.byType(Container),
      );
      expect(tester.getSize(badge.first), const Size(24, 24));
      final RenderParagraph digit = tester.renderObject<RenderParagraph>(
        find.text('1'),
      );
      // ...the paragraph is clamped to it, which is why a plain `getSize`
      expect(digit.size, const Size(24, 24));
      // ...while the text it actually lays out is 40 pt tall and paints
      expect(digit.textSize.height, greaterThan(24));
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% text · a screen and a half of scrolling to the CTA', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        walletChargeInfoScreenLargeText,
        walletChargeInfoScreenPhoneBox,
      );

      // Step 3 is already cut off, and neither note nor the CTA is built.
      expect(
        tester.getBottomLeft(
          find.bySemanticsIdentifier('charge_info_pay_cash_step'),
        ).dy,
        greaterThan(walletChargeInfoScreenPhoneBox.height),
      );
      expect(find.bySemanticsIdentifier('charge_info_fee_note'), findsNothing);
      expect(find.byType(OmdsPrimaryButton), findsNothing);

      // Measured 1198 pt of overrun against a 788 pt viewport — asserted as
      final ScrollableState scrollable = tester.state(find.byType(Scrollable));
      expect(
        scrollable.position.maxScrollExtent,
        greaterThan(scrollable.position.viewportDimension),
      );

      await tester.scrollUntilVisible(
        find.bySemanticsIdentifier('charge_info_back_cta'),
        300,
      );
      await tester.pumpAndSettle();
      expect(find.byType(OmdsPrimaryButton), findsOneWidget);
    });

    testWidgets('AR · 200% renders RTL Arabic copy, latin step digits', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        walletChargeInfoScreenArabicLargeText,
        walletChargeInfoScreenPhoneBox,
      );

      final BuildContext stepContext = tester.element(
        find.text('توجّه إلى أي متجر معتمد من جيب قريب منك.'),
      );
      expect(Directionality.of(stepContext), TextDirection.rtl);
      // The badges keep latin digits while the copy beside them mirrors, so the
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // The step badge is right-aligned in Arabic (it leads the row, and the
      expect(
        tester.getCenter(find.text('1')).dx,
        greaterThan(walletChargeInfoScreenPhoneBox.width / 2),
      );
      expect(find.text('Go to any authorized Jeeb store near you.'), findsNothing);
    });
  });
}
