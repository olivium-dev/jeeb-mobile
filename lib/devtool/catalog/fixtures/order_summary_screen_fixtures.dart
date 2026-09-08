// Designed states for `OrderSummaryScreen` (JM-031 order-summary) — ONE source

import 'dart:async';

import '../../../features/order_summary/data/fake_order_summary_repository.dart';
import '../../../features/order_summary/domain/order_summary.dart';
import '../../../features/order_summary/domain/order_summary_repository.dart';

/// One designed state: the id the route would carry, and the repository behind
/// it.
final class OrderSummaryScreenDesignedState {
  const OrderSummaryScreenDesignedState({
    required this.deliveryId,
    this.repository,
  });

  /// The `/orders/:id/summary` path parameter this state stands for.
  final String deliveryId;

  /// The read behind this state. Always a local fake — or NULL, which hands the
  /// decision to `OrderSummaryScreen._resolveRepository()`.
  final OrderSummaryRepository? repository;
}

/// A read that never completes — the cold-load state, held open.
/// Not a synthetic condition: it is the first frame of EVERY order summary,
/// because `OrderSummaryCubit.load()` emits `loading` before it awaits and only
class OrderSummaryScreenPendingRepository implements OrderSummaryRepository {
  const OrderSummaryScreenPendingRepository();

  @override
  Future<OrderSummary> fetchSummary(String deliveryId) =>
      Completer<OrderSummary>().future;
}

/// The item summary on [OrderSummaryScreenFixtures.longestContent].
/// Public because the render test pins it — it is the one string that fixture
const String kOrderSummaryScreenLongItem =
    'Two crates of bottled water, a 5 kg bag of rice, four tins of tuna and '
    'the blood-pressure medicine from the pharmacy next to the Mar Elias '
    'junction — ring the bell twice, the intercom on the third floor is broken';

/// The jeeber id [OrderSummaryScreenFixtures.minimalPayload] shows in place of
/// a name.
const String kOrderSummaryScreenJeeberId =
    'jbr-7f3c1a92-4d8e-4b21-9a05-6c1e2f3a4b5d';

/// The designed states, named once for both dev surfaces.
/// Every member is a getter so that each read hands out a fresh state — the
abstract final class OrderSummaryScreenFixtures {
  /// CATALOG · "Loaded". The reference reading: an accepted express order with
  /// every optional field populated — rating, count, ETA and item summary.
  static OrderSummaryScreenDesignedState get loaded =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2044',
        repository: FakeOrderSummaryRepository(
          summary: const OrderSummary(
            deliveryId: 'DEL-2044',
            requestId: 'REQ-2044',
            conversationId: 'CONV-2044',
            price: 14.5,
            currency: 'USD',
            jeeberName: 'Rami Chidiac',
            tier: 'express',
            jeeberRating: 4.8,
            jeeberRatingCount: 214,
            etaMinutes: 12,
            itemSummary: 'Pharmacy pickup',
          ),
        ),
      );

  /// CATALOG · "Failed — Not Found". The accepted order is gone (404), or the
  /// deep link carried an id this account cannot see.
  static OrderSummaryScreenDesignedState get notFound =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2044',
        repository: FakeOrderSummaryRepository(
          failure: OrderSummaryFailure.notFound,
        ),
      );

  /// CATALOG · "Loading". The fetch is on the wire and nothing has come back.
  static OrderSummaryScreenDesignedState get coldRead =>
      const OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2044',
        repository: OrderSummaryScreenPendingRepository(),
      );

  /// The phone is offline (or the gateway is unreachable).
  /// A DIFFERENT typed failure from [notFound] — and, on this screen, the same
  static OrderSummaryScreenDesignedState get networkFailure =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2077',
        repository: FakeOrderSummaryRepository(
          failure: OrderSummaryFailure.network,
        ),
      );

  /// The emptiest LOADED body this screen can reach — every optional field
  /// absent and every required one defaulted.
  static OrderSummaryScreenDesignedState get minimalPayload =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2101',
        repository: FakeOrderSummaryRepository(
          summary: const OrderSummary(
            deliveryId: 'DEL-2101',
            requestId: 'DEL-2101',
            conversationId: null,
            price: null,
            currency: null,
            jeeberName: kOrderSummaryScreenJeeberId,
            tier: '',
          ),
        ),
      );

  /// The wire carried no amount: the ticket says "unavailable", never $0.00.
  static OrderSummaryScreenDesignedState get priceUnavailable =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2102',
        repository: FakeOrderSummaryRepository(
          summary: const OrderSummary(
            deliveryId: 'DEL-2102',
            requestId: 'REQ-2102',
            conversationId: 'CONV-2102',
            price: null,
            currency: null,
            jeeberName: 'Rami Chidiac',
            tier: 'express',
          ),
        ),
      );

  /// Two of the three secondary reads failed — the partial-data note rides
  /// above a ticket that is otherwise complete.
  static OrderSummaryScreenDesignedState get partialSecondaryReads =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2103',
        repository: FakeOrderSummaryRepository(
          summary: const OrderSummary(
            deliveryId: 'DEL-2103',
            requestId: 'REQ-2103',
            conversationId: 'CONV-2103',
            price: 14.5,
            currency: 'USD',
            jeeberName: 'Rami Chidiac',
            tier: 'express',
            partialSections: <OrderSummarySection>{
              OrderSummarySection.offers,
              OrderSummarySection.jeeber,
            },
          ),
        ),
      );

  /// No conversation id on the wire: the Chat CTA is hidden, not guessed.
  static OrderSummaryScreenDesignedState get noConversationId =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2104',
        repository: FakeOrderSummaryRepository(
          summary: const OrderSummary(
            deliveryId: 'DEL-2104',
            requestId: 'REQ-2104',
            conversationId: null,
            price: 9.0,
            currency: 'USD',
            jeeberName: 'Rami Chidiac',
            tier: 'standard',
          ),
        ),
      );

  /// The longest plausible content on every axis at once.
  /// A seven-digit lira amount is ordinary in SYP rather than adversarial, the
  static OrderSummaryScreenDesignedState get longestContent =>
      OrderSummaryScreenDesignedState(
        deliveryId: 'DEL-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
        repository: FakeOrderSummaryRepository(
          summary: const OrderSummary(
            deliveryId: 'DEL-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            requestId: 'REQ-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            conversationId: 'CONV-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            price: 1234567.89,
            currency: 'SYP',
            jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
            tier: 'on-the-way',
            jeeberRating: 4.97,
            jeeberRatingCount: 12480,
            etaMinutes: 240,
            itemSummary: kOrderSummaryScreenLongItem,
          ),
        ),
      );

  /// NO repository and NO DI: what the screen shows when nothing is registered.
  /// `_resolveRepository()` ends in `return FakeOrderSummaryRepository();`, so
  static OrderSummaryScreenDesignedState get unconfiguredDi =>
      const OrderSummaryScreenDesignedState(deliveryId: 'DEL-2044');
}
