import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_stepper.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../application/dispute_status_cubit.dart';
import '../application/dispute_status_state.dart';
import '../data/empty_dispute_status_repository.dart';
import '../domain/dispute_status_repository.dart';
import 'dispute_status_l10n.dart';

/// Board gutter + block rhythm (redesign-2026-08 §4.3): 24px sides, 16px above
/// the first block. The docked footer owns the bottom edge, so the list only
/// needs to clear it.
const EdgeInsetsGeometry _kBodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.medium,
);

/// dispute-status (JM-065). The status screen for a submitted dispute, reached
/// from dispute-open-evidence (`dispute_submit_cta` → here, JM-060), a
/// transaction-detail dispute link, or a notification.
///
/// Renders the 4-state machine (40_GUARDRAILS_ARCH §3): loading / failed /
/// loaded. Loaded shows `dispute_status_state` (Open / Resolved), the typed
/// outcome note when resolved (refund / penalty, D2), and a read-only evidence
/// summary (reason / comment / photos / voice / chat snapshot / timeline, D53).
/// `dispute_status_support` → support-ticket (D76); `dispute_status_back` →
/// order-chat (the originating thread when the dispute carries a ref, else a
/// safe pop).
///
/// redesign-2026-08: re-skinned onto the Jeeb kit — [JeebTopBar] in-body
/// header, the lifecycle as a [JeebStepper] (the neighbouring live-tracking
/// screen's signature band), the state as a role-coloured [JeebInfoNote], the
/// outcome and evidence as [JeebSectionLabel] + [JeebOutlinedCard] blocks, and
/// the two edges docked in a [JeebCtaFooter]. Same flow, same copy, same
/// identifiers.
///
/// Reads the LIVE compliment-service via `sl<DisputeStatusRepository>()`
/// (DioDisputeStatusRepository; `GET /v1/disputes/:disputeId` mock-ready on
/// :4010 — 42_GUARDRAILS_MOCK §4). [repository] is a constructor test seam
/// (40_GUARDRAILS_ARCH §5.4) — production leaves it null; an unconfigured GetIt
/// (router-resolution widget tests) falls back to [EmptyDisputeStatusRepository]
/// so the screen renders its error state rather than throwing.
///
/// Semantics identifiers exposed (EXACT — 30_BACKLOG JM-065, 41_GUARDRAILS_TESTING):
///   `dispute_status_root`       — screen host container
///   `dispute_status_state`      — Open / Resolved indicator
///   `dispute_status_outcome`    — resolved outcome note (refund / penalty, D2)
///   `dispute_status_evidence`   — auto-attached evidence summary (D53)
///   `dispute_status_support`    — → support-ticket (D76)
///   `dispute_status_back`       — → order-chat
///   `dispute_status_loading`    — D30 loading
///   `dispute_status_error`      — D30 error
///   `dispute_status_retry_cta`  — D30 retry
class DisputeStatusScreen extends StatelessWidget {
  const DisputeStatusScreen({
    super.key,
    required this.disputeId,
    this.repository,
  });

  /// The dispute id from the `/disputes/:id` path param.
  final String disputeId;

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final DisputeStatusRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DisputeStatusCubit>(
      create: (_) => DisputeStatusCubit(
        repository: _resolveRepository(),
        disputeId: disputeId,
      )..load(),
      child: const _DisputeStatusView(),
    );
  }

  /// Resolves the repo: an explicit override (tests) → the registered LIVE
  /// `DioDisputeStatusRepository` → an empty fallback when GetIt is not
  /// configured. Mirrors `NotificationsListScreen._resolveRepository()`.
  DisputeStatusRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<DisputeStatusRepository>()) {
      return sl<DisputeStatusRepository>();
    }
    return const EmptyDisputeStatusRepository();
  }
}

class _DisputeStatusView extends StatelessWidget {
  const _DisputeStatusView();

