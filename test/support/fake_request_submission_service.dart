import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';

/// Scriptable in-memory [RequestSubmissionService] for unit + widget tests.
class FakeRequestSubmissionService implements RequestSubmissionService {
  FakeRequestSubmissionService({
    this.requestId = 'fake-request-id',
    this.error,
  });

  /// Id returned on a successful submit.
  String requestId;

  /// When non-null, [submit] throws this instead of returning [requestId].
  RequestSubmissionException? error;

  /// Number of times [submit] was invoked.
  int submitCount = 0;

  /// The draft passed to the most recent [submit] call.
  RequestDraft? lastDraft;

  @override
  Future<String> submit(RequestDraft draft) async {
    submitCount++;
    lastDraft = draft;
    final err = error;
    if (err != null) throw err;
    return requestId;
  }
}
