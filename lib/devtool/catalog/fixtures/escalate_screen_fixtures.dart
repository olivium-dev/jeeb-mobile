// Designed states for `EscalateScreen` (JM-060 dispute-open-evidence) — ONE
// source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_04_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/escalate/presentation/escalate_screen.dart
//                                                       the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog entry owned a private `_CatalogEscalateRepository` plus a private
// `_EscalateFixture` enum. They moved here whole when the screen got a preview
// section, because two copies of the same "designed state" drift and the
// catalog is the one a designer signs off against.
//
// One thing changed in the move. The enum-of-behaviours became a single
// SCRIPTED repository with independent axes, because the two collaborator calls
// this screen makes are independent: `fetchEvidence` runs unconditionally at
// mount and `submitEscalation` only on the CTA. The enum could not express
// "evidence still in flight" (the state the screen spends its first frames in,
// and the one that renders the wrong copy — see the preview section) without a
// fifth case that meant nothing to the submit path.
//
// NOTHING here touches the network. Every answer comes from a const value,
// throws, or never completes — the [CatalogNetworkGuard] both hosts install is
// a net, not the plan. `EscalateCubit` takes a repository rather than a seed
// state, so a designed state here is described by what the collaborator answers
// plus the pre-drive in [EscalateScreenPreviewFixtures.cubit]; the real
// mount-time `loadEvidence` path then runs exactly as it does in production.

import 'dart:async';

import '../../../features/escalate/application/escalate_cubit.dart';
import '../../../features/escalate/domain/escalate_repository.dart';

/// A fake [EscalateRepository] whose two calls are scripted independently.
///
/// Both axes have a "never completes" setting, spelled as a [Completer] that is
/// never completed: it holds no timer and no subscription, so a frozen state is
/// stable for as long as the host is open without arming anything a widget test
/// would report as pending.
class ScriptedEscalateRepository implements EscalateRepository {
  const ScriptedEscalateRepository({
    this.evidence = EscalateScreenPreviewFixtures.fullEvidence,
    this.evidenceFailure,
    this.evidenceStalls = false,
    this.submitFailure,
    this.submitStalls = false,
    this.caseId = EscalateScreenPreviewFixtures.caseId,
  });

  /// What a successful [fetchEvidence] answers.
  final EscalateEvidence evidence;

  /// When set, [fetchEvidence] throws it. `EscalateCubit.loadEvidence` catches
  /// EVERY failure and degrades to [EscalateEvidence.empty], so this is how the
  /// empty-evidence reading is reached — the screen has no other route to it.
  final EscalateErrorKind? evidenceFailure;

  /// When true, [fetchEvidence] never resolves and `evidenceLoaded` stays false.
  final bool evidenceStalls;

  /// When set, [submitEscalation] throws it — the classified error view.
  final EscalateErrorKind? submitFailure;

  /// When true, [submitEscalation] never resolves, freezing the cubit on
  /// [EscalatePhase.submitting].
  final bool submitStalls;

  /// The dispute id a successful submit returns.
  final String caseId;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) {
    if (evidenceStalls) return Completer<EscalateEvidence>().future;
    final EscalateErrorKind? failure = evidenceFailure;
    if (failure != null) {
      return Future<EscalateEvidence>.error(EscalateException(failure));
    }
    return Future<EscalateEvidence>.value(evidence);
  }

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const <String>[],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) {
    if (submitStalls) return Completer<EscalateResult>().future;
    final EscalateErrorKind? failure = submitFailure;
    if (failure != null) {
      return Future<EscalateResult>.error(EscalateException(failure));
    }
    return Future<EscalateResult>.value(
      EscalateResult(caseId: caseId, status: 'open'),
    );
  }
}

/// The designed states of `EscalateScreen`, as repositories plus the cubit
/// pre-drive that puts the screen in each one.
class EscalateScreenPreviewFixtures {
  const EscalateScreenPreviewFixtures._();

  /// The delivery every state hangs off.
  static const String deliveryId = 'DEL-1001';

  /// The dispute id a successful submit returns. Only the SUCCESS phase uses
  /// it, and no host below reaches success: the screen's `listenWhen` routes to
  /// `dispute-status` the moment it lands, through a [GoRouter] that exists in
  /// neither the catalog nor the preview canvas.
  static const String caseId = 'DSP-1001';

