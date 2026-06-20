import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../application/dispute_status_cubit.dart';
import '../application/dispute_status_state.dart';
import '../data/empty_dispute_status_repository.dart';
import '../domain/dispute_status_repository.dart';
import 'dispute_status_l10n.dart';

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
        appBar: OMDSAppBar(
          title: copy.title,
          showBackButton: true,
          // The app-bar leading back honours the same edge as the explicit
          // `dispute_status_back` CTA (→ order-chat / safe pop).
          onBackPressed: () => _back(context),
        ),
        body: BlocBuilder<DisputeStatusCubit, DisputeStatusState>(
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: theme.colorScheme.error),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'dispute_status_error',
              container: true,
              child: Text(
                _message(copy, failure),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'dispute_status_retry_cta',
              button: true,
              container: true,
              child: FilledButton.icon(
                onPressed: () => context.read<DisputeStatusCubit>().refresh(),
                icon: const Icon(Icons.refresh),
                label: Text(copy.retry),
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
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
        Spacing.xLarge,
      ),
      children: [
        _StateCard(copy: copy, dispute: dispute),
        const SizedBox(height: Spacing.large),
        // JM-065 AC1: the outcome note ALWAYS renders — a resolved dispute shows
        // the refund/penalty outcome (D2); an OPEN dispute shows the pending
        // outcome (the flow asserts `dispute_status_outcome_note` on the open
        // dispute it seeds). Coined id `dispute_status_outcome_note`.
        _OutcomeCard(copy: copy, dispute: dispute),
        const SizedBox(height: Spacing.large),
        // JM-065 AC1: the evidence summary ALWAYS renders (D53). Coined id
        // `dispute_status_evidence_summary`.
        _EvidenceCard(copy: copy, evidence: dispute.evidence),
        const SizedBox(height: Spacing.xLarge),
        Semantics(
          identifier: 'dispute_status_support',
          button: true,
          container: true,
          // EDGE → support-ticket (JM-063, D76). Seed the order ref via `extra`
          // so the support form can pre-fill the linked order (the support
          // screen reads a String `extra`).
          child: OmdsPrimaryButton(
            text: copy.supportCta,
            onTap: () => context.goNamed(
              'support-ticket',
              extra: dispute.orderRef,
            ),
          ),
        ),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'dispute_status_back',
          button: true,
          container: true,
          // EDGE → order-chat (back).
          child: TextButton(
            onPressed: () => _DisputeStatusView._back(context),
            child: Text(copy.backCta),
          ),
        ),
      ],
    );
  }
}

/// `dispute_status_state` — the Open / Resolved indicator (JM-065 AC). A chip
/// + label keyed off the dispute lifecycle state.
class _StateCard extends StatelessWidget {
  const _StateCard({required this.copy, required this.dispute});

  final DisputeStatusL10n copy;
  final DisputeStatus dispute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = dispute.isResolved;
    final color = resolved ? theme.colorScheme.primary : theme.colorScheme.tertiary;
    return Semantics(
      identifier: 'dispute_status_state',
      container: true,
      child: Row(
        children: [
          Icon(
            resolved ? Icons.check_circle_outline : Icons.hourglass_top_outlined,
            color: color,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              resolved ? copy.resolvedLabel : copy.openLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    final amount = _formattedAmount(dispute);
    final resolved = dispute.isResolved;
    return Semantics(
      identifier: 'dispute_status_outcome_note',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.outcomeHeading,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            // Resolved → the refund/penalty outcome line (D2); open → the
            // pending-outcome body (the dispute is still under review).
            resolved
                ? copy.outcomeLine(dispute.outcome, amount: amount)
                : copy.openBody,
            style: theme.textTheme.bodyMedium,
          ),
          if (dispute.note != null && dispute.note!.isNotEmpty) ...[
            const SizedBox(height: Spacing.small),
            Text(dispute.note!, style: theme.textTheme.bodySmall),
          ],
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
    final theme = Theme.of(context);
    final lines = <Widget>[];

    void addLine(IconData icon, String text) {
      lines.add(Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: Sizes.medium, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: Spacing.small),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ));
    }

    final reason = evidence.reason;
    if (reason != null && reason.isNotEmpty) {
      addLine(Icons.flag_outlined, copy.reasonLabel(reason));
    }
    final comment = evidence.comment;
    if (comment != null && comment.isNotEmpty) {
      addLine(Icons.notes_outlined, '${copy.evidenceCommentLabel}: $comment');
    }
    if (evidence.photoCount > 0) {
      addLine(Icons.photo_outlined, copy.photosLabel(evidence.photoCount));
    }
    if (evidence.hasVoice) {
      addLine(Icons.mic_none_outlined, copy.voiceLabel);
    }
    if (evidence.hasChatSnapshot) {
      addLine(Icons.chat_bubble_outline, copy.chatLabel(evidence.chatMessageCount));
    }
    if (evidence.timelineCount > 0) {
      addLine(Icons.timeline_outlined, copy.timelineLabel(evidence.timelineCount));
    }

    return Semantics(
      identifier: 'dispute_status_evidence_summary',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.evidenceHeading,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.small),
          ...lines,
        ],
      ),
    );
  }
}
