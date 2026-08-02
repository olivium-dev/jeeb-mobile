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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/dispute_status/dispute_status_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so four things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so each card shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes a background and the
//    `SafeArea`. That is the same nesting the Screen Catalog produces. The box
//    is therefore a real device ([_disputeStatusScreenPhoneBox], 390x844, plus
//    the 320x568 [_disputeStatusScreenCompactBox]) rather than the harness
//    default 390x200 — a scrolling column of three cards and two CTAs cannot be
//    judged in a 200 pt strip. The width is pinned in the TREE as well as in
//    `size:`, so the render tests measure the same phone instead of the 800 pt
//    test surface.
//
// 2. Every card is frozen with `TickerMode(enabled: false)`. The cold-read
//    state is an `OmdsLoadingState`, i.e. an indeterminate
//    `CircularProgressIndicator` that schedules frames forever, and
//    `pumpAndSettle` waits for frames to STOP being scheduled. Muting the
//    tickers paints a deterministic `t = 0` frame and lets the suite settle.
//
// 3. Every state is pinned by a CAPTION rather than by screen copy — see
//    [DisputeStatusScreenCaptions]. Four of these previews have nothing of
//    their own to pin: the cold read paints no text at all, the empty-evidence
//    card is copy-identical to the reference open dispute, the two blank-id
//    cards render the same error page (which is the finding), and the compact
//    card is the longest-content card at a different width. The render test's
//    `preview specifics` group then asserts the real state behind every
//    caption, so the caption is never the whole proof.
//
// 4. The states come from
//    `lib/devtool/catalog/fixtures/dispute_status_screen_fixtures.dart`, shared
//    with the Screen Catalog entry (`devtool/catalog/entries/batch_03_entries.dart`),
//    which used to own a private copy of the same fake repository and three
//    inline `DisputeStatus` literals. Nothing here resolves DI and no preview
//    passes a real repository — every one drives the shipped `repository:` seam
//    with a local fake — so these are network-free by construction rather than
//    by the guard in [jeebPreviewHost].
//
// The one thing NOT reproduced is a router. `dispute_status_support` and
// `dispute_status_back` both call `context.goNamed`, and there is no [GoRouter]
// above a preview card, so both CTAs are inert here. They are still rendered,
// because whether they are OFFERED in a given state is most of what these cards
// are for.
//
// ## What these previews exposed in the screen
//
//  * **The evidence card renders a heading over nothing.** `_EvidenceCard`
//    builds its `lines` conditionally and then always emits the
//    "Evidence summary" title above them, so a dispute with no attachments —
//    `Open · no evidence attached`, and every dispute the service returns
//    before the evidence POST lands — shows a section header with empty space
//    under it and no explanation. `DisputeEvidenceSummary.hasAny` exists in the
//    domain for exactly this decision and nothing on this screen reads it.
//  * **An unparsed wire status is presented as "Open — under review".**
//    `_StateCard` branches on `dispute.isResolved`, which is
//    `state == DisputeState.resolved` — so [DisputeState.unknown] takes the
//    else branch and gets the open label, the warning hourglass and the
//    "We're reviewing your dispute" body. `DioDisputeStatusRepository._state()`
//    returns `unknown` for ANY status it does not enumerate (`escalated`,
//    `withdrawn`, a missing field), so `Unknown wire state` is the screen
//    asserting something it was never told.
//  * **Retry on a blank id is a dead button.** `DisputeStatusCubit.refresh()`
//    opens with `if (disputeId.trim().isEmpty) return;` — the same guard
//    `load()` uses — so the ONE affordance the error page offers cannot fire.
//    `Blank id · Retry cannot fire` puts a resolved dispute behind a recording
//    repository and the id never reaches it, on mount or on tap; the render
//    test asserts the recorded call list is still empty afterwards. It renders
//    pixel-identically to `Error · not found`, which is the point: a healthy
//    read and a broken one produce the same dead end.
//  * **A 401 is indistinguishable from "something went wrong".**
//    `_ErrorBody._message` folds [DisputeStatusFailure.unauthorized] in with
//    `unknown` and `null`, so an expired session reads "Could not load this
//    dispute." over a Retry that will 401 again forever. Nothing routes to a
//    re-authentication.
//  * **Nothing on the loaded screen says WHICH dispute it is.** No id, no order
//    reference, no opened-at, no resolved-at — `DisputeStatus` carries
//    `orderRef`, `createdAt` and `resolvedAt` and the body renders none of
//    them. `orderRef` is read only to seed the support form. Two disputes on
//    the same order with different outcomes are the same picture, which is also
//    why every fixture here has to vary its evidence set to be
//    distinguishable.
//  * **"Back to chat" does not always go to chat.** The CTA label is a
//    constant while `_DisputeStatusView._back` falls back to `context.pop()`
//    and then to `context.go('/')` when the dispute carries no chat ref. The
//    honest fallback is right; the promise above it is not conditional on it.
//  * **A refund amount can render with no currency.** `_formattedAmount`
//    returns the bare figure when `currency` is null, and the Dio parser reads
//    the two fields independently — so `Longest content` shows
//    "A refund of 1234.50 was issued to you." with no unit anywhere.
//  * **The back-office note can be printed twice.**
//    `DioDisputeStatusRepository` maps `note` onto BOTH `DisputeStatus.note`
//    and `evidence.comment` (the latter via `comment ?? note`), so any payload
//    carrying `note` and no `comment` renders the same paragraph under the
//    outcome and again as "Your note: …" in the evidence summary. Visible in
//    `Longest content`; pinned by the render test.
//  * **The cold read is a bare spinner with no copy and no way out.**
//    `_LoadingBody` is `Center(child: OmdsLoadingState())` with no `message:`,
//    and the support CTA lives in the loaded body — so for as long as the fetch
//    takes there is no text, no skeleton, no timeout and no route to support.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _disputeStatusScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _disputeStatusScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see note 3 in the section prose. Dev chrome, never shipped copy, so
/// they are deliberately un-localized and rendered LTR at a fixed text scale.
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
///
/// `TickerMode(enabled: false)` mutes the indeterminate spinner — see note 2 in
/// the section prose. The `SizedBox` pins the device width the layout is
/// designed against; height is pinned too, but a render surface shorter than
/// [box] enforces its own, so only the width is exact in tests. The screen
/// keeps its own `Scaffold`; nothing here substitutes for it.
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
        // latin line and the 200% card does not spend a third of the device on
        // a label.
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
///
/// Every element of the loaded body is present at once — the warning-coloured
/// state row, the pending-outcome note (JM-065 AC1: the outcome card renders
/// for an OPEN dispute too), five evidence lines, and both CTAs.
///
/// Matrixed because the evidence lines are `Row`s of a leading icon and an
/// `Expanded` text: AR has to mirror all six of them together, and 200% is
/// where a one-line summary becomes a three-line one and the CTAs leave the
/// fold.
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
///
/// The only fixture that has both, and therefore the only card where the
/// outcome line reads as money rather than as a number — read it beside
/// `Longest content`, where the same code path drops the unit.
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
///
/// `refundAmount` is null — the ordinary case, since the money moved on the
/// other side — so `outcomeLine` drops to its amount-less form. This card also
/// carries a back-office `note`, which renders as a second paragraph under the
/// outcome; that slot is otherwise invisible.
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
///
/// `_EvidenceCard` emits its heading unconditionally and its lines
/// conditionally, so this is "Evidence summary" over blank space — no
/// "nothing attached yet" line, no affordance to attach one, and no hint that
/// the section is complete rather than still loading. The domain already
/// exposes `DisputeEvidenceSummary.hasAny`; nothing here reads it.
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
///
/// Every dispute opens here. `_LoadingBody` is a bare centred spinner — no
/// message, no skeleton, no timeout — and the support CTA lives inside the
/// loaded body, so a slow read leaves the user with nothing to read and nothing
/// to tap for as long as it takes.
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
///
/// [DisputeStatusFailure.network] is the only branch of `_ErrorBody._message`
/// that tells the user what to do about it ("Check your network and try
/// again"), and the only one where Retry can actually succeed.
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
///
/// The blank id is what actually produces the failure — `load()` short-circuits
/// to `notFound` before any repository is consulted — so this is the deep-link
/// and notification-payload case rather than a 404 from the service.
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
///
/// `_ErrorBody._message` folds `unauthorized` in with `unknown`, so the user is
/// told "Could not load this dispute." and offered a Retry that will fail the
/// same way every time. Nothing on this page can recover an expired session.
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
///
/// Identical on screen to `Error · not found`, deliberately: the difference is
/// that this one had somewhere to go. `refresh()` short-circuits on the same
/// blank-id guard as `load()`, so the Retry button never issues a read — the
/// render test asserts the recording repository's call list is still empty
/// after the tap.
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
///
/// `DioDisputeStatusRepository._state()` maps anything outside its five known
/// strings to [DisputeState.unknown], and `_StateCard` asks only
/// `dispute.isResolved` — so an escalated or withdrawn dispute is shown as
/// actively under review, with the reassuring body to match.
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
///
/// A 242-character back-office note printed TWICE (once under the outcome, once
/// as "Your note: …", because the Dio parser maps `note` onto both
/// `DisputeStatus.note` and `evidence.comment`), a refund amount with no
/// currency beside it, five photos, a 142-message chat snapshot and an 18-step
/// timeline. Nothing clamps: the column grows and the `ListView` absorbs it,
/// which is the right failure mode and also why this is invisible without a
/// device-sized canvas.
///
/// Matrixed because the EN-light reading stays plausible long after AR and 200%
/// have run out of room.
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
///
/// Nothing on this screen is pinned outside the scroll view — the app bar is
/// the only fixed chrome — so a short device costs reach rather than layout:
/// both CTAs move below the fold and there is no scrollbar, fade or shadow to
/// say so.
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
