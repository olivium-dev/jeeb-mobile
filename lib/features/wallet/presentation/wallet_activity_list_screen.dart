import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../application/wallet_ledger_cubit.dart';
import '../application/wallet_ledger_state.dart';
import '../data/empty_wallet_ledger_repository.dart';
import '../domain/wallet_ledger_repository.dart';
import 'wallet_activity_l10n.dart';
import 'widgets/wallet_activity_row.dart';

/// wallet-activity-list (JM-055). The typed ledger of wallet movements
/// (Reserve / Fee-won / Released / Refund / Penalty / Top up / Gift), each row
/// `wallet_activity_row_<id>` carrying amount + sign + icon + ref, with infinite
/// scroll + skeletons (D73) and a tap → transaction-detail (JM-056). Reached from
/// `wallet_see_all_activity` (wallet-hub, JM-053) + `earnings_activity_link`
/// (earnings, JM-052).
///
/// Renders the canonical 4-state machine (40_GUARDRAILS_ARCH §3; the D30
/// contract, 42_GUARDRAILS_MOCK §5.1): loading (full-screen skeletons, D73) /
/// failed (inline error + retry) / loaded(+empty). On the loaded list a
/// scroll-end fetches the next page and appends it (infinite scroll), with an
/// in-list skeleton footer while the page is on the wire and a soft, retryable
/// footer when it fails.
///
/// Data: reads the Jeeber ledger via `sl<WalletLedgerRepository>()` — the LIVE
/// `DioWalletLedgerRepository` (W2m `GET /v1/jeeb/wallet/ledger` is mock-ready on
/// :4010, 42_GUARDRAILS_MOCK "W2 mock closeout"; bound real in
/// `injection_container.dart` JM-055). [repository] is a constructor test seam
/// (§5.4) — production leaves it null; an unconfigured GetIt (router-resolution
/// widget tests) falls back to an empty repo (mirrors JM-057).
///
/// Semantics identifiers exposed (EXACT — 30_BACKLOG JM-055, 41_GUARDRAILS_TESTING):
///   `wallet_activity_root`        — screen host container (nav target)
///   `wallet_activity_loading`     — first-load skeleton state (D30/D73)
///   `wallet_activity_error`       — cold-load failure (D30)
///   `wallet_activity_retry_cta`   — retry the cold load (D30)
///   `wallet_activity_empty`       — loaded + no rows (D30)
///   `wallet_activity_row_<id>`    — per-ledger-row (dynamic id), tap → txn-detail
///   `wallet_activity_load_more`   — in-list next-page skeleton (D73 infinite)
class WalletActivityListScreen extends StatelessWidget {
  const WalletActivityListScreen({super.key, this.repository});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final WalletLedgerRepository? repository;

  /// Resolves the repo: an explicit override (tests) → the registered LIVE
  /// `DioWalletLedgerRepository` → an empty fallback when GetIt is not configured
  /// (router-resolution widget tests). Mirrors
  /// `NotificationsListScreen._resolveRepository()`.
  WalletLedgerRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<WalletLedgerRepository>()) {
      return sl<WalletLedgerRepository>();
    }
    return const EmptyWalletLedgerRepository();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WalletLedgerCubit>(
      create: (_) => WalletLedgerCubit(repository: _resolveRepository())..load(),
      child: const _WalletActivityView(),
    );
  }
}

class _WalletActivityView extends StatelessWidget {
  const _WalletActivityView();

  @override
  Widget build(BuildContext context) {
    final copy = WalletActivityL10n.of(context);
    return Semantics(
      identifier: 'wallet_activity_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: copy.title,
          showBackButton: true,
          // Normally pushed from wallet-hub's `wallet_see_all_activity` or
          // earnings' `earnings_activity_link`, but also reachable via deep
          // link with an empty Navigator stack. Pop when we can (pushed
          // entry), else return to the shell — never pop the last page
          // (which would leave an empty Navigator → black surface).
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        body: BlocBuilder<WalletLedgerCubit, WalletLedgerState>(
          builder: (context, state) {
            switch (state.status) {
              case WalletLedgerStatus.initial:
              case WalletLedgerStatus.loading:
                return _LoadingSkeletons(copy: copy);
              case WalletLedgerStatus.failed:
                return _ErrorBody(
                  message: _errorCopy(copy, state.error),
                  retryLabel: copy.retry,
                  onRetry: () => context.read<WalletLedgerCubit>().refresh(),
                );
              case WalletLedgerStatus.loaded:
                return RefreshIndicator(
                  onRefresh: () => context.read<WalletLedgerCubit>().refresh(),
                  child: !state.hasEntries
                      ? _EmptyBody(copy: copy)
                      : _LoadedList(state: state, copy: copy),
                );
            }
          },
        ),
      ),
    );
  }

  static String _errorCopy(WalletActivityL10n copy, WalletLedgerFailure? f) {
    switch (f) {
      case WalletLedgerFailure.network:
        return copy.networkError;
      case WalletLedgerFailure.unauthorized:
      case WalletLedgerFailure.unknown:
      case null:
        return copy.loadError;
    }
  }
}

