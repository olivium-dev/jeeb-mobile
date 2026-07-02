// Widget tests for JeeberPendingOffersScreen (JM-047, D15) — the STANDALONE
// surface. It reuses JM-048's SubmittedOffersCubit + PendingOfferRow, so these
// tests prove the standalone chrome (root + back) and that the reused rows
// expose the EXACT Semantics identifiers from 65_W2_TEST_PLAN §2 JM-047:
//   AC1: pending_offer_0_price + pending_offer_0_eta + pending_offer_awaiting_label
//   AC2: pending_offer_0_withdraw_cta present
//   AC3: tapping the withdraw CTA removes pending_offer_0 (optimistic)
//   AC4: pending_offers_back present (the back edge to delivery-requests)
//   + the empty-state and error-state render under the root.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offer.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offers_repository.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedRepository implements SubmittedOffersRepository {
  _ScriptedRepository({
    List<SubmittedOffer>? offers,
    this.listThrows = false,
    this.withdrawSucceeds = true,
  }) : _offers = List<SubmittedOffer>.of(offers ?? const <SubmittedOffer>[]);

  final List<SubmittedOffer> _offers;
  final bool listThrows;
  final bool withdrawSucceeds;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    if (listThrows) throw Exception('boom');
    return _offers;
  }

  @override
  Future<bool> withdraw(String offerId) async => withdrawSucceeds;
}

SubmittedOffer _offer(String id, {int? eta = 25, double price = 12.5}) =>
    SubmittedOffer(
      id: id,
      requestId: 'req-$id',
      price: price,
      currency: 'USD',
      etaMinutes: eta,
    );

void main() {
  Future<void> pump(WidgetTester tester, SubmittedOffersRepository repo) async {
    await tester.pumpWidget(
      wrapForTest(
        JeeberPendingOffersScreen(repository: repo, jeeberId: 'user-jeeber-002'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exposes the JM-047 root + back identifiers', (tester) async {
    await pump(
      tester,
      _ScriptedRepository(offers: [_offer('pending-offer-jeeber-001')]),
    );

    expect(find.bySemanticsIdentifier('jeeber_pending_offers_root'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('pending_offers_back'), findsOneWidget);
  });

  testWidgets('AC1/AC2: row exposes price, eta, awaiting label + withdraw CTA',
      (tester) async {
    await pump(tester, _ScriptedRepository(offers: [_offer('o1')]));

    expect(find.bySemanticsIdentifier('pending_offer_0'), findsOneWidget);
    expect(find.bySemanticsIdentifier('pending_offer_0_price'), findsOneWidget);
    expect(find.bySemanticsIdentifier('pending_offer_0_eta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('pending_offer_awaiting_label'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('pending_offer_0_withdraw_cta'),
        findsOneWidget);
  });

  testWidgets('AC3: tapping withdraw removes the row (optimistic)',
      (tester) async {
    await pump(
      tester,
      _ScriptedRepository(offers: [_offer('o1'), _offer('o2')]),
    );

    expect(find.bySemanticsIdentifier('pending_offer_0'), findsOneWidget);
    expect(find.bySemanticsIdentifier('pending_offer_1'), findsOneWidget);

    await tester.tap(find.bySemanticsIdentifier('pending_offer_0_withdraw_cta'));
    await tester.pump();
    await tester.pumpAndSettle();

    // One row remains (the list re-indexes), so index 1 is gone.
    expect(find.bySemanticsIdentifier('pending_offer_1'), findsNothing);
    expect(find.bySemanticsIdentifier('pending_offer_0'), findsOneWidget);
  });

  testWidgets('withdraw failure keeps the row (busy cleared, no removal)',
      (tester) async {
    await pump(
      tester,
      _ScriptedRepository(offers: [_offer('o1')], withdrawSucceeds: false),
    );

    await tester.tap(find.bySemanticsIdentifier('pending_offer_0_withdraw_cta'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Row remains so the jeeber can retry (parity with the feed sub-tab).
    expect(find.bySemanticsIdentifier('pending_offer_0'), findsOneWidget);
  });

  testWidgets('empty list renders the empty-state under the root',
      (tester) async {
    await pump(tester, _ScriptedRepository(offers: const []));

    expect(find.bySemanticsIdentifier('jeeber_pending_offers_root'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('pending_offer_0'), findsNothing);
  });

  testWidgets('cold-load failure renders an error-state with retry',
      (tester) async {
    await pump(tester, _ScriptedRepository(listThrows: true));

    expect(find.bySemanticsIdentifier('jeeber_pending_offers_root'),
        findsOneWidget);
    // OmdsErrorState renders a FilledButton.icon retry control. The `.icon`
    // factory yields a private _FilledButtonWithIcon subclass, so match on the
    // FilledButton supertype rather than the exact runtime type.
    expect(
      find.byWidgetPredicate((w) => w is FilledButton),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('sprint-009: a TERMINAL offer shows the status badge and NO '
      'withdraw CTA; a still-open offer keeps the awaiting label + withdraw',
      (tester) async {
    await pump(
      tester,
      _ScriptedRepository(offers: [
        const SubmittedOffer(
          id: 'accepted-1',
          requestId: 'r1',
          price: 9,
          currency: 'USD',
          status: OfferStatus.accepted,
        ),
        _offer('open-1'), // default submitted
      ]),
    );

    // Row 0 (accepted) → outcome badge, no withdraw / awaiting.
    expect(find.bySemanticsIdentifier('pending_offer_0_status'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('pending_offer_0_withdraw_cta'),
      findsNothing,
    );

    // Row 1 (open) → awaiting label + withdraw, no status badge.
    expect(
      find.bySemanticsIdentifier('pending_offer_awaiting_label'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('pending_offer_1_withdraw_cta'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('pending_offer_1_status'), findsNothing);
  });
}
