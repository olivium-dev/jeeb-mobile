import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/layout/bottom_inset.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../../core/widgets/jeeb/jeeb_filter_button.dart';
import '../../../../core/widgets/jeeb/jeeb_filter_pills.dart';
import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_cubit.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import '../../../jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../jeeber_request_feed/cubit/request_feed_state.dart';
import '../../../jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../../jeeber_request_feed/cubit/submitted_offers_state.dart';
import '../../../jeeber_request_feed/data/request_feed_models.dart';
import '../../../jeeber_request_feed/presentation/jeeber_failure_exit.dart';
import '../../../jeeber_request_feed/presentation/jeeber_feed_card.dart';
import '../../../jeeber_request_feed/presentation/pending_offer_row.dart';
import 'availability_card.dart';
import 'jeeber_feed_filter_sheet.dart';
import 'jeeber_home_greeting.dart';
import 'jeeber_no_requests_view.dart';

/// Tab the Jeeber feed view is currently filtered to, matching the three
/// filter chips in the Figma `deliveryman-requests` flow:
///
/// * [requests] — incoming requests (Ignore/Offer cards, screen 24).
/// * [pendingResponse] — requests the Jeeber offered on, awaiting the client
///   (italic "Pending" cards, screen 25).
/// * [replies] — accepted requests with delivery-status actions (screen 26).
enum JeeberFeedTab { requests, pendingResponse, replies }

/// T-MOB-029: Tier filter for the Requests tab.
///
/// * [all] — show all tiers.
/// * [flash] — Flash-tier requests only.
/// * [express] — Express-tier requests only.
/// * [standard] — Standard-tier requests only.
enum JeeberTierFilter { all, flash, express, standard }

/// The feed's one visibility predicate — top-level because the filter sheet's
/// live result count must be computed with exactly this rule, not a copy.
List<DeliveryRequest> jeeberFeedVisibleRequests({
  required List<DeliveryRequest> source,
  required JeeberFeedTab tab,
  required JeeberTierFilter tier,
  required String query,
}) {
  final lowered = query.trim().toLowerCase();
  return source
      .where((r) {
        // Server-owned action authority: never expose a stale terminal row as
        // offerable, even if a repository seam still supplies it.
        if (!r.requestIsOpen) return false;
        if (lowered.isNotEmpty && !_matchesQuery(r, lowered)) return false;
        if (r.feedStatus != _statusForTab(tab)) return false;
        if (!_matchesTier(r, tier)) return false;
        return true;
      })
      .toList(growable: false);
}

JeeberFeedItemStatus _statusForTab(JeeberFeedTab tab) => switch (tab) {
  JeeberFeedTab.requests => JeeberFeedItemStatus.incoming,
  JeeberFeedTab.pendingResponse => JeeberFeedItemStatus.pendingResponse,
  JeeberFeedTab.replies => JeeberFeedItemStatus.accepted,
};

/// Backend tier mapping: flash→Flash, standard→Express, light+bulk→Standard.
bool _matchesTier(DeliveryRequest r, JeeberTierFilter tier) => switch (tier) {
  JeeberTierFilter.all => true,
  JeeberTierFilter.flash => r.tier == JeeberRequestTier.flash,
  JeeberTierFilter.express => r.tier == JeeberRequestTier.standard,
  JeeberTierFilter.standard =>
    r.tier == JeeberRequestTier.light || r.tier == JeeberRequestTier.bulk,
};

bool _matchesQuery(DeliveryRequest r, String q) =>
    (r.senderName?.toLowerCase().contains(q) ?? false) ||
    (r.itemsSummary?.toLowerCase().contains(q) ?? false) ||
    r.pickup.label.toLowerCase().contains(q);

/// State 3 of the Jeeber home: registered, available, and at least one
/// live request in the feed.
///
/// Renders the single greeting title → state-aware availability → compact
/// active-work disclosure → stage tabs + filter disc → applied-facet pills →
/// [JeeberFeedCard] list. The list reads from [RequestFeedCubit] —
/// the host (the screen) is responsible for providing the cubit through
/// the widget tree.
class JeeberFeedTabView extends StatefulWidget {
  const JeeberFeedTabView({
    super.key,
    this.profileName,
    this.profileAvatarUrl,
    this.initialTab = JeeberFeedTab.requests,
    this.onOpenRequest,
    this.onMakeOffer,
    this.submittedOffersCubit,
    this.leadingBanner,
  });

