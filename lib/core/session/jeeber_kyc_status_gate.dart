import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../features/kyc/domain/kyc_gateway.dart';
import '../../features/kyc/domain/kyc_submission.dart';
import '../dev_seam/dev_seam.dart';
import '../dev_seam/dev_seam_config.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
// Narrowed with `show` on purpose: the production code above imports
// `widgets.dart`, and a bare `material.dart` here would make that import
// redundant (`unnecessary_import`). Only the preview fixture needs Material.
import 'package:flutter/material.dart' show ColorScheme, Theme, ThemeData;
import '../../l10n/app_localizations.dart';
import '../previews/jeeb_preview.dart';

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
    // E19 tri-state: `ResubmitRequested` is NOT approved and NOT the terminal
    // final rejection — the jeeber has a submission on file that needs a
    // fix-and-resend. For the COARSE delivery/offer gate that is the same
    // contract as `pending`: browse the feed, but offering stays gated
    // (feed_make_offer_cta → offer_kyc_gate) and never unlocks the composer
    // (isApproved stays false). The DISTINCT resubmit affordance lives in the
    // KYC status view + the offer-gate status line, which read the fine-grained
    // [KycStatus] directly and render the resubmit CTA/prompt.
    KycStatus.resubmitRequested => JeeberKycStatus.pending,
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/core/jeeber_kyc_gate_builder_preview_test.dart
// ===========================================================================
//
// Widget previews for [JeeberKycGateBuilder] — run with
// `flutter widget-preview start`.
//
// [JeeberKycGateBuilder] paints nothing of its own: it reads a
// [JeeberKycStatusGate] and hands the status to a caller-supplied builder,
// re-running it whenever a [Listenable] gate notifies. So "empty / loading /
// error" in the usual sense do not exist here — the states that can break are
// the four KYC statuses the DELIVERY tab branches on (JM-036 / D38) and the two
// shapes of gate the widget treats differently without saying so: a plain
// synchronous gate (built once) and a [Listenable] one (re-resolved on notify).
//
// Because the widget is invisible, every preview below renders its resolved
// destination through [_ResolvedDestination], a fixture that is NOT part of
// production. It stands in for `_JeeberHomeHost` in
// `lib/features/shell/tabs/dashboard_tab.dart` and makes the three things the
// gate actually decides visible at once:
//
//  * the destination the status maps to
//    ([JeeberDeliveryTabDestination.forStatus]), under its real localized
//    headline, so the AR RTL and 200% renderings exercise real strings;
//  * whether offering is unlocked ([JeeberKycStatusGate.isApproved]) — the D38
//    invariant that is the ONLY difference between `pending` and `approved`,
//    both of which land on the feed;
//  * a `source · status → destination` line, so a preview wired to the wrong
//    gate fails the render test instead of looking plausible in the canvas.
//
// The real `_JeeberHomeHost` is deliberately not used: it builds four cubits
// off `sl<...>()`, three of which are Dio-backed, so previewing through it
// would mean previewing DI rather than the gate. The fixture reproduces its
// decision (`forStatus(gate.status)`) exactly and nothing else.
//
// Every gate below is inert. The synchronous states use a fixture gate with a
// canned status; the live states use the real [LiveJeeberKycStatusGate] driven
// by production's own in-memory [FakeKycGateway], so no preview can reach the
// network even before [jeebPreviewHost] installs its guard.
//
// Two things these previews surfaced, both in the gate rather than in the
// previews — see the notes on `Live · fetch in flight`:
//
//  * [JeeberKycStatus] cannot express "not known yet", so the pre-fetch window
//    is rendered as a fully actionable register prompt;
//  * nothing calls [LiveJeeberKycStatusGate.refresh] after construction, so
//    that window is permanent if the one read fails.

/// The canvas box for a tab body: phone width, and tall enough that the 200%
/// rendering of the longest headline (`kycRejectedHeadline`) still fits — a
/// clipped fixture would report its own overflow instead of anything about the
/// gate. Pinned by the render test.
const Size _jeeberKycGateBuilderTabBox = Size(390, 280);

