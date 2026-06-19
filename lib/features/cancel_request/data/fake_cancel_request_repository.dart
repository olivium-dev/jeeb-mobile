import '../domain/cancel_request_repository.dart';

/// In-memory [CancelRequestRepository] for widget tests (40_GUARDRAILS_ARCH §1).
///
/// NEVER registered in DI — this is a constructor test seam only (CTO brief
/// §6.4). The default succeeds; pass [failWith] to drive the failure copy.
class FakeCancelRequestRepository implements CancelRequestRepository {
  FakeCancelRequestRepository({this.failWith});

  /// When non-null, [cancelRequest] throws this failure instead of succeeding.
  final CancelRequestFailure? failWith;

  /// Request ids passed to [cancelRequest], in call order (test assertions).
  final List<String> cancelledRequestIds = <String>[];

  @override
  Future<void> cancelRequest({required String requestId}) async {
    cancelledRequestIds.add(requestId);
    final f = failWith;
    if (f != null) throw CancelRequestException(f);
  }
}