  static const Key rootKey = Key('jeeber-feed-tab-view-root');
  static const Key searchBarKey = Key('jeeber-feed-tab-view-search-bar');
  static const Key tabStripKey = Key('jeeber-feed-tab-view-tab-strip');
  static const Key tierStripKey = Key('jeeber-feed-tab-view-tier-strip');
  static const Key listKey = Key('jeeber-feed-tab-view-list');
  static const Key pendingListKey = Key('jeeber-feed-tab-view-pending-list');
  static const Key offlineBannerKey = Key(
    'jeeber-feed-tab-view-offline-banner',
  );

  /// Profile display name for the shared greeting.
  final String? profileName;

  /// Profile avatar URL for the shared greeting header.
  final String? profileAvatarUrl;

  /// Filter chip selected on first render (dev-seam / deep-link entry point).
  final JeeberFeedTab initialTab;

  /// Optional row-tap forward so the host (the screen) can decide whether
  /// to route into a request-detail page.
  final ValueChanged<DeliveryRequest>? onOpenRequest;

  /// JM-048: optional override for the make-offer routing. When null the view
  /// routes itself (KYC gate when unapproved → composer when approved) so the
  /// shell does not need to wire it; tests pass a stub to assert the branch
  /// without a router. See [_defaultMakeOffer].
  final ValueChanged<DeliveryRequest>? onMakeOffer;

  /// JM-048 AC3: optional cubit backing the Pending-Response sub-tab with the
  /// jeeber's submitted offers (`GET /offer-service/v1/offers?jeeberId=`). When
  /// null the Pending tab falls back to the request-feed-derived pending view
  /// (dev-seam capture / tests), so this widget stays usable without DI.
  final SubmittedOffersCubit? submittedOffersCubit;

  /// PUSH-UI-REACTION: an optional card (the jeeber's "active deliveries"
  /// banner) rendered as the FIRST, scrolling item of the feed's request list
  /// (and above its empty state) so a just-won delivery surfaces the instant the
  /// `offer_accepted` push refetch returns it — even while the jeeber is still
  /// browsing a non-empty feed. Rides inside the scroll (not as a fixed header)
  /// so it never overflows the short-viewport feed. Null for callers/tests that
  /// do not inject one → the feed is unchanged.
  final Widget? leadingBanner;

  @override
  State<JeeberFeedTabView> createState() => _JeeberFeedTabViewState();
}

class _JeeberFeedTabViewState extends State<JeeberFeedTabView> {
  late JeeberFeedTab _activeTab = widget.initialTab;
  JeeberTierFilter _tierFilter = JeeberTierFilter.all;
  String _query = '';

  bool get _hasAppliedFilters =>
      _tierFilter != JeeberTierFilter.all || _query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Lazily warm the pending list if the view opens directly on the Pending
    // tab (deep-link / dev-seam `initialTab`).
    if (_activeTab == JeeberFeedTab.pendingResponse) {
      _loadPendingOffers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvailabilityCubit, AvailabilityViewState>(
      builder: (context, avState) => _buildBody(context, avState),
    );
  }

  void _loadPendingOffers() {
    final cubit = widget.submittedOffersCubit;
    if (cubit == null) return;
    if (cubit.state.status == SubmittedOffersStatus.initial) {
      cubit.load();
    }
  }

  /// Self-contained make-offer routing (JM-044/048 D38 invariant) used when the
  /// host does not supply [JeeberFeedTabView.onMakeOffer]: an UNAPPROVED jeeber
  /// is routed through `offer-kyc-gate`; an APPROVED jeeber goes straight to the
  /// composer (`jeeber-offer-submission`). Resolves the gate from DI with a
  /// seam-backed fallback so a harness without the gate registered never throws
  /// (mirrors `dashboard_tab.dart`). Guarded by `GoRouter.maybeOf` so it is a
  /// no-op in a router-less widget test.
  void _defaultMakeOffer(BuildContext context, DeliveryRequest request) {
    if (GoRouter.maybeOf(context) == null) return;
    final gate = sl.isRegistered<JeeberKycStatusGate>()
        ? sl<JeeberKycStatusGate>()
        : const SeamJeeberKycStatusGate();
    if (gate.isApproved) {
      context.pushNamed(
        'jeeber-offer-submission',
        pathParameters: {'id': request.id},
      );
    } else {
      context.goNamed('offer-kyc-gate');
    }
  }

