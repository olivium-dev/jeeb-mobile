import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/request_draft.dart';

class RequestSummaryState {

  const RequestSummaryState({this.draft, this.isSubmitting = false, this.isSubmitted = false, this.error});
  final RequestDraft? draft;
  final bool isSubmitting;
  final bool isSubmitted;
  final String? error;
}

class RequestSummaryCubit extends Cubit<RequestSummaryState> {
  RequestSummaryCubit() : super(const RequestSummaryState());

  void setDraft(RequestDraft draft) => emit(RequestSummaryState(draft: draft));

  Future<void> submit() async {
    emit(RequestSummaryState(draft: state.draft, isSubmitting: true));
    await Future.delayed(const Duration(seconds: 1));
    emit(RequestSummaryState(draft: state.draft, isSubmitted: true));
  }
}
