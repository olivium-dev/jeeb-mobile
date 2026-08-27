abstract class ReverseGeocoder {
  /// Best-effort. Must NEVER throw and must NEVER hang: return null on any
  /// failure, empty result, or timeout. Callers treat null as "show the
  /// coordinate instead" — this is pure display/label enrichment, never a
  /// gate on pin usability or request submission.
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}
