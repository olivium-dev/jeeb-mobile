import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/widgets/directional_icons.dart';
import '../application/reviews_cubit.dart';
import '../application/reviews_state.dart';
import '../data/empty_reviews_repository.dart';
import '../domain/reviews_repository.dart';
import 'reviews_l10n.dart';
import 'widgets/review_row.dart';

/// reviews-list (JM-068). The full "All reviews" list reached from
/// `profile_view_all_reviews` on jeeber-profile-reviews (JM-067), at
/// `/profile/delivery-man/reviews?jeeberId=` (the integrator-registered route).
///
/// Renders the canonical 4-state machine (40_GUARDRAILS_ARCH §3; the D30
/// contract, 42_GUARDRAILS_MOCK §5.1): loading (full-screen skeletons, D73) /
/// failed (inline error + retry) / loaded(+empty). On the loaded list a
/// scroll-end fetches the next page and appends it (infinite scroll, D73), with
/// an in-list skeleton footer while a page is on the wire and a soft, retryable
/// footer when it fails.
///
/// D-decisions wired:
///  - D58 — reviewer FIRST NAME only (`review_<id>_reviewer_name`).
///  - D59 — cold-start (< 5 ratings): the aggregate score is HIDDEN, a "New"
///    badge (`reviews_new_badge`) + hidden-score note (`reviews_hidden_score_note`)
///    show instead; the individual rows still render.
///  - D27 — every row carries `review_<id>_report_cta`; a tap confirms then
///    POSTs the report (one-shot snackbar).
///  - D57 — NO Helpful/Reply controls on the rows (immutable reviews) — enforced
///    in [ReviewRow] (`showActions: false`).
///
/// Data: reads the jeeber's reviews via `sl<ReviewsRepository>()` — the
/// INTEGRATOR-STUB today (R1m wired in `DioReviewsRepository`, swapped in DI once
/// verified on :4010, 42_GUARDRAILS_MOCK "FINAL WAVE … R1m"). [repository] is a
/// constructor test seam (§5.4); an unconfigured GetIt (router-resolution widget
/// tests) falls back to an empty repo (mirrors JM-055/JM-057).
///
/// Semantics identifiers exposed (EXACT — 30_BACKLOG JM-068, 67_W34_TEST_PLAN
/// §JM-068, 41_GUARDRAILS_TESTING):
///   `reviews_root`                 — screen host container (nav target)
///   `reviews_loading`              — first-load skeleton state (D30/D73)
///   `reviews_error`                — cold-load failure (D30)
///   `reviews_retry_cta`            — retry the cold load (D30)
///   `reviews_empty`                — loaded + no rows (D30)
///   `reviews_new_badge`            — cold-start New badge (D59)
///   `reviews_hidden_score_note`    — cold-start <5 hidden-score note (D59)
///   `review_<id>_reviewer_name`    — per-row first-name attribution (D58)
///   `review_<id>_report_cta`       — per-row report (dynamic id, D27)
///   `reviews_load_more`            — in-list next-page skeleton (D73 infinite)
///   `reviews_back`                 — → jeeber-profile-reviews
// ORPHAN (JEBV4-227, verified 2026-07-12): path-param route twin, zero callsites (query-param twin is live) — see docs/project-understanding/reconciliation/orphans.md
class ReviewsListScreen extends StatelessWidget {
  const ReviewsListScreen({
    super.key,
    this.jeeberId,
    this.repository,
    this.authTokenStore,
  });

  /// The jeeber whose reviews are listed (from `?jeeberId=` when present). When
  /// null/empty the screen resolves the REAL authenticated session user's own
  /// id (the jeeber viewing their own reviews) so a deep-link / cold-start (no
  /// `extra`) still renders content (R-F) — NEVER a hardcoded `user-jeeber-002`
  /// fixture id (S0-OAD-03).
  final String? jeeberId;

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final ReviewsRepository? repository;

  /// Session/auth source for the cold-deep-link id resolution. Test seam —
  /// defaults to the real [AuthTokenStore].
  final AuthTokenStore? authTokenStore;

  /// Resolves the repo: an explicit override (tests) → the registered DI binding
  /// → an empty fallback when GetIt is not configured (router-resolution widget
  /// tests). Mirrors `WalletActivityListScreen._resolveRepository()`.
  ReviewsRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<ReviewsRepository>()) {
      return sl<ReviewsRepository>();
    }
    return const EmptyReviewsRepository();
  }

  Widget _buildFor(String resolvedJeeberId) => BlocProvider<ReviewsCubit>(
        create: (_) => ReviewsCubit(
          repository: _resolveRepository(),
          jeeberId: resolvedJeeberId,
        )..load(),
        child: const _ReviewsView(),
      );

  @override
  Widget build(BuildContext context) {
    final explicit = jeeberId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      // `?jeeberId=` present — view that jeeber's public reviews directly.
      return _buildFor(explicit);
    }
    // No `?jeeberId=` (cold deep-link): resolve the REAL authenticated session
    // user's own reviews from the auth source — never a hardcoded fixture id.
    return FutureBuilder<String?>(
      future: (authTokenStore ?? AuthTokenStore()).userId,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: OmdsLoadingState()));
        }
        return _buildFor((snapshot.data ?? '').trim());
      },
    );
  }
}

