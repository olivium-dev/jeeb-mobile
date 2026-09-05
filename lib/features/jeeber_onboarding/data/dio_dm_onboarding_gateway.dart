import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/gateway_problem.dart';
import '../domain/dm_onboarding_gateway.dart';

/// UX-05: the submit that used to be an `async {}`. The route is not deployed
/// yet, so 404/405/501 still resolve — a gap must not block the funnel.
class DioDmOnboardingGateway implements DmOnboardingGateway {
  const DioDmOnboardingGateway(this._dio, {this.operationId});

  final Dio _dio;

  /// Idempotency scope for a retried submit; null mints none.
  final String? operationId;

  @override
  Future<void> submit(DmOnboardingSubmission submission) async {
    final String? key = submission.operationId ?? operationId;
    try {
      await _dio.post<Map<String, dynamic>>(
        DmOnboardingGateway.submitPath,
        data: submission.toJson(),
        options: key == null
            ? null
            : Options(headers: <String, Object?>{'Idempotency-Key': key}),
      );
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 404 || status == 405 || status == 501) {
        Diag.event('dm_onboarding_submit_route_absent', {'status': status});
        return;
      }
      final AppFailure failure = AppFailure.of(e);
      final GatewayProblem? problem =
          failure.problem ?? GatewayProblem.tryParse(e.response?.data);
      if (failure is ConflictFailure &&
          _reasonOf(problem) == 'out_of_coverage') {
        throw const DmOnboardingOutOfCoverageException();
      }
      Diag.event('dm_onboarding_submit_failed', {'kind': failure.kind.name});
      throw DmOnboardingGatewayException(failure);
    }
  }

  /// D1: this endpoint emits `https://problems.jeeb.lb/<svc>/<code>`, not the
  /// `/errors/` shape `typeSuffix` recognises — last segment is the fallback.
  static String? _reasonOf(GatewayProblem? problem) =>
      problem?.typeSuffix ?? _lastSegment(problem?.type);

  static String? _lastSegment(String? type) {
    if (type == null || type.isEmpty) return null;
    final segments = type.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? null : segments.last;
  }
}
