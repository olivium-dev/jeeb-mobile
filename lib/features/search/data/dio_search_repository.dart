import 'package:dio/dio.dart';

import '../domain/search_repository.dart';

/// Dio-backed [SearchRepository] — the gateway free-text search BFF:
///
///   GET `/v1/search?q=<query>`  → `{ "results": [ { id, type, title,
///                                  subtitle, ref } ] }`
///
/// This IS the DI default. The mobile gateway does not expose this BFF route
/// yet, so a `404` is mapped to [SearchFailure.unavailable] — the screen then
/// renders an honest "search isn't available yet" empty state instead of a
/// hard error or a dead-end. Once the route lands the same code path returns
/// real hits with NO call-site change. The inbox is scoped to the
/// authenticated user via the bearer token (the gateway derives the owner from
/// the JWT `sub`); no client-side user id is passed.
class DioSearchRepository implements SearchRepository {
  const DioSearchRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<SearchResult>> search(String query) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/search',
        queryParameters: <String, dynamic>{'q': query},
      );
      final data = res.data ?? const <String, dynamic>{};
      final raw = data['results'] ?? data['items'];
      final list = raw is List ? raw : const <dynamic>[];
      final out = <SearchResult>[];
      for (final item in list) {
        if (item is Map) {
          out.add(_result(item.cast<String, dynamic>()));
        }
      }
      return out;
    } on DioException catch (e) {
      throw SearchRepositoryException(_map(e), e.message);
    }
  }

  SearchResult _result(Map<String, dynamic> json) {
    final id = _str(json['id']) ?? '';
    return SearchResult(
      id: id,
      kind: _kind(json['type'] ?? json['kind']),
      title: _str(json['title']) ?? '',
      subtitle: _str(json['subtitle'] ?? json['body']),
      refId: _str(json['ref'] ?? json['targetId']) ?? (id.isEmpty ? null : id),
    );
  }

  SearchResultKind _kind(Object? v) {
    switch (v) {
      case 'order':
      case 'delivery':
        return SearchResultKind.order;
      case 'conversation':
      case 'chat':
        return SearchResultKind.conversation;
      default:
        return SearchResultKind.unknown;
    }
  }

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  SearchFailure _map(DioException e) {
    final code = e.response?.statusCode;
    if (code == 404) return SearchFailure.unavailable;
    if (code == 401 || code == 403) return SearchFailure.unauthorized;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return SearchFailure.network;
      default:
        return SearchFailure.unknown;
    }
  }
}
