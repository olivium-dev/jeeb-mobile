import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../features/kyc/domain/kyc_gateway.dart';
import '../../features/kyc/domain/kyc_submission.dart';
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

/// Debug-only dev-seam gate. In DEBUG it reads the `jeeb.seam.kyc_status` seam
/// ([DevSeamConfig.kycStatusSeed], 65_W2_TEST_PLAN §3.1) so a Maestro flow can
/// drive the DELIVERY-tab/offer gate deterministically:
///   * `none`/`pending`/`rejected` (or absent for a jeeber session) → NOT
///     approved → register prompt / gate.
///   * `approved` → the feed / composer.
///
/// The dev seam is the "explicit dev flag" ([kDebugMode]) side of the gate: it
/// exists ONLY so Maestro/widget tests can script a deterministic KYC status
/// without a network round-trip. Production never depends on it — DI registers
/// the network-backed [LiveJeeberKycStatusGate] (which delegates to THIS gate in
/// debug for seam determinism, and queries the live BFF in release).
///
/// In RELEASE the seam is inert ([DevSeam.current] is empty). This gate reports
/// [JeeberKycStatus.none] — a CONSERVATIVE, non-approved default (JEBV4-267). It
/// used to hardcode [JeeberKycStatus.approved] in release, which made every
/// release build treat unapproved jeebers as approved (the delivery tab + offer
/// composer showed jeeber UX that then 403'd server-side). This gate is only
/// ever reached in release as a defensive DI-fallback (DI always registers the
/// live gate); returning `none` keeps that fallback honest — it never
/// default-approves. The real, network-backed source is [LiveJeeberKycStatusGate].
class SeamJeeberKycStatusGate implements JeeberKycStatusGate {
  const SeamJeeberKycStatusGate();

  @override
  JeeberKycStatus get status {
    // RELEASE: never default-approve (JEBV4-267). This const gate has no live
    // source of its own, so the honest conservative fallback is `none`
    // (register-prompt), NOT `approved`. Production resolves the real status via
    // [LiveJeeberKycStatusGate]; this branch is a defensive DI-fallback only.
    if (!kDebugMode) return JeeberKycStatus.none;
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

/// The REAL, network-backed jeeber KYC gate (JM-036, JEBV4-267). Registered in
/// DI as the production [JeeberKycStatusGate] so the DELIVERY tab, the offer
/// make-offer routing, and the wallet KYC banner all read the LIVE status in
/// release instead of the old hardcoded `approved` no-op.
///
/// Source: [KycGateway.fetchStatus] (`GET /v1/kyc/status`, mock-rewritten to the
/// `/user-management/…/kyc` path — U1), the same live decision the offer-KYC
/// gate's status line already reads. The BFF auto-approves KYC on submit
/// (gateway f3bdef9 / PR #261), so a jeeber who has completed onboarding reads
/// back `Verified` → [JeeberKycStatus.approved] and reaches the feed/composer
/// immediately; honest gating therefore does NOT brick new jeebers.
///
/// Build-mode behaviour:
///   * DEBUG — delegates to [SeamJeeberKycStatusGate] verbatim, so every
///     existing Maestro/widget flow that scripts `jeeb.seam.kyc_status` keeps
///     driving the branch deterministically (no network in test). The dev seam
///     is preserved behind the explicit [kDebugMode] flag; no live fetch runs.
///   * RELEASE — reports the cached live status. Until the first fetch resolves
///     it returns a CONSERVATIVE non-approved default ([JeeberKycStatus.none]),
///     never `approved` (JEBV4-267 invariant: never default-approve in release).
///     A [ChangeNotifier] fires when the fetch lands so [JeeberKycGateBuilder]
///     consumers (the DELIVERY tab) re-resolve their destination. Server-side
///     gating still enforces the invariant (403) if a read ever fails.
class LiveJeeberKycStatusGate extends ChangeNotifier
    implements JeeberKycStatusGate {
  /// [useLiveSource] selects the status source and defaults to `!kDebugMode`:
  ///   * RELEASE (`true`) — query the live BFF via [KycGateway] and cache it.
  ///   * DEBUG   (`false`) — delegate to the dev seam ([SeamJeeberKycStatusGate])
  ///     so Maestro/widget flows keep driving `jeeb.seam.kyc_status`.
  /// It is exposed only so tests can exercise the release path deterministically
  /// (`useLiveSource: true`); production always takes the [kDebugMode] default,
  /// so this flag never changes real build behaviour.
  LiveJeeberKycStatusGate(this._gateway, {bool? useLiveSource})
    : _useLiveSource = useLiveSource ?? !kDebugMode {
    // The live fetch runs only when the live source is active (release): in
    // debug the dev seam is the source of truth, so we never touch the network.
    if (_useLiveSource) unawaited(refresh());
  }

  final KycGateway _gateway;
  final bool _useLiveSource;

  /// Last-known live status, or `null` before the first successful fetch.
  JeeberKycStatus? _cached;

  @override
  JeeberKycStatus get status {
    // DEBUG: preserve the deterministic dev-seam behaviour verbatim so no
    // existing Maestro/widget flow changes (the seam is the dev-flag source).
    if (!_useLiveSource) return const SeamJeeberKycStatusGate().status;
    // RELEASE: honest live status. Conservative non-approved default until the
    // first fetch resolves — an unapproved jeeber is client-gated, never treated
    // as approved (JEBV4-267). Consumers rebuild via [JeeberKycGateBuilder] when
    // [refresh] notifies.
    return _cached ?? JeeberKycStatus.none;
  }

  @override
  bool get isApproved => status == JeeberKycStatus.approved;

  /// Re-reads the live KYC decision and, on a change, notifies listeners so the
  /// reactive consumers ([JeeberKycGateBuilder]) re-resolve. A network failure
  /// leaves the cache untouched (conservative default holds); the server still
  /// gates the action, so a failed read never wrongly approves.
  Future<void> refresh() async {
    try {
      final submission = await _gateway.fetchStatus();
      final next = _map(submission.status);
      if (next != _cached) {
        _cached = next;
        notifyListeners();
      }
    } catch (_) {
      // Keep the conservative default; server-side 403 remains the backstop.
    }
  }

  static JeeberKycStatus _map(KycStatus status) => switch (status) {
    KycStatus.notSubmitted => JeeberKycStatus.none,
    KycStatus.pending => JeeberKycStatus.pending,
    KycStatus.approved => JeeberKycStatus.approved,
    KycStatus.rejected => JeeberKycStatus.rejected,
  };
}

/// Rebuilds [builder] whenever [gate] reports a new KYC status. When [gate] is a
/// [Listenable] (the release [LiveJeeberKycStatusGate], which notifies after its
/// live fetch resolves) the subtree re-resolves so a late `approved`/`pending`
/// read reaches the DELIVERY-tab destination without a re-login. For a plain
/// synchronous gate (the const seam gate or a test fake) it builds exactly once,
/// so debug/Maestro behaviour is unchanged.
class JeeberKycGateBuilder extends StatelessWidget {
  const JeeberKycGateBuilder({
    super.key,
    required this.gate,
    required this.builder,
  });

  final JeeberKycStatusGate gate;
  final Widget Function(BuildContext context, JeeberKycStatusGate gate) builder;

  @override
  Widget build(BuildContext context) {
    final gate = this.gate;
    if (gate is Listenable) {
      return ListenableBuilder(
        listenable: gate as Listenable,
        builder: (context, _) => builder(context, this.gate),
      );
    }
    return builder(context, gate);
  }
}
