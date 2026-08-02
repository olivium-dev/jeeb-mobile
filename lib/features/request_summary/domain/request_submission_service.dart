import 'request_draft.dart';

abstract class RequestSubmissionService {
  Future<String> submit(RequestDraft draft);
}

enum RequestSubmissionFailure {
  invalidInput,

  unauthorized,

  network,

  server,
}

class RequestSubmissionException implements Exception {
  const RequestSubmissionException(this.failure, [this.message]);

  final RequestSubmissionFailure failure;
  final String? message;

  @override
  String toString() =>
      'RequestSubmissionException(${failure.name}'
      '${message == null ? '' : ': $message'})';
}
