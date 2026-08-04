import 'package:flutter/services.dart' show rootBundle;

/// MIDNIGHT M0-6: the one dark Google Maps style the app ever applies.
///
/// Google Maps renders its LIGHT default until a style JSON is handed to it —
/// a white-and-beige rectangle in the middle of a `#070C33` screen, which is
/// exactly what the R3 / R11 board tiles do not show. The JSON in
/// `assets/map_styles/midnight.json` re-values every base feature into the
/// Midnight palette (land `#0B1351`, water `#070C33`, roads in the `#10175E`
/// family with a one-step-lighter stroke, labels periwinkle `#8A93D8` on a
/// navy halo, POI + transit off), measured off those two tiles.
///
/// Loading it is a `rootBundle` read, so it is asynchronous; this holder makes
/// that cost payable exactly ONCE per process:
///  * the decoded string is cached after the first successful read, and
///  * concurrent callers share a single in-flight future (both map surfaces can
///    mount at the same time on a resumed deep link).
///
/// **Total by contract.** A missing or unreadable asset returns null and the
/// map falls back to the platform default rather than throwing out of a
/// `build`/`initState`: a broken decoration must never take down live tracking.
/// Call sites pass the result straight into `GoogleMap(style: ...)`, which
/// accepts null as "no custom style".
abstract final class JeebMapStyle {
  /// Bundle key — must match the `assets:` entry in pubspec.yaml.
  static const String asset = 'assets/map_styles/midnight.json';

  static String? _cached;
  static Future<String?>? _inFlight;

  /// The style JSON if it has already been read, else null.
  ///
  /// Lets a widget that rebuilds (or a second map mounted after the first)
  /// paint Midnight on its FIRST frame instead of flashing the light default
  /// for the frame it takes [load] to complete.
  static String? get cached => _cached;

  /// Reads (once) and returns the Midnight style JSON, or null if it cannot be
  /// read. Never throws.
  static Future<String?> load() {
    final String? cached = _cached;
    if (cached != null) return Future<String?>.value(cached);
    return _inFlight ??= _read();
  }

  static Future<String?> _read() async {
    try {
      final String json = await rootBundle.loadString(asset);
      _cached = json;
      return json;
    } catch (_) {
      // See the class doc: a map with default colours beats no map at all.
      return null;
    } finally {
      _inFlight = null;
    }
  }

  /// Test seam — drops the cache so a test can assert the load path itself.
  static void debugReset() {
    _cached = null;
    _inFlight = null;
  }
}