  /// The reference auto-attach (D53): a snapshot with a message count plus the
  /// three status rows a delivery in flight has reached.
  static const EscalateEvidence fullEvidence = EscalateEvidence(
    chatSnapshotUrl: 'https://cdn.example.com/dispute/snapshot.png',
    chatMessageCount: 12,
    timeline: <EscalateTimelineEntry>[
      EscalateTimelineEntry(status: 'Ordered'),
      EscalateTimelineEntry(status: 'Picked'),
      EscalateTimelineEntry(status: 'InTransit'),
    ],
  );

  /// A completed delivery's auto-attach: a long-running conversation and a
  /// timeline that reaches the terminal row.
  ///
  /// `AtDoor` is deliberately absent — the screen maps BOTH `AtDoor` and `Done`
  /// to the same localized "Delivered" label, so a timeline carrying both
  /// renders the same line twice with nothing to tell them apart.
  static const EscalateEvidence completedEvidence = EscalateEvidence(
    chatSnapshotUrl: 'https://cdn.example.com/dispute/snapshot-248.png',
    chatMessageCount: 248,
    timeline: <EscalateTimelineEntry>[
      EscalateTimelineEntry(status: 'Ordered'),
      EscalateTimelineEntry(status: 'Picked'),
      EscalateTimelineEntry(status: 'InTransit'),
      EscalateTimelineEntry(status: 'Done'),
    ],
  );

  /// The five photo paths that reach the `≤5` cap (D53). Their order is the
  /// order the chips render in, and the chip label is derived from the INDEX,
  /// so the paths themselves never reach a pixel.
  static const List<String> cappedPhotos = <String>[
    'dispute_photo_1.jpg',
    'dispute_photo_2.jpg',
    'dispute_photo_3.jpg',
    'dispute_photo_4.jpg',
    'dispute_photo_5.jpg',
  ];

  /// The captured voice-evidence clip (D53).
  static const String voicePath = 'dispute_voice.m4a';

  // ───────────────────────────── the states ───────────────────────────────

  /// Catalog "Reason picker (evidence loaded)": the auto-attach resolved and
  /// the customer has chosen nothing yet.
  static EscalateRepository evidenceLoaded() =>
      const ScriptedEscalateRepository();

  /// Catalog "Evidence degraded": `fetchEvidence` fails, `loadEvidence`
  /// swallows it, and the panel renders [EscalateEvidence.empty].
  static EscalateRepository evidenceDegraded() =>
      const ScriptedEscalateRepository(
        evidenceFailure: EscalateErrorKind.network,
      );

  /// The auto-attach still in flight — `evidenceLoaded` never flips.
  static EscalateRepository evidenceStalled() =>
      const ScriptedEscalateRepository(evidenceStalls: true);

  /// Catalog "Submitting": the POST never resolves, so the phase stays
  /// [EscalatePhase.submitting]. Drive it with `cubit(..., submit: true)`.
  static EscalateRepository stalledSubmit() =>
      const ScriptedEscalateRepository(submitStalls: true);

  /// Catalog "Error (network)": the POST fails with a classified transport
  /// error. Drive it with `cubit(..., submit: true)`.
  static EscalateRepository failingSubmit([
    EscalateErrorKind kind = EscalateErrorKind.network,
  ]) => ScriptedEscalateRepository(submitFailure: kind);

  /// A completed delivery's evidence, for the longest-content reading.
  static EscalateRepository completedEvidenceLoaded() =>
      const ScriptedEscalateRepository(evidence: completedEvidence);

  // ────────────────────────────── the cubit ────────────────────────────────

  /// The cubit both hosts mount above the screen, optionally pre-driven.
  ///
  /// No `loadEvidence()` here on purpose — `EscalateScreen.initState` posts its
  /// own on the first frame, so calling it here would double the read and hide
  /// the mount path the screen actually ships.
  ///
  /// [submit] is fire-and-forget: `EscalateCubit.submit` emits
  /// [EscalatePhase.submitting] synchronously before its first `await`, so the
  /// phase is already correct on the first frame and the scripted repository
  /// decides what happens after it.
  static EscalateCubit cubit(
    EscalateRepository repository, {
    EscalateReason? reason,
    List<String> photoPaths = const <String>[],
    String? voicePath,
    bool submit = false,
  }) {
    final EscalateCubit cubit = EscalateCubit(
      repository: repository,
      deliveryId: deliveryId,
    );
    if (reason != null) cubit.setReason(reason);
    for (final String path in photoPaths) {
      cubit.addPhoto(path);
    }
    if (voicePath != null) cubit.setVoice(voicePath);
    if (submit) unawaited(cubit.submit());
    return cubit;
  }
}
