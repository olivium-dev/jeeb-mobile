import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/support_repository.dart';
import 'support_state.dart';

/// Drives the support-ticket / contact-us form (JM-063).
///
/// Reads/writes the form fields (`support_category` / `support_body` /
/// `support_attach` / `support_order_link`) and submits a [SupportTicketDraft]
/// through the abstract [SupportRepository] (DI-bound to the S1 Dio impl, or the
/// INTEGRATOR-STUB until S1's `/v1/support` rewrite key lands — CTO-D2). On
/// success it emits [SupportPhase.success] so the screen shows the confirmation
/// before routing to customer-profile (D76).
class SupportCubit extends Cubit<SupportState> {
  SupportCubit(this._repository, {String? initialOrderRef})
      : super(SupportState(orderRef: initialOrderRef));

  final SupportRepository _repository;

  void setCategory(SupportCategory category) {
    emit(state.copyWith(category: category, clearFailure: true));
  }

  void setBody(String body) {
    emit(state.copyWith(body: body, clearFailure: true));
  }

  void setOrderRef(String? orderRef) {
    final trimmed = orderRef?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      emit(state.copyWith(clearOrderRef: true));
    } else {
      emit(state.copyWith(orderRef: trimmed));
    }
  }

  void addAttachment(String path) {
    if (!state.canAttach) return;
    emit(
      state.copyWith(
        attachmentPaths: <String>[...state.attachmentPaths, path],
      ),
    );
  }

  void removeAttachment(String path) {
    final updated = List<String>.from(state.attachmentPaths)..remove(path);
    emit(state.copyWith(attachmentPaths: updated));
  }

  Future<void> submit() async {
    if (!state.canSubmit || state.phase == SupportPhase.submitting) return;
    emit(state.copyWith(phase: SupportPhase.submitting, clearFailure: true));
    try {
      final ticket = await _repository.submitTicket(
        SupportTicketDraft(
          category: state.category!,
          body: state.body.trim(),
          orderRef: state.orderRef,
          attachmentPaths: state.attachmentPaths,
        ),
      );
      emit(state.copyWith(phase: SupportPhase.success, ticketId: ticket.id));
    } on SupportRepositoryException catch (e) {
      emit(state.copyWith(phase: SupportPhase.error, failure: e.failure));
    } catch (_) {
      emit(
        state.copyWith(
          phase: SupportPhase.error,
          failure: SupportFailure.unknown,
        ),
      );
    }
  }

  /// Return from the error state to the form so the user can retry
  /// (`support_retry_cta`).
  void retryFromError() {
    emit(state.copyWith(phase: SupportPhase.inputting, clearFailure: true));
  }
}
