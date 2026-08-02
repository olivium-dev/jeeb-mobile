import '../domain/dispute_status_repository.dart';

class EmptyDisputeStatusRepository implements DisputeStatusRepository {
  const EmptyDisputeStatusRepository();

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    throw const DisputeStatusRepositoryException(
      DisputeStatusFailure.notFound,
      'No DisputeStatusRepository registered',
    );
  }
}
