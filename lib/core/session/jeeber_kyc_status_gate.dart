import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../features/kyc/domain/kyc_gateway.dart';
import '../../features/kyc/domain/kyc_submission.dart';
import '../dev_seam/dev_seam.dart';
import '../dev_seam/dev_seam_config.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
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

/// The canvas box for a tab body: phone width, and tall enough that the 200%
/// rendering of the longest headline (`kycRejectedHeadline`) still fits — a
const Size _jeeberKycGateBuilderTabBox = Size(390, 280);

/// Marks the resolved destination block so the render test can measure it.
/// Which destination the gate picked is the widget's whole contract; asserting
const Key jeeberKycGateBuilderPreviewBodyKey = Key('jeeber-kyc-gate-preview-body');

/// Stand-in for the DELIVERY-tab body: paints the destination
/// [JeeberKycGateBuilder] resolved, and reports the status it came from.
class _JeeberKycGateBuilderResolvedDestination extends StatelessWidget {
  const _JeeberKycGateBuilderResolvedDestination({required this.gate, required this.source});

  final JeeberKycStatusGate gate;

  /// Which KIND of gate produced this — `sync` (not a [Listenable]: built once)
  /// or `live` (a [Listenable]: re-resolved on notify). Rendered so the two
  final String source;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final JeeberDeliveryTabDestination destination =
        JeeberDeliveryTabDestination.forStatus(gate.status);

    // The real headline each destination renders in production, so the AR RTL
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
          Text(
            gate.isApproved ? 'Offering unlocked' : 'Offering gated',
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
          const SizedBox(height: 8),
          // Forced LTR: this line is diagnostic, not copy, and an ASCII arrow
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
Widget _jeeberKycGateBuilderLive(KycGateway gateway) => _jeeberKycGateBuilderHosted(
      LiveJeeberKycStatusGate(gateway, useLiveSource: true),
      source: 'live',
    );

/// Never onboarded: the only status that should ever show the register prompt.
/// Its "Register now" CTA chains into the onboarding wizard (JM-039), which is
@JeebPreview(group: 'core', name: 'none · register prompt', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderNotOnboarded() => _jeeberKycGateBuilderSync(JeeberKycStatus.none);

/// The W2-closer regression, made visible.
/// A registered jeeber whose KYC is still `pending` BROWSES the feed; only
@JeebPreview(group: 'core', name: 'pending · feed, offering gated', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderPending() => _jeeberKycGateBuilderSync(JeeberKycStatus.pending);

/// The happy path: verified, feed reachable, composer unlocked.
/// Renders the same destination as `pending` — the ONLY visible difference is
@JeebPreview(group: 'core', name: 'approved · offering unlocked', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderApproved() => _jeeberKycGateBuilderSync(JeeberKycStatus.approved);

/// Terminal rejection (D52/D87): neither the feed nor the register prompt.
/// In production this destination is a post-frame redirect to the
@JeebPreview(group: 'core', name: 'rejected · terminal', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderRejected() => _jeeberKycGateBuilderSync(JeeberKycStatus.rejected);

/// JEBV4-267, and the state this whole widget exists for: the release gate
/// before its one live read has landed.
@JeebPreview(group: 'core', name: 'live · fetch in flight', size: _jeeberKycGateBuilderTabBox)
Widget jeeberKycGateBuilderLiveFetchInFlight() => _jeeberKycGateBuilderLive(_JeeberKycGateBuilderStalledGateway());

/// The reactive contract: a live `approved` read landing AFTER the first build.
/// The gate reports `none` synchronously, then notifies when the fetch
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
class _JeeberKycGateBuilderStalledGateway extends FakeKycGateway {
  @override
  Future<KycSubmission> fetchStatus() => Completer<KycSubmission>().future;
}
