/// Single normalizer for every gateway timestamp string the app renders
/// (feed cards, order history, wallet activity, transaction detail, tracking
/// events). Cycle-5 T11 "data-truth" item 3: several surfaces parsed server
/// ISO strings with the raw [DateTime.parse]/[DateTime.tryParse] and then
/// called `toLocal()` at render — a no-op when the string had no zone marker,
/// leaking the UTC wall clock as if it were local (SW-03: cards read "12:31"
/// under a 14:31 status bar; wallet "4h ago" for a 4-minute-old row).
///
/// Rule: server times are UTC instants. An ISO-8601 string WITHOUT an explicit
/// zone (no trailing `Z`, no `±hh:mm`) is re-interpreted as UTC; a string that
/// already carries a zone parses as the instant it names. Presentation converts
/// with `toLocal()`, and instant diffs (`difference`) are exact in any device
/// zone. Pure Dart — no Flutter/intl imports so data and domain layers can use
/// it too (mirrors [MoneyFormat]).
abstract final class ServerTime {
  /// Parses [raw] into a UTC [DateTime], or `null` when [raw] is
  /// null / blank / unparseable. The caller owns the fallback — a missing
  /// time is UNKNOWN and must never be fabricated into "now" at this layer.
  static DateTime? parse(String? raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed; // had `Z` or an explicit offset
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }
}
