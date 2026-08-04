/// Composite "best value" ranking for the offer-review list (screen 11).
///
/// The redesigned sort bar's first chip is **Best**, and the top card wears a
/// `Best value` badge. Neither is a single-field sort: at the accept-exactly-ONE
/// moment the customer is weighing price, reputation and speed together, so the
/// ordering is a **Borda count** over three per-criterion rankings — fee
/// ascending, rating descending, ETA ascending — and the lowest total wins.
/// Ties fall back to newest-first, the same stable tie-break the price/rating
/// sorts use, so an unchanged offer set never churns its positions between
/// pushes.
///
/// Honesty rules live here rather than in the UI:
///  * A Jeeber with `ratingCount == 0` has no reputation the app may reason
///    about, so it contributes the **neutral** rating rank (the middle of the
///    field). It is never scored as though `rating: 0.0` were a real average,
///    and never promoted as though it were perfect.
///  * [bestValueOfferId] is null for a single-offer list — "best of one" is a
///    badge with no information in it.
///  * [fastestOfferId] is null unless the minimum ETA is *unique*, and null
///    when that offer already holds the best-value badge: one card never wears
///    two ranking badges.
///
/// **Distance is deliberately absent.** The gateway's offer row carries no
/// `distanceKm` — `DioOffersRepository._parseOffer` has nothing to read — so no
/// proximity term can enter this ranking without being invented. The board's
/// "3 km away" line is a data gap, not a missing sort key.
library;

import 'offer.dart';

/// Orders [offers] by the composite best-value score (best first).
///
/// Pure and total: a list of 0 or 1 offers is returned unchanged, and the
/// result is always unmodifiable so a caller cannot mutate cubit state.
List<Offer> rankByBestValue(List<Offer> offers) {
  if (offers.length < 2) return List<Offer>.unmodifiable(offers);
  final Map<String, double> scores = _bordaScores(offers);
  final List<Offer> out = List<Offer>.of(offers);
  out.sort((Offer a, Offer b) {
    final int byScore = scores[a.id]!.compareTo(scores[b.id]!);
    if (byScore != 0) return byScore;
    // Newest first — identical to the price/rating tie-break so two equally
    // ranked bids don't swap places on every refresh.
    return b.submittedAt.compareTo(a.submittedAt);
  });
  return List<Offer>.unmodifiable(out);
}

/// Id of the offer that earns the `Best value` badge, or null when the list is
/// too short for the badge to mean anything (< 2 offers).
String? bestValueOfferId(List<Offer> offers) {
  if (offers.length < 2) return null;
  return rankByBestValue(offers).first.id;
}

/// Id of the offer that earns the `Fastest` pill, or null.
///
/// Null when the list is too short, when the minimum ETA is shared by more than
/// one bid (there is no single fastest), or when the fastest bid is already the
/// best-value card.
String? fastestOfferId(List<Offer> offers) {
  if (offers.length < 2) return null;
  int minimum = offers.first.etaMinutes;
  for (final Offer offer in offers) {
    if (offer.etaMinutes < minimum) minimum = offer.etaMinutes;
  }
  final List<Offer> quickest = offers
      .where((Offer offer) => offer.etaMinutes == minimum)
      .toList(growable: false);
  if (quickest.length != 1) return null;
  final String id = quickest.single.id;
  return id == bestValueOfferId(offers) ? null : id;
}

/// Sum of the three per-criterion ranks, keyed by offer id. Lower is better.
Map<String, double> _bordaScores(List<Offer> offers) {
  final int total = offers.length;
  // The middle of a 0..total-1 rank scale: the value that neither helps nor
  // hurts an offer whose rating the app is not allowed to reason about.
  final double neutralRating = (total - 1) / 2;

  final Map<String, double> feeRanks = _fractionalRanks(
    offers,
    (Offer offer) => offer.fee,
  );
  final Map<String, double> etaRanks = _fractionalRanks(
    offers,
    (Offer offer) => offer.etaMinutes.toDouble(),
  );

  // Rating is ranked over the RATED subset only, then stretched back across the
  // full 0..total-1 scale so all three criteria carry the same weight even when
  // half the field is unrated.
  final List<Offer> rated = offers
      .where((Offer offer) => offer.ratingCount > 0)
      .toList(growable: false);
  final Map<String, double> ratedRanks = _fractionalRanks(
    rated,
    (Offer offer) => -offer.rating,
  );
  final int ratedCount = rated.length;
  final double stretch =
      (ratedCount > 1 && total > 1) ? (total - 1) / (ratedCount - 1) : 0;

  final Map<String, double> scores = <String, double>{};
  for (final Offer offer in offers) {
    final double? rank = ratedRanks[offer.id];
    // A lone rated offer has no field to be ranked against, so it is neutral
    // too — being the only Jeeber with reviews is not evidence of being better.
    final double ratingRank = (rank == null || ratedCount < 2)
        ? neutralRating
        : rank * stretch;
    scores[offer.id] = feeRanks[offer.id]! + ratingRank + etaRanks[offer.id]!;
  }
  return scores;
}

/// Fractional ("mean of tied positions") ranking of [offers] by [key],
/// ascending. Tied values share one rank so a tie never silently decides the
/// composite.
Map<String, double> _fractionalRanks(
  List<Offer> offers,
  double Function(Offer) key,
) {
  final List<Offer> sorted = List<Offer>.of(offers)
    ..sort((Offer a, Offer b) => key(a).compareTo(key(b)));
  final Map<String, double> ranks = <String, double>{};
  var start = 0;
  while (start < sorted.length) {
    var end = start;
    while (end + 1 < sorted.length && key(sorted[end + 1]) == key(sorted[start])) {
      end++;
    }
    final double mean = (start + end) / 2;
    for (var index = start; index <= end; index++) {
      ranks[sorted[index].id] = mean;
    }
    start = end + 1;
  }
  return ranks;
}
