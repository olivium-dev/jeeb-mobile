import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../core/di/injection_container.dart';

class CatalogNetworkGuard extends StatefulWidget {
  const CatalogNetworkGuard({required this.builder, super.key});

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

class CatalogMutationBlockedException implements Exception {
  const CatalogMutationBlockedException(this.method, this.uri);

  final String method;
  final Uri uri;

  @override
  String toString() => 'Catalog blocked $method $uri';
}