  void _onMakeOffer(BuildContext context, DeliveryRequest request) {
    final handler = widget.onMakeOffer;
    if (handler != null) {
      handler(request);
      return;
    }
    _defaultMakeOffer(context, request);
  }

  Widget _buildBody(BuildContext context, AvailabilityViewState avState) {
    final isOffline = avState.status.state != AvailabilityState.online;
    // JEBV4-284: a Column + Expanded overflowed by 100px once the header stack
    // outgrew a squeezed viewport. Slivers, never a Column — see the repro test.
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: JeeberHomeGreeting(
            name: widget.profileName,
            avatarUrl: widget.profileAvatarUrl,
          ),
        ),
        // §G2/SW-23: the availability control is persistent across dashboard
        // states — the state-aware row renders here too, so going busy (feed
        // non-empty) never hides the online/offline switch.
        SliverToBoxAdapter(
          child: AvailabilityCard(
            view: avState,
            onToggle: () => context.read<AvailabilityCubit>().toggle(),
            onExtendActivity: () =>
                context.read<AvailabilityCubit>().extendActivity(),
          ),
        ),
        if (isOffline) const SliverToBoxAdapter(child: _OfflineBanner()),
        // Existing delivery work stays visible without burying the earning
        // task: ActiveDeliveriesBanner is collapsed to one disclosure row at
        // rest and expands only on explicit request.
        if (!isOffline && widget.leadingBanner != null)
          SliverToBoxAdapter(child: widget.leadingBanner!),
        if (!isOffline)
          ..._feedControls(context).map((w) => SliverToBoxAdapter(child: w)),
        if (!isOffline)
          const SliverToBoxAdapter(child: _FeedRefreshFailedNote()),
        ..._feedSlivers(isOffline),
      ],
    );
    // Pull-to-refresh owns the whole page (it used to wrap only the inner feed
    // list). Offline there is no feed cubit contract to refresh, so the plain
    // scroll view is returned.
    return SafeArea(
      key: JeeberFeedTabView.rootKey,
      child: isOffline
          ? scrollView
          : JeebPullToRefresh(
              onRefresh: () => context.read<RequestFeedCubit>().refresh(),
              child: scrollView,
            ),
    );
  }

  /// The stage strip + the one filter disc, then the applied-facet pills.
  List<Widget> _feedControls(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.medium,
          Spacing.xLarge,
          0,
        ),
        child: Row(
          children: [
            Expanded(
              child: _FeedTabStrip(
                active: _activeTab,
                onChanged: _onTabChanged,
                submittedOffersCubit: widget.submittedOffersCubit,
              ),
            ),
            const SizedBox(width: Spacing.xSmall),
            JeebFilterButton(
              identifier: 'jeeber_feed_filter_open',
              semanticLabel: l10n.jeeberFeedFilterOpenLabel,
              active: _hasAppliedFilters,
              onTap: () => _openFilterSheet(context),
            ),
          ],
        ),
      ),
      JeebFilterPillRow(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.small,
          Spacing.xLarge,
          0,
        ),
        pills: _appliedPills(context, l10n),
      ),
    ];
  }

  /// One pill per applied facet. Each ✕ drops only its own facet; tapping the
  /// body reopens the sheet on the facet the jeeber is looking at.
  List<Widget> _appliedPills(BuildContext context, AppLocalizations l10n) {
    final pills = <Widget>[];
    if (_tierFilter != JeeberTierFilter.all) {
      final label = jeeberTierFilterLabel(l10n, _tierFilter);
      pills.add(
        JeebFilterPill(
          label: label,
          identifier: 'jeeber_feed_filter_pill_tier',
          clearIdentifier: 'jeeber_feed_filter_pill_tier_clear',
          clearSemanticLabel: l10n.filterPillClearA11yLabel(label),
          onTap: () => _openFilterSheet(context),
          onClear: () => setState(() => _tierFilter = JeeberTierFilter.all),
        ),
      );
    }
    if (_query.isNotEmpty) {
      final label = l10n.jeeberFeedSearchPillLabel(_query);
      pills.add(
        JeebFilterPill(
          label: label,
          identifier: 'jeeber_feed_filter_pill_query',
          clearIdentifier: 'jeeber_feed_filter_pill_query_clear',
          clearSemanticLabel: l10n.filterPillClearA11yLabel(label),
          onTap: () => _openFilterSheet(context),
          onClear: () => setState(() => _query = ''),
        ),
      );
    }
    return pills;
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final selection = await JeeberFeedFilterSheet.show(
      context,
      requests: context.read<RequestFeedCubit>().state.requests,
      tab: _activeTab,
      tier: _tierFilter,
      query: _query,
    );
    if (selection == null || !mounted) return;
    setState(() {
      _tierFilter = selection.tier;
      _query = selection.query;
    });
  }

  /// The feed body as SLIVERS of the page's own scroll view.
  ///
  /// It used to be one `SliverFillRemaining(hasScrollBody: true)` holding a
  /// nested `ListView`. That nested viewport was only what the header stack
  /// left over (~209dp on SM-S908B), so its rows were laid out inside a box far
  /// too small to show them and the outer scroll view — being exactly viewport
  /// sized — had nothing to scroll, leaving the rows unreachable. Flattening
  /// the rows into the page's slivers means one scroll surface for everything.
  List<Widget> _feedSlivers(bool isOffline) {
    if (isOffline) {
      return const [
        SliverFillRemaining(hasScrollBody: true, child: _OfflineEmptyBody()),
      ];
    }
    // JM-048 AC3: the Pending-Response sub-tab is backed by the jeeber's
    // submitted offers (real data) when a [SubmittedOffersCubit] is supplied;
    // otherwise it falls back to the request-feed-derived pending view.
    if (_activeTab == JeeberFeedTab.pendingResponse &&
        widget.submittedOffersCubit != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: true,
          child: _PendingOffersList(
            cubit: widget.submittedOffersCubit!,
            // JM-047 AC4 (RD-2): the pending sub-tab's back edge →
            // delivery-requests. Tabs are not routes here (the feed lives
            // inside the shell), so "back" switches the active sub-tab back to
            // Requests (jeeber-requests-home).
            onBack: () => _onTabChanged(JeeberFeedTab.requests),
          ),
        ),
      ];
    }
    return [
      _FeedRequestSliver(
        onClearFilters: _clearFilters,
        activeTab: _activeTab,
        tierFilter: _tierFilter,
        query: _query,
        onOpenRequest: widget.onOpenRequest,
        onMakeOffer: (req) => _onMakeOffer(context, req),
      ),
    ];
  }

  void _clearFilters() {
    setState(() {
      _tierFilter = JeeberTierFilter.all;
      _query = '';
    });
  }

  void _onTabChanged(JeeberFeedTab? next) {
    if (next == null || next == _activeTab) return;
    setState(() => _activeTab = next);
    if (next == JeeberFeedTab.pendingResponse) {
      _loadPendingOffers();
    }
  }

}

