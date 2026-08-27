import 'package:geocoding/geocoding.dart';

import '../domain/reverse_geocoder.dart';

typedef PlacemarkLookup =
    Future<List<Placemark>> Function(double latitude, double longitude);

class GeocodingReverseGeocoder implements ReverseGeocoder {
  GeocodingReverseGeocoder({
    PlacemarkLookup? placemarkLookup,
    Duration timeout = const Duration(seconds: 5),
  }) : _placemarkLookup = placemarkLookup ?? _lookupOnDevice,
       _timeout = timeout;

  final PlacemarkLookup _placemarkLookup;
  final Duration _timeout;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await _placemarkLookup(
        latitude,
        longitude,
      ).timeout(_timeout);
      if (placemarks.isEmpty) return null;
      return _format(placemarks.first);
    } on Object {
      return null;
    }
  }

  static Future<List<Placemark>> _lookupOnDevice(
    double latitude,
    double longitude,
  ) => Geocoding().placemarkFromCoordinates(latitude, longitude);

  static String? _format(Placemark placemark) {
    final parts = <String>[];
    _addPart(parts, _firstNonEmpty(placemark.street, placemark.thoroughfare));
    _addPart(parts, placemark.subLocality);
    _addPart(parts, placemark.locality);
    return parts.isEmpty ? null : parts.join(', ');
  }

  static String? _firstNonEmpty(String? preferred, String? fallback) {
    final preferredValue = preferred?.trim();
    if (preferredValue != null && preferredValue.isNotEmpty) {
      return preferredValue;
    }
    return fallback;
  }

  static void _addPart(List<String> parts, String? candidate) {
    final value = candidate?.trim();
    if (value == null || value.isEmpty || parts.contains(value)) return;
    parts.add(value);
  }
}
