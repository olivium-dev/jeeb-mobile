import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../application/wallet_ledger_cubit.dart';
import '../application/wallet_ledger_state.dart';
import '../data/empty_wallet_ledger_repository.dart';
import '../domain/wallet_ledger_repository.dart';
import 'wallet_activity_l10n.dart';
import 'widgets/wallet_activity_row.dart';

/// The board gutter (24) with 16 above the first card and 24 below the last —
/// 23's `SliverPadding` rhythm, reused so the list reads as the hub's own
/// continuation.
const EdgeInsetsGeometry _kListPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.xLarge,
);

/// The skeleton card shell — the same r18 / 14-16 shape a real row paints, so
/// the first frame does not resize when the page lands.
const double _kSkeletonRadius = 18;
const EdgeInsetsGeometry _kSkeletonPadding = EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.medium,
  vertical: 14,
);

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
///   `wallet_activity_back`        — the top bar's leading circle (redesign-2026-08)
///   `wallet_activity_loading`     — first-load skeleton state (D30/D73)
///   `wallet_activity_error`       — cold-load failure (D30)
///   `wallet_activity_retry_cta`   — retry the cold load (D30)
///   `wallet_activity_empty`       — loaded + no rows (D30)
///   `wallet_activity_row_<id>`    — per-ledger-row (dynamic id), tap → txn-detail
///   `wallet_activity_load_more`   — in-list next-page skeleton (D73 infinite)
///
/// Redesign-2026-08: a re-skin onto the Jeeb kit, not a rewrite — same route,
/// same 4-state machine, same infinite scroll, every identifier unmoved. There
/// is no board render for this screen; the language comes from the hub it hangs
/// off, 23 (`screens/23-wallet.png`): an in-body [JeebTopBar] that renders in
/// EVERY state, a 24px gutter, and outlined cards 12px apart instead of
/// full-bleed rows separated by hairlines.
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
        // The header is an in-body row, not a Material app bar, so it renders
        // in EVERY state (loading / failed / loaded) and carries the board's
        // 24px gutter instead of a centred M3 title.
        body: SafeArea(
          child: Column(
            children: [
              JeebTopBar(
                identifier: 'wallet_activity_back',
                title: copy.title,
                leadingTooltip:
                    MaterialLocalizations.of(context).backButtonTooltip,
                // Normally pushed from wallet-hub's `wallet_see_all_activity`
                // or earnings' `earnings_activity_link`, but also reachable via
                // deep link with an empty Navigator stack. Pop when we can
                // (pushed entry), else return to the shell — never pop the last
                // page (which would leave an empty Navigator → black surface).
                onLeadingPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(
                child: BlocBuilder<WalletLedgerCubit, WalletLedgerState>(
                  builder: (context, state) {
                    switch (state.status) {
                      case WalletLedgerStatus.initial:
                      case WalletLedgerStatus.loading:
                        return const _LoadingSkeletons();
                      case WalletLedgerStatus.failed:
                        return _ErrorBody(
                          message: _errorCopy(copy, state.error),
                          retryLabel: copy.retry,
                          onRetry: () =>
                              context.read<WalletLedgerCubit>().refresh(),
                        );
                      case WalletLedgerStatus.loaded:
                        // The house pull-to-refresh (the hub and the inbox both
                        // use it) — a raw `RefreshIndicator` is a token-check
                        // violation this screen carried since JM-055.
                        return OmdsPullToRefresh(
                          onRefresh: () =>
                              context.read<WalletLedgerCubit>().refresh(),
                          child: !state.hasEntries
                              ? _EmptyBody(copy: copy)
                              : _LoadedList(state: state, copy: copy),
                        );
                    }
                  },
                ),
              ),
            ],
          ),
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
    // Scrollable so the note + pill survive a 200% text scale instead of
    // overflowing a centred, unscrollable Column.
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
        vertical: Sizes.fiveXLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The kit's error tone keeps its role colours on every surface — a
          // tinted note, not the 64px red glyph the screen used to plant in the
          // middle of an otherwise white, airy list.
          JeebInfoNote.error(
            identifier: 'wallet_activity_error',
            icon: Icons.error_outline,
            text: message,
          ),
          const SizedBox(height: Spacing.medium),
          JeebCtaButton(
            identifier: 'wallet_activity_retry_cta',
            label: retryLabel,
            leadingIcon: Icons.refresh,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

/// First-load skeletons (D73 — never a bare spinner on a list, 42 §5.1). Hosts
/// the asserted `wallet_activity_loading` state node.
class _LoadingSkeletons extends StatelessWidget {
  const _LoadingSkeletons();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'wallet_activity_loading',
      container: true,
      child: ListView.separated(
        padding: _kListPadding,
        itemCount: 8,
        // R7/R12: the card outlines ARE the separation — a divider between two
        // outlined cards draws a third line nobody asked for.
        separatorBuilder: (context, index) =>
            const SizedBox(height: Spacing.small),
        itemBuilder: (context, index) => const JeebOutlinedCard(
          radius: _kSkeletonRadius,
          padding: _kSkeletonPadding,
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
      // R1: the residual space stays white and top-aligned — the same band 24's
      // empty tab and the inbox use, not a viewport-fraction spacer.
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
        vertical: Sizes.sixXLarge,
      ),
      children: [
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
      padding: _kListPadding,
      itemCount: itemCount,
      // R7/R12: the card outlines ARE the separation — the hairline dividers
      // this list used to draw between rows added a third line nobody asked
      // for. Same gap above the footer slot, so nothing jumps when it appears.
      separatorBuilder: (_, index) => const SizedBox(height: Spacing.small),
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
        padding: const EdgeInsetsDirectional.only(top: Spacing.xSmall),
        child: Row(
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
            // A soft, in-list retry — the `text` variant, not a second pill
            // competing with the cold-load CTA.
            JeebCtaButton.text(
              identifier: 'wallet_activity_load_more_retry',
              label: copy.retry,
              onTap: () => context.read<WalletLedgerCubit>().retryLoadMore(),
            ),
          ],
        ),
      );
    }
    // Loading-more (or simply "more exists" — the skeleton doubles as the
    // bottom affordance that more is coming). Same card shell as a real row, so
    // the list keeps its rhythm while the page is on the wire.
    return Semantics(
      identifier: 'wallet_activity_load_more',
      container: true,
      child: const JeebOutlinedCard(
        radius: _kSkeletonRadius,
        padding: _kSkeletonPadding,
        child: OmdsListItemShimmer(hasTrailing: true),
      ),
    );
  }
}
