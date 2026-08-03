import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_state.dart';
import 'package:jeeb_mobile/features/client_offers/data/dio_offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_select_chip.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';
import 'package:omds/omds.dart';

import 'support/offers_fixtures.dart';
import 'support/scripted_offers_repository.dart';
import 'support/sync_app_localizations.dart';

/// A [Dio] whose interceptor resolves every request with [body] (status 200) so
/// a test can drive the REAL [DioOffersRepository] off a canned wire payload —
/// no mock-server, no network. Used to reproduce the exact LIVE gateway
/// `GET /v1/offers?requestId=` envelope on the on-device path.
Dio _dioRespond(
  Object? offersBody, {
  Object? requestBody = const {'status': 'pending'},
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(
          data: options.path.startsWith('/v1/requests/')
              ? requestBody
              : offersBody,
          statusCode: 200,
          requestOptions: options,
        ),
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
    refreshSignals: const Stream.empty(),
    clockTicks: const Stream.empty(),
  );
}

OffersSnapshot _snapshot(
  Iterable offers, {
  DateTime? deadline,
  bool requestIsOpen = true,
  String? requestTitle,
}) => OffersSnapshot(
  offers: List.unmodifiable(offers),
  windowExpiresAt: deadline ?? DateTime.now().add(const Duration(minutes: 15)),
  requestIsOpen: requestIsOpen,
  requestTitle: requestTitle,
);

const double _kAndroidNavigationBarInset = 48;