/// T-MOB-029: Banner shown when Jeeber goes offline (AC3).
///
/// A full-bleed coloured slab became an inset note: offline is an attention
/// state (self-inflicted, recoverable), not a failure, so it keeps the warning
/// role but stops behaving like a system error bar. Inks come from the kit's
/// warning tone — this file is raw-colour gated.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.small,
        Spacing.xLarge,
        0,
      ),
      child: JeebInfoNote.warning(
        key: JeeberFeedTabView.offlineBannerKey,
        // OFF-16: duty-off, not connectivity — "offline" is reserved for the
        // real transport banner.
        icon: Icons.pause_circle_outline,
        title: l10n.availabilityDutyOffTitle,
        text: l10n.availabilityDutyOffSubtitle,
      ),
    );
  }
}

/// Empty body shown while the Jeeber is offline (feed cleared per AC3).
///
/// The board draws no offline frame, so it reads as E3's quiet-street block
/// with the offline copy — one empty family for the whole screen.
class _OfflineEmptyBody extends StatelessWidget {
  const _OfflineEmptyBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Duty-off has no feed contract to pull, so the host takes no onRefresh.
    return JeebStateHost(
      padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
      child: JeebEmptyState(
        identifier: 'jeeber_feed_offline_empty_state',
        variant: JeebEmptyStateVariant.street,
        headline: l10n.jeeberFeedDutyOffEmptyHeadline,
        body: l10n.jeeberFeedDutyOffEmptyBody,
      ),
    );
  }
}

