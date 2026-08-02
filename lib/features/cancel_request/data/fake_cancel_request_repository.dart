import '../domain/cancel_request_repository.dart';

class FakeCancelRequestRepository implements CancelRequestRepository {
  FakeCancelRequestRepository({this.failWith});

  final CancelRequestFailure? failWith;

  final List<String> cancelledRequestIds = <String>[];

  @override
  Future<void> cancelRequest({required String requestId}) async {
    cancelledRequestIds.add(requestId);
    final f = failWith;
    if (f != null) throw CancelRequestException(f);
  }
}
