import 'package:equatable/equatable.dart';

import '../../kyc/domain/kyc_submission.dart';

/// Loading lifecycle for the offer KYC gate's live-status read (JM-044).
///
/// The gate ALWAYS renders its three exits + the top-up note regardless of this
/// phase (the D38 invariant is enforced by the JM-048 feed call site routing an
/// unapproved jeeber here in the first place). The phase only governs the small,
/// optional status line: while [loading] / on [error] we simply omit it rather
/// than block the gate, so the CTAs are never gated behind a network round-trip.
enum OfferKycGatePhase { loading, ready, error }

/// State for [OfferKycGateCubit]. Carries the live KYC status read from
/// `GET /v1/kyc/status` (mock-rewritten to `/user-management/v1/kyc`) so the
/// gate can surface the current decision (pending / rejected) using the
/// existing `kycStatus*` copy — without adding any new l10n keys.
class OfferKycGateState extends Equatable {
  const OfferKycGateState({
    this.phase = OfferKycGatePhase.loading,
    this.status = KycStatus.notSubmitted,
  });

  final OfferKycGatePhase phase;

  /// The live decision. `notSubmitted` / `none` shows no extra status line
  /// (the headline + body already say "get approved to start sending offers").
  final KycStatus status;

  bool get isApproved => status == KycStatus.approved;
  bool get isPending => status == KycStatus.pending;
  bool get isRejected => status == KycStatus.rejected;

  OfferKycGateState copyWith({
    OfferKycGatePhase? phase,
    KycStatus? status,
  }) {
    return OfferKycGateState(
      phase: phase ?? this.phase,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [phase, status];
}
