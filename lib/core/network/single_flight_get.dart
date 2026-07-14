import 'package:dio/dio.dart';

/// Shared single-flight coalescer for idempotent `GET`s (F3 / FIX-A).
///
/// The customer "Choose a Jeeber" path runs THREE uncoordinated pollers over
/// ONE shared [Dio]:
///   1. the customer-home poll (`DioClientHomeRepository`) probing
///      `GET /v1/offers?requestId` for every open request,
///   2. the waiting-screen poll (`DioWaitingRepository.fetchOfferCount`), and
///   3. the offer-review poll (`DioOffersRepository.fetchOffers`).
///
/// Each one used to hold (at best) its OWN in-flight dedupe map, so an
/// identical `GET /v1/offers?requestId=<id>` fired by two different repos in
/// the same instant produced two concurrent wire calls. Behind a slow proxy any
/// response slower than the 5s poll cadence overlaps the next tick, multiplying
/// the fan-out until the gateway's per-subscription limiter trips a 429.
///
/// Promoting the coalescer to the shared network layer (a single DI instance
/// injected into all three repos) collapses every concurrent identical read —
/// regardless of which repo issued it — onto ONE underlying [Dio.get]. Entries
/// self-evict the instant their future settles, so this is a single-flight
/// coalescer, never a cache: a later poll cycle always issues a fresh read.
class SingleFlightGet {
  SingleFlightGet(this._dio);

  final Dio _dio;

  /// Keyed by `path?sorted-query`. Holds the RAW [Dio.get] future so every
  /// concurrent caller awaits the same round-trip (and every caller sees the
  /// same success body OR the same error — a 429 is delivered to all of them).
  final Map<String, Future<Response<dynamic>>> _inFlight =
      <String, Future<Response<dynamic>>>{};

  /// Issues `GET [path]` (with [queryParameters]) unless an identical read is
  /// already in flight, in which case the existing future is returned so the
  /// duplicate never touches the network.
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final key = _key(path, queryParameters);
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _dio.get<dynamic>(path, queryParameters: queryParameters);
    _inFlight[key] = future;
    // Evict once settled. The `.ignore()` is deliberate: `whenComplete` returns
    // a SEPARATE future that would otherwise resurface the original's error as
    // an unhandled async error — the real error is still delivered to whoever
    // awaits [future] itself.
    future.whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }).ignore();
    return future;
  }

  /// Order-independent `(path, query)` key so `{a,b}` and `{b,a}` collapse.
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
