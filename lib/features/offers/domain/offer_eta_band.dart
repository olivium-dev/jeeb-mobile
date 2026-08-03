// PURE Dart — no Flutter / Dio / GetIt (40_GUARDRAILS_ARCH §1 layer rules).
//
// JM-045 AC2 (D14): the offer composer's ETA picker is **bounded by the tier
// SLA band**, NOT a free integer-minute field. This value object models the
// allowed pickup-ETA window for a request's tier and enumerates the discrete
// options the dropdown offers, so the Jeeber can only bid an ETA inside the
// band the tier promises the customer.
//
// The band is derived from the tier the request was created under. The mock
// tier catalog (`GET /v1/tiers`, T1) exposes a per-tier `ttlMinutes`; the SLA
// band is `[stepMinutes, ttlMinutes]` quantised to [stepMinutes]-minute steps
// (a Jeeber promises a pickup ETA no later than the tier's TTL). When the
// request's tier is unknown (the in-app feed payload does not yet carry it —
// see 50_ROUTE_REQUESTS JM-045), we fall back to the widest catalog band so
// the picker is still bounded and deterministic rather than free-form.

/// The bounded set of pickup-ETA options (in whole minutes) a Jeeber may pick
/// on the offer composer for a given tier SLA band (D14).
class OfferEtaBand {
  const OfferEtaBand({required this.options});

  /// Build a band for `[minMinutes, maxMinutes]` quantised to [stepMinutes].
  ///
  /// Defensive: clamps a non-positive / inverted range to a single sane option
  /// so the picker never renders empty (40_GUARDRAILS_ARCH §4 — degrade, don't
  /// crash). Bounds are inclusive; the ceiling is always present even if it is
  /// not a clean multiple of [stepMinutes].
  factory OfferEtaBand.fromRange({
    required int minMinutes,
    required int maxMinutes,
    int stepMinutes = 5,
  }) {
    final step = stepMinutes <= 0 ? 5 : stepMinutes;
    final floor = minMinutes <= 0 ? step : minMinutes;
    final ceil = maxMinutes < floor ? floor : maxMinutes;
    final out = <int>[];
    for (var m = floor; m <= ceil; m += step) {
      out.add(m);
    }
    if (out.isEmpty || out.last != ceil) out.add(ceil);
    return OfferEtaBand(options: List<int>.unmodifiable(out));
  }

  /// The widest deterministic fallback band used when the request's tier is not
  /// known to the composer (the feed payload omits it today — JM-045 route
  /// note). 5..120 min in 5-min steps spans the catalog's Flash (≤30) through
  /// the slower tiers, keeping the picker bounded (D14) without inventing a
  /// per-tier promise we can't read.
  factory OfferEtaBand.defaultBand() =>
      OfferEtaBand.fromRange(minMinutes: 5, maxMinutes: 120);

  /// The ordered, ascending list of selectable ETA values (minutes). Always
  /// non-empty. `options.first` is the floor of the band, `options.last` the
  /// tier SLA ceiling.
  final List<int> options;

  /// Whether [minutes] is an allowed selection in this band.
  bool contains(int minutes) => options.contains(minutes);

  /// The three representative options the composer surfaces inline (the
  /// redesigned screen draws exactly three ETA pills).
  ///
  /// Thirds of the band ceiling, each snapped to a real option so nothing
  /// unselectable is ever offered; duplicates collapse and the ceiling is
  /// always the last entry. Bands of three or fewer options are returned
  /// verbatim.
  ///
  /// The full [options] list stays the authority (D14) — the picker sheet
  /// still offers every legal bid, so this narrows the *default* reach, never
  /// the band itself. A 60-minute ceiling yields `[20, 40, 60]` (the board);
  /// the 5..120 fallback band yields `[40, 80, 120]`.
  List<int> get quickOptions {
    if (options.length <= 3) return options;
    final ceiling = options.last;
    final picks = <int>[];
    for (var third = 1; third <= 3; third++) {
      final snapped = _nearestOption(ceiling * third / 3);
      if (picks.isEmpty || picks.last != snapped) picks.add(snapped);
    }
    return List<int>.unmodifiable(picks);
  }

  /// The option closest to [target]; ties keep the lower option.
  int _nearestOption(double target) {
    var best = options.first;
    var bestDelta = (best - target).abs();
    for (final option in options) {
      final delta = (option - target).abs();
      if (delta < bestDelta) {
        best = option;
        bestDelta = delta;
      }
    }
    return best;
  }
}
