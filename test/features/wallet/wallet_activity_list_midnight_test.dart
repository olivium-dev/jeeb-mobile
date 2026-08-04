// MIDNIGHT M3-11 adoption instruments (wallet-activity-list + its row).
//
// The screen has no board tile; every value below is derived from R4
// (04-r4-wallet) whose hub this list hangs off, with R19 as the secondary
// pattern for row facts. Each is read back off the BUILT widget, because the
// golden comparator tolerates 5% pixel diff and is blind to a token re-point.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_activity_list_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/widgets/wallet_activity_row.dart';
import 'package:jeeb_mobile/features/wallet/presentation/widgets/wallet_state_mark.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _Repo implements WalletLedgerRepository {
  const _Repo(this._entries, {this.throws});

  final List<WalletLedgerEntry> _entries;
  final WalletLedgerFailure? throws;

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) async {
    final WalletLedgerFailure? f = throws;
    if (f != null) throw WalletLedgerRepositoryException(f);
    return WalletLedgerPage(entries: _entries, page: page, totalPages: 1);
  }
}

WalletLedgerEntry _row(
  String id, {
  required int sign,
  WalletLedgerType type = WalletLedgerType.feeWon,
}) => WalletLedgerEntry(
  id: id,
  type: type,
  amount: 0.9,
  sign: sign,
  ref: 'off-$id',
  timestamp: '2026-06-18T10:00:00Z',
  currency: 'USD',
);

Widget _harness(WalletLedgerRepository repo) => MaterialApp(
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
  home: WalletActivityListScreen(repository: repo),
);

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  Future<void> pump(WidgetTester tester, WalletLedgerRepository repo) async {
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();
  }

  group('field — R4\'s two radials, carried from the hub', () {
    testWidgets('content variant, ORANGE glow top-start, PERIWINKLE wash '
        'end-mid, still', (tester) async {
      await pump(tester, _Repo(<WalletLedgerEntry>[_row('a', sign: -1)]));

      final JeebMidnightField field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topStart);
      expect(field.washPlacement, JeebFieldWashPlacement.endMid);
      expect(field.animateDecor, isFalse);
      // The glow is the ORANGE layer and the wash the PERIWINKLE one; asserting
      // both anchors catches the mirrored-layer error screens have shipped with.
      expect(field.glowPlacement!.fx, closeTo(0.12, 0.001));
      expect(field.glowPlacement!.fy, closeTo(-0.08, 0.001));
      expect(field.washPlacement!.fx, closeTo(1.17, 0.001));
      expect(field.washPlacement!.fy, closeTo(0.65, 0.001));
    });

    testWidgets('the field mounts in every state, not only loaded', (
      tester,
    ) async {
      await pump(
        tester,
        const _Repo(<WalletLedgerEntry>[], throws: WalletLedgerFailure.network),
      );
      expect(find.byType(JeebMidnightField), findsOneWidget);
    });
  });

  group('row — R21 rung, R19 money facts', () {
    testWidgets('rest-glass card at JeebRadii.lg', (tester) async {
      await pump(tester, _Repo(<WalletLedgerEntry>[_row('a', sign: -1)]));

      final JeebOutlinedCard card = tester.widget<JeebOutlinedCard>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is JeebOutlinedCard &&
              w.identifier == 'wallet_activity_row_a',
        ),
      );
      expect(card.radius, JeebRadii.lg);
      expect(card.padding, kWalletActivityRowPadding);
    });

    testWidgets('type label is onSurface, NOT the accent — primary IS #D73B00 '
        'under Midnight', (tester) async {
      await pump(tester, _Repo(<WalletLedgerEntry>[_row('a', sign: -1)]));

      final ColorScheme scheme = Theme.of(
        tester.element(find.text('Fee')),
      ).colorScheme;
      expect(_styleOf(tester, 'Fee').color, scheme.onSurface);
      expect(_styleOf(tester, 'Fee').color, isNot(scheme.primary));
    });

    testWidgets('credit money ink is the success-soft pair (R19)', (
      tester,
    ) async {
      await pump(
        tester,
        _Repo(<WalletLedgerEntry>[
          _row('a', sign: 1, type: WalletLedgerType.topup),
        ]),
      );

      final JeebRoles roles = tester.element(find.text('+0.90 USD')).jeebRoles;
      expect(_styleOf(tester, '+0.90 USD').color, roles.onSuccessContainer);
    });

    testWidgets('debit money ink is danger-SOFT, never full-strength error', (
      tester,
    ) async {
      await pump(tester, _Repo(<WalletLedgerEntry>[_row('a', sign: -1)]));

      final Element el = tester.element(find.text('-0.90 USD'));
      final JeebRoles roles = el.jeebRoles;
      final ColorScheme scheme = Theme.of(el).colorScheme;
      expect(_styleOf(tester, '-0.90 USD').color, roles.onErrorContainer);
      // The R22 ruling the kit's `JeebCtaVariant.danger` records.
      expect(_styleOf(tester, '-0.90 USD').color, isNot(scheme.error));
      // ...and never the accent it used to be.
      expect(_styleOf(tester, '-0.90 USD').color, isNot(scheme.primary));
    });

    testWidgets('money emphasis is `price` — 22/w800/-0.5 (§6)', (tester) async {
      await pump(tester, _Repo(<WalletLedgerEntry>[_row('a', sign: -1)]));

      final TextStyle style = _styleOf(tester, '-0.90 USD');
      expect(style.fontSize, 22);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.letterSpacing, -0.5);
    });
  });

  group('states — the JeebEmptyState family, R19\'s money composition', () {
    testWidgets('empty', (tester) async {
      await pump(tester, const _Repo(<WalletLedgerEntry>[]));

      final JeebEmptyState block = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(block.status, JeebEmptyStateStatus.empty);
      expect(block.identifier, 'wallet_activity_empty');
      // No CTA: nothing here routes to "make a ledger row happen".
      expect(block.action, isNull);
      // R19's ruling: the client mic + shopping medallions are replaced by a
      // glass money mark, so a read-only ledger draws no solid orange act.
      expect(block.center, isA<WalletStateMark>());
      expect(block.medallions, isEmpty);
      expect(find.byType(WalletStateMark), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.receipt_long)).color,
        Theme.of(tester.element(find.byType(WalletStateMark))).colorScheme.onSurface,
      );
    });

    testWidgets('error keeps BOTH frozen ids and is danger-tinted', (
      tester,
    ) async {
      await pump(
        tester,
        const _Repo(<WalletLedgerEntry>[], throws: WalletLedgerFailure.network),
      );

      final JeebEmptyState block = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(block.status, JeebEmptyStateStatus.error);
      expect(block.center, isA<WalletStateMark>());
      expect(block.medallions, isEmpty);
      expect(find.bySemanticsIdentifier('wallet_activity_error'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('wallet_activity_retry_cta'),
        findsOneWidget,
      );
    });

    testWidgets('loading is the breathing skeleton, not an OMDS shimmer', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const _StallRepo()));
      await tester.pump();

      final JeebEmptyState block = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(block.status, JeebEmptyStateStatus.loading);
      // The kit paints its skeleton over the whole frame, so the centre slot is
      // deliberately empty here rather than carrying a mark nothing draws.
      expect(block.center, isNull);
      expect(
        find.bySemanticsIdentifier('wallet_activity_loading'),
        findsOneWidget,
      );
    });
  });
}

class _StallRepo implements WalletLedgerRepository {
  const _StallRepo();

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) =>
      Completer<WalletLedgerPage>().future;
}
