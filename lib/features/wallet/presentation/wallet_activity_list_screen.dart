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

class WalletActivityListScreen extends StatelessWidget {
  const WalletActivityListScreen({super.key, this.repository});

  final WalletLedgerRepository? repository;

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
    final showFooter =
        state.loadingMore || state.loadMoreError || state.hasMore;
    final itemCount = entries.length + (showFooter ? 1 : 0);

    return ListView.separated(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
      itemCount: itemCount,
      separatorBuilder: (_, index) {
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

  void _openDetail(BuildContext context, String id) {
    if (id.isEmpty) return;
    context.pushNamed(
      'transaction-detail',
      pathParameters: <String, String>{'id': id},
    );
  }
}

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
