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
}
