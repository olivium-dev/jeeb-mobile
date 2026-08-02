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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/wallet/wallet_activity_list_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so three things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (the OMDS app bar + the list body) and
//    [jeebPreviewHost] wraps every child in one as well, so the canvas shows
//    two nested Scaffolds. The inner one is the real surface; the outer
//    contributes only a background. The canvas box is therefore a real device
//    ([_walletActivityListScreenPhoneBox], 390x844) rather than the harness's
//    default 390x200 — an app bar over eight skeleton rows cannot be judged in
//    a 200 pt strip.
//
// 2. Every affordance on it navigates. The app bar's back arrow calls
//    `context.canPop()`/`context.go('/')` and a row tap calls
//    `pushNamed('transaction-detail')`; those are GoRouter extensions, so both
//    throw WHEN TAPPED unless a `Router` sits above the screen — which neither
//    the canvas host nor the render harness provides. (The screen paints
//    without one; it is only the taps that die, which is the worst version of
//    this: a canvas that looks fine and is dead to the touch.)
//    [_WalletActivityListScreenHost] supplies one over a local [GoRouter]
//    whose stand-in routes catch both destinations, so the canvas is honest to
//    tap in and shows WHICH id was forwarded.
//
// 3. State is driven the only way this screen allows: through the
//    `repository:` constructor seam (40_GUARDRAILS_ARCH §5.4), with the fakes
//    shared with the Screen Catalog entry
//    (`lib/devtool/catalog/fixtures/wallet_activity_list_screen_fixtures.dart`).
//    The screen builds its own [WalletLedgerCubit] internally — there is no
//    `cubit:` seam — so a state is reachable here only if some canned page
//    shape produces it. No preview constructs a `DioWalletLedgerRepository`
//    and `_resolveRepository()`'s `sl<>()` branch is never reached, so these
//    are network-free by construction rather than by the guard in
//    [jeebPreviewHost].
//
// Two footer states cannot be reached from a fixture alone, and both are worth
// knowing about: `loadingMore` and `loadMoreError` are emitted only by
// `loadMore()`, which only `_LoadedListState._onScroll` calls. In the canvas
// you reach the first by scrolling [walletActivityListScreenPaged] to the end
// (its fake serves the same page for as long as you keep scrolling); a fake
// that threw from page 2 would give you the soft retry footer.
//
// What these previews surfaced in the screen — the notes on each say more:
//
//  * the `hasMore` footer is the SAME animating shimmer as the `loadingMore`
//    footer, and `showFooter` is true whenever a further page merely EXISTS.
//    A settled list therefore ends in a row that shimmers as though something
//    were on the wire, and nothing distinguishes "more exists" from "more is
//    loading" — see [walletActivityListScreenPaged];
//  * `unauthorized` and `unknown` collapse to one string in
//    `_WalletActivityView._errorCopy`, so an expired session reads as a
//    generic "Could not load your activity." and is offered a Retry that will
//    fail the same way forever — see [walletActivityListScreenSessionExpired];
//  * that Retry calls `refresh()`, which emits NOTHING before awaiting the
//    fetch. The failed surface stays byte-identical while the request is in
//    flight: no spinner, no disabled CTA, no snackbar. On a slow connection
//    the only feedback is the eventual repaint;
//  * the ORDINARY ledger overflows under large text. Not a pathological row —
//    the three-row fixture below, whose widest amount is `+50.00 USD`, throws
//    `A RenderFlex overflowed by 3.0 pixels on the right` at 200% text on a
//    390x844 phone, and breaks at **150%** on a 320x568 device (where 200%
//    costs two rows, 45 px and 73 px).
//    [WalletActivityRow] puts the amount outside its `Expanded`, so the amount
//    claims its intrinsic width first and the whole row grows past the
//    viewport instead of the text column yielding. The row's own preview file
//    documents the 59 px break on a pathological ref; what this screen adds is
//    that an everyday page breaks too. Pinned by the render test;
//  * `_LoadedList` builds each row without `WalletActivityRow.now`, so every
//    relative timestamp is read off the wall clock. These previews are the one
//    surface in the repo where that shows: the fixture instants are fixed, so
//    the ages they render keep growing.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _walletActivityListScreenPhoneBox = Size(390, 844);

