import 'package:dio/dio.dart';

import '../../core/network/app_failure.dart';
import 'dev_gateway_client.dart';

/// Maps a Dev Tool read failure onto the kit's failure family by status code.
AppFailure devGatewayFailure(Object error) {
  if (error is AppFailure) return error;
  if (error is DioException) return AppFailure.of(error);
  if (error is DevGatewayException) {
    return switch (error.statusCode) {
      401 => UnauthorizedFailure(cause: error),
      403 => ForbiddenFailure(cause: error),
      404 => NotFoundFailure(cause: error),
      410 => GoneFailure(cause: error),
      429 => RateLimitedFailure(cause: error),
      final int status when status >= 500 => ServerFailure(
        status: status,
        cause: error,
      ),
      _ => UnknownFailure(cause: error),
    };
  }
  return UnknownFailure(cause: error);
}

/// Gateway-authored hints are preserved; arbitrary exception strings are not.
String? devGatewayMessage(Object error) =>
    error is DevGatewayException ? error.message : null;
