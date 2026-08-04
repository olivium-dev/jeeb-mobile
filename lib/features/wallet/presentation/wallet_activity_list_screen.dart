import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../application/wallet_ledger_cubit.dart';
import '../application/wallet_ledger_state.dart';
import '../data/empty_wallet_ledger_repository.dart';
import '../domain/wallet_ledger_repository.dart';
import 'wallet_activity_l10n.dart';
import 'widgets/wallet_activity_row.dart';
import 'widgets/wallet_state_mark.dart';

/// The board gutter (24) with 16 above the first card and 24 below the last —
/// R4's `SliverPadding` rhythm, reused so the list reads as the hub's own
/// continuation.
const EdgeInsetsGeometry _kListPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.xLarge,
);

/// The wallet journey's empty/loading/error composition, taken from R19 (the
/// jeeber's other money ledger, one screen along): the `e1` frame with its
/// client-facing mic and shopping medallions REPLACED by a glass money mark.
///
/// `pocket` is the nearest subject — a pocket is the wallet metaphor — but
/// `_pocketLayers()` ignores the kit's `center` slot and hard-draws a solid
/// orange mic plus an accent bloom, which R4's caption does not allow on a
/// read-only surface. See [WalletStateMark].
const JeebEmptyStateVariant _kStateArt = JeebEmptyStateVariant.e1;

/// The medallion ring is E1's "bring me anything" shopping set — a client
/// prompt with no place on a money ledger (R19's own ruling).
const List<JeebEmptyMedallion> _kNoMedallions = <JeebEmptyMedallion>[];

/// wallet-activity-list (JM-055). The typed ledger of wallet movements
/// (Reserve / Fee-won / Released / Refund / Penalty / Top up / Gift), each row
/// `wallet_activity_row_<id>` carrying amount + sign + icon + ref, with infinite
/// scroll + skeletons (D73) and a tap → transaction-detail (JM-056). Reached from
/// `wallet_see_all_activity` (wallet-hub, JM-053) + `earnings_activity_link`
/// (earnings, JM-052).
///
/// Renders the canonical 4-state machine (40_GUARDRAILS_ARCH §3; the D30
/// contract, 42_GUARDRAILS_MOCK §5.1): loading / failed / loaded(+empty). On the
/// loaded list a scroll-end fetches the next page and appends it (infinite
/// scroll), with an in-list skeleton footer while the page is on the wire and a
/// soft, retryable footer when it fails.
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
///   `wallet_activity_back`        — the top bar's leading circle
///   `wallet_activity_loading`     — first-load skeleton state (D30/D73)
///   `wallet_activity_error`       — cold-load failure (D30)
///   `wallet_activity_retry_cta`   — retry the cold load (D30)
///   `wallet_activity_empty`       — loaded + no rows (D30)
///   `wallet_activity_row_<id>`    — per-ledger-row (dynamic id), tap → txn-detail
///   `wallet_activity_load_more`   — in-list next-page skeleton (D73 infinite)
///
/// MIDNIGHT (M3-11): a re-skin, not a rewrite — same route, same 4-state
/// machine, same infinite scroll, every frozen identifier unmoved. The board
/// never drew this screen; it is DERIVED from R4 (`04-r4-wallet.png`), the hub
/// this list hangs off, whose treatment `wallet_hub_screen.dart` already ships:
/// the same two radials on the same anchors (ORANGE glow top-start, PERIWINKLE
/// wash end-side at mid-height), the `content` layer set because the orbit ring
/// is the hub's hero moment and not a ledger's, and `animateDecor: false`
/// because 03-MOTION-NOTES §R4 records zero animated elements on this tile.
/// The three non-loaded states move onto the one Midnight pattern family
/// (study-notes ruling 1) — the light-theme OMDS shimmer/empty widgets they used
/// paint `Colors.grey.shade300` on a navy field.
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
        backgroundColor: Colors.transparent,
        // R4's two radials, carried from the hub: the ORANGE glow top-start and
        // the PERIWINKLE wash end-side at mid-height are separate layers on
        // separate anchors, and neither moves.
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.topStart,
          washPlacement: JeebFieldWashPlacement.endMid,
          animateDecor: false,
          // The header is an in-body row, not a Material app bar, so it renders
          // in EVERY state (loading / failed / loaded) and carries the board's
          // 24px gutter instead of a centred M3 title.
          child: SafeArea(
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
                          return _StateBlock(
                            status: JeebEmptyStateStatus.loading,
                            // TODO(midnight): l10n-queued —
                            // walletActivityLoadingHeadline.
                            headline: copy.title,
                            identifier: 'wallet_activity_loading',
                          );
                        case WalletLedgerStatus.failed:
                          return _StateBlock(
                            status: JeebEmptyStateStatus.error,
                            // TODO(midnight): l10n-queued —
                            // walletActivityErrorTitle.
                            headline: copy.loadError,
                            body: state.error == WalletLedgerFailure.network
                                ? copy.networkError
                                : null,
                            identifier: 'wallet_activity_error',
                            glyph: Icons.cloud_off,
                            action: JeebCtaButton.primary(
                              identifier: 'wallet_activity_retry_cta',
                              label: copy.retry,
                              expand: false,
                              onTap: () =>
                                  context.read<WalletLedgerCubit>().refresh(),
                            ),
                          );
                        case WalletLedgerStatus.loaded:
                          // The house pull-to-refresh (the hub and the inbox
                          // both use it).
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
      ),
    );
  }
}

