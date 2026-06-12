import 'package:flutter_bloc/flutter_bloc.dart';

class OfferSubmissionState {

  const OfferSubmissionState({this.price, this.estimatedMinutes, this.isSubmitting = false, this.isSubmitted = false, this.error});
  final double? price;
  final int? estimatedMinutes;
  final bool isSubmitting;
  final bool isSubmitted;
  final String? error;
}

class OfferSubmissionCubit extends Cubit<OfferSubmissionState> {
  OfferSubmissionCubit() : super(const OfferSubmissionState());

  void setPrice(double price) => emit(OfferSubmissionState(price: price, estimatedMinutes: state.estimatedMinutes));
  void setEstimatedMinutes(int minutes) => emit(OfferSubmissionState(price: state.price, estimatedMinutes: minutes));

  Future<void> submit(String requestId) async {
    if (state.price == null || state.price! <= 0) {
      emit(OfferSubmissionState(price: state.price, estimatedMinutes: state.estimatedMinutes, error: 'Price is required'));
      return;
    }
    emit(OfferSubmissionState(price: state.price, estimatedMinutes: state.estimatedMinutes, isSubmitting: true));
    await Future.delayed(const Duration(seconds: 1));
    emit(OfferSubmissionState(price: state.price, estimatedMinutes: state.estimatedMinutes, isSubmitted: true));
  }
}