/// Feed sub-tab chips — Nearby {n} / Pending {n} / Replies {n}.
///
/// Built from individual pills (not the monolithic [OmdsFilterChips]) because
/// JM-048 needs a per-chip Semantics identifier on the Pending chip
/// (`jeeber_feed_pending_tab`) so the QA flow can tap it, which the bundled
/// filter-chips widget does not expose. Each chip carries its own id; all three
/// are queryable (honest), only `jeeber_feed_pending_tab` is contract-required.
///
/// The counts are the board's, and every one of them is derived from state the
/// screen already holds — no new fetch, no new cubit field. They live INSIDE
/// the localized label (`Nearby {count}`) rather than in the kit's badge slot,
/// so Arabic decides its own digit/word order. STAGE TABS, not filters: each
/// swaps the list body, which is why they stayed when tier/search left.
class _FeedTabStrip extends StatelessWidget {
  const _FeedTabStrip({
    required this.active,
    required this.onChanged,
    required this.submittedOffersCubit,
  });

  final JeeberFeedTab active;
  final ValueChanged<JeeberFeedTab?> onChanged;

  /// When present it is the authority on the pending count (the jeeber's real
  /// submitted offers); otherwise the feed-derived count stands in.
  final SubmittedOffersCubit? submittedOffersCubit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestFeedCubit, RequestFeedState>(
      builder: (context, feedState) {
        final cubit = submittedOffersCubit;
        if (cubit == null) {
          return _strip(context, feedState, _count(feedState, _pendingStatus));
        }
        return BlocBuilder<SubmittedOffersCubit, SubmittedOffersState>(
          bloc: cubit,
          builder: (context, offersState) =>
              _strip(context, feedState, offersState.offers.length),
        );
      },
    );
  }

  static const JeeberFeedItemStatus _pendingStatus =
      JeeberFeedItemStatus.pendingResponse;

  Widget _strip(
    BuildContext context,
    RequestFeedState feedState,
    int pendingCount,
  ) {
    final l10n = AppLocalizations.of(context);
    // Three equal shares, never a scroller: a scrolling row parked the third
    // chip half off-screen ("Repli…") with nothing to say it was scrollable.
    return Row(
      key: JeeberFeedTabView.tabStripKey,
      children: [
        Expanded(
          child: _tabChip(
            identifier: 'jeeber_feed_requests_tab',
            label: l10n.jeeberFeedNearbyCount(
              _count(feedState, JeeberFeedItemStatus.incoming),
            ),
            semanticLabel: l10n.jeeberFeedFilterRequests,
            tab: JeeberFeedTab.requests,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: _tabChip(
            identifier: 'jeeber_feed_pending_tab',
            label: l10n.jeeberFeedPendingCount(pendingCount),
            semanticLabel: l10n.jeeberFeedFilterPendingResponse,
            tab: JeeberFeedTab.pendingResponse,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: _tabChip(
            identifier: 'jeeber_feed_replies_tab',
            label: l10n.jeeberFeedRepliesCount(
              _count(feedState, JeeberFeedItemStatus.accepted),
            ),
            semanticLabel: l10n.jeeberFeedFilterReplies,
            tab: JeeberFeedTab.replies,
          ),
        ),
      ],
    );
  }

  /// [jeeberFeedVisibleRequests] minus the query/tier facets: what the tab
  /// would show if you tapped it right now.
  int _count(RequestFeedState state, JeeberFeedItemStatus status) {
    return state.requests
        .where(
          (r) =>
              r.requestIsOpen &&
              r.feedStatus == status &&
              !state.expiredIds.contains(r.id),
        )
        .length;
  }

  Widget _tabChip({
    required String identifier,
    required String label,
    required String semanticLabel,
    required JeeberFeedTab tab,
  }) {
    void onTap() => onChanged(tab);
    return Semantics(
      identifier: identifier,
      button: true,
      selected: active == tab,
      // TalkBack reads the tab, not "Nearby twelve" — the count is decoration
      // for the eye and noise for the ear.
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(
          onTap: onTap,
          // FittedBox, not the chip's own ellipsis: under an equal share a long
          // localized label has to shrink to stay readable, never truncate.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: JeebSelectChip(
              role: JeebChipRole.filter,
              label: label,
              selected: active == tab,
            ),
          ),
        ),
      ),
    );
  }
}