/// Cold-load failure (D30). Renders the error message in the asserted
/// `wallet_activity_error` node and the retry as a distinct
/// `wallet_activity_retry_cta` node (the D30 `<screen>_retry_cta` convention),
/// so a flow can assert the error AND tap the retry by id — a custom layout is
/// used (instead of `OmdsErrorState`) precisely because the OMDS widget merges
/// its internal retry button into one node.
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
            Icon(Icons.error_outline,
                size: 64, color: theme.colorScheme.error),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'wallet_activity_error',
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
              identifier: 'wallet_activity_retry_cta',
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
/// the asserted `wallet_activity_loading` state node.
class _LoadingSkeletons extends StatelessWidget {
  const _LoadingSkeletons({required this.copy});

  final WalletActivityL10n copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'wallet_activity_loading',
      container: true,
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
        itemCount: 8,
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
          child: OmdsListItemShimmer(hasTrailing: true),
        ),
      ),
    );
  }
}

/// Empty = `loaded` + an empty list (NOT a fifth status, §3). Wrapped in a
/// scrollable so pull-to-refresh still works on an empty ledger.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.copy});

  final WalletActivityL10n copy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Semantics(
          identifier: 'wallet_activity_empty',
          container: true,
          child: OmdsEmptyState(
            icon: Icons.receipt_long_outlined,
            title: copy.emptyTitle,
            subtitle: copy.emptyBody,
          ),
        ),
      ],
    );
  }
}

/// The loaded ledger with infinite scroll. A [ScrollController] near-bottom
/// trigger fetches the next page (the cubit single-flights + de-dupes); the
/// footer shows a load-more skeleton while a page is in flight, or a soft retry
/// when it fails (D73 / D30).
class _LoadedList extends StatefulWidget {
  const _LoadedList({required this.state, required this.copy});

  final WalletLedgerState state;
  final WalletActivityL10n copy;

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
      context.read<WalletLedgerCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final copy = widget.copy;
    final entries = state.entries;
    // One extra slot for the footer (load-more skeleton / retry) when relevant.
    final showFooter =
        state.loadingMore || state.loadMoreError || state.hasMore;
    final itemCount = entries.length + (showFooter ? 1 : 0);

    return ListView.separated(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
      itemCount: itemCount,
      separatorBuilder: (_, index) {
        // No divider above the footer slot.
        if (index >= entries.length - 1) return const SizedBox.shrink();
        return const Divider(
          height: 1,
          indent: Spacing.medium,
          endIndent: Spacing.medium,
        );
      },
      itemBuilder: (context, index) {
        if (index >= entries.length) {
          return _Footer(state: state, copy: copy);
        }
        final entry = entries[index];
        return WalletActivityRow(
          entry: entry,
          copy: copy,
          onTap: () => _openDetail(context, entry.id),
        );
      },
    );
  }

  /// Tap → transaction-detail (JM-056), `/wallet/transactions/:id`. Side-effect
  /// navigation lives in the gesture callback (an explicit user gesture), never
  /// in a `builder` (40_GUARDRAILS_ARCH §3 nav-in-listener rule).
  void _openDetail(BuildContext context, String id) {
    if (id.isEmpty) return;
    context.pushNamed(
      'transaction-detail',
      pathParameters: <String, String>{'id': id},
    );
  }
}

/// The infinite-scroll footer: a load-more skeleton while the next page is on
/// the wire (`wallet_activity_load_more`, D73), or a soft retry when it failed.
class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.copy});

  final WalletLedgerState state;
  final WalletActivityL10n copy;

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
              identifier: 'wallet_activity_load_more_retry',
              button: true,
              container: true,
              child: TextButton(
                onPressed: () =>
                    context.read<WalletLedgerCubit>().retryLoadMore(),
                child: Text(copy.retry),
              ),
            ),
          ],
        ),
      );
    }
    // Loading-more (or simply "more exists" — the skeleton doubles as the
    // bottom affordance that more is coming).
    return Semantics(
      identifier: 'wallet_activity_load_more',
      container: true,
      child: const Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: OmdsListItemShimmer(hasTrailing: true),
      ),
    );
  }
}