class _ReviewsView extends StatelessWidget {
  const _ReviewsView();

  @override
  Widget build(BuildContext context) {
    final copy = ReviewsL10n.of(context);
    return Semantics(
      identifier: 'reviews_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: copy.title,
          // EDGE: reviews-list → jeeber-profile-reviews (back). The asserted
          // `reviews_back` node is the leading affordance (21_NAV_PLAN §C,
          // JM-068). pop() returns to the profile that pushed us; on a cold
          // deep-link (no history) fall back to the shell root.
          leading: Semantics(
            identifier: 'reviews_back',
            button: true,
            child: IconButton(
              icon: Icon(DirectionalIcons.back(context)),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
          ),
        ),
        body: BlocConsumer<ReviewsCubit, ReviewsState>(
          // One-shot report side-effect (D27): fire a single snackbar when a
          // report finishes, then acknowledge so a rebuild doesn't replay it
          // (40_GUARDRAILS_ARCH §3 nav/side-effects in listener, never builder).
          listenWhen: (p, n) =>
              p.reportStatus != n.reportStatus &&
              (n.reportStatus == ReportStatus.succeeded ||
                  n.reportStatus == ReportStatus.failed),
          listener: (context, state) {
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  state.reportStatus == ReportStatus.succeeded
                      ? copy.reportSuccess
                      : copy.reportFailure,
                ),
              ),
            );
            context.read<ReviewsCubit>().acknowledgeReport();
          },
          builder: (context, state) {
            switch (state.status) {
              case ReviewsStatus.initial:
              case ReviewsStatus.loading:
                return _LoadingSkeletons(copy: copy);
              case ReviewsStatus.failed:
                return _ErrorBody(
                  message: _errorCopy(copy, state.error),
                  retryLabel: copy.retry,
                  onRetry: () => context.read<ReviewsCubit>().refresh(),
                );
              case ReviewsStatus.loaded:
                return RefreshIndicator(
                  onRefresh: () => context.read<ReviewsCubit>().refresh(),
                  child: !state.hasReviews
                      ? _EmptyBody(copy: copy)
                      : _LoadedList(state: state, copy: copy),
                );
            }
          },
        ),
      ),
    );
  }

  static String _errorCopy(ReviewsL10n copy, ReviewsFailure? f) {
    switch (f) {
      case ReviewsFailure.network:
        return copy.networkError;
      case ReviewsFailure.notFound:
      case ReviewsFailure.unauthorized:
      case ReviewsFailure.unknown:
      case null:
        return copy.loadError;
    }
  }
}

/// Cold-load failure (D30). Renders the error message in the asserted
/// `reviews_error` node and the retry as a distinct `reviews_retry_cta` node (the
/// D30 `<screen>_retry_cta` convention) — a custom layout (not `OmdsErrorState`)
/// so a flow can assert the error AND tap the retry by id (the OMDS widget merges
/// its internal retry button into one node). Mirrors JM-055.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'reviews_error',
              container: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'reviews_retry_cta',
              button: true,
              container: true,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First-load skeletons (D73 — never a bare spinner on a list, 42 §5.1). Hosts
/// the asserted `reviews_loading` state node.
class _LoadingSkeletons extends StatelessWidget {
  const _LoadingSkeletons({required this.copy});

  final ReviewsL10n copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'reviews_loading',
      container: true,
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
        itemCount: 6,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: Spacing.medium,
          endIndent: Spacing.medium,
        ),
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: OmdsListItemShimmer(hasTrailing: false),
        ),
      ),
    );
  }
}

/// Empty = `loaded` + an empty list (NOT a fifth status, §3). Wrapped in a
/// scrollable so pull-to-refresh still works on an empty list.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.copy});

  final ReviewsL10n copy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Semantics(
          identifier: 'reviews_empty',
          container: true,
          child: OmdsEmptyState(
            icon: Icons.reviews_outlined,
            title: copy.emptyTitle,
            subtitle: copy.emptyBody,
          ),
        ),
      ],
    );
  }
}

/// The aggregate header above the rows. D59: when cold-start (< 5 ratings) the
/// numeric score is HIDDEN — a "New" badge (`reviews_new_badge`) + the
/// hidden-score note (`reviews_hidden_score_note`) show instead; otherwise the
/// rounded average + count render.
class _AggregateHeader extends StatelessWidget {
  const _AggregateHeader({required this.state, required this.copy});