/// The request rows as a SLIVER of the page scroll view.
///
/// Sliver (not a nested `ListView`) so the rows share the page's single scroll
/// surface: a tall active-deliveries banner above them pushes them down the
/// page instead of squeezing them out of a fixed-height inner viewport, and
/// they stay reachable by scrolling.
class _FeedRequestSliver extends StatelessWidget {
  const _FeedRequestSliver({
    required this.activeTab,
    required this.tierFilter,
    required this.query,
    required this.onOpenRequest,
    required this.onMakeOffer,
    required this.onClearFilters,
  });

  final JeeberFeedTab activeTab;
  final JeeberTierFilter tierFilter;
  final String query;
  final ValueChanged<DeliveryRequest>? onOpenRequest;
  final ValueChanged<DeliveryRequest> onMakeOffer;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestFeedCubit, RequestFeedState>(
      builder: (context, state) => _FeedRequestSliverBody(
        state: state,
        activeTab: activeTab,
        tierFilter: tierFilter,
        query: query,
        onOpenRequest: onOpenRequest,
        onMakeOffer: onMakeOffer,
        onClearFilters: onClearFilters,
      ),
    );
  }
}

class _FeedRequestSliverBody extends StatelessWidget {
  const _FeedRequestSliverBody({
    required this.state,
    required this.activeTab,
    required this.tierFilter,
    required this.query,
    required this.onOpenRequest,
    required this.onMakeOffer,
    required this.onClearFilters,
  });

  final RequestFeedState state;
  final JeeberFeedTab activeTab;
  final JeeberTierFilter tierFilter;
  final String query;
  final ValueChanged<DeliveryRequest>? onOpenRequest;
  final ValueChanged<DeliveryRequest> onMakeOffer;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final visible = jeeberFeedVisibleRequests(
      source: state.requests,
      tab: activeTab,
      tier: tierFilter,
      query: query,
    );
    final cubit = context.read<RequestFeedCubit>();
    // ES-05: error, then filtered-empty, then the plain empty board.
    if (state.status == RequestFeedStatus.error && state.requests.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: true,
        child: _FeedFailureBody(failure: state.error, onRetry: cubit.refresh),
      );
    }
    if (state.requests.isNotEmpty && visible.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: true,
        child: _FilteredEmptyState(onClearFilters: onClearFilters),
      );
    }
    if (visible.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: true,
        child: _EmptyTabState(onRefresh: cubit.refresh),
      );
    }
    // JM-048: the FIRST incoming row exposes the screen-level
    // `feed_make_offer_cta` so the QA flow taps an unambiguous make-offer CTA
    // — never an expired card, whose offer affordance is inert.
    final firstIncomingIndex = visible.indexWhere(
      (r) =>
          r.feedStatus == JeeberFeedItemStatus.incoming &&
          !state.expiredIds.contains(r.id),
    );
    return SliverPadding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
      sliver: SliverList.builder(
        key: JeeberFeedTabView.listKey,
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final request = visible[index];
          return JeeberFeedCard(
            request: request,
            isExpired: state.expiredIds.contains(request.id),
            // JM-048: card tap opens detail; the "Offer" button routes through
            // the KYC gate / composer (D38), distinct from a plain detail open.
            // POST-ACCEPT ENTRY POINT: an ACCEPTED (Replies-tab) card is the
            // jeeber's surface for a delivery whose offer the customer
            // accepted — tapping it opens the order conversation (chat-detail
            // keyed on the request id == correlationKey, resolved against the
            // live gateway), NOT the pre-offer make-offer/decline detail.
            onTap: request.feedStatus == JeeberFeedItemStatus.accepted
                ? () => GoRouter.of(
                    context,
                  ).pushNamed('chat-detail', pathParameters: {'id': request.id})
                : onOpenRequest == null
                ? null
                : () => onOpenRequest!(request),
            onIgnore: () => cubit.decline(request.id),
            onOffer: () => onMakeOffer(request),
            onAdvanceStatus: () => cubit.accept(request.id),
            exposeMakeOfferId: index == firstIncomingIndex,
            // R5: the same computation also decides the ONE orange CTA on the
            // screen — the newest offerable row. No second source of truth.
            isFreshest: index == firstIncomingIndex,
            // TODO(redesign-24): the board marks voice-filed requests with a
            // waveform. `DeliveryRequest` carries no `hasAudio`/`audioUrl`, so
            // the mark stays off rather than guessed — see W-2 §4.5.
            isVoice: false,
          );
        },
      ),
    );
  }
}

