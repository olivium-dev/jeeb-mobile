import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../application/dispute_status_cubit.dart';
import '../application/dispute_status_state.dart';
import '../data/empty_dispute_status_repository.dart';
import '../domain/dispute_status_repository.dart';
import 'dispute_status_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/dispute_status_screen_fixtures.dart';

class DisputeStatusScreen extends StatelessWidget {
  const DisputeStatusScreen({
    super.key,
    required this.disputeId,
    this.repository,
  });

  final String disputeId;

  final DisputeStatusRepository? repository;

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
        _OutcomeCard(copy: copy, dispute: dispute),
        const SizedBox(height: Spacing.large),
        _EvidenceCard(copy: copy, evidence: dispute.evidence),
        const SizedBox(height: Spacing.xLarge),
        Semantics(
          identifier: 'dispute_status_support',
          button: true,
          container: true,
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
          child: TextButton(
            onPressed: () => _DisputeStatusView._back(context),
            child: Text(copy.backCta),
          ),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.copy, required this.dispute});

  final DisputeStatusL10n copy;
  final DisputeStatus dispute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = dispute.isResolved;
    final roles = context.jeebRoles;
    final color = resolved ? roles.success : roles.warning;
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _disputeStatusScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _disputeStatusScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they
final class DisputeStatusScreenCaptions {
  DisputeStatusScreenCaptions._();

  /// The reference reading: under review, evidence attached.
  static const String openUnderReview = 'preview · open · full evidence set';

  /// Resolved with a refund, amount AND currency present.
  static const String resolvedRefund = 'preview · resolved · refund + currency';

  /// Resolved with a penalty and no amount on the wire.
  static const String resolvedPenalty = 'preview · resolved · penalty, no sum';

  /// The empty state: an evidence heading with nothing under it.
  static const String openNoEvidence = 'preview · open · NO evidence attached';

  /// The fetch is on the wire and nothing has come back.
  static const String coldRead = 'preview · cold read · fetch in flight';

  /// Offline / service unreachable.
  static const String networkFailure = 'preview · error · network';

  /// The shipped fallback repository behind a blank id.
  static const String notFoundFallback = 'preview · error · not found';

  /// A 401/403, folded into the generic error copy.
  static const String sessionExpired = 'preview · error · session expired';

  /// A blank id in front of a repository that would have answered.
  static const String blankIdRetryInert =
      'preview · blank id · Retry cannot fire';

  /// A wire status the parser did not recognize.
  static const String unknownWireState =
      'preview · unknown wire state · shown as Open';

  /// Every string at its longest plausible length.
  static const String longestContent = 'preview · longest content';

  /// The same content on the narrowest supported device.
  static const String compact = 'preview · longest content · 320x568 viewport';
}

