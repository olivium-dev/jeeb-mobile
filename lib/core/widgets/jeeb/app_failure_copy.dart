import '../../../l10n/app_localizations.dart';
import '../../network/app_failure.dart';

/// The four things a screen needs to render a failure: what to call it, what
/// to say about it, what the button says, and whether retrying is honest.
typedef FailureCopy = ({
  String title,
  String body,
  String action,
  bool retryable,
});

/// THE copy family for [AppFailure]: only Network/Timeout blame the user's
/// connection, and no branch leaks "server"/"gateway"/parse vocabulary.
FailureCopy failureCopy(AppLocalizations l10n, AppFailure failure) {
  switch (failure) {
    case NetworkFailure():
      return (
        title: l10n.errorNetworkTitle,
        body: l10n.errorNetworkBody,
        action: l10n.actionRetry,
        retryable: true,
      );
    case TimeoutFailure():
      return (
        title: l10n.errorTimeoutTitle,
        body: l10n.errorTimeoutBody,
        action: l10n.actionRetry,
        retryable: true,
      );
    case ServerFailure(:final bool unavailable, :final Duration? retryAfter):
      return (
        title: l10n.errorServerTitle,
        body: unavailable
            ? _retryIn(l10n, retryAfter) ?? l10n.errorServiceUnavailableBody
            : l10n.errorServerBody,
        action: l10n.actionRetry,
        retryable: true,
      );
    case UnauthorizedFailure(:final bool recovering):
      return recovering
          ? (
              title: l10n.errorGenericTitle,
              body: l10n.errorReconnectingBody,
              action: l10n.actionRetry,
              retryable: true,
            )
          : (
              title: l10n.errorSessionExpiredTitle,
              body: l10n.errorSessionExpiredBody,
              action: l10n.actionSignIn,
              retryable: false,
            );
    case ForbiddenFailure():
      return (
        title: l10n.errorForbiddenTitle,
        body: l10n.errorForbiddenBody,
        action: l10n.actionBack,
        retryable: false,
      );
    case NotFoundFailure():
      return (
        title: l10n.errorNotFoundTitle,
        body: l10n.errorNotFoundBody,
        action: l10n.actionBack,
        retryable: false,
      );
    case ConflictFailure():
      return (
        title: l10n.errorGenericTitle,
        body: l10n.errorConflictBody,
        action: l10n.actionRetry,
        retryable: true,
      );
    case GoneFailure():
      return (
        title: l10n.errorNotFoundTitle,
        body: l10n.errorGoneBody,
        action: l10n.actionBack,
        retryable: false,
      );
    case ValidationFailure():
      return (
        title: l10n.errorGenericTitle,
        body: l10n.errorValidationBody,
        action: l10n.actionRetry,
        retryable: true,
      );
    case RateLimitedFailure(:final Duration? retryAfter):
      return (
        title: l10n.errorRateLimitedTitle,
        body: _retryIn(l10n, retryAfter) ?? l10n.errorRateLimitedBody,
        action: l10n.actionRetry,
        retryable: true,
      );
    case UnknownFailure():
      return (
        title: l10n.errorGenericTitle,
        body: l10n.errorGenericBody,
        action: l10n.actionRetry,
        retryable: true,
      );
  }
}

/// The countdown line, or null when there is no usable window: past a minute a
/// literal "in 180 seconds" reads worse than the vague copy it replaces.
String? _retryIn(AppLocalizations l10n, Duration? retryAfter) {
  if (retryAfter == null) return null;
  final int seconds = retryAfter.inSeconds;
  if (seconds < 0 || seconds > 60) return null;
  return l10n.errorRateLimitedRetryIn(seconds);
}