/// Either of the two places this screen navigates to, stubbed.
///
/// The real destinations are wallet-hub (`/`, the deep-link fallback the back
/// arrow takes when there is nothing to pop) and transaction-detail (JM-056);
/// here they only have to exist so a tap lands somewhere and shows which path
/// was taken and with which id.
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
          // reorders visually inside an RTL paragraph.
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
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt on every frame would drop the navigation state
/// `context.canPop()` reads. `Router.withConfig` is exactly what
/// `MaterialApp.router` does internally, so this adds a Router and nothing else
/// — the ambient theme, locale and text scale still come from the preview host
/// above it.
///
/// `initialLocation` is the activity route itself with nothing beneath it,
/// which is the deep-link entry the screen's back handler was written for:
/// `canPop()` is false, so the arrow takes the `context.go('/')` branch to the
/// hub stand-in rather than popping the last page to a black surface.
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
/// approval starter credit), newest first, one page.
///
/// Matrixed because the list is a stack of `icon + text column + number` rows:
/// the AR card is where the whole row mirrors — and where the sign lands at the
/// far end of `+50.00 USD` instead of in front of it, since
/// `WalletActivityL10n.signedAmount` concatenates a neutral `+`/`-` into an RTL
/// paragraph — and the 200% card is where this everyday page BREAKS: measured
/// on the 390x844 box above, the amount takes its intrinsic width first (it is
/// the one child of the row outside the `Expanded`) and the row overflows by
/// 3 px. On a 320 pt device the same three rows break at 150%. Nothing here is
/// a pathological fixture; this is the plainest ledger the screen can show.
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
///
/// Built with the shipped [EmptyWalletLedgerRepository] rather than a fake with
/// an empty list, because that is the class production actually falls back to
/// when `sl<WalletLedgerRepository>()` is unregistered: this preview is the
/// router-resolution path as well as the zero-state.
///
/// The body is a `ListView` with `AlwaysScrollableScrollPhysics` under a
/// `RefreshIndicator`, so pull-to-refresh still works on an empty ledger — the
/// one interaction available here. Note the top gap is
/// `MediaQuery.size.height * 0.18` of the WHOLE screen, not of the body, so it
/// does not track the app bar.
@JeebPreview(
  group: 'wallet',
  name: 'Empty · no activity yet',
  size: _walletActivityListScreenPhoneBox,
)
Widget walletActivityListScreenEmpty() =>
    _walletActivityListScreenHosted(const EmptyWalletLedgerRepository());

/// Cold load failed with [WalletLedgerFailure.network] — the offline case, and
/// the only failure that gets copy of its own ("No connection. Check your
/// network and try again.").
///
/// Read the retry. `wallet_activity_retry_cta` calls `refresh()`, which emits
/// nothing until the fetch resolves, so tapping it changes NOTHING on screen
/// while the request is in flight — no spinner, no disabled button. Offline,
/// where the failure is instant, that is invisible; on a slow connection it is
/// a CTA that looks ignored.
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
///
/// This card exists to be read against [walletActivityListScreenOffline], and
/// the finding is that it is IDENTICAL to it apart from one line of copy:
/// `_errorCopy` folds `unauthorized` in with `unknown` and `null`, so a user
/// whose session died is told "Could not load your activity." and offered a
/// Retry that re-runs the same unauthorized call. There is no sign-in
/// affordance anywhere on this surface, so the loop has no exit.
///
/// Matrixed for the copy rather than the layout. These two error strings are
/// the ones `WalletActivityL10n` still supplies from its feature-local EN/AR
/// map — the integrator has not landed ARB keys for them (JM-055, REQUESTED in
/// `50_ROUTE_REQUESTS.md`) — so this card is the only place the Arabic
/// wording, and its length against the retry button, is ever seen.
///
/// The layout itself holds: the error body is a `Center` → `Column` with no
/// scroll fallback, but at 200% text it clears both the 390x844 box above and
/// a 320x568 compact device. It is one longer localized string from clipping
/// rather than scrolling, which is what the AR card is worth watching for.
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
///
/// Row 0 is the longest gateway reference beside the widest amount, which is
/// where [WalletActivityRow]'s asymmetry bites — the amount is the only child
/// of the row outside the `Expanded`, so it takes its intrinsic width first and
/// the reference ellipsizes into what is left. Row 1 is a `type` this build
/// does not know (rendered as the generic "Activity") carrying no `currency`,
/// so its amount is a bare number in a ledger of USD. Row 2 has neither `ref`
/// nor `ts` and collapses to the row's floor, which is still 56 pt of leading
/// icon tall.
///
/// The rest fills the page past one screen so the divider rhythm and the scroll
/// are real. Note the separator suppression: `_LoadedList` drops the divider
/// above the footer slot by index, so the list ends flush rather than on a
/// hanging rule.
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
/// list), hosted in the asserted `wallet_activity_loading` node.
///
/// Worth checking against [walletActivityListScreenLoaded] side by side: the
/// skeleton rows are `hasTrailing: true` two-line items, while a real row is
/// three lines (type, ref, relative time) plus an amount, so the list visibly
/// re-flows when the page lands rather than settling into the same rhythm.
@JeebPreview(
  group: 'wallet',
  name: 'Loading · first page',
  size: _walletActivityListScreenPhoneBox,
)
Widget walletActivityListScreenLoading() => _walletActivityListScreenHosted(
      const WalletActivityListScreenPendingRepository(),
    );

/// Page 1 of 3 — a loaded, SETTLED list that still has a further page.
///
/// This is the preview the infinite-scroll footer is worth having. `showFooter`
/// is `loadingMore || loadMoreError || hasMore`, and the `hasMore` branch
/// renders the same `wallet_activity_load_more` shimmer the in-flight branch
/// does. Nothing is loading in this card and nothing will until the list is
/// scrolled, yet the bottom row animates exactly as though a page were on the
/// wire — so the affordance that means "there is more below" is indistinguishable
/// from the one that means "fetching". With only three rows on a phone the
/// fake row is on screen from the first frame, one divider-free gap under a
/// list that has finished loading.
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
