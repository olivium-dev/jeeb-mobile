import 'package:dio/dio.dart';

class SingleFlightGet {
  SingleFlightGet(this._dio);

  final Dio _dio;

  final Map<String, Future<Response<dynamic>>> _inFlight =
      <String, Future<Response<dynamic>>>{};

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final key = _key(path, queryParameters);
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _dio.get<dynamic>(path, queryParameters: queryParameters);
    _inFlight[key] = future;
    future.whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }).ignore();
    return future;
  }

  static String _key(String path, Map<String, dynamic>? query) {
    final buffer = StringBuffer(path)..write('?');
    if (query != null && query.isNotEmpty) {
      final entries = query.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in entries) {
        buffer
          ..write(entry.key)
          ..write('=')
          ..write(entry.value)
          ..write('&');
      }
    }
    return buffer.toString();
  }
}
