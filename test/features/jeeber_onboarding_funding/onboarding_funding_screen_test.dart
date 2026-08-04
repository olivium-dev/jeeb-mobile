// Widget tests for OnboardingFundingScreen (JM-041), added with the
// redesign-2026-08 re-skin and re-cut for MIDNIGHT M3-18.
//
//   AC1: the four frozen identifiers render — funding_explainer,
//        funding_topup_cta, funding_continue_cta (+ funding_back).
//   FAIL-SAFE (40_GUARDRAILS_ARCH §3): a failed wallet fetch hides only the
//        enrichment amounts; the explainer and both CTAs still render.
//   Enrichment: funding_starter_credit_amount / funding_reserved_now_amount
//        appear only when their amounts are non-zero.
//   MIDNIGHT: per-element assertions read off the widgets — goldens are
//        evidence, not gates (wave-C fixup ruling).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedWalletRepository implements WalletRepository {
  const _ScriptedWalletRepository(this._balance, {this.throws = false});

  final WalletBalance _balance;
  final bool throws;

  @override
  Future<WalletBalance> fetchBalance() async {
    if (throws) {
      throw const WalletRepositoryException(WalletFailure.network);
    }
    return _balance;
  }
}

/// Never completes — the wallet read is still in flight.
class _PendingWalletRepository implements WalletRepository {
  @override
  Future<WalletBalance> fetchBalance() => Completer<WalletBalance>().future;
}

/// Fails once, then succeeds — drives the retry path.
class _FlakyWalletRepository implements WalletRepository {
  _FlakyWalletRepository(this._balance);

  final WalletBalance _balance;
  int calls = 0;

  @override
  Future<WalletBalance> fetchBalance() async {
    calls++;
    if (calls == 1) {
      throw const WalletRepositoryException(WalletFailure.network);
    }
    return _balance;
  }
}

const WalletBalance _enriched = WalletBalance(
  availableBalance: 40,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 4,
  giftCredit: 5,
  currency: 'USD',
);

const WalletBalance _empty = WalletBalance(
  availableBalance: 0,
  affordabilityState: WalletAffordability.empty,
  reservedNow: 0,
  giftCredit: 0,
  currency: 'USD',
);

