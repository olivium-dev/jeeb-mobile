import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/dispute_status_repository.dart';
import 'dispute_status_state.dart';

/// Drives dispute-status (JM-065). Imports `domain/` only
/// (40_GUARDRAILS_ARCH §2.2); the abstract [DisputeStatusRepository] is
/// constructor-injected (the screen resolves the LIVE
/// `DioDisputeStatusRepository` from `sl<DisputeStatusRepository>()`; the
/// compliment-service GET-by-id is mock-ready on :4010 — 42_GUARDRAILS_MOCK §4).
///
/// Responsibilities:
///  - cold-load the dispute by id,
///  - re-fetch on retry without flipping to a full-screen spinner replay loop,
///  - surface a typed failure (network / not-found / auth / unknown) so the
///    screen renders the D30 error state with a Retry.
class DisputeStatusCubit extends Cubit<DisputeStatusState> {
  DisputeStatusCubit({
    required DisputeStatusRepository repository,
    required this.disputeId,
  })  : _repository = repository,
        super(const DisputeStatusState());

  final DisputeStatusRepository _repository;

  /// The dispute id from the `/disputes/:id` path param.
  final String disputeId;

  /// Cold-entry load. Guards re-entry so a remount doesn't refetch (§2.2). A
  /// blank id is a deterministic not-found rather than a wasted round-trip.
  Future<void> load() async {
    if (state.status != DisputeStatusViewStatus.initial) return;
    if (disputeId.trim().isEmpty) {
      emit(state.copyWith(
        status: DisputeStatusViewStatus.failed,
        error: DisputeStatusFailure.notFound,
      ));
      return;
    }
    emit(state.copyWith(
      status: DisputeStatusViewStatus.loading,
      clearError: true,
    ));
    await _fetch();
  }

  /// Retry / pull-to-refresh. Re-issues the fetch; on a cold failure it returns
  /// to `loading` (there is nothing on screen to keep), otherwise it refreshes
  /// in place.
  Future<void> refresh() async {
    if (disputeId.trim().isEmpty) return;
    if (state.status == DisputeStatusViewStatus.failed) {
      emit(state.copyWith(
        status: DisputeStatusViewStatus.loading,
        clearError: true,
      ));
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final dispute = await _repository.fetchDispute(disputeId);
      emit(state.copyWith(
        status: DisputeStatusViewStatus.loaded,
        dispute: dispute,
        clearError: true,
      ));
    } on DisputeStatusRepositoryException catch (e) {
      emit(state.copyWith(
        status: DisputeStatusViewStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: DisputeStatusViewStatus.failed,
        error: DisputeStatusFailure.unknown,
      ));
    }
  }
}
