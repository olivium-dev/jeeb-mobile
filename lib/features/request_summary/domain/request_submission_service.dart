import '../../../core/network/app_failure.dart';
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
  const RequestSubmissionException(this.failure, [this.message])
      : appFailure = null;

  /// Carries the classified [AppFailure] alongside the legacy enum, so a catch
  /// site can render kind-aware copy without a signature break.
  const RequestSubmissionException.classified(
    this.failure, {
    this.message,
    this.appFailure,
  });

  final RequestSubmissionFailure failure;
  final String? message;

  /// Diagnostics + copy selection only; never rendered verbatim.
  final AppFailure? appFailure;

  @override
  String toString() =>
      'RequestSubmissionException(${failure.name}'
      '${message == null ? '' : ': $message'})';
}

/// The gateway refused the create because the description matched the
/// prohibited-items list. [blocked] means no acknowledgement can clear it.
class RequestModerationRequired extends RequestSubmissionException {
  const RequestModerationRequired({
    this.matches = const <String>[],
    this.blocked = false,
    AppFailure? appFailure,
  }) : super.classified(
          RequestSubmissionFailure.invalidInput,
          appFailure: appFailure,
        );

  /// The flagged keywords the gateway reported.
  final List<String> matches;

  /// True for `prohibited-item-blocked`: terminal, never acknowledgeable.
  final bool blocked;

  @override
  String toString() =>
      'RequestModerationRequired(blocked: $blocked, matches: ${matches.length})';
}
