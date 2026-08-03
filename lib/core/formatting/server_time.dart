abstract final class ServerTime {
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
