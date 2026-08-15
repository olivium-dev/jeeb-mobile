import 'package:dio/dio.dart';

/// W6-02 compat window: the fleet is dropping the `/v1` prefix, so a versioned
/// call that comes back route-not-found is replayed once on its unversioned twin.
class UnversionedPathFallbackInterceptor extends Interceptor {
  UnversionedPathFallbackInterceptor(
    this._retryClient, {
    this.scopedToSubtrees = const <String>[],
  });

  final Dio _retryClient;

  /// Empty means every versioned path is eligible. A non-empty list narrows the
  /// replay to those subtrees, so a client can opt in with a small blast radius.
  final List<String> scopedToSubtrees;

  static const String versionPrefix = '/v1';

  static const String retriedFlag = 'jeeb.compat.unversioned.retried';

  /// Only 404/405 is replayed: both mean no handler ran, so replaying a
  /// POST/PATCH here cannot duplicate a side effect that already happened.
  static const Set<int> replayStatuses = <int>{404, 405};

  /// `/v1/deliveries` -> `GET /deliveries` is the gateway's ListShipments
  /// (a different DTO), not the versioned list. Sub-paths are true aliases.
  static const Set<String> collidingPaths = <String>{'/v1/deliveries'};

  /// `/requests` and `/requests/{id}` are RequestsController, a different
  /// action set from the v1 ones — and `POST /requests` creates a request.
  static const List<String> collidingSubtrees = <String>['/v1/requests'];

  /// `/v1/requests/7?x=1` -> `/v1/requests/7`, so a query never fools a match.
  static String routePart(String path) {
    final query = path.indexOf('?');
    return query == -1 ? path : path.substring(0, query);
  }

  /// `/v1/requests/7` -> `/requests/7`; null when there is no versioned twin.
  static String? unversioned(String path) {
    if (!path.startsWith('$versionPrefix/')) return null;
    return path.substring(versionPrefix.length);
  }

  /// Exact match or a `/`-delimited descendant, so `/v1/authz` never matches
  /// the `/v1/auth` subtree.
  static bool _under(String route, Iterable<String> prefixes) =>
      prefixes.any((prefix) => route == prefix || route.startsWith('$prefix/'));

  /// True when the unversioned twin is already a DIFFERENT live route, where a
  /// replay would silently shadow it instead of reaching the same handler.
  static bool collides(String path) {
    final route = routePart(path);
    if (collidingPaths.contains(route)) return true;
    return _under(route, collidingSubtrees);
  }

  /// True when this instance is allowed to replay [path] at all.
  bool inScope(String path) =>
      scopedToSubtrees.isEmpty || _under(routePart(path), scopedToSubtrees);

  static bool shouldReplay(RequestOptions options, int? status) {
    if (status == null || !replayStatuses.contains(status)) return false;
    if (options.extra[retriedFlag] == true) return false;
    // A FormData body is a one-shot stream; a replay would send empty parts.
    if (options.data is FormData) return false;
    if (collides(options.path)) return false;
    return unversioned(options.path) != null;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!inScope(options.path) ||
        !shouldReplay(options, err.response?.statusCode)) {
      handler.next(err);
      return;
    }

    final versionedPath = options.path;
    options.path = unversioned(versionedPath)!;
    options.extra[retriedFlag] = true;
    try {
      final replayed = await _retryClient.fetch<dynamic>(options);
      handler.resolve(replayed);
    } on DioException {
      // Revert-safe: the caller still sees the original versioned failure.
      options.path = versionedPath;
      handler.next(err);
    }
  }
}
