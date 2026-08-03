import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_cubit.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import '../../../jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../jeeber_request_feed/cubit/request_feed_state.dart';
import '../../../jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../../jeeber_request_feed/cubit/submitted_offers_state.dart';
import '../../../jeeber_request_feed/data/request_feed_models.dart';
import '../../../jeeber_request_feed/presentation/jeeber_feed_card.dart';
import '../../../jeeber_request_feed/presentation/pending_offer_row.dart';
import 'availability_card.dart';
import 'jeeber_home_greeting.dart';

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

/// State 3 of the Jeeber home: registered, available, and at least one
/// live request in the feed.
///
/// Renders the single greeting title → state-aware availability → compact
/// active-work disclosure → OMDS search bar → feed tabs/filters →
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
  // Keep the editing session at screen lifetime: local filtering rebuilds the
  // feed on every keystroke and must not transfer IME state to a new owner.
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  JeeberTierFilter _tierFilter = JeeberTierFilter.all;
  String _query = '';

  /// C8: the search field is collapsed behind the magnifier at rest — the board
  /// spends the row on the count chips, not on an empty input. This is the
  /// search *affordance*, not the deleted global-search feature.
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    // Lazily warm the pending list if the view opens directly on the Pending
    // tab (deep-link / dev-seam `initialTab`).
    if (_activeTab == JeeberFeedTab.pendingResponse) {
      _loadPendingOffers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
    // JEBV4-284: the fixed header stack (greeting + availability card, plus —
    // once online — the search bar + tab/tier strips) has enough natural
    // height that once the on-screen keyboard shows (search field focused)
    // and eats into the viewport, a plain Column + Expanded still overflows:
    // Expanded floors at zero, but the *non-flexible* header total alone
    // already exceeds what is left ("BOTTOM OVERFLOWED BY 100 PIXELS" on
    // SM-S921B, run-26). A CustomScrollView lets the whole body scroll
    // instead of overflow when squeezed — the same remedy `_NoRequestsScope`
    // above already applies for its own tall-content overflow (Fix 6(b)).
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
          ..._feedControls().map((w) => SliverToBoxAdapter(child: w)),
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
          : OmdsPullToRefresh(
              onRefresh: () => context.read<RequestFeedCubit>().refresh(),
              child: scrollView,
            ),
    );
  }

  List<Widget> _feedControls() => [
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
          _SearchToggle(expanded: _searchExpanded, onTap: _onSearchToggled),
        ],
      ),
    ),
    if (_searchExpanded) ...[
      const SizedBox(height: Spacing.small),
      _FeedSearchBar(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (query) => setState(() => _query = query),
      ),
    ],
    if (_activeTab == JeeberFeedTab.requests) ...[
      const SizedBox(height: Spacing.small),
      _TierFilterStrip(active: _tierFilter, onChanged: _onTierChanged),
    ],
  ];

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
        SliverFillRemaining(hasScrollBody: false, child: _OfflineEmptyBody()),
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
        activeTab: _activeTab,
        tierFilter: _tierFilter,
        query: _query,
        onOpenRequest: widget.onOpenRequest,
        onMakeOffer: (req) => _onMakeOffer(context, req),
      ),
    ];
  }

  void _onTabChanged(JeeberFeedTab? next) {
    if (next == null || next == _activeTab) return;
    setState(() => _activeTab = next);
    if (next == JeeberFeedTab.pendingResponse) {
      _loadPendingOffers();
    }
  }

  void _onTierChanged(JeeberTierFilter? next) {
    if (next == null || next == _tierFilter) return;
    setState(() => _tierFilter = next);
  }

  /// Expanding focuses the field straight away (the tap WAS the intent to
  /// type); collapsing clears the query too, so a hidden filter can never keep
  /// suppressing rows the jeeber can no longer see a reason for.
  void _onSearchToggled() {
    if (_searchExpanded) {
      setState(() {
        _searchExpanded = false;
        _query = '';
        _searchController.clear();
      });
      return;
    }
    setState(() => _searchExpanded = true);
    _searchFocusNode.requestFocus();
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
        icon: Icons.wifi_off,
        title: l10n.jeeberFeedOfflineBannerTitle,
        text: l10n.jeeberFeedOfflineBannerSubtitle,
      ),
    );
  }
}

/// Empty body shown while the Jeeber is offline (feed cleared per AC3).
class _OfflineEmptyBody extends StatelessWidget {
  const _OfflineEmptyBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      icon: Icons.wifi_off,
      title: l10n.jeeberFeedOfflineBannerTitle,
      subtitle: l10n.jeeberFeedOfflineBannerSubtitle,
    );
  }
}

