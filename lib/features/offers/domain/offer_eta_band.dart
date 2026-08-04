// PURE Dart — no Flutter / Dio / GetIt (40_GUARDRAILS_ARCH §1 layer rules).

class OfferEtaBand {
  const OfferEtaBand({required this.options});

  /// so the picker never renders empty (40_GUARDRAILS_ARCH §4 — degrade, don't
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

  factory OfferEtaBand.defaultBand() =>
      OfferEtaBand.fromRange(minMinutes: 5, maxMinutes: 120);

  final List<int> options;

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
