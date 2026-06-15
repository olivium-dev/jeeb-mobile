import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/request_draft.dart';
import '../domain/request_submission_service.dart';

class RequestSummaryState {
  const RequestSummaryState({
    this.draft,
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.requestId,
    this.error,
  });

  final RequestDraft? draft;
  final bool isSubmitting;
  final bool isSubmitted;

  /// Server-minted id of the created request, set once [isSubmitted] is true.
  final String? requestId;

  /// User-facing failure message, set when a submit attempt fails.
  final String? error;
}

class RequestSummaryCubit extends Cubit<RequestSummaryState> {
  RequestSummaryCubit(this._service) : super(const RequestSummaryState());

  final RequestSubmissionService _service;

  void setDraft(RequestDraft draft) => emit(RequestSummaryState(draft: draft));

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
    } on RequestSubmissionException catch (e) {
      if (isClosed) return;
      emit(RequestSummaryState(draft: draft, error: _messageFor(e.failure)));
    }
  }

  String _messageFor(RequestSubmissionFailure failure) {
    switch (failure) {
      case RequestSubmissionFailure.network:
        return 'No connection. Check your network and try again.';
      case RequestSubmissionFailure.invalidInput:
        return 'We could not submit this request. Please review and retry.';
      case RequestSubmissionFailure.server:
        return 'Something went wrong. Please try again.';
    }
  }
}