/// T-MOB-029: Tier filter chips — All / Flash / Express / Standard.
class _TierFilterStrip extends StatelessWidget {
  const _TierFilterStrip({required this.active, required this.onChanged});

  final JeeberTierFilter active;
  final ValueChanged<JeeberTierFilter?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = _filters(l10n);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      child: SingleChildScrollView(
        key: JeeberFeedTabView.tierStripKey,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.indexed.map((entry) {
            final (index, filter) = entry;
            return Padding(
              padding: EdgeInsetsDirectional.only(
                end: index < filters.length - 1 ? Spacing.xSmall : 0,
              ),
              child: _tierChip(index, filter),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  Widget _tierChip(int index, OmdsFilterOption<JeeberTierFilter> filter) {
    void onTap() => onChanged(filter.value);
    return Semantics(
      identifier: 'jeeber_feed_tier_chip_$index',
      button: true,
      selected: active == filter.value,
      label: filter.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(
          onTap: onTap,
          // No `onTap` on the pill: MinTapTarget owns the gesture (it wraps
          // its child in an IgnorePointer), so an InkWell here would be dead.
          child: JeebSelectChip(
            role: JeebChipRole.filter,
            label: filter.label,
            selected: active == filter.value,
          ),
        ),
      ),
    );
  }

  List<OmdsFilterOption<JeeberTierFilter>> _filters(AppLocalizations l10n) => [
    OmdsFilterOption(
      label: l10n.jeeberFeedTierAll,
      value: JeeberTierFilter.all,
    ),
    OmdsFilterOption(
      label: l10n.jeeberFeedTierFlash,
      value: JeeberTierFilter.flash,
    ),
    OmdsFilterOption(
      label: l10n.jeeberFeedTierExpress,
      value: JeeberTierFilter.express,
    ),
    OmdsFilterOption(
      label: l10n.jeeberFeedTierStandard,
      value: JeeberTierFilter.standard,
    ),
  ];
}

class _FeedSearchBar extends StatelessWidget {
  const _FeedSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      child: Semantics(
        identifier: 'jeeber_feed_search_field',
        child: OmdsSearchBar(
          key: JeeberFeedTabView.searchBarKey,
          controller: controller,
          focusNode: focusNode,
          hintText: AppLocalizations.of(context).jeeberFeedSearchHint,
          onChanged: onChanged,
        ),
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
/// so Arabic decides its own digit/word order.
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
    return SingleChildScrollView(
      key: JeeberFeedTabView.tabStripKey,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tabChip(
            identifier: 'jeeber_feed_requests_tab',
            label: l10n.jeeberFeedNearbyCount(
              _count(feedState, JeeberFeedItemStatus.incoming),
            ),
            semanticLabel: l10n.jeeberFeedFilterRequests,
            tab: JeeberFeedTab.requests,
          ),
          const SizedBox(width: Spacing.xSmall),
          _tabChip(
            identifier: 'jeeber_feed_pending_tab',
            label: l10n.jeeberFeedPendingCount(pendingCount),
            semanticLabel: l10n.jeeberFeedFilterPendingResponse,
            tab: JeeberFeedTab.pendingResponse,
          ),
          const SizedBox(width: Spacing.xSmall),
          _tabChip(
            identifier: 'jeeber_feed_replies_tab',
            label: l10n.jeeberFeedRepliesCount(
              _count(feedState, JeeberFeedItemStatus.accepted),
            ),
            semanticLabel: l10n.jeeberFeedFilterReplies,
            tab: JeeberFeedTab.replies,
          ),
        ],
      ),
    );
  }

  /// The `_visibleRequests` predicate minus the query/tier filters: what the
  /// tab would show if you tapped it right now.
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
          child: JeebSelectChip(
            role: JeebChipRole.filter,
            label: label,
            selected: active == tab,
          ),
        ),
      ),
    );
  }
}

/// The board's Ø38 magnifier disc. Tapping it reveals the search field (and
/// tapping it again hides + clears it), so the row at rest is chips only.
class _SearchToggle extends StatelessWidget {
  const _SearchToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'jeeber_feed_search_toggle',
      button: true,
      label: l10n.jeeberFeedSearchToggleLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(
          onTap: onTap,
          child: Container(
            width: Sizes.threeXLarge,
            height: Sizes.threeXLarge,
            alignment: AlignmentDirectional.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              expanded ? Icons.close : Icons.search,
              size: Sizes.medium,
              color: colorScheme.primary,
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
  });

