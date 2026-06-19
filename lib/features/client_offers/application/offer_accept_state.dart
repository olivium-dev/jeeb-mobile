import 'package:equatable/equatable.dart';

import '../domain/offers_repository.dart';

/// Lifecycle of the JM-029 accept-confirm action.
///
/// The accept-confirm sheet is a small confirm surface with a single async
/// operation (accept the chosen offer → capture the fee + close losing offers
/// server-side). It is its own 4-state machine per 40_GUARDRAILS_ARCH §2/§3,
/// independent of the offer-review list's `OffersScreenStatus`:
///   * [idle]       — sheet shown, awaiting the user's confirm tap.
///   * [submitting] — the accept call is in flight (confirm CTA shows a spinner;
///                    cancel stays available, confirm is debounced).
///   * [succeeded]  — accept landed; [OfferAcceptState.result] carries the
///                    server `conversationId`/`deliveryId` so the listener can
///                    navigate to `order-chat`.
///   * [failed]     — accept failed; [OfferAcceptState.error] drives inline copy
///                    and the user may retry confirm or cancel.
enum OfferAcceptStatus { idle, submitting, succeeded, failed }

/// State for [OfferAcceptCubit] (JM-029).
class OfferAcceptState extends Equatable {
  const OfferAcceptState({
    this.status = OfferAcceptStatus.idle,
    this.result,
    this.error,
  });

  final OfferAcceptStatus status;

  /// The accept outcome (conversation/delivery ids) — set only on
  /// [OfferAcceptStatus.succeeded].
  final OfferAcceptResult? result;

  /// Typed failure from the last accept attempt — set only on
  /// [OfferAcceptStatus.failed].
  final OffersFailure? error;

  bool get isSubmitting => status == OfferAcceptStatus.submitting;

  OfferAcceptState copyWith({
    OfferAcceptStatus? status,
    OfferAcceptResult? result,
    bool clearResult = false,
    OffersFailure? error,
    bool clearError = false,
  }) {
    return OfferAcceptState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, result, error];
}
