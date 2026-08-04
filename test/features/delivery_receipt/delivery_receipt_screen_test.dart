import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/delivery_receipt_screen_fixtures.dart';
import 'package:jeeb_mobile/features/delivery_receipt/data/fake_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// The redesigned `delivered-receipt-confirm` (JM-033, redesign screen 14).
///
/// Until this file existed the screen's behavioural contract lived only in
/// out-of-CI Maestro (`jm-033`). These tests pin the six identifiers, the AC4
/// negative assertion (no commission / platform-fee line on a customer
/// surface) and the scroll posture that keeps the CTAs reachable at 200% text
/// scale.
///
/// `OmdsCachedImage` never resolves under `flutter test`'s HttpClient, so every
/// case drives bounded `pump()`s — never `pumpAndSettle()`.
DeliveryReceipt _receipt({
  String? proofPhotoUrl = 'https://cdn.jeeb.app/proof/d-1.jpg',
  double? cashAmount = 8.0,
  String jeeberName = 'Karim',
}) => DeliveryReceipt(
  deliveryId: 'd-1',
  jeeberName: jeeberName,
  jeeberId: 'user-jeeber-002',
  cashAmount: cashAmount,
  currency: 'USD',
  status: 'AtDoor',
  proofPhotoUrl: proofPhotoUrl,
);

/// Mounts the screen on a router that owns the two destinations it navigates
/// to (`mutual-rating` after a confirm, `escalate` behind "Not yet").
/// A read that never lands — the loading state of every receipt.
DeliveryReceiptRepository _pending() =>
    const DeliveryReceiptScreenPendingRepository();

