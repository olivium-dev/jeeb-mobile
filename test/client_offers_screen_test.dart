import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/data/dio_offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';

import 'support/offers_fixtures.dart';
import 'support/scripted_offers_repository.dart';
import 'support/sync_app_localizations.dart';

/// A [Dio] whose interceptor resolves every request with [body] (status 200) so
/// a test can drive the REAL [DioOffersRepository] off a canned wire payload —
/// no mock-server, no network. Used to reproduce the exact LIVE gateway
/// `GET /v1/offers?requestId=` envelope on the on-device path.
Dio _dioRespond(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(data: body, statusCode: 200, requestOptions: options),
      ),
    ),
  );
  return dio;
}

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
    // Lane item 3: one MoneyFormat everywhere - the pill renders "$17.50",
    // not a bare "17.50" with a separate currency-code line.
    // MoneyFormat wraps the token in an LTR isolate (JEBV4-98/F10).
    expect(find.text('\u2066\$17.50\u2069'), findsOneWidget);
    expect(find.text('22 min ETA'), findsOneWidget);
    expect(find.text('Bicycle'), findsOneWidget);
  });

  testWidgets(
      'ClientOffersScreen — renders the offer CARD (not "Waiting for offers") '
      'for a LIVE gateway "pending" offer, with a working Accept CTA '
      '(iter6 offer-card render gap, STATE/iter6-FINAL-PROOF.md STEP-3)',
      (tester) async {
    // The EXACT live gateway `GET /v1/offers?requestId=` body the on-device app
    // received in logcat: the flat OfferDto inside { items: [...] } with the
    // gateway-collapsed `status: "pending"` (offer-service submitted/edited/
    // pending → gateway pending). Drives the REAL DioOffersRepository → cubit →
    // screen so this is the genuine on-device parse+render path, not a fixture.
    final now = DateTime.now().toUtc().toIso8601String();
    final repo = DioOffersRepository(
      _dioRespond({
        'items': [
          {
            'id': 'a7e85c0b-real-offer',
            'requestId': '7299b700-real-request',
            'jeeberId': 'd1000000-0000-4000-8000-000000000002',
            'status': 'pending',
            'fee': 6.5,
            'etaMinutes': 18,
            'note': 'Karim here, on my way',
            'createdAt': now,
          },
        ],
      }),
    );
    await tester.pumpWidget(
      wrapForTest(
        ClientOffersScreen(
          requestId: '7299b700-real-request',
          repository: repo,
          cubitFactory: _testCubitFactory,
        ),
      ),
    );
    // The real DioOffersRepository resolves its GET asynchronously through the
    // Dio interceptor microtask chain, so let the load() future settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    // The offer CARD renders (was previously dropped → empty-state bug)...
    expect(
      find.byKey(const Key('offer-card-a7e85c0b-real-offer')),
      findsOneWidget,
      reason: 'the pending offer must surface as a card',
    );
    // ...and its Accept CTA is present (the in-app Accept button, now reachable).
    expect(
      find.byKey(const Key('offer-card-accept-a7e85c0b-real-offer')),
      findsOneWidget,
      reason: 'the in-app Accept button must display on the card',
    );
    // The "Waiting for offers" empty-state must NOT show when items is non-empty.
    expect(find.byKey(const Key('offer-empty-state')), findsNothing);
    // The parsed fee surfaces on the card via the unified MoneyFormat
    // (6.5 USD -> "$6.50", lane item 3).
    expect(find.text('\u2066\$6.50\u2069'), findsWidgets);
  });
}
