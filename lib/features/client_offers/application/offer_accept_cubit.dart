import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/offers_repository.dart';
import 'offer_accept_state.dart';

class OfferAcceptCubit extends Cubit<OfferAcceptState> {
  OfferAcceptCubit({
    required OffersRepository repository,
    required String requestId,
    required String offerId,
    OfferAcceptState? initialState,
  })  : _repository = repository,
        _requestId = requestId,
        _offerId = offerId,
        super(initialState ?? const OfferAcceptState());

  final OffersRepository _repository;
  final String _requestId;
  final String _offerId;

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
      if (isClosed) return;
      emit(state.copyWith(
        status: OfferAcceptStatus.succeeded,
        result: result,
      ));
      Diag.event('offer_accept_result', <String, Object?>{
        'offerId': _offerId,
        'status': 'succeeded',
      });
    } on OffersRepositoryException catch (e) {
      if (isClosed) return;
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
      if (isClosed) return;
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