/// An empty tab is E3 — the same "Empty ≠ dead" panel the no-requests screen
/// draws. Always-scrollable: pull-to-refresh over an empty feed depends on it.
class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  // Only reached when the jeeber is on duty; the duty-off body is separate.
  Widget build(BuildContext context) => JeeberFeedEmptyPanel(
    isOnline: true,
    onRefresh: onRefresh,
  );
}

/// A filter emptied the list — the way out is clearing it, not a refresh.
class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebStateHost(
      child: JeebEmptyState(
        reason: JeebEmptyStateReason.filtered,
        variant: JeebEmptyStateVariant.street,
        identifier: 'jeeber_feed_filtered_empty_state',
        headline: l10n.jeeberFeedFilterEmptyTitle,
        body: l10n.jeeberFeedFilterEmptyBody,
        secondaryAction: JeebCtaButton.text(
          label: l10n.actionClearFilters,
          expand: false,
          identifier: 'jeeber_feed_clear_filters_cta',
          onTap: onClearFilters,
        ),
      ),
    );
  }
}

/// The feed's cold failure inside the sliver body.
class _FeedFailureBody extends StatelessWidget {
  const _FeedFailureBody({required this.failure, required this.onRetry});

  final AppFailure? failure;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final resolved = failure ?? const UnknownFailure();
    final exit = jeeberFailureExit(
      context,
      resolved,
      AppLocalizations.of(context),
      onReload: onRetry,
    );
    return JeebStateHost(
      child: JeebFailureBlock(
        failure: resolved,
        identifier: 'jeeber_feed_error',
        retryIdentifier: 'jeeber_feed_retry_cta',
        exitIdentifier: 'jeeber_feed_exit_cta',
        variant: JeebEmptyStateVariant.street,
        onRetry: () => onRetry(),
        onExit: exit.onExit,
        exitLabel: exit.label,
      ),
    );
  }
}

/// LR-12: a refresh failed while rows are on screen — the strip says so and
/// the rows stay.
class _FeedRefreshFailedNote extends StatelessWidget {
  const _FeedRefreshFailedNote();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestFeedCubit, RequestFeedState>(
      buildWhen: (prev, curr) => prev.refreshError != curr.refreshError,
      builder: (context, state) {
        final failure = state.refreshError;
        if (failure == null) return const SizedBox.shrink();
        final cubit = context.read<RequestFeedCubit>();
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.small,
            Spacing.xLarge,
            0,
          ),
          child: JeebRefreshFailedNote(
            failure: failure,
            identifier: 'jeeber_feed_refresh_failed_note',
            onDismiss: cubit.clearRefreshError,
            onRetry: () => cubit.refresh(),
          ),
        );
      },
    );
  }
}

/// JM-048 AC3 + JM-047: the Pending-Response sub-tab body, backed by the
/// jeeber's submitted offers (`GET /offer-service/v1/offers?jeeberId=`). Renders
/// `pending_offer_<index>` rows with the per-row withdraw control (D15); empty
/// and loading states reuse the feed's chrome.
class _PendingOffersList extends StatelessWidget {
  const _PendingOffersList({required this.cubit, this.onBack});

  final SubmittedOffersCubit cubit;

