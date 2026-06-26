import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../application/search_cubit.dart';
import '../application/search_state.dart';
import '../data/empty_search_repository.dart';
import '../domain/search_repository.dart';
import 'search_l10n.dart';
import 'widgets/search_result_row.dart';

/// SearchResultsScreen (Sprint-5 Stream C) — runs the query handed over from
/// [SearchScreen] (`/search-results?q=`) and renders the 4-state machine
/// (40_GUARDRAILS_ARCH §3): loading / failed / loaded(+no-results). A row tap
/// dispatches the deep-link for its kind (order → delivery-detail; conversation
/// → chat-detail; unknown → no nav, AP-9 honesty). A refine search bar re-runs
/// the query in place.
///
/// Reads the LIVE gateway search via `sl<SearchRepository>()`
/// (DioSearchRepository). When `/v1/search` is absent the repo raises
/// [SearchFailure.unavailable] → an honest "search isn't available yet" empty
/// state (never a dead-end). [repository] is a constructor test seam (§5.4).
///
/// Semantics identifiers (EXACT):
///   `search_results_root`   — screen host container
///   `search_results_input`  — the refine search field
///   `search_result_<id>`    — per-result row (dynamic), tap → deep-link
class SearchResultsScreen extends StatelessWidget {
  const SearchResultsScreen({
    super.key,
    required this.query,
    this.repository,
  });

  /// The query forwarded from the compose screen / a deep link.
  final String query;

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final SearchRepository? repository;

  /// Resolves the repo: an explicit override (tests) → the registered LIVE
  /// [DioSearchRepository] → an inert fallback when GetIt is not configured
  /// (router-resolution widget tests). Mirrors `NotificationsListScreen`.
  SearchRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<SearchRepository>()) {
      return sl<SearchRepository>();
    }
    return const EmptySearchRepository();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SearchCubit>(
      create: (_) =>
          SearchCubit(repository: _resolveRepository())..search(query),
      child: const _SearchResultsView(),
    );
  }
}

class _SearchResultsView extends StatelessWidget {
  const _SearchResultsView();

  @override
  Widget build(BuildContext context) {
    final copy = SearchL10n.of(context);
    return Semantics(
      identifier: 'search_results_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: copy.resultsTitle,
          showBackButton: true,
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Spacing.medium),
                child: Semantics(
                  identifier: 'search_results_input',
                  container: true,
                  child: _RefineBar(copy: copy),
                ),
              ),
              const Expanded(child: _ResultsBody()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns its [TextEditingController] (seeded with the in-flight query) so the
/// field shows what was searched and can refine it — disposed on unmount, never
/// re-created per build.
class _RefineBar extends StatefulWidget {
  const _RefineBar({required this.copy});

  final SearchL10n copy;

  @override
  State<_RefineBar> createState() => _RefineBarState();
}

class _RefineBarState extends State<_RefineBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<SearchCubit>().state.query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OmdsSearchBar(
      controller: _controller,
      hintText: widget.copy.hint,
      onSubmitted: (q) => context.read<SearchCubit>().search(q),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody();

  @override
  Widget build(BuildContext context) {
    final copy = SearchL10n.of(context);
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        switch (state.status) {
          case SearchStatus.idle:
          case SearchStatus.loading:
            return const OmdsLoadingState();
          case SearchStatus.failed:
            return _FailureBody(copy: copy, failure: state.error);
          case SearchStatus.loaded:
            return state.hasResults
                ? _ResultsList(results: state.results)
                : _NoResultsBody(copy: copy);
        }
      },
    );
  }
}

/// `unavailable` (the endpoint is absent) is an honest INFO empty state with a
/// retry, NOT a hard error — distinct from a transport/unknown failure.
class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.copy, required this.failure});

  final SearchL10n copy;
  final SearchFailure? failure;

  @override
  Widget build(BuildContext context) {
    if (failure == SearchFailure.unavailable) {
      return OmdsEmptyState(
        icon: Icons.search_off_outlined,
        title: copy.unavailableTitle,
        subtitle: copy.unavailableBody,
        buttonText: copy.retry,
        onButtonTap: () => context.read<SearchCubit>().retry(),
      );
    }
    return OmdsErrorState(
      message: copy.errorCopy(failure),
      retryLabel: copy.retry,
      onRetry: () => context.read<SearchCubit>().retry(),
    );
  }
}

class _NoResultsBody extends StatelessWidget {
  const _NoResultsBody({required this.copy});

  final SearchL10n copy;

  @override
  Widget build(BuildContext context) {
    return OmdsEmptyState(
      icon: Icons.search_off_outlined,
      title: copy.noResultsTitle,
      subtitle: copy.noResultsBody,
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});

  final List<SearchResult> results;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = results[index];
        return SearchResultRow(
          result: result,
          onTap: () => _dispatch(context, result),
        );
      },
    );
  }

  /// Deep-link dispatch (the InkWell callback — an explicit gesture, never a
  /// `builder` side effect, §3 nav-in-listener rule).
  void _dispatch(BuildContext context, SearchResult result) {
    final ref = result.refId;
    switch (result.kind) {
      case SearchResultKind.order:
        if (ref != null) {
          context.pushNamed('delivery-detail', pathParameters: {'id': ref});
        }
        break;
      case SearchResultKind.conversation:
        if (ref != null) {
          context.pushNamed('chat-detail', pathParameters: {'id': ref});
        }
        break;
      case SearchResultKind.unknown:
        break;
    }
  }
}
