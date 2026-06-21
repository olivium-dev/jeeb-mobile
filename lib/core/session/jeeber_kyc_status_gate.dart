import 'dart:async';

import 'package:flutter/foundation.dart';

import '../dev_seam/dev_seam.dart';
import '../dev_seam/dev_seam_config.dart';
import '../../features/customer_profile/domain/customer_profile_repository.dart';

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

/// Maps a raw getMe `kycStatus` wire value onto [JeeberKycStatus]. Defensive
/// (40_GUARDRAILS §4): unknown / null / `''` degrade to [fallback] (the gate's
/// production-safe default) rather than throwing, so a malformed getMe body
/// never red-screens the DELIVERY tab.
JeeberKycStatus jeeberKycStatusFromWire(
  String? raw, {
  JeeberKycStatus fallback = JeeberKycStatus.approved,
}) {
  switch (raw?.trim().toLowerCase()) {
    case 'none':
    case 'unregistered':
    case 'not_started':
    case 'notstarted':
      return JeeberKycStatus.none;
    case 'pending':
    case 'submitted':
    case 'in_review':
    case 'inreview':
    case 'review':
      return JeeberKycStatus.pending;
    case 'approved':
    case 'verified':
    case 'active':
      return JeeberKycStatus.approved;
    case 'rejected':
    case 'denied':
    case 'declined':
      return JeeberKycStatus.rejected;
    default:
      return fallback;
  }
}

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

/// The REAL getMe-backed gate (JM-036). Replaces [SeamJeeberKycStatusGate] in
/// production DI: the DELIVERY-tab destination + the offer gate now read the
/// signed-in user's actual `kycStatus` from `GET /users/me` (the same getMe the
/// profile/greeting use), classified `none|pending|approved|rejected`
/// (D38/D52).
///
/// The [JeeberKycStatusGate] interface is synchronous (the router redirect + the
/// DELIVERY-tab `build()` read `status` without an await), so this gate caches
/// the last-resolved status and exposes a fire-and-forget [refresh] that
/// re-pulls getMe. Hydration:
///   * eager — [refresh] is kicked once when the gate is constructed (DI), so
///     the cache is typically warm by the time a jeeber reaches the tab;
///   * on-entry — the shell re-kicks [refresh] when the jeeber Dashboard tab is
///     built, so a role-switch / KYC-approval mid-session reflects on the next
///     tab entry.
///
/// In DEBUG the seam still wins (so existing Maestro flows that drive
/// `jeeb.seam.kyc_status` stay deterministic and don't depend on a live getMe):
/// when a kyc-status seam is present this gate defers to [SeamJeeberKycStatusGate].
/// Until the first getMe resolves (and in any fail-safe case — no repository,
/// network error, getMe omits `kycStatus`) the cache holds [_fallback]
/// (`approved` → feed), preserving the prior production-safe default so the
/// swap never REGRESSES the existing jeeber feed.
class GetMeJeeberKycStatusGate implements JeeberKycStatusGate {
  GetMeJeeberKycStatusGate({
    required CustomerProfileRepository repository,
    JeeberKycStatus fallback = JeeberKycStatus.approved,
    bool hydrateOnCreate = true,
  })  : _repository = repository,
        _fallback = fallback,
        _cached = fallback {
    if (hydrateOnCreate) {
      // Fire-and-forget warm-up; never awaited (the interface is synchronous).
      unawaited(refresh());
    }
  }

  final CustomerProfileRepository _repository;
  final JeeberKycStatus _fallback;
  final SeamJeeberKycStatusGate _seam = const SeamJeeberKycStatusGate();

  JeeberKycStatus _cached;

  /// Re-pull getMe and update the cache. Fail-safe: a network/parse error keeps
  /// the current cache (never downgrades a known status to the fallback on a
  /// transient blip), and never throws — so a fire-and-forget call can't crash
  /// the caller.
  Future<void> refresh() async {
    try {
      final profile = await _repository.fetchProfile();
      _cached = jeeberKycStatusFromWire(profile.kycStatus, fallback: _fallback);
    } on CustomerProfileRepositoryException {
      // Keep the last-known status (or the fallback) — a flaky getMe must not
      // bounce a registered jeeber out of the feed.
    } catch (_) {
      // Same fail-safe behaviour for any unexpected error.
    }
  }

  @override
  JeeberKycStatus get status {
    // DEBUG: an explicit `jeeb.seam.kyc_status` seam (or the legacy
    // `home_tab=unregistered` flag) wins so Maestro flows stay deterministic.
    if (kDebugMode && _seamIsDriving) return _seam.status;
    return _cached;
  }

  /// True when a debug seam is actively driving the KYC branch (so the live
  /// getMe cache should be bypassed). Release always returns false.
  bool get _seamIsDriving {
    if (!kDebugMode) return false;
    if (DevSeam.current.kycStatusSeed != KycStatusSeed.none) return true;
    return DevSeam.current.homeTab == 'unregistered';
  }

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}
