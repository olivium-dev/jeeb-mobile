import 'package:dio/dio.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../domain/masked_call_repository.dart';

class DioMaskedCallRepository implements MaskedCallRepository {
  const DioMaskedCallRepository(this._dio, {OperationIdFactory? newKey})
      : _newKey = newKey ?? newOperationId;

  final Dio _dio;

  /// Minted per START, not per delivery: a later call is a NEW session, so the
  /// key only has to survive the transport replay of one attempt.
  final OperationIdFactory _newKey;

  @override
  Future<String> startCall({required String orderId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/deliveries/${Uri.encodeComponent(orderId)}/masked-call',
        options: Options(
          headers: <String, Object?>{'Idempotency-Key': _newKey()},
        ),
      );
      final data = response.data ?? const <String, dynamic>{};
      final raw = data['sessionId'] ?? data['session_id'];
      if (raw is! String || raw.trim().isEmpty) {
        throw const UnknownFailure(parse: true);
      }
      return raw.trim();
    } on DioException catch (e) {
      throw AppFailure.of(e);
    }
  }
}
