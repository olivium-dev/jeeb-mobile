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

enum JeeberKycStatus { none, pending, approved, rejected }

enum JeeberDeliveryTabDestination {
  registerPrompt,
  feed,
  kycRejected;

  static JeeberDeliveryTabDestination forStatus(JeeberKycStatus status) =>
      switch (status) {

        JeeberKycStatus.none => JeeberDeliveryTabDestination.registerPrompt,

        JeeberKycStatus.pending => JeeberDeliveryTabDestination.feed,

        JeeberKycStatus.approved => JeeberDeliveryTabDestination.feed,

        JeeberKycStatus.rejected => JeeberDeliveryTabDestination.kycRejected,
      };
}

abstract class JeeberKycStatusGate {

  JeeberKycStatus get status;

  bool get isApproved => status == JeeberKycStatus.approved;
}

class SeamJeeberKycStatusGate implements JeeberKycStatusGate {
  const SeamJeeberKycStatusGate();

  @override
  JeeberKycStatus get status {

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

        if (DevSeam.current.homeTab == 'unregistered') {
          return JeeberKycStatus.none;
        }
        return JeeberKycStatus.approved;
    }
  }

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}

class LiveJeeberKycStatusGate extends ChangeNotifier
    implements JeeberKycStatusGate {

  LiveJeeberKycStatusGate(this._gateway, {bool? useLiveSource})
    : _useLiveSource = useLiveSource ?? !kDebugMode {

    if (_useLiveSource) unawaited(refresh());
  }

  final KycGateway _gateway;
  final bool _useLiveSource;

  JeeberKycStatus? _cached;

  @override
  JeeberKycStatus get status {

    if (!_useLiveSource) return const SeamJeeberKycStatusGate().status;

    return _cached ?? JeeberKycStatus.none;
  }

  @override
  bool get isApproved => status == JeeberKycStatus.approved;

  Future<void> refresh() async {
    try {
      final submission = await _gateway.fetchStatus();
      final next = _map(submission.status);
      if (next != _cached) {
        _cached = next;
        notifyListeners();
      }
    } catch (_) {

    }
  }

  static JeeberKycStatus _map(KycStatus status) => switch (status) {
    KycStatus.notSubmitted => JeeberKycStatus.none,
    KycStatus.pending => JeeberKycStatus.pending,
    KycStatus.approved => JeeberKycStatus.approved,
    KycStatus.rejected => JeeberKycStatus.rejected,

    KycStatus.resubmitRequested => JeeberKycStatus.pending,
  };
}

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