/// Marks the resolved destination block so the render test can measure it.
/// Which destination the gate picked is the widget's whole contract; asserting
/// it is the only way a test can tell the six previews apart.
const Key jeeberKycGateBuilderPreviewBodyKey = Key('jeeber-kyc-gate-preview-body');

/// Stand-in for the DELIVERY-tab body: paints the destination
/// [JeeberKycGateBuilder] resolved, and reports the status it came from.
class _JeeberKycGateBuilderResolvedDestination extends StatelessWidget {
  const _JeeberKycGateBuilderResolvedDestination({required this.gate, required this.source});

  final JeeberKycStatusGate gate;

  /// Which KIND of gate produced this — `sync` (not a [Listenable]: built once)
  /// or `live` (a [Listenable]: re-resolved on notify). Rendered so the two
  /// branches of [JeeberKycGateBuilder.build] are distinguishable on screen and
  /// in the render test.
  final String source;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final JeeberDeliveryTabDestination destination =
        JeeberDeliveryTabDestination.forStatus(gate.status);

    // The real headline each destination renders in production, so the AR RTL
    // and 200% renderings measure shipped copy rather than fixture lorem.
    final String headline = switch (destination) {
      JeeberDeliveryTabDestination.registerPrompt => l10n.jeeberRegisterTitle,
      JeeberDeliveryTabDestination.feed => l10n.jeeberFeedSectionTitle,
      JeeberDeliveryTabDestination.kycRejected => l10n.kycRejectedHeadline,
    };
    final Color background = switch (destination) {
      JeeberDeliveryTabDestination.registerPrompt =>
        colors.surfaceContainerHighest,
      JeeberDeliveryTabDestination.feed => colors.primaryContainer,
      JeeberDeliveryTabDestination.kycRejected => colors.errorContainer,
    };
    final Color foreground = switch (destination) {
      JeeberDeliveryTabDestination.registerPrompt => colors.onSurface,
      JeeberDeliveryTabDestination.feed => colors.onPrimaryContainer,
      JeeberDeliveryTabDestination.kycRejected => colors.onErrorContainer,
    };

