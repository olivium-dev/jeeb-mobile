import 'package:equatable/equatable.dart';

import '../../domain/cancellation_result.dart';

/// All possible states for the cancellation flow cubit.
sealed class CancellationState extends Equatable {
  const CancellationState();

  @override
  List<Object?> get props => [];
}

/// Initial idle state — form is displayed, nothing submitted yet.
final class CancellationIdle extends CancellationState {
  const CancellationIdle();
}

/// Submission in progress — disable the submit button.
final class CancellationLoading extends CancellationState {
  const CancellationLoading();
}

/// Successful cancellation; [result] carries fee and week count data.
final class CancellationSuccess extends CancellationState {
  const CancellationSuccess(this.result);

  final CancellationResult result;

  @override
  List<Object?> get props => [result];
}

/// Rate-limit hit (HTTP 429). [retryAfter] is when the limit resets.
final class CancellationRateLimited extends CancellationState {
  const CancellationRateLimited({this.retryAfter});

  final DateTime? retryAfter;

  @override
  List<Object?> get props => [retryAfter];
}

/// Delivery already picked-up or terminal — cannot cancel.
final class CancellationTooLate extends CancellationState {
  const CancellationTooLate();
}

/// Generic error (network / 5xx). [message] is retained for diagnostics only
/// and is NEVER rendered to the user — the screen maps this state to a
/// localized generic-error string so raw backend text never leaks into the UI.
final class CancellationError extends CancellationState {
  const CancellationError([this.message]);

  final String? message;

  @override
  List<Object?> get props => [message];
}
