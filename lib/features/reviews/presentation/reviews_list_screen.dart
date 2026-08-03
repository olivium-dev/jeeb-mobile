import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_system_chip.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
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
///
/// redesign-2026-08 (no board render — screen 15 `15-mutual-rating` is the
/// adjacent reference): a re-skin onto the Jeeb kit, not a product change. The
/// `OMDSAppBar` became an in-body [JeebTopBar] (so the header renders in EVERY
/// state, the wallet-hub idiom), the divider-separated `OmdsReviewCard` rows
/// became outlined [JeebOutlinedCard]s on a 24px gutter with an 12px rhythm,
/// the D59 badge/note pair became a [JeebSystemChip] + [JeebInfoNote], and the
/// error/retry pair became a [JeebInfoNote] + [JeebCtaButton]. Every raw
/// `TextStyle` now resolves through `context.jeebText`. All 11 identifiers are
/// unmoved and the 4-state machine, pagination and D27 confirm flow are byte
/// -for-byte the same behaviour.
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
        // The board's header is an in-body row, not a Material app bar, so it
        // renders in EVERY state (loading / failed / loaded) — the wallet-hub
        // idiom. `identifier` lands on the kit's leading circle, which is the
        // frozen `<screen>_back` contract (03-WAVE1-KIT §1.1).
        body: SafeArea(
          child: Column(
            children: [
              JeebTopBar(
                // EDGE: reviews-list → jeeber-profile-reviews (back). The
                // asserted `reviews_back` node is the leading affordance
                // (21_NAV_PLAN §C, JM-068). pop() returns to the profile that
                // pushed us; on a cold deep-link (no history) fall back to the
                // shell root.
                identifier: 'reviews_back',
                title: copy.title,
                onLeadingPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(child: _body(context, copy)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ReviewsL10n copy) {
    return BlocConsumer<ReviewsCubit, ReviewsState>(
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
            return const _LoadingSkeletons();
          case ReviewsStatus.failed:
            return _ErrorBody(
              message: _errorCopy(copy, state.error),
              retryLabel: copy.retry,
              onRetry: () => context.read<ReviewsCubit>().refresh(),
            );
          case ReviewsStatus.loaded:
            // `OmdsPullToRefresh`, not a raw `RefreshIndicator` — the house
            // wrapper the order-history / wallet lists use, and what
            // `tool/check_design_tokens.sh` gates on.
            return OmdsPullToRefresh(
              onRefresh: () => context.read<ReviewsCubit>().refresh(),
              child: !state.hasReviews
                  ? _EmptyBody(copy: copy)
                  : _LoadedList(state: state, copy: copy),
            );
        }
      },
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

/// The board gutter (24) for every band on this screen, with the 16px first
/// block below the top bar and a 24px tail under the last card.
const EdgeInsetsGeometry _kListPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.xLarge,
);

/// Cold-load failure (D30). Renders the error message in the asserted
/// `reviews_error` node and the retry as a distinct `reviews_retry_cta` node (the
/// D30 `<screen>_retry_cta` convention) — a custom layout (not `OmdsErrorState`)
/// so a flow can assert the error AND tap the retry by id (the OMDS widget merges
/// its internal retry button into one node). Mirrors JM-055.
///
/// redesign-2026-08: the 64px red glyph slab became the kit's error note — the
/// soft `errorContainer` tint the migration's error family was added for — over
/// a navy retry pill. Same two nodes, same behaviour.
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
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            JeebInfoNote.error(
              identifier: 'reviews_error',
              icon: Icons.error,
              text: message,
            ),
            const SizedBox(height: Spacing.large),
            JeebCtaButton.primary(
              identifier: 'reviews_retry_cta',
              label: retryLabel,
              leadingIcon: Icons.refresh,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// First-load skeletons (D73 — never a bare spinner on a list, 42 §5.1). Hosts
/// the asserted `reviews_loading` state node.
///
/// redesign-2026-08: the shimmers now sit in the same outlined cards the loaded
/// rows use, so the list does not re-flow its own geometry when the page lands.
class _LoadingSkeletons extends StatelessWidget {
  const _LoadingSkeletons();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'reviews_loading',
      container: true,
      child: ListView.separated(
        padding: _kListPadding,
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
        itemBuilder: (_, _) => const JeebOutlinedCard(
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
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (state.coldStart || state.averageScore == null) {
      // The badge is a settled fact about the jeeber, not a live/expiring one,
      // so it takes the filled system tone — orange stays rationed.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JeebSystemChip.filled(
            identifier: 'reviews_new_badge',
            label: copy.newBadge,
            center: false,
          ),
          const SizedBox(height: Spacing.small),
          // `.outlined` (brown 1.5px, periwinkle body) — byte-for-byte the
          // treatment 15's blind-reveal note uses, so the two rating surfaces
          // explain themselves the same way.
          JeebInfoNote.outlined(
            identifier: 'reviews_hidden_score_note',
            icon: Icons.auto_awesome,
            text: copy.hiddenScoreNote,
          ),
        ],
      );
    }
    return Row(
      children: [
        // Navy, never `starRatingColor`: §4.1 rations the warm ink, and this
        // aggregate is the same meta line `delivery_man_profile_header` draws.
        Icon(Icons.star, size: Sizes.large, color: scheme.primary),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Semantics(
            identifier: 'reviews_aggregate',
            child: Text(
              copy.aggregate(state.averageScore!, state.reviewCount),
              style: context.jeebText.titleProminent
                  .copyWith(color: scheme.primary),
            ),
          ),
        ),
      ],
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
      padding: _kListPadding,
      itemCount: itemCount,
      // R7/R12: the card outlines ARE the separation — a divider between two
      // outlined cards draws a third line nobody asked for. The header keeps
      // the wider block rhythm below it; the cards sit on the 12px list gap.
      separatorBuilder: (_, index) => SizedBox(
        height: index < headerCount ? Spacing.large : Spacing.small,
      ),
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
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              copy.loadMoreError,
              style: context.jeebText.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: Spacing.xSmall),
          JeebCtaButton.text(
            identifier: 'reviews_load_more_retry',
            label: copy.retry,
            labelStyle: context.jeebText.bodySmall,
            contentPadding: EdgeInsetsDirectional.zero,
            onTap: () => context.read<ReviewsCubit>().retryLoadMore(),
          ),
        ],
      );
    }
    return Semantics(
      identifier: 'reviews_load_more',
      container: true,
      child: const JeebOutlinedCard(
        child: OmdsListItemShimmer(hasTrailing: false),
      ),
    );
  }
}
