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

class ReviewsListScreen extends StatelessWidget {
  const ReviewsListScreen({
    super.key,
    this.jeeberId,
    this.repository,
    this.authTokenStore,
  });

  final String? jeeberId;

  final ReviewsRepository? repository;

  final AuthTokenStore? authTokenStore;

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
      return _buildFor(explicit);
    }
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
    const headerCount = 1;
    final itemCount = headerCount + reviews.length + (showFooter ? 1 : 0);

    return ListView.separated(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.large),
      itemCount: itemCount,
      separatorBuilder: (_, index) {
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

  Future<void> _confirmReport(BuildContext context, String reviewId) async {
    if (reviewId.isEmpty) return;
    final copy = widget.copy;
    final cubit = context.read<ReviewsCubit>();
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