/// Mounts the real screen on one shared designed state, framed, captioned and
/// frozen.
Widget _disputeStatusScreenHosted(
  DisputeStatusScreenDesignedState state,
  String caption, {
  Size box = _disputeStatusScreenPhoneBox,
}) {
  return TickerMode(
    enabled: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DisputeStatusScreenCaption(caption: caption),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: DisputeStatusScreen(
                disputeId: state.disputeId,
                repository: state.repository,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The dev-chrome line painted above each device frame.
class _DisputeStatusScreenCaption extends StatelessWidget {
  const _DisputeStatusScreenCaption({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      child: Text(
        caption,
        // Dev chrome: LTR and unscaled, so the AR card still reads it as one
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The reference reading: a dispute under review with the full D53 evidence set
/// behind it.
@JeebPreview(
  group: 'dispute_status',
  name: 'Open · under review',
  size: _disputeStatusScreenPhoneBox,
  matrix: true,
)
Widget disputeStatusScreenOpenUnderReview() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.openUnderReview,
      DisputeStatusScreenCaptions.openUnderReview,
    );

/// Resolved in the customer's favour: the D2 refund line with both an amount
/// and a currency.
@JeebPreview(
  group: 'dispute_status',
  name: 'Resolved · refund issued',
  size: _disputeStatusScreenPhoneBox,
)
Widget disputeStatusScreenResolvedRefund() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.resolvedRefund,
      DisputeStatusScreenCaptions.resolvedRefund,
    );

/// The other D2 outcome: a penalty applied to the jeeber, with no figure.
/// `refundAmount` is null — the ordinary case, since the money moved on the
@JeebPreview(
  group: 'dispute_status',
  name: 'Resolved · penalty, no amount',
  size: _disputeStatusScreenPhoneBox,
)
Widget disputeStatusScreenResolvedPenalty() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.resolvedPenalty,
      DisputeStatusScreenCaptions.resolvedPenalty,
    );

/// The EMPTY state: an open dispute with nothing attached to it.
/// `_EvidenceCard` emits its heading unconditionally and its lines
@JeebPreview(
  group: 'dispute_status',
  name: 'Open · no evidence attached',
  size: _disputeStatusScreenPhoneBox,
)
Widget disputeStatusScreenOpenNoEvidence() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.openNoEvidence,
      DisputeStatusScreenCaptions.openNoEvidence,
    );

/// Cold start: the fetch is in flight and nothing has come back.
/// Every dispute opens here. `_LoadingBody` is a bare centred spinner — no
@JeebPreview(
  group: 'dispute_status',
  name: 'Loading · cold read',
  size: _disputeStatusScreenPhoneBox,
)
Widget disputeStatusScreenColdRead() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.coldRead,
      DisputeStatusScreenCaptions.coldRead,
    );

/// The D30 error page with the one failure that names itself.
/// [DisputeStatusFailure.network] is the only branch of `_ErrorBody._message`
@JeebPreview(
  group: 'dispute_status',
  name: 'Error · network',
  size: _disputeStatusScreenPhoneBox,
)
Widget disputeStatusScreenNetworkFailure() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.networkFailure,
      DisputeStatusScreenCaptions.networkFailure,
    );

/// The Screen Catalog's error card: the shipped fallback repository behind a
/// blank id.
@JeebPreview(
  group: 'dispute_status',
  name: 'Error · not found',
  size: _disputeStatusScreenPhoneBox,
)
Widget disputeStatusScreenNotFound() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.notFoundFallback,
      DisputeStatusScreenCaptions.notFoundFallback,
    );

/// A 401/403 — the session expired while the screen was opening.
/// `_ErrorBody._message` folds `unauthorized` in with `unknown`, so the user is
@JeebPreview(
  group: 'dispute_status',
  name: 'Error · session expired',
  size: _disputeStatusScreenPhoneBox,
)
Widget disputeStatusScreenSessionExpired() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.sessionExpired,
      DisputeStatusScreenCaptions.sessionExpired,
    );

/// A blank id in front of a repository holding a perfectly good dispute.
/// Identical on screen to `Error · not found`, deliberately: the difference is
@JeebPreview(
  group: 'dispute_status',
  name: 'Blank id · Retry cannot fire',
  size: _disputeStatusScreenPhoneBox,
)
Widget disputeStatusScreenBlankIdRetryInert() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.blankIdWithLiveData,
      DisputeStatusScreenCaptions.blankIdRetryInert,
    );

/// A wire status the parser did not recognize, rendered as "Open — under
/// review".
@JeebPreview(
  group: 'dispute_status',
  name: 'Unknown wire state · shown as Open',
  size: _disputeStatusScreenPhoneBox,
)
Widget disputeStatusScreenUnknownWireState() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.unknownWireState,
      DisputeStatusScreenCaptions.unknownWireState,
    );

/// The longest plausible string on every axis at once — plus two defects the
/// production parser makes ordinary.
@JeebPreview(
  group: 'dispute_status',
  name: 'Longest content',
  size: _disputeStatusScreenPhoneBox,
  matrix: true,
)
Widget disputeStatusScreenLongestContent() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.longestContent,
      DisputeStatusScreenCaptions.longestContent,
    );

/// The same ceiling on the narrowest viewport the app supports.
/// Nothing on this screen is pinned outside the scroll view — the app bar is
@JeebPreview(
  group: 'dispute_status',
  name: 'Longest content · compact 320x568',
  size: _disputeStatusScreenCompactBox,
)
Widget disputeStatusScreenCompact() => _disputeStatusScreenHosted(
      DisputeStatusScreenFixtures.longestContent,
      DisputeStatusScreenCaptions.compact,
      box: _disputeStatusScreenCompactBox,
    );