void main() {
  testWidgets(
    'ClientOffersScreen — first paint renders sorted offers and timer',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([
            buildOffer(id: 'a', jeeberName: 'Karim', fee: 30),
            buildOffer(id: 'b', jeeberName: 'Hadi', fee: 15),
          ]),
        ],
      );
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

      expect(find.byKey(const Key('offer-window-timer')), findsOneWidget);
      expect(find.byKey(const Key('offer-card-a')), findsOneWidget);
      expect(find.byKey(const Key('offer-card-b')), findsOneWidget);

      // The default sort is now the composite `best` ranking, so ask for price
      // explicitly before asserting price order — the test then states what it
      // means instead of leaning on a default that changed.
      await tester.tap(find.byKey(const Key('offer-sort-price')));
      await tester.pump();

      // Price asc — 'b' should appear before 'a' in the list.
      final positions = tester
          .widgetList(find.byKey(const Key('offer-list')))
          .toList();
      expect(positions, isNotEmpty);
      final bTopLeft = tester.getTopLeft(find.byKey(const Key('offer-card-b')));
      final aTopLeft = tester.getTopLeft(find.byKey(const Key('offer-card-a')));
      expect(bTopLeft.dy, lessThan(aTopLeft.dy));
    },
  );

  testWidgets('ClientOffersScreen — sort toggle re-orders the cards', (
    tester,
  ) async {
    final repo = ScriptedOffersRepository(
      snapshots: [
        _snapshot([
          buildOffer(id: 'cheap', fee: 10, rating: 4.0),
          buildOffer(id: 'pricey', fee: 50, rating: 5.0),
        ]),
      ],
    );
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

    // Price asc → cheap above pricey. Asked for explicitly: `best` is the
    // default now and it weighs rating and ETA alongside the fee.
    await tester.tap(find.byKey(const Key('offer-sort-price')));
    await tester.pump();

    var cheapY = tester
        .getTopLeft(find.byKey(const Key('offer-card-cheap')))
        .dy;
    var priceyY = tester
        .getTopLeft(find.byKey(const Key('offer-card-pricey')))
        .dy;
    expect(cheapY, lessThan(priceyY));

    await tester.tap(find.byKey(const Key('offer-sort-rating')));
    await tester.pump();

    cheapY = tester.getTopLeft(find.byKey(const Key('offer-card-cheap'))).dy;
    priceyY = tester.getTopLeft(find.byKey(const Key('offer-card-pricey'))).dy;
    expect(
      priceyY,
      lessThan(cheapY),
      reason: 'rating desc — best rating first',
    );
  });

  testWidgets('offer sort chips expose tokenized minimum hit targets', (
    tester,
  ) async {
    final repo = ScriptedOffersRepository(
      snapshots: [
        _snapshot([buildOffer(id: 'a', fee: 10), buildOffer(id: 'b', fee: 20)]),
      ],
    );
    await tester.pumpWidget(
      wrapForTest(
        ClientOffersScreen(
          requestId: 'req-targets',
          repository: repo,
          cubitFactory: _testCubitFactory,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    for (final key in const [
      Key('offer-sort-best'),
      Key('offer-sort-price'),
      Key('offer-sort-rating'),
    ]) {
      final target = find.byKey(key);
      final visual = find.descendant(
        of: target,
        matching: find.byType(JeebSelectChip),
      );
      expect(
        tester.getSize(target).height,
        greaterThanOrEqualTo(UIConstants.buttonHeight),
      );
      expect(
        tester.getSize(visual).height,
        lessThan(tester.getSize(target).height),
        reason: 'the hit target grows without inflating the visual capsule',
      );
    }
  });

  testWidgets(
    'ClientOffersScreen — accept tap opens the offer-accept-confirm sheet '
    '(JM-029, not inline accept)',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([buildOffer(id: 'pick-me', jeeberName: 'Hadi')]),
        ],
      );
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
      expect(find.byKey(const Key('offer-accept-confirm-cta')), findsOneWidget);
    },
  );

  testWidgets(
    'ClientOffersScreen — cancel request CTA is at least 48dp while open',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([buildOffer(id: 'pick-me', jeeberName: 'Hadi')]),
        ],
      );
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

      final cancelCta = find.byKey(const Key('offer-review-cancel-cta'));
      expect(cancelCta, findsOneWidget);
      expect(
        tester.getSize(cancelCta).height,
        greaterThanOrEqualTo(UIConstants.buttonHeight),
      );
    },
  );

  testWidgets(
    'ClientOffersScreen — list bottom padding keeps Cancel request above '
    'the Android navigation bar at max scroll',
    (tester) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(
        bottom: _kAndroidNavigationBarInset * dpr,
      );
      tester.view.padding = FakeViewPadding(
        bottom: _kAndroidNavigationBarInset * dpr,
      );
      addTearDown(tester.view.reset);
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([
            buildOffer(id: 'one'),
            buildOffer(id: 'two'),
            buildOffer(id: 'three'),
          ]),
        ],
      );
      await tester.pumpWidget(
        wrapForTest(
          ClientOffersScreen(
            requestId: 'req-inset',
            repository: repo,
            cubitFactory: _testCubitFactory,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final listFinder = find.byKey(const Key('offer-list'));
      final cancelCta = find.byKey(const Key('offer-review-cancel-cta'));

      // The footer is DOCKED now (outside the scroll view), so the clearance
      // lives on its own padding rather than on the list's scroll extent.
      final footerPadding = tester.widget<Padding>(
        find.byKey(const Key('offer-review-footer')),
      );
      expect(
        footerPadding.padding.resolve(TextDirection.ltr).bottom,
        Spacing.twoXLarge + _kAndroidNavigationBarInset,
        reason:
            'the docked footer carries the fixed gutter AND the system bottom '
            'inset, so the CTA never sits under the navigation bar',
      );

      final scrollable = find.descendant(
        of: listFinder,
        matching: find.byType(Scrollable),
      );
      await tester.fling(scrollable, const Offset(0, -1000), 10000);
      await tester.pumpAndSettle();

      final screenBottom = tester.getRect(find.byType(Scaffold)).bottom;
      final gapBelowCta = screenBottom - tester.getRect(cancelCta).bottom;
      expect(
        gapBelowCta,
        greaterThanOrEqualTo(Spacing.xLarge + _kAndroidNavigationBarInset),
        reason:
            'the full 48dp Cancel request target must clear the Android '
            'navigation bar at max scroll; gap was $gapBelowCta',
      );
    },
  );

  testWidgets('ClientOffersScreen — empty state when no offers yet', (
    tester,
  ) async {
    final repo = ScriptedOffersRepository(snapshots: [_snapshot(const [])]);
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

    expect(find.byKey(const Key('offer-empty-state')), findsOneWidget);
  });

  testWidgets('ClientOffersScreen — failed load shows retry CTA', (
    tester,
  ) async {
    final repo = ScriptedOffersRepository(
      snapshots: [_snapshot(const [])],
      fetchFailure: OffersFailure.network,
    );
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

    final error = find.byKey(const Key('offer-load-error'));
    expect(error, findsOneWidget);
    expect(find.text('Check your connection, then retry.'), findsOneWidget);
    expect(
      tester.getSize(error).width,
      lessThanOrEqualTo(Sizes.threeHundredLarge),
      reason: 'error copy stays compact enough for balanced wrapping',
    );

    // `offer_review_list_root` now spans the in-body top bar too, so the
    // centring anchor is the content region below it.
    final body = find.byKey(const Key('offer-review-content'));
    expect(
      tester.getCenter(error).dy,
      closeTo(tester.getCenter(body).dy, 1),
      reason: 'the error state must be centered in the remaining scaffold body',
    );

    final retry = find.ancestor(
      of: find.text('Retry'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(
      tester.getSize(retry).height,
      greaterThanOrEqualTo(UIConstants.buttonHeight),
    );
  });

  testWidgets(
    'ClientOffersScreen — failure then Retry reattaches poll and countdown '
    'and clears the load error',
    (tester) async {
      var fakeNow = kBaseTime;
      final pollTicks = StreamController<void>();
      final clockTicks = StreamController<void>();
      addTearDown(pollTicks.close);
      addTearDown(clockTicks.close);
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([
            buildOffer(id: 'recovered'),
          ], deadline: kBaseTime.add(const Duration(seconds: 10))),
          _snapshot([
            buildOffer(id: 'recovered'),
            buildOffer(id: 'polled', fee: 5),
          ], deadline: kBaseTime.add(const Duration(seconds: 10))),
        ],
        fetchFailure: OffersFailure.network,
      );
      late ClientOffersCubit cubit;

      await tester.pumpWidget(
        wrapForTest(
          ClientOffersScreen(
            requestId: 'req-retry',
            repository: repo,
            cubitFactory: (repository, requestId) {
              cubit = ClientOffersCubit(
                repository: repository,
                requestId: requestId,
                now: () => fakeNow,
                refreshSignals: pollTicks.stream,
                clockTicks: clockTicks.stream,
              );
              return cubit;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(cubit.state.status, OffersScreenStatus.failed);
      expect(cubit.state.error, OffersFailure.network);
      expect(find.byKey(const Key('offer-load-error')), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(cubit.state.status, OffersScreenStatus.loaded);
      expect(cubit.state.error, isNull);
      expect(find.byKey(const Key('offer-load-error')), findsNothing);
      expect(find.byKey(const Key('offer-error-banner')), findsNothing);
      expect(pollTicks.hasListener, isTrue);
      expect(clockTicks.hasListener, isTrue);
      expect(cubit.state.windowRemaining, const Duration(seconds: 10));

      fakeNow = kBaseTime.add(const Duration(seconds: 1));
      clockTicks.add(null);
      await tester.pump();
      expect(cubit.state.windowRemaining, const Duration(seconds: 9));

      pollTicks.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('offer-card-polled')), findsOneWidget);
      expect(repo.fetchCalls, 3);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('ClientOffersScreen — vehicle and fee surface inside the card', (
    tester,
  ) async {
    final repo = ScriptedOffersRepository(
      snapshots: [
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
      ],
    );
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
              'createdAt': '2026-07-04T23:05:45.994303Z',
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
      expect(find.byKey(const Key('offer-window-timer')), findsNothing);
      expect(find.text('Offer window expired'), findsNothing);
      final accept = tester.widget<OmdsPrimaryButton>(
        find.byKey(const Key('offer-card-accept-a7e85c0b-real-offer')),
      );
      expect(accept.isEnabled, isTrue);
      // The parsed fee surfaces on the card via the unified MoneyFormat
      // (6.5 USD -> "$6.50", lane item 3).
      expect(find.text('\u2066\$6.50\u2069'), findsWidgets);
    },
  );

  testWidgets(
    'ClientOffersScreen — expires only on a terminal server snapshot',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          OffersSnapshot(
            offers: [buildOffer(id: 'server-expired', jeeberName: 'Karim')],
            windowExpiresAt: null,
            requestIsOpen: false,
            requestIsExpired: true,
          ),
        ],
      );

      await tester.pumpWidget(
        wrapForTest(
          ClientOffersScreen(
            requestId: 'req-expired',
            repository: repo,
            cubitFactory: _testCubitFactory,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Offer window expired'), findsOneWidget);
      expect(
        tester
            .widget<OmdsPrimaryButton>(
              find.byKey(const Key('offer-card-accept-server-expired')),
            )
            .isEnabled,
        isFalse,
      );
      expect(find.byKey(const Key('offer-review-cancel-cta')), findsNothing);
    },
  );

  testWidgets(
    'ClientOffersScreen — the Best value badge lands on the ranked-first card',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([
            buildOffer(id: 'meh', fee: 40, rating: 4.0, etaMinutes: 55),
            buildOffer(id: 'winner', fee: 8, rating: 4.9, etaMinutes: 20),
          ]),
        ],
      );
      await tester.pumpWidget(
        wrapForTest(
          ClientOffersScreen(
            requestId: 'req-badge',
            repository: repo,
            cubitFactory: _testCubitFactory,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Index 0 is the ranked-first card under the default `best` sort.
      expect(
        find.bySemanticsIdentifier('offer_card_0_best_value_badge'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_card_1_best_value_badge'),
        findsNothing,
      );
      expect(find.text('Best value'), findsOneWidget);
    },
  );

  testWidgets(
    'ClientOffersScreen — no Best value badge on a single-offer list '
    '("best of one" says nothing)',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([buildOffer(id: 'solo')]),
        ],
      );
      await tester.pumpWidget(
        wrapForTest(
          ClientOffersScreen(
            requestId: 'req-solo',
            repository: repo,
            cubitFactory: _testCubitFactory,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Best value'), findsNothing);
      expect(find.text('Fastest'), findsNothing);
    },
  );

  testWidgets(
    'ClientOffersScreen — the window strip carries the live offer count',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([
            buildOffer(id: 'a', fee: 10),
            buildOffer(id: 'b', fee: 20),
            buildOffer(id: 'c', fee: 30),
          ]),
        ],
      );
      await tester.pumpWidget(
        wrapForTest(
          ClientOffersScreen(
            requestId: 'req-strip',
            repository: repo,
            cubitFactory: _testCubitFactory,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('offer_review_window_strip'),
        findsOneWidget,
      );
      expect(find.textContaining('3 offers in'), findsOneWidget);
    },
  );

  testWidgets(
    'ClientOffersScreen — the top bar carries the back id and renders the '
    'request title only when the wire supplied one',
    (tester) async {
      final titled = ScriptedOffersRepository(
        snapshots: [
          _snapshot([buildOffer(id: 'a')], requestTitle: 'Medicine'),
        ],
      );
      await tester.pumpWidget(
        wrapForTest(
          ClientOffersScreen(
            requestId: 'req-title',
            repository: titled,
            cubitFactory: _testCubitFactory,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsIdentifier('offer_review_back'), findsOneWidget);
      expect(find.text('Choose a Jeeber'), findsOneWidget);
      expect(find.text('Medicine'), findsOneWidget);
    },
  );

  testWidgets(
    'ClientOffersScreen — a title-less request renders a one-line top bar, '
    'never a placeholder subtitle',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([buildOffer(id: 'a')]),
        ],
      );
      await tester.pumpWidget(
        wrapForTest(
          ClientOffersScreen(
            requestId: 'req-no-title',
            repository: repo,
            cubitFactory: _testCubitFactory,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Choose a Jeeber'), findsOneWidget);
      // The top bar's title/subtitle block collapses to the title alone.
      final titleBlock = find.ancestor(
        of: find.text('Choose a Jeeber'),
        matching: find.byType(Column),
      );
      expect(
        titleBlock,
        findsWidgets,
        reason: 'the bar still lays out; it simply has no second line',
      );
      expect(find.text('Medicine'), findsNothing);
    },
  );
}