  final ReviewsState state;
  final ReviewsL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.coldStart || state.averageScore == null) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.medium,
          Spacing.medium,
          Spacing.medium,
          Spacing.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: 'reviews_new_badge',
              child: OmdsChip(
                label: copy.newBadge,
                icon: Icon(
                  Icons.auto_awesome,
                  size: Sizes.small,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Semantics(
              identifier: 'reviews_hidden_score_note',
              child: Text(
                copy.hiddenScoreNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.medium,
        Spacing.medium,
        Spacing.small,
      ),
      child: Row(
        children: [
          Icon(Icons.star, size: Sizes.medium, color: theme.colorScheme.primary),
          const SizedBox(width: Spacing.xSmall),
          Semantics(
            identifier: 'reviews_aggregate',
            child: Text(
              copy.aggregate(state.averageScore!, state.reviewCount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The loaded list with infinite scroll. A [ScrollController] near-bottom trigger
/// fetches the next page (the cubit single-flights + de-dupes); the footer shows
/// a load-more skeleton while a page is in flight, or a soft retry when it fails
/// (D73 / D30). The aggregate header is the first sliver via a header slot.
class _LoadedList extends StatefulWidget {
  const _LoadedList({required this.state, required this.copy});

  final ReviewsState state;
  final ReviewsL10n copy;

  @override
  State<_LoadedList> createState() => _LoadedListState();
}

class _LoadedListState extends State<_LoadedList> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// Fetch the next page when within ~400px of the end. The cubit no-ops when
  /// there is no further page or a fetch is already in flight, so it is safe to
  /// fire repeatedly during a fling.
  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<ReviewsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final copy = widget.copy;
    final reviews = state.reviews;
    final showFooter =
        state.loadingMore || state.loadMoreError || state.hasMore;
    // index 0 = aggregate header; then the rows; then an optional footer slot.
    const headerCount = 1;
    final itemCount = headerCount + reviews.length + (showFooter ? 1 : 0);

    return ListView.separated(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.large),
      itemCount: itemCount,
      separatorBuilder: (_, index) {
        // No divider under the header or above the footer slot.
        if (index < headerCount) return const SizedBox.shrink();
        if (index >= headerCount + reviews.length - 1) {
          return const SizedBox.shrink();
        }
        return const Divider(
          height: 1,
          indent: Spacing.medium,
          endIndent: Spacing.medium,
        );
      },
      itemBuilder: (context, index) {
        if (index < headerCount) {
          return _AggregateHeader(state: state, copy: copy);
        }
        final rowIndex = index - headerCount;
        if (rowIndex >= reviews.length) {
          return _Footer(state: state, copy: copy);
        }
        final review = reviews[rowIndex];
        return ReviewRow(
          review: review,
          copy: copy,
          onReport: () => _confirmReport(context, review.id),
        );
      },
    );
  }

  /// D27 — confirm, then POST the report. The confirm dialog + cubit call live in
  /// this gesture callback (an explicit user gesture), never in a `builder`
  /// (40_GUARDRAILS_ARCH §3). The one-shot result snackbar fires from the
  /// screen's `BlocConsumer.listener`.
  Future<void> _confirmReport(BuildContext context, String reviewId) async {
    if (reviewId.isEmpty) return;
    final copy = widget.copy;
    final cubit = context.read<ReviewsCubit>();
    // OmdsConfirmationDialog pops itself with `true`/`false` (its buttons call
    // `Navigator.pop(<result>)` internally), so we read the result directly and
    // do NOT pass popping `onConfirm`/`onCancel` (that would double-pop).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => OmdsConfirmationDialog(
        title: copy.reportConfirmTitle,
        content: copy.reportConfirmBody,
        confirmText: copy.reportConfirmCta,
        cancelText: copy.reportCancelCta,
      ),
    );
    if (confirmed == true) {
      await cubit.reportReview(reviewId);
    }
  }
}

/// The infinite-scroll footer: a load-more skeleton while the next page is on the
/// wire (`reviews_load_more`, D73), or a soft retry when it failed. Mirrors
/// JM-055.
class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.copy});

  final ReviewsState state;
  final ReviewsL10n copy;

  @override
  Widget build(BuildContext context) {
    if (state.loadMoreError) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.medium,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                copy.loadMoreError,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: Spacing.small),
            Semantics(
              identifier: 'reviews_load_more_retry',
              button: true,
              container: true,
              child: TextButton(
                onPressed: () => context.read<ReviewsCubit>().retryLoadMore(),
                child: Text(copy.retry),
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      identifier: 'reviews_load_more',
      container: true,
      child: const Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: OmdsListItemShimmer(hasTrailing: false),
      ),
    );
  }
}