/// The loading and error twins of [_EmptyBody] — same illustration, kit skeleton
/// / danger-tinted centre (study-notes ruling 1), centred in the residual band.
/// Scrolls so the block survives 200% text scale on a short phone.
///
/// Hosts the frozen `wallet_activity_loading` / `wallet_activity_error` nodes;
/// the retry keeps its own `wallet_activity_retry_cta` node inside, which
/// survives because [JeebEmptyState] sets `explicitChildNodes`.
class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.status,
    required this.headline,
    required this.identifier,
    this.glyph,
    this.body,
    this.action,
  });

  final JeebEmptyStateStatus status;
  final String headline;
  final String identifier;

  /// Null on loading: the kit paints its skeleton over the whole frame and
  /// never reaches the `center` slot.
  final IconData? glyph;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final IconData? mark = glyph;
    return Center(
      child: SingleChildScrollView(
        child: JeebEmptyState(
          status: status,
          variant: _kStateArt,
          center: mark == null ? null : WalletStateMark(glyph: mark),
          medallions: _kNoMedallions,
          headline: headline,
          body: body,
          identifier: identifier,
          action: action,
        ),
      ),
    );
  }
}

/// Empty = `loaded` + an empty list (NOT a fifth status, §3). Wrapped in a
/// scrollable so pull-to-refresh still works on an empty ledger.
///
/// No CTA: nothing on this screen routes to "make a ledger row happen" (top-up
/// is the hub's edge, one screen up), and the E2 ruling is that an unmounted CTA
/// beats a destination-less one.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.copy});

  /// R21/E4: the illustration sits high, not centred in the residual band.
  static const double topGap = Sizes.threeXLarge;

  final WalletActivityL10n copy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.only(
        top: topGap,
        bottom: Sizes.sixXLarge,
      ),
      children: [
        JeebEmptyState(
          identifier: 'wallet_activity_empty',
          variant: _kStateArt,
          // The screen's own subject: a list of money movements, with none yet.
          center: const WalletStateMark(glyph: Icons.receipt_long),
          medallions: _kNoMedallions,
          headline: copy.emptyTitle,
          body: copy.emptyBody,
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
      // R7/R12: the card outlines ARE the separation — a divider between two
      // outlined cards draws a third line nobody asked for. Same gap above the
      // footer slot, so nothing jumps when it appears.
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        radius: JeebRadii.lg,
        padding: kWalletActivityRowPadding,
        child: _RowSkeleton(),
      ),
    );
  }
}

/// The next-page placeholder: two glass bars in a real row's two bands.
///
/// Replaces `OmdsListItemShimmer`, which paints `Colors.grey.shade300` over
/// `Colors.white` — a light-theme widget on a navy field. Still, deliberately
/// still: 03-MOTION-NOTES §R4 records zero animated elements on this tile.
class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  /// The headline band tracks `cardTitle`'s 15.5 box; the meta band `bodySmall`.
  static const double _headlineHeight = 15.5;
  static const double _metaHeight = 12.5;
  static const double _metaWidthFraction = 0.45;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors glass =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();

    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Bar(
            color: glass.glassFillEmphasis,
            height: _headlineHeight,
            widthFactor: 1,
          ),
          const SizedBox(height: Spacing.xSmall),
          _Bar(
            color: glass.glassFill,
            height: _metaHeight,
            widthFactor: _metaWidthFraction,
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.color,
    required this.height,
    required this.widthFactor,
  });

  final Color color;
  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(JeebRadii.sm),
        ),
        child: SizedBox(height: height, width: double.infinity),
      ),
    );
  }
}
