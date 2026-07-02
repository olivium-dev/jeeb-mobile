import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/offers_repository.dart';
import 'offer_accept_state.dart';

/// Drives the JM-029 accept-confirm sheet.
///
/// The sheet is the D11/D71 comprehension gate: confirming an offer is a
/// consequential, irreversible action (it captures the fee and closes every
/// losing offer), so it is fronted by an explicit confirm step rather than
/// firing inline from the offer card. This cubit owns the single async
/// operation — `POST /v1/offers/:offerId/accept` via [OffersRepository] — and
/// maps the typed [OffersRepositoryException] to a [OffersFailure] the sheet
/// renders as inline copy. The sheet's `listener` reads
/// [OfferAcceptState.result] on success and navigates to `order-chat`.
class OfferAcceptCubit extends Cubit<OfferAcceptState> {
  OfferAcceptCubit({
    required OffersRepository repository,
    required String requestId,
    required String offerId,
  })  : _repository = repository,
        _requestId = requestId,
        _offerId = offerId,
        super(const OfferAcceptState());

  final OffersRepository _repository;
  final String _requestId;
  final String _offerId;

  /// Confirms the offer. Guards re-entry while a call is in flight so a
  /// double-tap on the confirm CTA cannot fire two accepts. On success the
  /// state carries the [OfferAcceptResult] (conversation/delivery ids) for the
  /// listener to navigate on; on failure it carries a typed [OffersFailure].
  Future<void> confirm() async {
    if (state.status == OfferAcceptStatus.submitting) return;
    emit(state.copyWith(
      status: OfferAcceptStatus.submitting,
      clearError: true,
    ));
    try {
      final result = await _repository.acceptOffer(
        requestId: _requestId,
        offerId: _offerId,
      );
      emit(state.copyWith(
        status: OfferAcceptStatus.succeeded,
        result: result,
      ));
      Diag.event('offer_accept_result', <String, Object?>{
        'offerId': _offerId,
        'status': 'succeeded',
      });
    } on OffersRepositoryException catch (e) {
      emit(state.copyWith(
        status: OfferAcceptStatus.failed,
        error: e.failure,
      ));
      Diag.event('offer_accept_result', <String, Object?>{
        'offerId': _offerId,
        'status': 'failed',
        'failure': e.failure.name,
      });
    } catch (_) {
      emit(state.copyWith(
        status: OfferAcceptStatus.failed,
        error: OffersFailure.unknown,
      ));
      Diag.event('offer_accept_result', <String, Object?>{
        'offerId': _offerId,
        'status': 'failed',
        'failure': OffersFailure.unknown.name,
      });
    }
  }
}