Widget _harness(
  DeliveryReceipt receipt, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  DeliveryReceiptRepository? repository,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/orders/d-1/receipt',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id/receipt',
        builder: (BuildContext context, GoRouterState state) =>
            DeliveryReceiptScreen(
              deliveryId: state.pathParameters['id']!,
              repository:
                  repository ?? FakeDeliveryReceiptRepository(receipt: receipt),
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

  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

Future<void> _pumpLoaded(WidgetTester tester, Widget harness) async {
  await tester.pumpWidget(harness);
  // Two frames: one for the cubit's `load()` future, one for the rebuild.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('DeliveryReceiptScreen — R14 field', () {
    testWidgets('mounts the measured top-start periwinkle bloom, no orange', (
      tester,
    ) async {
      await _pumpLoaded(tester, _harness(_receipt()));

      final JeebMidnightField field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      // Board tpl 845: `480px 400px at 15% -6% rgba(119,127,192,.24)` and NO
      // orange radial — the bloom sits above the top edge, not at mid-height.
      expect(field.washPlacement, JeebFieldWashPlacement.topStart);
      expect(field.washPlacement!.fy, lessThan(0));
      expect(field.glowColor, Colors.transparent);
      expect(field.variant, JeebFieldVariant.content);
      expect(field.animateDecor, isFalse);
    });

    testWidgets('the bloom stays on the start edge under RTL', (tester) async {
      await _pumpLoaded(
        tester,
        _harness(_receipt(), locale: const Locale('ar')),
      );

      final JeebMidnightField field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.washPlacement, JeebFieldWashPlacement.topStart);
      expect(
        field.washPlacement!.alignment.resolve(TextDirection.rtl).x,
        greaterThan(0),
      );
    });
  });

  group('DeliveryReceiptScreen — identifiers', () {
    testWidgets('the loaded body emits every JM-033 identifier', (
      tester,
    ) async {
      await _pumpLoaded(tester, _harness(_receipt()));

      for (final String id in <String>[
        'receipt_prompt',
        'receipt_cash_to_jeeber_label',
        'receipt_proof_photo',
        'receipt_proof_zoom_cta',
        'receipt_confirm_cta',
        'receipt_not_yet_cta',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: '$id must survive the redesign (Maestro jm-033 keys on it)',
        );
      }
      expect(find.byKey(const Key('receipt-confirm-cta')), findsOneWidget);
      expect(find.byKey(const Key('receipt-not-yet-cta')), findsOneWidget);
    });

    testWidgets('there is no app bar and the prompt is the only heading', (
      tester,
    ) async {
      await _pumpLoaded(tester, _harness(_receipt()));

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Did you receive your order?'), findsOneWidget);
    });
  });

  group('DeliveryReceiptScreen — AC4 (no fee on a customer surface)', () {
    testWidgets('emits no commission line and no fee-shaped copy', (
      tester,
    ) async {
      await _pumpLoaded(tester, _harness(_receipt()));

      expect(find.bySemanticsIdentifier('receipt_no_commission_line'),
          findsNothing);

      final Iterable<Text> texts = tester.widgetList<Text>(find.byType(Text));
      for (final Text text in texts) {
        final String value = text.data ?? text.textSpan?.toPlainText() ?? '';
        expect(value.contains('%'), isFalse, reason: 'AC4: "$value"');
        expect(value.toLowerCase().contains('commission'), isFalse,
            reason: 'AC4: "$value"');
        expect(value.toLowerCase().contains('platform fee'), isFalse,
            reason: 'AC4: "$value"');
      }
    });

    testWidgets('renders the cash amount inside the statement', (tester) async {
      await _pumpLoaded(tester, _harness(_receipt()));

      final Finder statement =
          find.bySemanticsIdentifier('receipt_cash_to_jeeber_label');
      expect(statement, findsOneWidget);
      expect(
        find.descendant(of: statement, matching: find.textContaining('Karim')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: statement, matching: find.textContaining('8.00')),
        findsOneWidget,
      );
    });

    testWidgets('degrades to the amount-less line when the gateway drops it', (
      tester,
    ) async {
      await _pumpLoaded(tester, _harness(_receipt(cashAmount: null)));

      expect(find.textContaining(r'$0.00'), findsNothing);
      expect(
        find.bySemanticsIdentifier('receipt_cash_to_jeeber_label'),
        findsOneWidget,
      );
    });
  });

  group('DeliveryReceiptScreen — proof hero', () {
    testWidgets('no photo means no zoom affordance, but the id survives', (
      tester,
    ) async {
      await _pumpLoaded(tester, _harness(_receipt(proofPhotoUrl: null)));

      expect(find.bySemanticsIdentifier('receipt_proof_photo'), findsOneWidget);
      expect(find.bySemanticsIdentifier('receipt_proof_zoom_cta'), findsNothing);
    });

    testWidgets('tapping the zoom pill opens the full-screen viewer', (
      tester,
    ) async {
      await _pumpLoaded(tester, _harness(_receipt()));

      await tester.tap(find.bySemanticsIdentifier('receipt_proof_zoom_cta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.bySemanticsIdentifier('receipt_proof_viewer_root'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('receipt_proof_viewer_close'),
        findsOneWidget,
      );
    });
  });

  group('DeliveryReceiptScreen — layout robustness', () {
    testWidgets('ar locale renders RTL without exceptions', (tester) async {
      await _pumpLoaded(
        tester,
        _harness(_receipt(jeeberName: 'كريم'), locale: const Locale('ar')),
      );

      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(
          tester.element(find.bySemanticsIdentifier('receipt_prompt')),
        ),
        TextDirection.rtl,
      );
      expect(find.bySemanticsIdentifier('receipt_confirm_cta'), findsOneWidget);
    });

    testWidgets('survives 200% text scale — the column scrolls, not overflows',
        (tester) async {
      await _pumpLoaded(tester, _harness(_receipt(), textScale: 2.0));

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomScrollView), findsOneWidget);
      // The footer is inside the scroll view, so it stays reachable.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsIdentifier('receipt_not_yet_cta'), findsOneWidget);
    });
  });

  // MIDNIGHT: loading and error left OmdsLoadingState/OmdsErrorState for the
  // one JeebEmptyState pattern family (study-notes ruling 1).
  group('DeliveryReceiptScreen — non-loaded states', () {
    testWidgets('the read in flight renders the loading block', (tester) async {
      await tester.pumpWidget(_harness(_receipt(), repository: _pending()));
      await tester.pump();

      expect(find.bySemanticsIdentifier('receipt_loading'), findsOneWidget);
      expect(find.byType(JeebEmptyState), findsOneWidget);
      expect(
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState)).status,
        JeebEmptyStateStatus.loading,
      );
      // The prompt root survives, so a deep link never lands on a bare screen.
      expect(find.bySemanticsIdentifier('receipt_prompt'), findsOneWidget);
    });

    testWidgets('a failed read renders the error block with Retry', (
      tester,
    ) async {
      await _pumpLoaded(
        tester,
        _harness(
          _receipt(),
          repository: FakeDeliveryReceiptRepository(
            fetchFailure: DeliveryReceiptFailure.notFound,
          ),
        ),
      );

      expect(find.byKey(const Key('receipt-load-error')), findsOneWidget);
      expect(find.bySemanticsIdentifier('receipt_load_error'), findsOneWidget);
      expect(
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState)).status,
        JeebEmptyStateStatus.error,
      );
      expect(find.text("We couldn't find this delivery."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
