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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/wallet_activity_list_screen_fixtures.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _walletActivityListScreenPhoneBox = Size(390, 844);

/// Either of the two places this screen navigates to, stubbed.
/// The real destinations are wallet-hub (`/`, the deep-link fallback the back
/// arrow takes when there is nothing to pop) and transaction-detail (JM-056);
class _WalletActivityListScreenStandIn extends StatelessWidget {
  const _WalletActivityListScreenStandIn(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: diagnostic, not shipped copy, and a latin identifier
          label,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [WalletActivityListScreen] so its navigation
/// affordances work.
/// Stateful, and the router is built once and disposed with the host: a
class _WalletActivityListScreenHost extends StatefulWidget {
  const _WalletActivityListScreenHost({required this.repository});

  final WalletLedgerRepository repository;

  @override
  State<_WalletActivityListScreenHost> createState() =>
      _WalletActivityListScreenHostState();
}

class _WalletActivityListScreenHostState
    extends State<_WalletActivityListScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/wallet/activity',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const _WalletActivityListScreenStandIn('wallet-hub (JM-053)'),
      ),
      GoRoute(
        path: '/wallet/activity',
        builder: (_, _) =>
            WalletActivityListScreen(repository: widget.repository),
      ),
      GoRoute(
        path: '/wallet/transactions/:id',
        name: 'transaction-detail',
        builder: (_, GoRouterState state) => _WalletActivityListScreenStandIn(
          'transaction-detail: ${state.pathParameters['id']}',
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

Widget _walletActivityListScreenHosted(WalletLedgerRepository repository) =>
    _WalletActivityListScreenHost(repository: repository);

/// The happy path, and the shape the JM-055 ACs are written against: one debit
/// (the fee taken when an offer is won) and two credits (a store top-up and the
@JeebPreview(
  group: 'wallet',
  name: 'Loaded · mixed ledger',
  size: _walletActivityListScreenPhoneBox,
  matrix: true,
)
Widget walletActivityListScreenLoaded() => _walletActivityListScreenHosted(
      const WalletActivityListScreenFakeRepository(
        walletActivityListScreenMixedLedger,
      ),
    );

/// A jeeber who has not moved any money yet — `loaded` with an empty page,
/// which is NOT a fifth status (§3).
@JeebPreview(
  group: 'wallet',
  name: 'Empty · no activity yet',
  size: _walletActivityListScreenPhoneBox,
)
Widget walletActivityListScreenEmpty() =>
    _walletActivityListScreenHosted(const EmptyWalletLedgerRepository());

/// Cold load failed with [WalletLedgerFailure.network] — the offline case, and
/// the only failure that gets copy of its own ("No connection. Check your
@JeebPreview(
  group: 'wallet',
  name: 'Error · offline',
  size: _walletActivityListScreenPhoneBox,
)
Widget walletActivityListScreenOffline() => _walletActivityListScreenHosted(
      const WalletActivityListScreenFakeRepository(
        <WalletLedgerEntry>[],
        failure: WalletLedgerFailure.network,
      ),
    );

/// Cold load failed with [WalletLedgerFailure.unauthorized] — an expired or
/// revoked session.
@JeebPreview(
  group: 'wallet',
  name: 'Error · session expired',
  size: _walletActivityListScreenPhoneBox,
  matrix: true,
)
Widget walletActivityListScreenSessionExpired() =>
    _walletActivityListScreenHosted(
      const WalletActivityListScreenFakeRepository(
        <WalletLedgerEntry>[],
        failure: WalletLedgerFailure.unauthorized,
      ),
    );

/// The layout ceiling: a full 15-row page whose first three rows are the worst
/// shapes W2m can serve.
@JeebPreview(
  group: 'wallet',
  name: 'Loaded · worst page',
  size: _walletActivityListScreenPhoneBox,
)
Widget walletActivityListScreenWorstPage() => _walletActivityListScreenHosted(
      WalletActivityListScreenFakeRepository(
        walletActivityListScreenFullPage,
      ),
    );

/// The cold-start window, held open by a read that never lands: eight
/// full-screen `OmdsListItemShimmer` rows (D73 — never a bare spinner on a
@JeebPreview(
  group: 'wallet',
  name: 'Loading · first page',
  size: _walletActivityListScreenPhoneBox,
)
Widget walletActivityListScreenLoading() => _walletActivityListScreenHosted(
      const WalletActivityListScreenPendingRepository(),
    );

/// Page 1 of 3 — a loaded, SETTLED list that still has a further page.
/// This is the preview the infinite-scroll footer is worth having. `showFooter`
@JeebPreview(
  group: 'wallet',
  name: 'Loaded · more to come',
  size: _walletActivityListScreenPhoneBox,
)
Widget walletActivityListScreenPaged() => _walletActivityListScreenHosted(
      const WalletActivityListScreenFakeRepository(
        walletActivityListScreenMixedLedger,
        totalPages: 3,
      ),
    );
