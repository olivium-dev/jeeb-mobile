import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../core/di/injection_container.dart';

/// Runs one catalog preview with a fail-closed mutation interceptor installed
/// on the app's shared gateway client.
///
/// The Dev Tool shares the production GetIt graph. Individual catalog entries
/// still inject local repositories so their designed states are deterministic,
/// but this guard is the final safety net: any missed repository seam can read
/// data, while POST/PUT/PATCH/DELETE (and unknown verbs) are rejected locally
/// before Dio reaches its HTTP adapter.
class CatalogNetworkGuard extends StatefulWidget {
  const CatalogNetworkGuard({required this.builder, super.key});

  /// Deliberately a builder rather than an already-built child. The interceptor
  /// is installed in [State.initState] before fixture construction can resolve
  /// a repository or start work.
  final WidgetBuilder builder;

  @override
  State<CatalogNetworkGuard> createState() => _CatalogNetworkGuardState();
}

class _CatalogNetworkGuardState extends State<CatalogNetworkGuard> {
  final Interceptor _interceptor = const CatalogMutationInterceptor();
  Dio? _guardedDio;

  @override
  void initState() {
    super.initState();
    if (!sl.isRegistered<Dio>()) return;

    final dio = sl<Dio>();
    dio.interceptors.add(_interceptor);
    _guardedDio = dio;
  }

  @override
  void dispose() {
    _guardedDio?.interceptors.remove(_interceptor);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Dio interceptor used by [CatalogNetworkGuard].
///
/// Only explicitly read-only verbs pass. Treating every other method as a
/// mutation is intentional: a new or misspelled verb fails closed.
class CatalogMutationInterceptor extends Interceptor {
  const CatalogMutationInterceptor();

  static const Set<String> _readOnlyMethods = <String>{
    'GET',
    'HEAD',
    'OPTIONS',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final method = options.method.toUpperCase();
    if (_readOnlyMethods.contains(method)) {
      handler.next(options);
      return;
    }

    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: CatalogMutationBlockedException(method, options.uri),
      ),
    );
  }
}

/// Diagnostic carried by the local Dio rejection when a preview tries to
/// mutate the gateway.
class CatalogMutationBlockedException implements Exception {
  const CatalogMutationBlockedException(this.method, this.uri);

  final String method;
  final Uri uri;

  @override
  String toString() => 'Catalog blocked $method $uri';
}
