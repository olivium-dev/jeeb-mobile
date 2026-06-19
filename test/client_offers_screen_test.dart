import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';

import 'support/offers_fixtures.dart';
import 'support/scripted_offers_repository.dart';
import 'support/sync_app_localizations.dart';

/// Builds a cubit with the live ticker streams swapped for empty streams so
/// the test binding doesn't complain about pending timers.
ClientOffersCubit _testCubitFactory(
  OffersRepository repository,
  String requestId,
) {
  return ClientOffersCubit(
    repository: repository,
    requestId: requestId,
    pollTicks: const Stream.empty(),
    clockTicks: const Stream.empty(),
  );
}

OffersSnapshot _snapshot(
  Iterable offers, {
  DateTime? deadline,
  bool requestIsOpen = true,
}) =>
    OffersSnapshot(
      offers: List.unmodifiable(offers),
      windowExpiresAt: deadline ?? DateTime.now().add(const Duration(minutes: 5)),
      requestIsOpen: requestIsOpen,
    );

void main() {
  testWidgets(
      'ClientOffersScreen — first paint renders sorted offers and timer',
      (tester) async {
    final repo = ScriptedOffersRepository(snapshots: [
      _snapshot([
        buildOffer(id: 'a', jeeberName: 'Karim', fee: 30),
        buildOffer(id: 'b', jeeberName: 'Hadi', fee: 15),
      ]),
    ]);
    await tester.pumpWidget(
      wrapForTest(
        ClientOffersScreen(requestId: 'req-1', repository: repo, cubitFactory: _testCubitFactory),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('offer-window-timer')), findsOneWidget);
    expect(find.byKey(const Key('offer-card-a')), findsOneWidget);
    expect(find.byKey(const Key('offer-card-b')), findsOneWidget);

    // Price asc — 'b' should appear before 'a' in the list.
    final positions = tester
        .widgetList(find.byKey(const Key('offer-list')))
        .toList();
    expect(positions, isNotEmpty);
    final bTopLeft = tester.getTopLeft(find.byKey(const Key('offer-card-b')));
    final aTopLeft = tester.getTopLeft(find.byKey(const Key('offer-card-a')));
    expect(bTopLeft.dy, lessThan(aTopLeft.dy));
  });

  testWidgets('ClientOffersScreen — sort toggle re-orders the cards',
      (tester) async {
    final repo = ScriptedOffersRepository(snapshots: [
      _snapshot([
        buildOffer(id: 'cheap', fee: 10, rating: 4.0),
        buildOffer(id: 'pricey', fee: 50, rating: 5.0),
      ]),
    ]);
    await tester.pumpWidget(
      wrapForTest(
        ClientOffersScreen(requestId: 'req-1', repository: repo, cubitFactory: _testCubitFactory),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Default: price asc → cheap above pricey
    var cheapY = tester
        .getTopLeft(find.byKey(const Key('offer-card-cheap')))
        .dy;
    var priceyY = tester
        .getTopLeft(find.byKey(const Key('offer-card-pricey')))
        .dy;
    expect(cheapY, lessThan(priceyY));

    await tester.tap(find.byKey(const Key('offer-sort-rating')));
    await tester.pump();

    cheapY = tester
        .getTopLeft(find.byKey(const Key('offer-card-cheap')))
        .dy;
    priceyY = tester
        .getTopLeft(find.byKey(const Key('offer-card-pricey')))
        .dy;
    expect(priceyY, lessThan(cheapY),
        reason: 'rating desc — best rating first');
  });

  testWidgets(
      'ClientOffersScreen — accept tap opens the offer-accept-confirm sheet '
      '(JM-029, not inline accept)', (tester) async {
    final repo = ScriptedOffersRepository(snapshots: [
      _snapshot([buildOffer(id: 'pick-me', jeeberName: 'Hadi')]),
    ]);
    await tester.pumpWidget(
      wrapForTest(
        ClientOffersScreen(
          requestId: 'req-1',
          repository: repo,
          cubitFactory: _testCubitFactory,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Tapping accept must NOT accept inline — it opens the JM-029 sheet.
    await tester.tap(find.byKey(const Key('offer-card-accept-pick-me')));
    await tester.pumpAndSettle();

    // The accept call has not fired (the sheet's confirm CTA does that).
    expect(repo.lastAcceptedOfferId, isNull);
    expect(repo.acceptCalls, 0);
    // The offer-accept-confirm sheet (JM-029) is now visible.
    expect(
      find.byKey(const Key('offer-accept-confirm-cta')),
      findsOneWidget,
    );
  });

  testWidgets(
      'ClientOffersScreen — cancel request CTA is present while open (JM-030 '
      'edge; sheet open is exercised by the Maestro flow once JM-030 keys land)',
      (tester) async {
    final repo = ScriptedOffersRepository(snapshots: [
      _snapshot([buildOffer(id: 'pick-me', jeeberName: 'Hadi')]),
    ]);
    await tester.pumpWidget(
      wrapForTest(
        ClientOffersScreen(
          requestId: 'req-1',
          repository: repo,
          cubitFactory: _testCubitFactory,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('offer-review-cancel-cta')),
      findsOneWidget,
    );
  });

  testWidgets('ClientOffersScreen — empty state when no offers yet',
      (tester) async {
    final repo = ScriptedOffersRepository(snapshots: [_snapshot(const [])]);
    await tester.pumpWidget(
      wrapForTest(
        ClientOffersScreen(requestId: 'req-1', repository: repo, cubitFactory: _testCubitFactory),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('offer-empty-state')), findsOneWidget);
  });

  testWidgets('ClientOffersScreen — failed load shows retry CTA',
      (tester) async {
    final repo = ScriptedOffersRepository(
      snapshots: [_snapshot(const [])],
      fetchFailure: OffersFailure.network,
    );
    await tester.pumpWidget(
      wrapForTest(
        ClientOffersScreen(requestId: 'req-1', repository: repo, cubitFactory: _testCubitFactory),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('offer-load-error')), findsOneWidget);
  });

  testWidgets('ClientOffersScreen — vehicle and fee surface inside the card',
      (tester) async {
    final repo = ScriptedOffersRepository(snapshots: [
      _snapshot([
        buildOffer(
          id: 'show',
          jeeberName: 'Rana',
          fee: 17.5,
          currency: 'USD',
          etaMinutes: 22,
          vehicle: JeeberVehicle.bicycle,
        ),
      ]),
    ]);
    await tester.pumpWidget(
      wrapForTest(
        ClientOffersScreen(requestId: 'req-1', repository: repo, cubitFactory: _testCubitFactory),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Rana'), findsOneWidget);
    expect(find.text('17.50'), findsOneWidget);
    expect(find.text('22 min ETA'), findsOneWidget);
    expect(find.text('Bicycle'), findsOneWidget);
  });
}
