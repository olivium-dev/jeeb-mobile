// CO-01: an unbounded cold-retry re-arm kept a permanently throttled screen in
// `loading` FOR EVER. The cap turns it into a real, retryable failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_state.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';

/// Throws 429 until [healAfter] reads have been served.
class _Throttled implements OffersRepository {
  _Throttled({this.healAfter});

  final int? healAfter;
  int reads = 0;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    reads++;
    final int? heal = healAfter;
    if (heal != null && reads > heal) {
      return const OffersSnapshot(
        offers: <Offer>[],
        windowExpiresAt: null,
        requestIsOpen: true,
      );
    }
    throw const OffersRepositoryException(
      OffersFailure.rateLimited,
      'rate limited',
      Duration(seconds: 1),
    );
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async =>
      OfferAcceptResult.empty;
}

ClientOffersCubit _cubit(OffersRepository repo) => ClientOffersCubit(
  repository: repo,
  requestId: 'r1',
  retryDelay: (Duration _) async {},
  refreshSignals: const Stream<void>.empty(),
  clockTicks: const Stream<void>.empty(),
);

void main() {
  test('a permanent 429 reaches FAILED instead of looping in loading',
      () async {
    final _Throttled repo = _Throttled();
    final ClientOffersCubit cubit = _cubit(repo);
    addTearDown(cubit.close);

    await cubit.load();
    // The re-arm is synchronous under a zero delay, so the cap is already hit.
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.status, OffersScreenStatus.failed);
    expect(cubit.state.error, OffersFailure.rateLimited);
    expect(cubit.state.appFailure, isA<RateLimitedFailure>());
    expect(
      repo.reads,
      lessThanOrEqualTo(5),
      reason: 'the retry must be bounded, not unbounded',
    );
  });

  test('a success inside the window resets the counter', () async {
    final _Throttled repo = _Throttled(healAfter: 2);
    final ClientOffersCubit cubit = _cubit(repo);
    addTearDown(cubit.close);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.status, OffersScreenStatus.loaded);
    expect(cubit.state.error, isNull);
  });
}