  /// JM-047 AC4: invoked by the pending sub-tab's back control to return to the
  /// Requests sub-tab (delivery-requests). Optional so the widget stays usable
  /// in a harness that does not supply it.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SubmittedOffersCubit>.value(
      value: cubit,
      child: BlocListener<SubmittedOffersCubit, SubmittedOffersState>(
        bloc: cubit,
        listenWhen: (prev, curr) =>
            prev.lastEffect != curr.lastEffect && curr.lastEffect != null,
        listener: (context, state) => _onWithdrawFailed(context, state),
        child: Column(
          children: [
            _PendingOffersBackBar(onBack: onBack),
            Expanded(
              child: BlocBuilder<SubmittedOffersCubit, SubmittedOffersState>(
                bloc: cubit,
                builder: (context, state) => JeebPullToRefresh(
                  onRefresh: cubit.load,
                  child: _pendingBody(context, state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onWithdrawFailed(BuildContext context, SubmittedOffersState state) {
    final effect = state.lastEffect!;
    final l10n = AppLocalizations.of(context);
    showJeebErrorSnack(
      context,
      failure: effect.failure,
      message: effect.failure == null ? l10n.pendingOffersWithdrawFailed : null,
      identifier: 'pending_offers_withdraw_failed_snack',
      retryLabel: l10n.actionRetry,
      onRetry: () => cubit.withdraw(effect.offerId),
    );
    cubit.clearEffect();
  }

  Widget _pendingBody(BuildContext context, SubmittedOffersState state) {
    final l10n = AppLocalizations.of(context);
    if (state.status == SubmittedOffersStatus.loading && state.offers.isEmpty) {
      return JeebStateHost(
        child: JeebEmptyState(
          status: JeebEmptyStateStatus.loading,
          variant: JeebEmptyStateVariant.pocket,
          identifier: 'jeeber_pending_offers_loading',
          headline: l10n.pendingOffersLoadingHeadline,
        ),
      );
    }
    // UX-03: the error rung comes strictly before the empty one.
    if (state.status == SubmittedOffersStatus.error && state.offers.isEmpty) {
      final resolved = state.error ?? const UnknownFailure();
      final exit = jeeberFailureExit(context, resolved, l10n, onReload: cubit.load);
      return JeebStateHost(
        child: JeebFailureBlock(
          failure: resolved,
          identifier: 'jeeber_pending_offers_error',
          retryIdentifier: 'jeeber_pending_offers_retry_cta',
          exitIdentifier: 'jeeber_pending_offers_exit_cta',
          variant: JeebEmptyStateVariant.pocket,
          onRetry: () => cubit.load(),
          onExit: exit.onExit,
          exitLabel: exit.label,
        ),
      );
    }
    if (state.offers.isEmpty) {
      return _PendingEmptyState(l10n: l10n);
    }
    final refreshError = state.refreshError;
    return Column(
      children: [
        if (refreshError != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.small,
              Spacing.xLarge,
              0,
            ),
            child: JeebRefreshFailedNote(
              failure: refreshError,
              identifier: 'jeeber_pending_offers_refresh_failed_note',
              onDismiss: cubit.clearRefreshError,
              onRetry: () => cubit.load(),
            ),
          ),
        Expanded(
          child: ListView.builder(
            key: JeeberFeedTabView.pendingListKey,
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: Spacing.small,
            ),
            itemCount: state.offers.length,
            itemBuilder: (_, index) {
              final offer = state.offers[index];
              return PendingOfferRow(
                index: index,
                offer: offer,
                isWithdrawing: state.isWithdrawing(offer.id),
                onWithdraw: () => cubit.withdraw(offer.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// JM-047 AC4 (RD-2): the pending sub-tab's back affordance. The feed lives
/// inside the shell (no app bar of its own), so this leading row carries the
/// `pending_offers_back` Semantics id — mirroring the standalone
/// `jeeber-pending-offers` route's back idiom — and returns to the Requests
/// sub-tab (delivery-requests / jeeber-requests-home). The asserted contract is
/// the Semantics id, not visible text (i18n-safe, CTO brief §6.6); the back
/// glyph's tooltip is framework-localized via [BackButton].
class _PendingOffersBackBar extends StatelessWidget {
  const _PendingOffersBackBar({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        identifier: 'pending_offers_back',
        button: true,
        container: true,
        child: BackButton(onPressed: onBack ?? () {}),
      ),
    );
  }
}

class _PendingEmptyState extends StatelessWidget {
  const _PendingEmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return JeebStateHost(
      child: JeebEmptyState(
        identifier: 'jeeber_pending_offers_empty_state',
        variant: JeebEmptyStateVariant.pocket,
        headline: l10n.pendingOffersEmptyTitle,
        body: l10n.pendingOffersEmptyBody,
      ),
    );
  }
}
