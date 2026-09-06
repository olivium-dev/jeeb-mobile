import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/state/guarded.dart';
import '../domain/offer_submission_repository.dart';

enum OfferFormMode {
  idle,
  submitting,
  success,
  requestGone,

  insufficientBalance,

  /// 409 `offer-already-exists` — a live bid already stands (AE-05).
  duplicate,
  error,
}

class OfferFormState extends Equatable {
  const OfferFormState({
    this.mode = OfferFormMode.idle,
    this.priceError,
    this.etaError,
    this.noteError,
    this.conversationId,
    this.failure,
    this.errorReason,
    this.insufficientBalance,
  });

  final OfferFormMode mode;

  final String? priceError;

  final String? etaError;

  final String? noteError;

  final String? conversationId;

  /// The classified transport failure behind [errorReason]; the screen resolves
  /// its copy from `failureCopy` when no feature-specific line applies.
  final AppFailure? failure;

  final OfferSubmissionFailure? errorReason;

  final InsufficientBalanceInfo? insufficientBalance;

  /// Reason code for [priceError]. The application layer has no `BuildContext`,
  /// so it names the reason and the screen resolves the localized sentence.
  static const String priceErrorRequired = 'price-required';

  /// Reason code for [etaError].
  static const String etaErrorRequired = 'eta-required';

  /// Reason code for a server-rejected price (400 `offer-fee-too-low`).
  static const String priceErrorTooLow = 'price-too-low';

  /// Reason code for a server-rejected ETA (400 `offer-eta-invalid`).
  static const String etaErrorInvalid = 'eta-invalid';

  /// Reason code for a server-rejected note (400 `offer-note-too-long`).
  static const String noteErrorTooLong = 'note-too-long';

  bool get isSubmitting => mode == OfferFormMode.submitting;

  OfferFormState copyWith({
    OfferFormMode? mode,
    String? priceError,
    bool clearPriceError = false,
    String? etaError,
    bool clearEtaError = false,
    String? noteError,
    bool clearNoteError = false,
    String? conversationId,
    AppFailure? failure,
    OfferSubmissionFailure? errorReason,
    bool clearError = false,
    InsufficientBalanceInfo? insufficientBalance,
    bool clearInsufficientBalance = false,
  }) {
    return OfferFormState(
      mode: mode ?? this.mode,
      priceError: clearPriceError ? null : (priceError ?? this.priceError),
      etaError: clearEtaError ? null : (etaError ?? this.etaError),
      noteError: clearNoteError ? null : (noteError ?? this.noteError),
      conversationId: conversationId ?? this.conversationId,
      failure: clearError ? null : (failure ?? this.failure),
      errorReason: clearError ? null : (errorReason ?? this.errorReason),
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
    noteError,
    conversationId,
    failure,
    errorReason,
    insufficientBalance,
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
    String? idempotencyKey,
  }) async {
    // A double-tap on the docked CTA would otherwise post the offer twice.
    if (state.isSubmitting ||
        state.mode == OfferFormMode.requestGone ||
        state.errorReason == OfferSubmissionFailure.sameRoleViolation) {
      return;
    }

    final priceErr = _validatePrice(priceUsd);
    final etaErr = _validateEta(etaMinutes);
    if (priceErr != null || etaErr != null) {
      emit(state.copyWith(priceError: priceErr, etaError: etaErr));
      return;
    }

    emit(
      state.copyWith(
        mode: OfferFormMode.submitting,
        clearPriceError: true,
        clearEtaError: true,
        clearNoteError: true,
        clearError: true,
      ),
    );

    await guarded(
      () async {
        try {
          final result = await _submitOffer(
            requestId: requestId,
            priceUsd: priceUsd!,
            etaMinutes: etaMinutes!,
            note: note,
            idempotencyKey: idempotencyKey,
          );
          _logSubmitted(requestId, priceUsd, etaMinutes);
          emit(
            state.copyWith(
              mode: OfferFormMode.success,
              conversationId: result.conversationId,
            ),
          );
        } on OfferSubmissionException catch (e) {
          _handleError(e);
        }
      },
      (failure) => _handleError(
        OfferSubmissionException(OfferSubmissionFailure.server, cause: failure),
      ),
    );
  }

