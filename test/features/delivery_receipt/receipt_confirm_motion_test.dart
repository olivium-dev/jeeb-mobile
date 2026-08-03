// Wave-3 motion wiring (08-MOTION-SPEC §2.5, screen 14): confirming receipt
// plays `success-check.json` ONCE before the mandatory-rating hand-off.
//
// The load-bearing assertion is the last one in each case: the navigation is
// owned by the screen's own timer, NEVER by the animation finishing, so a slow
// or missing composition can never strand the customer on the prompt.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/delivery_receipt/data/fake_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/widgets/receipt_confirmed_overlay.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const DeliveryReceipt _receipt = DeliveryReceipt(
  deliveryId: 'd-1',
  jeeberName: 'Karim',
  jeeberId: 'user-jeeber-002',
  cashAmount: 8,
  currency: 'USD',
  status: 'AtDoor',
  proofPhotoUrl: 'https://cdn.jeeb.app/proof/d-1.jpg',
);

Widget _harness({bool disableAnimations = false}) {
  final GoRouter router = GoRouter(
    initialLocation: '/orders/d-1/receipt',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id/receipt',
        // The MediaQuery override sits INSIDE the app: WidgetsApp installs its
        // own `MediaQuery.fromView`, so an outer one would be shadowed.
        builder: (BuildContext context, GoRouterState state) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: DeliveryReceiptScreen(
            deliveryId: state.pathParameters['id']!,
            repository: FakeDeliveryReceiptRepository(receipt: _receipt),
          ),
        ),
      ),
      GoRoute(
        name: 'mutual-rating',
        path: '/orders/:id/rate',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('rating')),
      ),
      GoRoute(
        name: 'escalate',
        path: '/orders/:id/escalate',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('escalate')),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

/// `OmdsCachedImage` never resolves under `flutter test`'s HttpClient, so every
/// case drives bounded `pump()`s — never `pumpAndSettle()`.
Future<void> _pumpLoaded(WidgetTester tester, Widget harness) async {
  await tester.pumpWidget(harness);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.bySemanticsIdentifier('receipt_confirm_cta'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('confirming plays the one-shot mark over the prompt', (
    tester,
  ) async {
    await _pumpLoaded(tester, _harness());

    expect(find.byType(ReceiptConfirmedOverlay), findsNothing);
    await _confirm(tester);

    expect(find.byType(ReceiptConfirmedOverlay), findsOneWidget);
    // One-shot: a controller drives it, so it can never be handed a loop.
    final LottieBuilder mark = tester.widget<LottieBuilder>(
      find.descendant(
        of: find.byType(ReceiptConfirmedOverlay),
        matching: find.byType(LottieBuilder),
      ),
    );
    expect(mark.controller, isNotNull);
  });

  testWidgets('the rating hand-off still happens — the mark never gates it', (
    tester,
  ) async {
    await _pumpLoaded(tester, _harness());
    await _confirm(tester);

    // Past the 900ms beat. Nothing here waits on the composition loading.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('rating'), findsOneWidget);
  });

  testWidgets('reduce-motion skips the beat entirely — no mark, no delay', (
    tester,
  ) async {
    await _pumpLoaded(tester, _harness(disableAnimations: true));
    await _confirm(tester);

    expect(find.byType(ReceiptConfirmedOverlay), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('rating'), findsOneWidget);
  });

  testWidgets('the prompt identifiers survive up to the confirm', (
    tester,
  ) async {
    await _pumpLoaded(tester, _harness());

    for (final String id in <String>[
      'receipt_prompt',
      'receipt_cash_to_jeeber_label',
      'receipt_proof_photo',
      'receipt_confirm_cta',
      'receipt_not_yet_cta',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    }
  });
}
