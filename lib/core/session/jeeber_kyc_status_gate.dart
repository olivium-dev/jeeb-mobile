import 'package:flutter/foundation.dart';

import '../dev_seam/dev_seam.dart';
import '../dev_seam/dev_seam_config.dart';

/// The narrow view of jeeber KYC status the DELIVERY-tab gate (JM-036) and the
/// offer gate (JM-044) need to decide register-prompt-vs-feed and
/// gate-vs-composer. Kept as a tiny interface (not a full cubit) for the same
/// reasons as [AccountStatusGate] / [SessionGate]:
///   * the gate consumers depend only on a small enum, not on bloc internals;
///   * tests + the Maestro seam can inject a scripted status without a network
///     round-trip;
///   * a production-safe default ([SeamJeeberKycStatusGate]) keeps the existing
///     `jeeber_logged_in` flows reaching the feed until the real getMe-backed
///     source is wired by the JM-036 engineer.
///
/// W2-INT lands ONLY this interface + the seam-backed default + the DELIVERY-tab
/// switch (`shell/tabs/dashboard_tab.dart`). The REAL gate — which reads
/// role-level `kycStatus` from `GET /user-management/users/:userId/kyc` (or
/// getMe `kycStatus`, U1; NOT `/users/me`'s authStub-resolved identity) and
/// classifies `none|pending|approved|rejected` (D38/D52) — is the JM-036
/// engineer's to write. It swaps [SeamJeeberKycStatusGate] in DI without
/// touching the tab body (it depends on this interface, not the impl).
enum JeeberKycStatus { none, pending, approved, rejected }

/// What the DELIVERY tab body should render for a given KYC status (JM-036,
/// reconciled with D38). D38 gates **offering**, not feed-browsing: a jeeber who
/// has REGISTERED (onboarding complete / KYC submitted = `pending`) browses the
/// feed exactly like an approved jeeber; only the *make-offer* CTA is gated
/// (it routes through `offer_kyc_gate` until approval — JM-044/048). So the
/// DELIVERY tab maps:
///   * `none`     → [registerPrompt] (never onboarded — `delivery_register_prompt`).
///   * `pending`  → [feed]          (registered, browsing; offering gated).
///   * `approved` → [feed]          (registered, browsing; offering allowed).
///   * `rejected` → [kycRejected]   (terminal — the `kyc-rejected` screen, D52/D87).
///
/// This is the fix for the W2-closer finding that the old `!isApproved`
/// collapse routed a `pending` jeeber to `delivery_register_prompt`, which left
/// `feed_make_offer_cta` (and therefore the JM-044 offer-KYC gate) unreachable.
enum JeeberDeliveryTabDestination {
  registerPrompt,
  feed,
  kycRejected;

  /// The DELIVERY-tab body the gate resolves for [status] (JM-036, D38).
  /// A pure status→destination map kept OFF the [JeeberKycStatusGate] interface
  /// so the interface stays minimal (`status` + `isApproved`) — every existing
  /// implementer (incl. the seam-backed default and test fakes that `implements`
  /// the gate) keeps satisfying it without re-declaring derived members. The
  /// DELIVERY-tab host calls `JeeberDeliveryTabDestination.forStatus(gate.status)`.
  static JeeberDeliveryTabDestination forStatus(JeeberKycStatus status) =>
      switch (status) {
        // none = never onboarded → register prompt.
        JeeberKycStatus.none => JeeberDeliveryTabDestination.registerPrompt,
        // pending = registered, KYC submitted → BROWSE the feed; offering is
        // the only gated action (feed_make_offer_cta → offer_kyc_gate, D38).
        JeeberKycStatus.pending => JeeberDeliveryTabDestination.feed,
        // approved = registered + verified → feed; offering allowed.
        JeeberKycStatus.approved => JeeberDeliveryTabDestination.feed,
        // rejected = terminal (D52/D87) → the dedicated kyc-rejected screen.
        JeeberKycStatus.rejected => JeeberDeliveryTabDestination.kycRejected,
      };
}

/// The narrow gate the jeeber surfaces read.
abstract class JeeberKycStatusGate {
  /// The current jeeber KYC status (D38/D52). Drives JM-036/044.
  JeeberKycStatus get status;

  /// Whether the jeeber may SEND offers (the D38 invariant the offer flow
  /// gates on, JM-044/048): approved unlocks the composer; every other state
  /// routes `feed_make_offer_cta` through `offer_kyc_gate`.
  bool get isApproved => status == JeeberKycStatus.approved;
}

/// Debug-aware default gate. In DEBUG it reads the `jeeb.seam.kyc_status` seam
/// ([DevSeamConfig.kycStatusSeed], 65_W2_TEST_PLAN §3.1) so a Maestro flow can
/// drive the DELIVERY-tab/offer gate deterministically:
///   * `none`/`pending`/`rejected` (or absent for a jeeber session) → NOT
///     approved → register prompt / gate.
///   * `approved` → the feed / composer.
///
/// In RELEASE the seam is inert ([DevSeam.current] is empty), so this gate
/// reports [JeeberKycStatus.approved] — preserving the prior behaviour (the
/// jeeber Dashboard tab rendered the feed) for every call site until the JM-036
/// engineer wires the real getMe/kyc-backed gate. That is the least-surprising
/// production-safe default (R-F): it does not REGRESS the existing jeeber feed,
/// and it is overridden the moment the real status source lands.
class SeamJeeberKycStatusGate implements JeeberKycStatusGate {
  const SeamJeeberKycStatusGate();

  @override
  JeeberKycStatus get status {
    if (!kDebugMode) return JeeberKycStatus.approved;
    switch (DevSeam.current.kycStatusSeed) {
      case KycStatusSeed.approved:
        return JeeberKycStatus.approved;
      case KycStatusSeed.pending:
        return JeeberKycStatus.pending;
      case KycStatusSeed.rejected:
        return JeeberKycStatus.rejected;
      case KycStatusSeed.statusNone:
        return JeeberKycStatus.none;
      case KycStatusSeed.none:
        // No explicit `jeeb.seam.kyc_status`. Honour the LEGACY screen-19 debug
        // flag (`jeeb.home_tab=unregistered`) as "not approved" so the existing
        // W0 flow `19-delivery-screen-user-not-registered-as-del.yaml` — which
        // forces the register prompt via `home_tab` and predates the
        // `kyc_status` seam — still renders `delivery_register_prompt` without
        // editing that flow (W2 EXIT: no existing W0/W1 flow modified). Any
        // other absent-seam debug run (and the existing approved jeeber flows)
        // defaults to approved so it still reaches the feed.
        if (DevSeam.current.homeTab == 'unregistered') {
          return JeeberKycStatus.none;
        }
        return JeeberKycStatus.approved;
    }
  }

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}