  Future<OfferSubmissionResult> _submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    required String? note,
    required String? idempotencyKey,
  }) {
    final repo = _repository;
    if (idempotencyKey != null && repo is IdempotentOfferSubmission) {
      return (repo as IdempotentOfferSubmission).submitOfferIdempotent(
        requestId: requestId,
        priceUsd: priceUsd,
        etaMinutes: etaMinutes,
        idempotencyKey: idempotencyKey,
        note: note,
      );
    }
    return repo.submitOffer(
      requestId: requestId,
      priceUsd: priceUsd,
      etaMinutes: etaMinutes,
      note: note,
    );
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
    switch (e.failure) {
      case OfferSubmissionFailure.requestGone:
      case OfferSubmissionFailure.requestNotOpen:
        emit(
          state.copyWith(
            mode: OfferFormMode.requestGone,
            errorReason: e.failure,
            failure: e.cause,
          ),
        );
      case OfferSubmissionFailure.insufficientBalance:
        emit(
          state.copyWith(
            mode: OfferFormMode.insufficientBalance,
            insufficientBalance: e.balance,
            clearInsufficientBalance: e.balance == null,
          ),
        );
      case OfferSubmissionFailure.duplicateOffer:
        emit(
          state.copyWith(
            mode: OfferFormMode.duplicate,
            errorReason: e.failure,
            failure: e.cause,
          ),
        );
      // A field-shaped rejection lands on the field slot, never on the note
      // rung: "no connection" must never read as "your number is wrong".
      case OfferSubmissionFailure.feeTooLow:
        emit(
          state.copyWith(
            mode: OfferFormMode.error,
            errorReason: e.failure,
            failure: e.cause,
            priceError: OfferFormState.priceErrorTooLow,
          ),
        );
      case OfferSubmissionFailure.etaInvalid:
        emit(
          state.copyWith(
            mode: OfferFormMode.error,
            errorReason: e.failure,
            failure: e.cause,
            etaError: OfferFormState.etaErrorInvalid,
          ),
        );
      case OfferSubmissionFailure.noteTooLong:
        emit(
          state.copyWith(
            mode: OfferFormMode.error,
            errorReason: e.failure,
            failure: e.cause,
            noteError: OfferFormState.noteErrorTooLong,
          ),
        );
      case OfferSubmissionFailure.invalidInput:
      case OfferSubmissionFailure.outOfRange:
      case OfferSubmissionFailure.sameRoleViolation:
      case OfferSubmissionFailure.network:
      case OfferSubmissionFailure.server:
        emit(
          state.copyWith(
            mode: OfferFormMode.error,
            errorReason: e.failure,
            failure: e.cause,
          ),
        );
    }
  }

  void _logSubmitted(String requestId, double price, int eta) {
    Diag.event('offer_submitted', <String, Object?>{
      'requestId': requestId,
      'priceUsd': price,
      'etaMinutes': eta,
    });
  }

  void acknowledgeError() {
    // Changing a draft cannot change ownership of the addressed request.
    // Keep this refusal latched until the request-scoped composer is closed.
    if (state.errorReason == OfferSubmissionFailure.sameRoleViolation) return;
    if (state.mode == OfferFormMode.error ||
        state.mode == OfferFormMode.duplicate) {
      emit(
        state.copyWith(
          mode: OfferFormMode.idle,
          clearError: true,
          clearPriceError: true,
          clearEtaError: true,
          clearNoteError: true,
        ),
      );
    }
  }

  void acknowledgeInsufficientBalance() {
    if (state.mode == OfferFormMode.insufficientBalance) {
      emit(
        state.copyWith(
          mode: OfferFormMode.idle,
          clearInsufficientBalance: true,
        ),
      );
    }
  }
}