  final JeeberFeedTab activeTab;
  final JeeberTierFilter tierFilter;
  final String query;
  final ValueChanged<DeliveryRequest>? onOpenRequest;
  final ValueChanged<DeliveryRequest> onMakeOffer;

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
  });

  final RequestFeedState state;
  final JeeberFeedTab activeTab;
  final JeeberTierFilter tierFilter;
  final String query;
  final ValueChanged<DeliveryRequest>? onOpenRequest;
  final ValueChanged<DeliveryRequest> onMakeOffer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = _visibleRequests(state.requests);
    if (visible.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: true,
        child: _EmptyTabState(l10n: l10n),
      );
    }
    final cubit = context.read<RequestFeedCubit>();
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

  /// Filters the cubit's request set by active tab + tier filter + search
  /// query.
  List<DeliveryRequest> _visibleRequests(List<DeliveryRequest> source) {
    final lowered = query.trim().toLowerCase();
    return source
        .where((r) {
          // The request status on the feed item is server-owned action
          // authority. Never expose a stale terminal row as offerable even if
          // a repository/cubit seam still supplies it during reconciliation.
          if (!r.requestIsOpen) return false;
          if (lowered.isNotEmpty && !_matchesQuery(r, lowered)) return false;
          if (r.feedStatus != _statusForTab(activeTab)) return false;
          if (!_matchesTier(r)) return false;
          return true;
        })
        .toList(growable: false);
  }

  JeeberFeedItemStatus _statusForTab(JeeberFeedTab tab) => switch (tab) {
    JeeberFeedTab.requests => JeeberFeedItemStatus.incoming,
    JeeberFeedTab.pendingResponse => JeeberFeedItemStatus.pendingResponse,
    JeeberFeedTab.replies => JeeberFeedItemStatus.accepted,
  };

  /// Returns true when the request matches the selected tier filter (AC2).
  ///
  /// Backend tier mapping: flash→Flash, standard→Express, light+bulk→Standard.
  bool _matchesTier(DeliveryRequest r) {
    return switch (tierFilter) {
      JeeberTierFilter.all => true,
      JeeberTierFilter.flash => r.tier == JeeberRequestTier.flash,
      JeeberTierFilter.express => r.tier == JeeberRequestTier.standard,
      JeeberTierFilter.standard =>
        r.tier == JeeberRequestTier.light || r.tier == JeeberRequestTier.bulk,
    };
  }

  bool _matchesQuery(DeliveryRequest r, String q) {
    return (r.senderName?.toLowerCase().contains(q) ?? false) ||
        (r.itemsSummary?.toLowerCase().contains(q) ?? false) ||
        r.pickup.label.toLowerCase().contains(q);
  }
}

/// An empty tab is not an error: two start-aligned lines where the first card
/// would be, on the same white body. The LayoutBuilder + always-scrollable
/// shell stays — pull-to-refresh over an empty feed depends on it.
class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedInk =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.light())
            .mutedText;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.xLarge,
              Spacing.xLarge,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.jeeberFeedEmptyTitle,
                  style: context.jeebText.titleProminent.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: Spacing.xSmall),
                Text(
                  l10n.jeeberFeedEmptySubtitle,
                  style: context.jeebText.bodySmall.copyWith(color: mutedInk),
                ),
              ],
            ),
          ),
        ),
      ),
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
      child: Column(
        children: [
          _PendingOffersBackBar(onBack: onBack),
          Expanded(
            child: BlocBuilder<SubmittedOffersCubit, SubmittedOffersState>(
              bloc: cubit,
              builder: (context, state) => OmdsPullToRefresh(
                onRefresh: cubit.load,
                child: _pendingBody(context, state),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingBody(BuildContext context, SubmittedOffersState state) {
    if (state.status == SubmittedOffersStatus.loading && state.offers.isEmpty) {
      return const Center(child: OmdsLoadingState());
    }
    if (state.offers.isEmpty) {
      return _PendingEmptyState(l10n: AppLocalizations.of(context));
    }
    return ListView.builder(
      key: JeeberFeedTabView.pendingListKey,
      padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: OmdsEmptyState(
            icon: Icons.hourglass_empty_rounded,
            title: l10n.pendingOffersEmptyTitle,
            subtitle: l10n.pendingOffersEmptyBody,
          ),
        ),
      ),
    );
  }
}
