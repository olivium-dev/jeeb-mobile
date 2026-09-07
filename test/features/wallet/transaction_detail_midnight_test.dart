// MIDNIGHT M3-12 adoption instruments (transaction-detail).
//
// The screen has no board tile; every value below is derived from R4
// (04-r4-wallet), the hub two steps up, and read back off the BUILT widget —
// the golden comparator tolerates 5% pixel diff and is blind to a token
// re-point.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_glass_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_transaction_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/transaction_detail_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/widgets/wallet_state_mark.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _Repo implements WalletTransactionRepository {
  const _Repo(this._txn, {this.failure});

  final WalletTransaction _txn;
  final WalletTransactionFailure? failure;

  @override
  Future<WalletTransaction> fetchTransaction(String id) async {
    final WalletTransactionFailure? f = failure;
    if (f != null) throw WalletTransactionRepositoryException(f);
    return _txn;
  }
}

class _StallRepo implements WalletTransactionRepository {
  const _StallRepo();

  @override
  Future<WalletTransaction> fetchTransaction(String id) =>
      Completer<WalletTransaction>().future;
}

WalletTransaction _txn({int sign = -1, double amount = 1.5}) =>
    WalletTransaction(
      id: 'led-1',
      type: WalletLedgerType.feeWon,
      amount: amount,
      sign: sign,
      currency: 'USD',
      timestamp: '2026-06-19T10:00:00Z',
      ref: 'off-1',
      offerId: 'off-1',
      orderId: 'req-1',
      pinnedPrice: 15,
      feeRate: 0.1,
    );

Widget _harness(WalletTransactionRepository repo) => MaterialApp(
  theme: AppTheme.midnight(),
  // The kit illustration loops ∞ by design — reduce motion pins the rest frame.
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child ?? const SizedBox.shrink(),
  ),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<Object>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: TransactionDetailScreen(transactionId: 'led-1', repository: repo),
);

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  Future<void> pump(
    WidgetTester tester,
    WalletTransactionRepository repo,
  ) async {
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();
  }

  group('field — R4\'s two radials, carried from the hub', () {
    testWidgets('content variant, ORANGE glow top-start, PERIWINKLE wash '
        'end-mid, still', (tester) async {
      await pump(tester, _Repo(_txn()));

      final JeebMidnightField field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topStart);
      expect(field.washPlacement, JeebFieldWashPlacement.endMid);
      expect(field.animateDecor, isFalse);
      // Two layers, two anchors — the mirrored-layer guard.
      expect(field.glowPlacement!.fx, closeTo(0.12, 0.001));
      expect(field.glowPlacement!.fy, closeTo(-0.08, 0.001));
      expect(field.washPlacement!.fx, closeTo(1.17, 0.001));
      expect(field.washPlacement!.fy, closeTo(0.65, 0.001));
    });
  });

  group('amount hero — R4\'s frosted bank-card', () {
    testWidgets('hero glass at xl with the board\'s blur and floatNav lift, '
        'NOT the legacy navy-tinted card', (tester) async {
      await pump(tester, _Repo(_txn()));

      final JeebGlassCapsule card = tester.widget<JeebGlassCapsule>(
        find.byType(JeebGlassCapsule),
      );
      expect(card.radius, JeebRadii.xl);
      expect(card.blurSigma, JeebGlassCapsule.heroBlur);
      expect(card.shadow, JeebShadows.floatNav);
      // §7/theme-ruling-1: the navy-tinted `heroNavy` set is invisible on the
      // field and dies. The card it hung on is gone with it.
      expect(card.shadow, isNot(JeebShadows.heroNavy));
      expect(find.byType(JeebNavySurfaceCard), findsNothing);
    });

    testWidgets('debit amount is danger-SOFT, and no longer white-on-orange '
        'ink on a navy card', (tester) async {
      await pump(tester, _Repo(_txn()));

      final Element el = tester.element(find.text('-1.50 USD'));
      final JeebRoles roles = el.jeebRoles;
      final ColorScheme scheme = Theme.of(el).colorScheme;
      final TextStyle style = _styleOf(tester, '-1.50 USD');
      expect(style.color, roles.onErrorContainer);
      expect(style.color, isNot(scheme.onPrimary));
      expect(style.color, isNot(scheme.error));
      // R4's own hero number style survives the re-skin.
      expect(style.fontSize, 40);
      expect(style.fontWeight, FontWeight.w800);
    });

    testWidgets('credit amount is the success-soft pair', (tester) async {
      await pump(tester, _Repo(_txn(sign: 1)));

      final JeebRoles roles = tester.element(find.text('+1.50 USD')).jeebRoles;
      expect(_styleOf(tester, '+1.50 USD').color, roles.onSuccessContainer);
    });
  });

  group('field rows — the orange budget', () {
    testWidgets('the value ink is onSurface, not the accent: `primary` IS '
        '#D73B00 under Midnight', (tester) async {
      await pump(tester, _Repo(_txn()));

      final Element el = tester.element(find.text('10%'));
      final ColorScheme scheme = Theme.of(el).colorScheme;
      expect(_styleOf(tester, '10%').color, scheme.onSurface);
      expect(_styleOf(tester, '10%').color, isNot(scheme.primary));
    });
  });

  group('states — the JeebEmptyState family, R19\'s money composition', () {
    testWidgets('loading', (tester) async {
      await tester.pumpWidget(_harness(const _StallRepo()));
      await tester.pump();

      final JeebEmptyState block = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(block.status, JeebEmptyStateStatus.loading);
      expect(block.center, isNull);
    });

    testWidgets('error keeps the root id and carries a retry', (tester) async {
      await pump(
        tester,
        _Repo(_txn(), failure: WalletTransactionFailure.notFound),
      );

      final JeebEmptyState block = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(block.effectiveStatus, JeebEmptyStateStatus.error);
      expect(block.reason, JeebEmptyStateReason.failed);
      expect(block.action, isNotNull);
      // `parcel` draws no medallion ring, so E1's client mic + shopping set
      // never reaches this money surface.
      expect(block.variant, JeebEmptyStateVariant.parcel);
      expect(find.byType(WalletStateMark), findsNothing);
      expect(find.bySemanticsIdentifier('txn_detail_root'), findsOneWidget);
      // ES-18: the rung itself is findable now.
      expect(find.bySemanticsIdentifier('txn_detail_error'), findsOneWidget);
      // R6/F14: a 404 gets the way out, never an inert Retry.
      expect(find.bySemanticsIdentifier('txn_detail_exit_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('txn_detail_retry_cta'), findsNothing);
    });
  });
}