  @override
  Widget build(BuildContext context) {
    final copy = DisputeStatusL10n.of(context);
    return Semantics(
      identifier: 'dispute_status_root',
      container: true,
      child: Scaffold(
        // The board's header is an in-body row, not a Material app bar, so it
        // renders in every state (loading / failed / loaded) identically.
        body: SafeArea(
          child: Column(
            children: [
              JeebTopBar(
                title: copy.title,
                // The bar's back circle honours the same edge as the explicit
                // `dispute_status_back` CTA (→ order-chat / safe pop). The id
                // stays on that CTA — the contract names one node, not two.
                leadingTooltip: copy.backCta,
                onLeadingPressed: () => _back(context),
              ),
              Expanded(
                child: BlocBuilder<DisputeStatusCubit, DisputeStatusState>(
                  builder: (context, state) {
                    switch (state.status) {
                      case DisputeStatusViewStatus.initial:
                      case DisputeStatusViewStatus.loading:
                        return const _LoadingBody();
                      case DisputeStatusViewStatus.failed:
                        return _ErrorBody(copy: copy, failure: state.error);
                      case DisputeStatusViewStatus.loaded:
                        return _LoadedBody(copy: copy, dispute: state.dispute!);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Back edge → order-chat (JM-065 AC `dispute_status_back`). The dispute's
  /// chat ref addresses the originating thread; on a cold deep-link with no ref
  /// it pops, falling back to root so the user is never stranded (AP-9 honesty —
  /// never fabricate a chat id the dispute can't address).
  static void _back(BuildContext context) {
    final dispute = context.read<DisputeStatusCubit>().state.dispute;
    final ref = dispute?.chatRef;
    if (ref != null) {
      context.goNamed('chat-detail', pathParameters: <String, String>{'id': ref});
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'dispute_status_loading',
      container: true,
      child: const Center(child: OmdsLoadingState()),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.copy, required this.failure});

  final DisputeStatusL10n copy;
  final DisputeStatusFailure? failure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
          vertical: Spacing.large,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: scheme.error),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'dispute_status_error',
              container: true,
              child: Text(
                _message(copy, failure),
                textAlign: TextAlign.center,
                style: context.jeebText.body.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'dispute_status_retry_cta',
              button: true,
              container: true,
              child: JeebCtaButton(
                label: copy.retry,
                leadingIcon: Icons.refresh,
                // Hugs its label: a full-width pill under a centred column
                // reads as a docked footer that isn't there.
                expand: false,
                onTap: () => context.read<DisputeStatusCubit>().refresh(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(DisputeStatusL10n copy, DisputeStatusFailure? f) {
    switch (f) {
      case DisputeStatusFailure.network:
        return copy.networkError;
      case DisputeStatusFailure.notFound:
        return copy.notFoundError;
      case DisputeStatusFailure.unauthorized:
      case DisputeStatusFailure.unknown:
      case null:
        return copy.loadError;
    }
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.copy, required this.dispute});

  final DisputeStatusL10n copy;
  final DisputeStatus dispute;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: _kBodyPadding,
            children: [
              _StatusStepper(copy: copy, dispute: dispute),
              const SizedBox(height: Spacing.large),
              _StateCard(copy: copy, dispute: dispute),
              const SizedBox(height: Spacing.large),
              // JM-065 AC1: the outcome note ALWAYS renders — a resolved dispute
              // shows the refund/penalty outcome (D2); an OPEN dispute shows the
              // pending outcome (the flow asserts `dispute_status_outcome_note`
              // on the open dispute it seeds). Coined id
              // `dispute_status_outcome_note`.
              _OutcomeCard(copy: copy, dispute: dispute),
              const SizedBox(height: Spacing.large),
              // JM-065 AC1: the evidence summary ALWAYS renders (D53). Coined id
              // `dispute_status_evidence_summary`.
              _EvidenceCard(copy: copy, evidence: dispute.evidence),
            ],
          ),
        ),
        // The board docks the two edges (12 `tpl 782`) instead of letting them
        // scroll: support is reachable without reading to the bottom.
        JeebCtaFooter.single(
          below: Semantics(
            identifier: 'dispute_status_back',
            button: true,
            container: true,
            // EDGE → order-chat (back).
            child: JeebCtaButton.text(
              label: copy.backCta,
              onTap: () => _DisputeStatusView._back(context),
            ),
          ),
          child: Semantics(
            identifier: 'dispute_status_support',
            button: true,
            container: true,
            // EDGE → support-ticket (JM-063, D76). Seed the order ref via
            // `extra` so the support form can pre-fill the linked order (the
            // support screen reads a String `extra`).
            child: JeebCtaButton(
              label: copy.supportCta,
              onTap: () => context.goNamed(
                'support-ticket',
                extra: dispute.orderRef,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The dispute lifecycle as the board's node stepper — the same band screen 12
/// wears above its map, which is what makes this screen read as its neighbour.
///
/// Three nodes, all derived from data the dispute already carries: it exists,
/// so it was **submitted**; `isResolved` decides whether review is still the
/// active step. Nothing here claims a stage the API does not report — an
/// `unknown` state rests on "under review", exactly as the state label already
/// does.
class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.copy, required this.dispute});

  final DisputeStatusL10n copy;
  final DisputeStatus dispute;

  static const List<String> _stepIds = <String>[
    'dispute_status_step_submitted',
    'dispute_status_step_review',
    'dispute_status_step_resolved',
  ];

  @override
  Widget build(BuildContext context) {
    final resolved = dispute.isResolved;
    return Semantics(
      identifier: 'dispute_status_stepper',
      container: true,
      // Without this the per-step nodes fold into the root and their
      // identifiers stop being addressable (the OrderTrackingStepper rule).
      explicitChildNodes: true,
      child: JeebStepper(
        currentIndex: resolved ? 2 : 1,
        labels: <String>[
          copy.stepSubmittedLabel,
          copy.stepUnderReviewLabel,
          copy.resolvedLabel,
        ],
        stepIdentifiers: _stepIds,
        // The glow is "still moving": it rests once the back office has ruled.
        pulseActive: !resolved,
      ),
    );
  }
}

/// `dispute_status_state` — the Open / Resolved indicator (JM-065 AC), as the
/// board's strip note. A tone + glyph + label keyed off the dispute lifecycle.
class _StateCard extends StatelessWidget {
  const _StateCard({required this.copy, required this.dispute});

  final DisputeStatusL10n copy;
  final DisputeStatus dispute;

  @override
  Widget build(BuildContext context) {
    final resolved = dispute.isResolved;
    // Semantic roles: resolved = success, open = warning (attention pending).
    // The kit's success/warning tones keep their role colours on every surface
    // — here the state IS the message, so it never re-tones to a quiet grey.
    return Semantics(
      identifier: 'dispute_status_state',
      container: true,
      child: resolved
          ? JeebInfoNote.success(
              icon: Icons.check_circle,
              text: copy.resolvedLabel,
            )
          : JeebInfoNote.warning(
              icon: Icons.hourglass_top,
              text: copy.openLabel,
            ),
    );
  }
}

/// `dispute_status_outcome` — the resolved outcome note (refund / penalty, D2).
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.copy, required this.dispute});

  final DisputeStatusL10n copy;
  final DisputeStatus dispute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = context.jeebText;
    final amount = _formattedAmount(dispute);
    final resolved = dispute.isResolved;
    final note = dispute.note;
    return Semantics(
      identifier: 'dispute_status_outcome_note',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JeebSectionLabel(copy.outcomeHeading),
          const SizedBox(height: Spacing.small),
          JeebOutlinedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Resolved → the refund/penalty outcome line (D2); open → the
                  // pending-outcome body (the dispute is still under review).
                  resolved
                      ? copy.outcomeLine(dispute.outcome, amount: amount)
                      : copy.openBody,
                  style: text.body.copyWith(color: scheme.onSurface),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: Spacing.xSmall),
                  Text(
                    note,
                    style: text.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _formattedAmount(DisputeStatus d) {
    final a = d.refundAmount;
    if (a == null) return null;
    final currency = d.currency;
    final value = a.toStringAsFixed(2);
    return currency == null ? value : '$value $currency';
  }
}

/// `dispute_status_evidence` — the read-only auto-attached evidence summary
/// (D53). Not editable here (that is dispute-open-evidence, JM-060).
class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.copy, required this.evidence});

  final DisputeStatusL10n copy;
  final DisputeEvidenceSummary evidence;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    void addRow(IconData icon, String title, {String? subtitle}) {
      rows.add(
        JeebListRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          // Read-only summary: nothing here opens anything, so no chevron
          // promises a tap that does not exist.
          showChevron: false,
        ),
      );
    }

    final reason = evidence.reason;
    if (reason != null && reason.isNotEmpty) {
      addRow(Icons.flag, copy.reasonLabel(reason));
    }
    final comment = evidence.comment;
    if (comment != null && comment.isNotEmpty) {
      addRow(Icons.notes, copy.evidenceCommentLabel, subtitle: comment);
    }
    if (evidence.photoCount > 0) {
      addRow(Icons.photo, copy.photosLabel(evidence.photoCount));
    }
    if (evidence.hasVoice) {
      addRow(Icons.mic, copy.voiceLabel);
    }
    if (evidence.hasChatSnapshot) {
      addRow(Icons.chat_bubble, copy.chatLabel(evidence.chatMessageCount));
    }
    if (evidence.timelineCount > 0) {
      addRow(Icons.timeline, copy.timelineLabel(evidence.timelineCount));
    }

    return Semantics(
      identifier: 'dispute_status_evidence_summary',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JeebSectionLabel(copy.evidenceHeading),
          // An empty evidence set draws NO card: an outlined box with nothing
          // in it would imply evidence we do not have (AP-9 honesty).
          if (rows.isNotEmpty) ...[
            const SizedBox(height: Spacing.small),
            JeebOutlinedCard.grouped(children: rows),
          ],
        ],
      ),
    );
  }
}
