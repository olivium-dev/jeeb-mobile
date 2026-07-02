import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/offer_submission_repository.dart';

/// View-mode for the offer-submission form.
enum OfferFormMode {
  idle,
  submitting,
  success,
  requestGone,

  /// 402 (O1): the wallet can't cover the 10% reserve. The view surfaces the
  /// JM-046 `insufficient_balance_sheet` (NOT an error snack). The draft is
  /// preserved so "keep editing" returns the user to the filled composer.
  insufficientBalance,
  error,
}

/// State emitted by [OfferFormCubit].
class OfferFormState extends Equatable {
  const OfferFormState({
    this.mode = OfferFormMode.idle,
    this.priceError,
    this.etaError,
    this.conversationId,
    this.errorMessage,
    this.insufficientBalance,
  });

  final OfferFormMode mode;

  /// Inline price validation error (non-null when price ≤ 0).
  final String? priceError;

  /// Inline ETA validation error (non-null when ETA ≤ 0).
  final String? etaError;

  /// Set on [OfferFormMode.success] — used by the router to open chat.
  final String? conversationId;

  /// Set on [OfferFormMode.error] — displayed as a snack.
  final String? errorMessage;

  /// Set on [OfferFormMode.insufficientBalance] — the parsed 402
  /// `{needed, available, currency}` (O1) the JM-046 sheet renders.
  final InsufficientBalanceInfo? insufficientBalance;

  bool get isSubmitting => mode == OfferFormMode.submitting;

  OfferFormState copyWith({
    OfferFormMode? mode,
    String? priceError,
    bool clearPriceError = false,
    String? etaError,
    bool clearEtaError = false,
    String? conversationId,
    String? errorMessage,
    bool clearError = false,
    InsufficientBalanceInfo? insufficientBalance,
    bool clearInsufficientBalance = false,
  }) {
    return OfferFormState(
      mode: mode ?? this.mode,
      priceError: clearPriceError ? null : (priceError ?? this.priceError),
      etaError: clearEtaError ? null : (etaError ?? this.etaError),
      conversationId: conversationId ?? this.conversationId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      insufficientBalance: clearInsufficientBalance
          ? null
          : (insufficientBalance ?? this.insufficientBalance),
    );
  }

  @override
  List<Object?> get props => [
        mode,
        priceError,
        etaError,
        conversationId,
        errorMessage,
        insufficientBalance,
      ];
}

/// Cubit driving the Jeeber offer-submission form (T-MOB-030).
///
/// Validates client-side (price > 0, ETA > 0) then delegates to
/// [OfferSubmissionRepository]. On 200 emits [OfferFormMode.success] with
/// the [conversationId]; on 409 emits [OfferFormMode.requestGone] so the
/// view can send the user back to the feed.
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
    if (price == null || price <= 0) return 'Price must be greater than 0';
    return null;
  }

  String? _validateEta(int? eta) {
    if (eta == null || eta <= 0) return 'ETA must be greater than 0';
    return null;
  }

  void _handleError(OfferSubmissionException e) {
    if (e.failure == OfferSubmissionFailure.requestGone) {
      emit(state.copyWith(mode: OfferFormMode.requestGone));
      return;
    }
    // 402 (O1, JM-046): surface the insufficient-balance sheet, not an error
    // snack. The draft is untouched (price/eta/note live in the view's
    // controllers) so "keep editing" returns to the filled composer. Always set
    // the payload for THIS 402 — when the gateway omits a body (`e.balance ==
    // null`) explicitly clear it so the sheet never shows a prior 402's figures
    // (the composer then falls back to the computed reserve / wallet snapshot).
    if (e.failure == OfferSubmissionFailure.insufficientBalance) {
      emit(state.copyWith(
        mode: OfferFormMode.insufficientBalance,
        insufficientBalance: e.balance,
        clearInsufficientBalance: e.balance == null,
      ));
      return;
    }
    final msg = e.failure == OfferSubmissionFailure.network
        ? 'No internet connection'
        : 'Unable to submit offer. Please try again.';
    emit(state.copyWith(mode: OfferFormMode.error, errorMessage: msg));
  }

  void _logSubmitted(String requestId, double price, int eta) {
    // Domain event: offer submitted (no PII — ids + amount only).
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

  /// JM-046 "keep editing": dismiss the insufficient-balance sheet and return to
  /// the idle composer with the draft intact (the controllers hold the values).
  /// Idempotent — a no-op unless currently showing the sheet.
  void acknowledgeInsufficientBalance() {
    if (state.mode == OfferFormMode.insufficientBalance) {
      emit(state.copyWith(
        mode: OfferFormMode.idle,
        clearInsufficientBalance: true,
      ));
    }
  }
}
