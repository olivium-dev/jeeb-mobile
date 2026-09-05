import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission_service.dart';

class RequestSummaryState {
  const RequestSummaryState({
    this.draft,
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.requestId,
    this.error,
    this.moderationMatches = const <String>[],
    this.moderationBlocked = false,
    this.fieldErrors = const <String, List<String>>{},
  });

  final RequestDraft? draft;
  final bool isSubmitting;
  final bool isSubmitted;

  final String? requestId;

  /// The classified submit failure. Copy comes from `failureCopy`, never here.
  final AppFailure? error;

  /// Prohibited keywords the gateway flagged on a 409 requires-ack.
  final List<String> moderationMatches;

  /// True for `prohibited-item-blocked`: terminal, no acknowledgement helps.
  final bool moderationBlocked;

  /// `ValidationFailure.fieldErrors`, bound onto the offending inputs.
  final Map<String, List<String>> fieldErrors;

  RequestSummaryState copyWith({
    RequestDraft? draft,
    bool? isSubmitting,
    bool? isSubmitted,
    String? requestId,
    AppFailure? error,
    bool clearError = false,
    List<String>? moderationMatches,
    bool? moderationBlocked,
    Map<String, List<String>>? fieldErrors,
  }) =>
      RequestSummaryState(
        draft: draft ?? this.draft,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        requestId: requestId ?? this.requestId,
        error: clearError ? null : (error ?? this.error),
        moderationMatches: moderationMatches ?? this.moderationMatches,
        moderationBlocked: moderationBlocked ?? this.moderationBlocked,
        fieldErrors: fieldErrors ?? this.fieldErrors,
      );
}

class RequestSummaryCubit extends Cubit<RequestSummaryState> {
  RequestSummaryCubit(
    this._service, {
    OperationIdFactory operationIdFactory = newOperationId,
  })  : _newOperationId = operationIdFactory,
        super(const RequestSummaryState());

  final RequestSubmissionService _service;

  final OperationIdFactory _newOperationId;

  /// Mints the Idempotency-Key when the caller supplied none, so every retry
  /// and the moderation resubmit share one key instead of posting unkeyed.
  void setDraft(RequestDraft draft) => emit(RequestSummaryState(
        draft: draft.operationId == null
            ? draft.copyWith(operationId: _newOperationId())
            : draft,
      ));

  /// Clears the transient failure once a snack has rendered it.
  void acknowledgeError() =>
      emit(state.copyWith(clearError: true, fieldErrors: const {}));

  /// Drops the moderation prompt after the sheet resolves either way.
  void acknowledgeModeration() => emit(
        state.copyWith(
          moderationMatches: const <String>[],
          moderationBlocked: false,
          clearError: true,
        ),
      );

  Future<void> submit() async {
    final draft = state.draft;
    if (draft == null || state.isSubmitting) return;
    emit(RequestSummaryState(draft: draft, isSubmitting: true));
    try {
      final requestId = await _service.submit(draft);
      if (isClosed) return;
      emit(RequestSummaryState(
        draft: draft,
        isSubmitted: true,
        requestId: requestId,
      ));
    } on RequestModerationRequired catch (e) {
      if (isClosed) return;
      emit(RequestSummaryState(
        draft: draft,
        error: e.appFailure ?? const ConflictFailure(),
        moderationMatches: e.matches,
        moderationBlocked: e.blocked,
      ));
    } on RequestSubmissionException catch (e) {
      if (isClosed) return;
      final AppFailure failure = e.appFailure ?? _fallbackFor(e.failure);
      emit(RequestSummaryState(
        draft: draft,
        error: failure,
        fieldErrors: failure is ValidationFailure
            ? failure.fieldErrors
            : const <String, List<String>>{},
      ));
    } catch (e) {
      if (isClosed) return;
      emit(RequestSummaryState(draft: draft, error: AppFailure.of(e)));
    }
  }

  /// Only for a legacy exception raised without a classified failure.
  AppFailure _fallbackFor(RequestSubmissionFailure failure) => switch (failure) {
        RequestSubmissionFailure.network => const NetworkFailure(),
        RequestSubmissionFailure.unauthorized => const UnauthorizedFailure(),
        RequestSubmissionFailure.invalidInput => const ValidationFailure(),
        RequestSubmissionFailure.server => const ServerFailure(status: 500),
      };
}
