/// The single countdown renderer for every "time left" surface.
///
/// ## Why this exists
///
/// Two screens had independently written the same four lines:
///
/// ```dart
/// final minutes = d.inMinutes;              // TOTAL minutes, unbounded
/// final seconds = d.inSeconds % 60;
/// return '$minutes:${seconds.toString().padLeft(2, '0')}';
/// ```
///
/// `Duration.inMinutes` is the WHOLE duration in minutes, not the
/// minutes-within-the-hour, so the moment a window exceeds 60 minutes the
/// left-hand field stops being a clock field and becomes a raw count. On real
/// hardware during the live COD run the waiting screen rendered
/// **`1433:18 left to find a Jeeber`** — 23 h 53 m 18 s, printed as 1433
/// minutes. It is not a rounding wobble; it is unreadable.
///
/// Both call sites believed they were safe. `OfferWindowTimer` said so out
/// loud: *"the window cap is always under 30 min so a 3-digit minute count
/// never appears in practice"*. The waiting screen held the same unwritten
/// assumption and it is exactly the one that broke — its window comes from the
/// server's `offerDeadlineInSeconds`, and the gateway falls back to a 24 h
/// `TierExpiryWindowResolver.SafeExpiryWindow` whenever a request's tier does
/// not resolve. A client formatter must not depend on a server-side value
/// staying inside a range no client can enforce.
///
/// ## The display
///
/// * under an hour → `m:ss`   (`4:59`) — unchanged, this is the common case
/// * an hour or more → `h:mm:ss` (`23:53:18`) — the minutes field is promoted
///   rather than allowed to overflow
/// * negative (a deadline already passed) → clamped to `0:00`
///
/// Fields are zero-padded only where a clock demands it: the leading field is
/// never padded (`4:59`, not `04:59`), and every field to its right is padded
/// to two digits. The output is digits and colons only, so it is safe to
/// interpolate into an RTL sentence — Unicode bidi resolves a colon-separated
/// numeric run left-to-right inside an Arabic paragraph without any explicit
/// isolate.
library;

/// Formats a remaining [Duration] as a human countdown. See the library doc for
/// the format contract and why it is shared rather than re-written per screen.
class CountdownFormat {
  const CountdownFormat._();

  /// `m:ss` under an hour, `h:mm:ss` at an hour or more, `0:00` when [d] has
  /// already run out.
  static String format(Duration d) {
    if (d.isNegative) return '0:00';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final ss = _pad(seconds);
    if (hours == 0) return '$minutes:$ss';
    return '$hours:${_pad(minutes)}:$ss';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