final ThemeData _midnight = AppTheme.midnight();
final JeebSemanticColors _semantic =
    _midnight.extension<JeebSemanticColors>()!;

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required WalletRepository repo,
    Locale locale = const Locale('en'),
  }) async {
    // M0-4 ruling: Midnight primitives loop forever, so every assertion is
    // taken at the deterministic reduce-motion rest frame.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: _midnight,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object?>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: OnboardingFundingScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  Text textInside(WidgetTester tester, String identifier) => tester.widget<Text>(
        find
            .descendant(
              of: find.bySemanticsIdentifier(identifier),
              matching: find.byType(Text),
            )
            .first,
      );

  testWidgets('AC1: explainer, both CTAs and the back circle render',
      (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    expect(find.bySemanticsIdentifier('funding_explainer'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_topup_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_continue_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_back'), findsOneWidget);
  });

  testWidgets('enrichment: both live amounts render when non-zero',
      (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    expect(
      find.bySemanticsIdentifier('funding_starter_credit_amount'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('funding_reserved_now_amount'),
      findsOneWidget,
    );
  });

  testWidgets('zero amounts drop the enrichment, never the explainer',
      (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_empty));

    expect(find.bySemanticsIdentifier('funding_explainer'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('funding_starter_credit_amount'),
      findsNothing,
    );
    expect(
      find.bySemanticsIdentifier('funding_reserved_now_amount'),
      findsNothing,
    );
  });

  testWidgets('fail-safe: a failed wallet fetch keeps the explainer + CTAs',
      (tester) async {
    await pump(
      tester,
      repo: const _ScriptedWalletRepository(_enriched, throws: true),
    );

    expect(find.bySemanticsIdentifier('funding_explainer'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_topup_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_continue_cta'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('funding_starter_credit_amount'),
      findsNothing,
    );
  });

  testWidgets('RTL smoke: the Arabic locale lays out without overflow',
      (tester) async {
    await pump(
      tester,
      repo: const _ScriptedWalletRepository(_enriched),
      locale: const Locale('ar'),
    );

    expect(find.bySemanticsIdentifier('funding_explainer'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_continue_cta'), findsOneWidget);
  });

  // ── MIDNIGHT M3-18 ─────────────────────────────────────────────────────

  testWidgets('field: R23 chrome — content variant, one topEnd orange glow, '
      'no periwinkle wash, no motion', (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    final field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
    expect(field.washPlacement, isNull);
    expect(field.glowColor, isNull);
    expect(field.animateDecor, isFalse);
  });

  testWidgets('money emphasis: the starter credit is price 22/w800 in '
      'onSurface, not onPrimary white', (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    final style = textInside(tester, 'funding_starter_credit_amount').style!;
    expect(style.fontSize, 22);
    expect(style.fontWeight, FontWeight.w800);
    expect(style.color, _midnight.colorScheme.onSurface);
    expect(style.color, isNot(_midnight.colorScheme.onPrimary));
  });

  testWidgets('hero: explainer copy is inkSoft, the card carries the wallet '
      'ring and no retired navy lift', (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    final card = tester.widget<JeebNavySurfaceCard>(
      find.byType(JeebNavySurfaceCard),
    );
    // §7/§10: the navy-tinted shadow set is retired — heroNavy → none.
    expect(card.shadow, isEmpty);
    final ring = card.rings.single;
    expect(ring.diameter, 170);
    expect(ring.bottom, -50);
    expect(ring.end, -50);
    expect(ring.ink, JeebNavyRingInk.accent);

    final body = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(JeebNavySurfaceCard),
            matching: find.byType(Text),
          ),
        )
        .last;
    expect(body.style!.color, _semantic.inkSoft);
    expect(body.style!.color, isNot(_midnight.colorScheme.onPrimary));
  });

  testWidgets('reserve rule: the kit wallet reserve-row form, with a labelled '
      'w800 money stat', (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    final note = tester.widget<JeebInfoNote>(find.byType(JeebInfoNote));
    expect(note.tone, JeebInfoNoteTone.outlined);

    final stat = tester
        .widgetList<Text>(
          find.descendant(
            of: find.bySemanticsIdentifier('funding_reserved_now_amount'),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(stat.first.style!.color, _semantic.mutedText);
    expect(stat.last.style!.fontWeight, FontWeight.w800);
    expect(stat.last.style!.color, _midnight.colorScheme.onSurface);
  });

  testWidgets('orange budget: neither CTA is the accent pill', (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    final ctas = tester.widgetList<JeebCtaButton>(find.byType(JeebCtaButton));
    expect(ctas, hasLength(2));
    expect(
      ctas.map((c) => c.variant),
      everyElement(isNot(JeebCtaVariant.accent)),
    );
    expect(
      ctas.map((c) => c.variant),
      containsAll(<JeebCtaVariant>[
        JeebCtaVariant.primary,
        JeebCtaVariant.outline,
      ]),
    );
  });

  testWidgets('loading rung: the pocket skeleton, explainer untouched',
      (tester) async {
    await pump(tester, repo: _PendingWalletRepository());

    final block = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
    expect(block.status, JeebEmptyStateStatus.loading);
    expect(block.variant, JeebEmptyStateVariant.pocket);
    expect(block.compact, isTrue);
    expect(find.bySemanticsIdentifier('funding_wallet_loading'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_explainer'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_topup_cta'), findsOneWidget);
  });

  testWidgets('error rung: the pocket block is danger-status and retryable',
      (tester) async {
    await pump(
      tester,
      repo: const _ScriptedWalletRepository(_enriched, throws: true),
    );

    final block = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
    expect(block.status, JeebEmptyStateStatus.error);
    expect(block.variant, JeebEmptyStateVariant.pocket);
    expect(find.bySemanticsIdentifier('funding_wallet_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_wallet_retry'), findsOneWidget);
  });

  testWidgets('loaded rung: the lower third stays empty', (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    expect(find.byType(JeebEmptyState), findsNothing);
  });

  testWidgets('retry re-reads the wallet and lands the enrichment',
      (tester) async {
    final repo = _FlakyWalletRepository(_enriched);
    await pump(tester, repo: repo);

    expect(find.bySemanticsIdentifier('funding_wallet_error'), findsOneWidget);

    await tester.tap(find.bySemanticsIdentifier('funding_wallet_retry'));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.byType(JeebEmptyState), findsNothing);
    expect(
      find.bySemanticsIdentifier('funding_starter_credit_amount'),
      findsOneWidget,
    );
  });
}