    return Container(
      key: jeeberKycGateBuilderPreviewBodyKey,
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            headline,
            style: theme.textTheme.titleMedium?.copyWith(color: foreground),
          ),
          const SizedBox(height: 8),
          // D38: the feed is reachable at `pending` AND `approved`; only this
          // line differs between them. Without it the two states would render
          // as the same picture, which is exactly the "every preview shows the
          // same widget" failure the README warns about.
          Text(
            gate.isApproved ? 'Offering unlocked' : 'Offering gated',
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
          const SizedBox(height: 8),
          // Forced LTR: this line is diagnostic, not copy, and an ASCII arrow
          // between two latin identifiers reorders visually inside an RTL
          // paragraph.
          Text(
            '$source · ${gate.status.name} → ${destination.name}',
            textDirection: TextDirection.ltr,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

Widget _jeeberKycGateBuilderHosted(JeeberKycStatusGate gate, {required String source}) =>
    JeeberKycGateBuilder(
      gate: gate,
      builder: (BuildContext context, JeeberKycStatusGate gate) =>
          _JeeberKycGateBuilderResolvedDestination(gate: gate, source: source),
    );

/// A gate that is NOT a [Listenable] — the const seam gate, or a test fake.
/// [JeeberKycGateBuilder] builds these exactly once.
Widget _jeeberKycGateBuilderSync(JeeberKycStatus status) =>
    _jeeberKycGateBuilderHosted(_JeeberKycGateBuilderFixedGate(status), source: 'sync');

/// The real release gate, forced onto its live source so the canvas shows the
/// release branch rather than the dev seam. [gateway] is always an in-memory
/// fake, so "live" here means "the live code path", never the network.
Widget _jeeberKycGateBuilderLive(KycGateway gateway) => _jeeberKycGateBuilderHosted(
      LiveJeeberKycStatusGate(gateway, useLiveSource: true),
      source: 'live',
    );

/// Never onboarded: the only status that should ever show the register prompt.
///
/// Its "Register now" CTA chains into the onboarding wizard (JM-039), which is
/// why every other status reaching this destination is a bug rather than a
/// cosmetic slip — see the `pending` and `Live · fetch in flight` previews.
@JeebPreview(group: 'core', name: 'none · register prompt', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderNotOnboarded() => _jeeberKycGateBuilderSync(JeeberKycStatus.none);

/// The W2-closer regression, made visible.
///
/// A registered jeeber whose KYC is still `pending` BROWSES the feed; only
/// offering is gated (`feed_make_offer_cta` → `offer_kyc_gate`, D38 /
/// JM-044/048). The old `!isApproved` collapse routed this status to
/// `delivery_register_prompt`, which made the offer-KYC gate unreachable and
/// invited an already-registered jeeber to register again. If this preview ever
/// renders the register headline, that collapse is back.
@JeebPreview(group: 'core', name: 'pending · feed, offering gated', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderPending() => _jeeberKycGateBuilderSync(JeeberKycStatus.pending);

/// The happy path: verified, feed reachable, composer unlocked.
///
/// Renders the same destination as `pending` — the ONLY visible difference is
/// the offering line, which is the D38 invariant the offer flow gates on.
@JeebPreview(group: 'core', name: 'approved · offering unlocked', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderApproved() => _jeeberKycGateBuilderSync(JeeberKycStatus.approved);

/// Terminal rejection (D52/D87): neither the feed nor the register prompt.
///
/// In production this destination is a post-frame redirect to the
/// `kyc-rejected` screen, and the tab body carries the `delivery_register_prompt`
/// root for the single frame before it fires — so a rejected jeeber briefly sees
/// a register CTA. This preview renders the destination the gate actually
/// resolved, which is the decision under review; the frame-long prompt is
/// `_GateScoped`'s to fix, not this widget's.
@JeebPreview(group: 'core', name: 'rejected · terminal', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderRejected() => _jeeberKycGateBuilderSync(JeeberKycStatus.rejected);

/// JEBV4-267, and the state this whole widget exists for: the release gate
/// before its one live read has landed.
///
/// [JeeberKycStatus] has no `unknown` member, so `_cached ?? none` renders the
/// pre-fetch window as `none` — a fully actionable "Register as a delivery man"
/// prompt shown to a jeeber who may well be approved. Being conservative is
/// right (never default-approve); being INDISTINGUISHABLE from "never
/// onboarded" is the part worth looking at, and this preview is the only place
/// it is visible. The gateway here never completes, which is also what a failed
/// read looks like: `refresh()` swallows the error and nothing calls it again,
/// so this frame is the rest of the session.
@JeebPreview(group: 'core', name: 'live · fetch in flight', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderLiveFetchInFlight() => _jeeberKycGateBuilderLive(_JeeberKycGateBuilderStalledGateway());

/// The reactive contract: a live `approved` read landing AFTER the first build.
///
/// The gate reports `none` synchronously, then notifies when the fetch
/// resolves; [JeeberKycGateBuilder]'s [ListenableBuilder] branch re-resolves the
/// destination so the jeeber reaches the feed without a re-login. That
/// transition is the entire reason this widget exists — if it regresses, this
/// preview renders the register prompt instead. In the canvas the fake resolves
/// on a microtask, so the `none` frame is not visible here; look at
/// `live · fetch in flight` for what that frame contains.
@JeebPreview(group: 'core', name: 'live · approved lands late', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderLiveApprovedLandsLate() => _jeeberKycGateBuilderLive(
      FakeKycGateway(
        initial: const KycSubmission(status: KycStatus.approved),
      ),
    );

/// A gate with a canned status and no [Listenable] surface — the shape of the
/// const seam gate and of every test fake that `implements` the interface.
class _JeeberKycGateBuilderFixedGate implements JeeberKycStatusGate {
  const _JeeberKycGateBuilderFixedGate(this.status);

  @override
  final JeeberKycStatus status;

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}

/// A [KycGateway] whose status read never completes — models both the pre-fetch
/// window and (because the failure is swallowed and never retried) a read that
/// failed. Extends production's in-memory [FakeKycGateway] so the other four
/// members stay inert without restating them.
class _JeeberKycGateBuilderStalledGateway extends FakeKycGateway {
  @override
  Future<KycSubmission> fetchStatus() => Completer<KycSubmission>().future;
}
