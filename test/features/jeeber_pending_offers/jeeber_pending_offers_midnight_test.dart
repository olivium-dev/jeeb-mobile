// M3-36 per-element Midnight assertions for JeeberPendingOffersScreen.
//
// Goldens are evidence, not gates (02-STUDY-NOTES, wave-C fixup): the shared
// comparator tolerates 5% pixel diff, so mounting a field, swapping a state
// block or re-inking the price can leave every golden green. Every ruling this
// row landed is read back off the built widget here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offer.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offers_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _StaticRepository implements SubmittedOffersRepository {
  const _StaticRepository(this.offers);

  final List<SubmittedOffer> offers;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async => offers;

  @override
  Future<bool> withdraw(String offerId) async => true;
}

class _FailingRepository implements SubmittedOffersRepository {
  _FailingRepository();

  int reads = 0;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    reads++;
    throw Exception('designed load failure');
  }

  @override
  Future<bool> withdraw(String offerId) async => false;
}

class _StalledRepository implements SubmittedOffersRepository {
  const _StalledRepository();

  @override
  Future<List<SubmittedOffer>> listSubmitted() =>
      Completer<List<SubmittedOffer>>().future;

  @override
  Future<bool> withdraw(String offerId) => Completer<bool>().future;
}

const SubmittedOffer _offer = SubmittedOffer(
  id: 'o1',
  requestId: 'req-1',
  price: 12.5,
  currency: 'USD',
  etaMinutes: 25,
);

Widget _harness(
  SubmittedOffersRepository repo, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The empty-state illustrations loop forever by design; reduce motion pins
    // them at the rest frame so the tree settles.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: JeeberPendingOffersScreen(
      repository: repo,
      jeeberId: 'user-jeeber-002',
    ),
  );
}

Finder _underIdentifier(String identifier, Type type) => find.descendant(
  of: find.byWidgetPredicate(
    (Widget w) => w is Semantics && w.properties.identifier == identifier,
  ),
  matching: find.byType(type),
);

void main() {
  final ColorScheme scheme = AppTheme.midnight().colorScheme;

  group('field', () {
    testWidgets('mounts the content field, decor still, no wash override', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const _StaticRepository(<SubmittedOffer>[_offer])),
      );
      await tester.pumpAndSettle();

      final JeebMidnightField field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      // M3 standing rule: no motion beyond what the kit widgets bring.
      expect(field.animateDecor, isFalse);
      // Ratified `topEnd` default; wave-C's top-start class is R4/R9/R17 only.
      expect(field.glowPlacement, isNull);
      // A wash is measured per tile (wave-B fixup ruling) and none is measured
      // for this surface, so the periwinkle layer stays off.
      expect(field.washPlacement, isNull);
    });

    testWidgets('the scaffold does not paint over the field', (tester) async {
      await tester.pumpWidget(
        _harness(const _StaticRepository(<SubmittedOffer>[_offer])),
      );
      await tester.pumpAndSettle();

      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.transparent);
      expect(scaffold.appBar, isNull);
    });
  });

  group('states', () {
    testWidgets('empty renders the R16 twin block, pocket variant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const _StaticRepository(<SubmittedOffer>[])),
      );
      await tester.pumpAndSettle();

      final JeebEmptyState block = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(JeebEmptyState)),
      );
      expect(block.status, JeebEmptyStateStatus.empty);
      expect(block.variant, JeebEmptyStateVariant.pocket);
      expect(block.identifier, 'jeeber_pending_offers_empty_state');
      expect(block.headline, l10n.pendingOffersEmptyTitle);
      expect(block.body, l10n.pendingOffersEmptyBody);
    });

    testWidgets('cold load renders the skeleton block, no CTA', (tester) async {
      await tester.pumpWidget(_harness(const _StalledRepository()));
      await tester.pump();

      final JeebEmptyState block = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(block.status, JeebEmptyStateStatus.loading);
      expect(block.variant, JeebEmptyStateVariant.pocket);
      expect(block.action, isNull);
    });

    testWidgets(
      'cold failure renders the danger block + a retry that re-reads',
      (tester) async {
        final _FailingRepository repo = _FailingRepository();
        await tester.pumpWidget(_harness(repo));
        await tester.pumpAndSettle();

        final JeebEmptyState block = tester.widget<JeebEmptyState>(
          find.byType(JeebEmptyState),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(JeebEmptyState)),
        );
        expect(block.status, JeebEmptyStateStatus.error);
        expect(block.variant, JeebEmptyStateVariant.pocket);
        expect(block.headline, l10n.offersLoadErrorTitle);
        expect(block.action, isNotNull);
        expect(repo.reads, 1);

        await tester.tap(
          find.bySemanticsIdentifier('pending_offers_retry_cta'),
        );
        await tester.pumpAndSettle();
        expect(repo.reads, 2);
      },
    );

    testWidgets('the OMDS state widgets are gone from every branch', (
      tester,
    ) async {
      for (final SubmittedOffersRepository repo in <SubmittedOffersRepository>[
        const _StaticRepository(<SubmittedOffer>[]),
        _FailingRepository(),
      ]) {
        await tester.pumpWidget(_harness(repo));
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (Widget w) =>
                w.runtimeType.toString().startsWith('Omds') &&
                w.runtimeType.toString().contains('State'),
          ),
          findsNothing,
        );
      }
    });
  });

  group('orange budget', () {
    testWidgets('the offer price is onSurface ink, never the accent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const _StaticRepository(<SubmittedOffer>[_offer])),
      );
      await tester.pumpAndSettle();

      final Text price = tester.widget<Text>(
        _underIdentifier('pending_offer_0_price', Text),
      );
      expect(price.style?.color, scheme.onSurface);
      // The M3 Tier-1 defect signature: `primary` IS #D73B00 under Midnight.
      expect(price.style?.color, isNot(scheme.primary));
    });

    testWidgets('the withdraw pill stays a compact end control (R10)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const _StaticRepository(<SubmittedOffer>[_offer])),
      );
      await tester.pumpAndSettle();

      final Size card = tester.getSize(find.byType(JeebOutlinedCard).first);
      final Size pill = tester.getSize(
        find.byKey(const Key('pending-offer-withdraw-0')),
      );
      expect(pill.width, lessThan(card.width / 2));
    });

    testWidgets('the field draws no CTA-orange pill on the empty screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const _StaticRepository(<SubmittedOffer>[])),
      );
      await tester.pumpAndSettle();

      // The only sanctioned orange here is the pocket illustration's own mic;
      // nothing on the page is an accent CTA.
      expect(find.text('Withdraw offer'), findsNothing);
    });
  });

  testWidgets('renders under an RTL locale with the rows intact', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const _StaticRepository(<SubmittedOffer>[_offer]),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(JeebMidnightField))),
      TextDirection.rtl,
    );
    expect(find.bySemanticsIdentifier('pending_offer_0'), findsOneWidget);
    expect(find.bySemanticsIdentifier('pending_offers_back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
