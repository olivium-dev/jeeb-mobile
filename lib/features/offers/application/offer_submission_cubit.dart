import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/offer_submission_repository.dart';

enum OfferFormMode {
  idle,
  submitting,
  success,
  requestGone,

  insufficientBalance,
  error,
}

class OfferFormState extends Equatable {
  const OfferFormState({
    this.mode = OfferFormMode.idle,
    this.priceError,
    this.etaError,
    this.conversationId,
    this.errorMessage,
    this.errorReason,
    this.insufficientBalance,
    this.capInfo,
  });

  final OfferFormMode mode;

  final String? priceError;

  final String? etaError;

  final String? conversationId;

  final String? errorMessage;

  final OfferSubmissionFailure? errorReason;

  final InsufficientBalanceInfo? insufficientBalance;

  /// E2 cap figures from the 409 body — the screen renders the server's own
  /// limit rather than a hardcoded one (CONTRACT §2 E2).
  final OfferCapInfo? capInfo;

  /// Reason code for [priceError]. The application layer has no `BuildContext`,
  /// so it names the reason and the screen resolves the localized sentence.
  static const String priceErrorRequired = 'price-required';

  /// Reason code for [etaError].
  static const String etaErrorRequired = 'eta-required';

  bool get isSubmitting => mode == OfferFormMode.submitting;

  OfferFormState copyWith({
    OfferFormMode? mode,
    String? priceError,
    bool clearPriceError = false,
    String? etaError,
    bool clearEtaError = false,
    String? conversationId,
    String? errorMessage,
    OfferSubmissionFailure? errorReason,
    bool clearError = false,
    InsufficientBalanceInfo? insufficientBalance,
    bool clearInsufficientBalance = false,
    OfferCapInfo? capInfo,
  }) {
    return OfferFormState(
      mode: mode ?? this.mode,
      priceError: clearPriceError ? null : (priceError ?? this.priceError),
      etaError: clearEtaError ? null : (etaError ?? this.etaError),
      conversationId: conversationId ?? this.conversationId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorReason: clearError ? null : (errorReason ?? this.errorReason),
      insufficientBalance: clearInsufficientBalance
          ? null
          : (insufficientBalance ?? this.insufficientBalance),
      capInfo: clearError ? null : (capInfo ?? this.capInfo),
    );
  }

  @override
  List<Object?> get props => [
        mode,
        priceError,
        etaError,
        conversationId,
        errorMessage,
        errorReason,
        insufficientBalance,
        capInfo,
      ];
}

class OfferFormCubit extends Cubit<OfferFormState> {
  OfferFormCubit({required OfferSubmissionRepository repository})
      : _repository = repository,
        super(const OfferFormState());

  final OfferSubmissionRepository _repository;

  Future<void> submit({
    required String requestId,
    required double? priceUsd,
    required int? etaMinutes,
    String? note,
  }) async {
    final priceErr = _validatePrice(priceUsd);
    final etaErr = _validateEta(etaMinutes);
    if (priceErr != null || etaErr != null) {
      emit(state.copyWith(priceError: priceErr, etaError: etaErr));
      return;
    }

    emit(state.copyWith(
      mode: OfferFormMode.submitting,
      clearPriceError: true,
      clearEtaError: true,
      clearError: true,
    ));

    try {
      final result = await _repository.submitOffer(
        requestId: requestId,
        priceUsd: priceUsd!,
        etaMinutes: etaMinutes!,
        note: note,
      );
      _logSubmitted(requestId, priceUsd, etaMinutes);
      emit(state.copyWith(
        mode: OfferFormMode.success,
        conversationId: result.conversationId,
      ));
    } on OfferSubmissionException catch (e) {
      _handleError(e);
    }
  }

  String? _validatePrice(double? price) {
    if (price == null || price <= 0) return OfferFormState.priceErrorRequired;
    return null;
  }

  String? _validateEta(int? eta) {
    if (eta == null || eta <= 0) return OfferFormState.etaErrorRequired;
    return null;
  }

  void _handleError(OfferSubmissionException e) {
    if (e.failure == OfferSubmissionFailure.requestGone) {
      emit(state.copyWith(mode: OfferFormMode.requestGone));
      return;
    }
    if (e.failure == OfferSubmissionFailure.insufficientBalance) {
      emit(state.copyWith(
        mode: OfferFormMode.insufficientBalance,
        insufficientBalance: e.balance,
        clearInsufficientBalance: e.balance == null,
      ));
      return;
    }
    if (e.failure == OfferSubmissionFailure.offerCapReached) {
      // The cap sentence is localized off errorReason + the server's own limit
      // — never a hardcoded English literal (JEBV4-246).
      emit(state.copyWith(
        mode: OfferFormMode.error,
        errorReason: OfferSubmissionFailure.offerCapReached,
        capInfo: e.capInfo,
      ));
      return;
    }
    // holderUnresolved / feeUnresolvable / exposureUnresolvable land here too:
    // the screen resolves each E1–E5 reason to its own frozen copy.
    emit(state.copyWith(mode: OfferFormMode.error, errorReason: e.failure));
  }

  void _logSubmitted(String requestId, double price, int eta) {
    Diag.event('offer_submitted', <String, Object?>{
      'requestId': requestId,
      'priceUsd': price,
      'etaMinutes': eta,
    });
  }

  void acknowledgeError() {
    if (state.mode == OfferFormMode.error) {
      emit(state.copyWith(mode: OfferFormMode.idle, clearError: true));
    }
  }

  void acknowledgeInsufficientBalance() {
    if (state.mode == OfferFormMode.insufficientBalance) {
      emit(state.copyWith(
        mode: OfferFormMode.idle,
        clearInsufficientBalance: true,
      ));
    }
  }
}
