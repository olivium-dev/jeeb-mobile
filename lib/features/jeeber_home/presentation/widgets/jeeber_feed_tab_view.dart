import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../jeeber_request_feed/data/request_feed_repository.dart';
import '../../../jeeber_request_feed/domain/submitted_offer.dart';
import '../../../jeeber_request_feed/domain/submitted_offers_repository.dart';
import '../../domain/services/availability_gateway.dart';

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
          ),
        ),
        if (isOffline) SliverToBoxAdapter(child: _OfflineBanner()),
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
    _FeedSearchBar(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: (query) => setState(() => _query = query),
    ),
    const SizedBox(height: Spacing.small),
    _FeedTabStrip(active: _activeTab, onChanged: _onTabChanged),
    const SizedBox(height: Spacing.small),
    if (_activeTab == JeeberFeedTab.requests)
      _TierFilterStrip(active: _tierFilter, onChanged: _onTierChanged),
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
}

/// T-MOB-029: Banner shown when Jeeber goes offline (AC3).
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      // Offline is an attention state (self-inflicted, recoverable), not a
      // failure -> semantic warning role instead of the error pair.
      color: context.jeebRoles.warningContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      child: _OfflineBannerContent(l10n: l10n),
    );
  }
}

class _OfflineBannerContent extends StatelessWidget {
  const _OfflineBannerContent({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final color = context.jeebRoles.onWarningContainer;
    return Row(
      children: [
        Icon(Icons.wifi_off, color: color, size: Sizes.large),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _OfflineBannerText(l10n: l10n, color: color),
        ),
      ],
    );
  }
}

class _OfflineBannerText extends StatelessWidget {
  const _OfflineBannerText({required this.l10n, required this.color});

  final AppLocalizations l10n;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.jeeberFeedOfflineBannerTitle,
          style: theme.textTheme.labelLarge?.copyWith(color: color),
        ),
        Text(
          l10n.jeeberFeedOfflineBannerSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
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
        horizontal: Spacing.medium,
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
          child: OmdsChip(
            label: filter.label,
            isSelected: active == filter.value,
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
        horizontal: Spacing.medium,
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

/// Feed sub-tab chips — Requests / Pending / Replies.
///
/// Built from individual [OmdsChip]s (not the monolithic [OmdsFilterChips])
/// because JM-048 needs a per-chip Semantics identifier on the Pending chip
/// (`jeeber_feed_pending_tab`) so the QA flow can tap it, which the bundled
/// filter-chips widget does not expose. Each chip carries its own id; all three
/// are queryable (honest), only `jeeber_feed_pending_tab` is contract-required.
class _FeedTabStrip extends StatelessWidget {
  const _FeedTabStrip({required this.active, required this.onChanged});

  final JeeberFeedTab active;
  final ValueChanged<JeeberFeedTab?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: JeeberFeedTabView.tabStripKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
      ),
      child: Row(
        children: [
          _tabChip(
            identifier: 'jeeber_feed_requests_tab',
            label: l10n.jeeberFeedFilterRequests,
            tab: JeeberFeedTab.requests,
          ),
          const SizedBox(width: Spacing.small),
          _tabChip(
            identifier: 'jeeber_feed_pending_tab',
            label: l10n.jeeberFeedFilterPendingResponse,
            tab: JeeberFeedTab.pendingResponse,
          ),
          const SizedBox(width: Spacing.small),
          _tabChip(
            identifier: 'jeeber_feed_replies_tab',
            label: l10n.jeeberFeedFilterReplies,
            tab: JeeberFeedTab.replies,
          ),
        ],
      ),
    );
  }

  Widget _tabChip({
    required String identifier,
    required String label,
    required JeeberFeedTab tab,
  }) {
    void onTap() => onChanged(tab);
    return Semantics(
      identifier: identifier,
      button: true,
      selected: active == tab,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(
          onTap: onTap,
          child: OmdsChip(
            label: label,
            isSelected: active == tab,
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

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: OmdsEmptyState(
            icon: Icons.inbox_outlined,
            title: l10n.jeeberFeedEmptyTitle,
            subtitle: l10n.jeeberFeedEmptySubtitle,
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/jeeber_home/jeeber_feed_tab_view_preview_test.dart
// ===========================================================================
//
// Widget previews for [JeeberFeedTabView] — run with
// `flutter widget-preview start`.
//
// Unlike the leaf widgets it composes ([JeeberHomeGreeting],
// [AvailabilityCard], [JeeberFeedCard], [PendingOfferRow], each previewed in
// its own file), this widget is a whole PAGE. Its states are not "what does
// one card look like" but "which of five structurally different bodies is the
// jeeber looking at", and the page's own chrome — greeting, availability
// control, search bar, two chip strips — changes with them:
//
// * ONLINE + rows → the full chrome over a `SliverList` of [JeeberFeedCard]s.
// * ONLINE + nothing matching the active filter → the same chrome over one
//   centred empty state, whatever the reason (no requests, a tier chip that
//   excludes them all, or a search query that matches none).
// * OFFLINE → a warning banner, and the search bar + BOTH chip strips are
//   gone: `_buildBody` drops `_feedControls()` entirely, so an offline jeeber
//   cannot even see which tab they were on.
// * PENDING-RESPONSE with a [SubmittedOffersCubit] → a completely different
//   body ([_PendingOffersList]: its own back bar, its own list, its own empty
//   and loading states) mounted under the same chrome.
// * REPLIES → the same sliver as Requests, filtered to accepted rows, whose
//   cards carry an advance-delivery pill instead of Ignore/Offer.
//
// ## Network-free by construction
//
// Both ambient cubits are seeded subclasses that [Cubit.emit] one frame in
// their constructor and are never `start()`ed / `load()`ed, so no poll, no
// sweep timer and no socket exists behind these previews. Their repositories
// are the in-memory [SeededRequestFeedRepository] and a local canned
// [_JeeberFeedTabViewOffersRepository], so even the pull-to-refresh and
// withdraw affordances a reviewer taps in the canvas resolve locally. The
// guard in [jeebPreviewHost] is a net, not the plan.
//
// [JeeberFeedTabView.onMakeOffer] is deliberately left null, matching
// `jeeber_home_screen.dart`: the view then self-routes through
// `_defaultMakeOffer`, which returns early when `GoRouter.maybeOf` is null —
// so the production wiring is what is on review and the canvas still cannot
// navigate anywhere.
//
// ## What these previews expose
//
// * **The feed has no loading and no error surface at all.**
//   `_FeedRequestSliverBody` reads `state.requests` and nothing else, so
//   `RequestFeedStatus.loading` and `.error` both render "No Requests yet" —
//   byte-identical to a genuinely empty feed. A jeeber whose
//   `GET /v1/jeebers/me/feed` is failing is told there is no work. That is why
//   there is no separate "loading" or "error" preview below: there would be
//   nothing to look at. [jeeberFeedTabViewEmptyFeed] is all three states.
// * **Offline hides the tabs.** [jeeberFeedTabViewOffline] is seeded WITH a
//   request in the cubit precisely to show that going offline empties the feed
//   (T-MOB-029 AC3) *and* removes the tab strip — so a jeeber sitting on
//   Pending who toggles off loses the affordance to get back.
// * **The offline copy is printed twice**, once in the banner and once in the
//   empty body under it, with no other information between them.
// * The action row of an incoming card is where this page overflows first;
//   [jeeberFeedTabViewLongContent] pins it at the 360 pt Galaxy S22 width this
//   project ships against, which is where the Arabic Ignore/Offer pair runs out
//   of room. See the measured table in `jeeber_feed_card.dart`'s own section.
//
// The fixture values are the ones the existing widget tests already use —
// `Spinneys Dbayeh` / `Home, Ashrafieh` from `jeeber_feed_make_offer_test.dart`
// and the `12.5 USD / 25 min` offer from the same file — so a reviewer
// comparing the canvas against the suite sees the same page.

/// A phone page. 844 pt is the iPhone 14 viewport, i.e. enough that the feed's
/// header stack and at least two cards are on screen at once — which is the
/// whole question this widget answers (JEBV4-284 / the banner regression were
/// both "the rows exist but are below the fold").
const Size _jeeberFeedTabViewPageBox = Size(390, 844);

/// The Galaxy S22 width — the device this project runs its final on-device
/// check on, and the narrowest mainstream Android. 30 pt narrower than
/// [_jeeberFeedTabViewPageBox] is the difference between a card's Ignore/Offer
/// row fitting in Arabic and losing the Offer button off the edge.
const Size _jeeberFeedTabViewNarrowBox = Size(360, 844);

/// The instant the gateway reports, as a UTC instant. The card converts to
/// device-local before formatting (SW-03); a constant keeps the canvas from
/// re-rendering on a clock tick.
final DateTime _jeeberFeedTabViewReceivedAtUtc = DateTime.utc(
  2026,
  6,
  11,
  9,
  41,
);

/// Far enough out that nothing here expires by accident — these previews never
/// run the cubit's expiry sweep, so the deadline is inert either way.
final DateTime _jeeberFeedTabViewExpiresAt = DateTime.utc(2030);

/// One feed row. Defaults are the happy path from
/// `test/jeeber_feed_make_offer_test.dart`; each preview overrides only the
/// fields that define its state.
DeliveryRequest _jeeberFeedTabViewRequest({
  required String id,
  JeeberFeedItemStatus status = JeeberFeedItemStatus.incoming,
  JeeberDeliveryAction? action,
  String? senderName = 'Sami Fawaz',
  JeeberRequestTier? tier = JeeberRequestTier.flash,
  String? itemsSummary = '1 kilo potato, water gallon, coffee blend',
  double? distanceFromYouKm = 3,
}) {
  return DeliveryRequest(
    id: id,
    pickup: const RequestLocation(
      label: 'Spinneys Dbayeh',
      latitude: 33.8,
      longitude: 35.5,
    ),
    dropoff: const RequestLocation(
      label: 'Home, Ashrafieh',
      latitude: 33.9,
      longitude: 35.6,
    ),
    tier: tier,
    estimatedDistanceKm: 1.2,
    potentialEarnings: 10,
    currency: 'USD',
    expiresAt: _jeeberFeedTabViewExpiresAt,
    senderName: senderName,
    senderRating: 4,
    itemsSummary: itemsSummary,
    distanceFromYouKm: distanceFromYouKm,
    receivedAt: _jeeberFeedTabViewReceivedAtUtc,
    feedStatus: status,
    nextDeliveryAction: action,
  );
}

/// An inert ticker. [AvailabilityCubit]'s default factory is
/// `Stream.periodic(1 min)`, which a toggle in the canvas would start for real
/// and leave running behind every card; an empty stream keeps the toggle live
/// without the timer.
Stream<DateTime> _jeeberFeedTabViewNoTicker() => const Stream<DateTime>.empty();

/// [AvailabilityCubit] pinned to one frame: seeded in the constructor rather
/// than fetched, so there is no cold-start round trip and no idle ticker.
class _JeeberFeedTabViewAvailabilityCubit extends AvailabilityCubit {
  _JeeberFeedTabViewAvailabilityCubit(AvailabilityViewState seed)
    : super(
        gateway: InMemoryAvailabilityGateway(initial: seed.status),
        tickerFactory: _jeeberFeedTabViewNoTicker,
      ) {
    emit(seed);
  }
}

/// [RequestFeedCubit] pinned to one frame.
///
/// Never `start()`ed, so none of its three live subscriptions and neither of
/// its timers exist. The repository is the in-memory
/// [SeededRequestFeedRepository] holding the SAME snapshot, so the
/// pull-to-refresh the view wires up replays the fixture instead of reaching
/// `GET /v1/jeebers/me/feed`.
class _JeeberFeedTabViewFeedCubit extends RequestFeedCubit {
  _JeeberFeedTabViewFeedCubit(List<DeliveryRequest> requests)
    : super(repository: SeededRequestFeedRepository(requests)) {
    emit(
      RequestFeedState(
        status: RequestFeedStatus.ready,
        requests: requests,
      ),
    );
  }
}

/// Canned submitted offers — no Dio, no
/// `GET /offer-service/v1/offers?jeeberId=`. [withdraw] succeeds so the
/// per-row Withdraw control is honest to tap in the canvas.
class _JeeberFeedTabViewOffersRepository implements SubmittedOffersRepository {
  const _JeeberFeedTabViewOffersRepository(this._offers);

  final List<SubmittedOffer> _offers;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async => _offers;

  @override
  Future<bool> withdraw(String offerId) async => true;
}

/// [SubmittedOffersCubit] pinned to one frame. Seeded past
/// [SubmittedOffersStatus.initial] on purpose: that is the only status the
/// view's `_loadPendingOffers` will call `load()` for, so a seeded cubit is
/// never asked to fetch.
class _JeeberFeedTabViewOffersCubit extends SubmittedOffersCubit {
  _JeeberFeedTabViewOffersCubit(SubmittedOffersState seed)
    : super(repository: _JeeberFeedTabViewOffersRepository(seed.offers)) {
    emit(seed);
  }
}

/// The page as `jeeber_home_screen.dart` mounts it: both cubits ambient, a
/// profile name threaded for the greeting, `onOpenRequest` wired and
/// `onMakeOffer` left null so the view's own KYC-gate routing is what renders.
///
/// [leadingBanner] is not exercised here — the active-deliveries card belongs
/// to another feature and carries its own cubit; its interaction with this feed
/// is pinned by `test/features/shell/jeeber_feed_banner_hides_requests_test.dart`.
Widget _jeeberFeedTabViewHosted({
  AvailabilityState availability = AvailabilityState.online,
  List<DeliveryRequest> requests = const <DeliveryRequest>[],
  JeeberFeedTab initialTab = JeeberFeedTab.requests,
  SubmittedOffersState? submittedOffers,
}) {
  final SubmittedOffersState? offers = submittedOffers;
  return MultiBlocProvider(
    providers: [
      BlocProvider<AvailabilityCubit>(
        create: (_) => _JeeberFeedTabViewAvailabilityCubit(
          AvailabilityViewState(
            loadPhase: AvailabilityLoadPhase.ready,
            status: AvailabilityStatus(
              state: availability,
              activeDeliveryCount: 0,
            ),
          ),
        ),
      ),
      BlocProvider<RequestFeedCubit>(
        create: (_) => _JeeberFeedTabViewFeedCubit(requests),
      ),
    ],
    child: JeeberFeedTabView(
      profileName: 'Kamal',
      initialTab: initialTab,
      submittedOffersCubit: offers == null
          ? null
          : _JeeberFeedTabViewOffersCubit(offers),
      onOpenRequest: (_) {},
    ),
  );
}

/// State 3 of the jeeber home, and the reason the widget exists: online, with
/// live auctions on the board.
///
/// The full chrome is stacked above the rows — greeting, compact availability
/// switch, search bar, three sub-tabs, four tier chips — and that stack is what
/// makes this page fragile: it is ~290 pt of non-flexible header before the
/// first card, on a viewport that shrinks to ~370 pt the moment the search
/// field takes focus and the keyboard opens (JEBV4-284, measured on SM-S921B).
/// Everything is one `CustomScrollView` for that reason; the second card being
/// reachable by scrolling here is the contract.
///
/// Two rows, deliberately unlike each other — a Flash request with a rating and
/// a 3 km distance line, and a Standard one with a short description — so the
/// card's optional-field branches are both on screen for comparison.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Requests · live feed',
  size: _jeeberFeedTabViewPageBox,
)
Widget jeeberFeedTabViewLiveFeed() => _jeeberFeedTabViewHosted(
  requests: [
    _jeeberFeedTabViewRequest(id: 'req-feed-001'),
    _jeeberFeedTabViewRequest(
      id: 'req-feed-002',
      senderName: 'Layla Hamdan',
      tier: JeeberRequestTier.standard,
      itemsSummary: 'Envelope from the notary on Bliss Street',
      distanceFromYouKm: 0.4,
    ),
  ],
);

/// Nothing on the board — **and also every failure this page can have.**
///
/// `_FeedRequestSliverBody` branches on `state.requests.isEmpty` and reads
/// `RequestFeedState.status` not at all, so this exact rendering is what a
/// jeeber sees for all four of:
///
///   * a genuinely empty feed (this fixture),
///   * `RequestFeedStatus.loading` — the cold-start frame, with no spinner,
///   * `RequestFeedStatus.error` — a failed `GET /v1/jeebers/me/feed`, whose
///     `errorMessageKey` the cubit sets and nothing here renders,
///   * a non-empty feed filtered to nothing by a tier chip or a search query.
///
/// "No Requests yet / All requests will show up here" is a confident claim to
/// make in the last three of those. Worth reviewing as the page a jeeber stares
/// at while wondering why no work is arriving.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Requests · empty feed',
  size: _jeeberFeedTabViewPageBox,
)
Widget jeeberFeedTabViewEmptyFeed() => _jeeberFeedTabViewHosted();

/// The layout ceiling: the longest plausible row on the narrowest real device.
///
/// A client name that cannot fit on one line, a real-world food order as the
/// description, a two-digit distance — still incoming, so the Ignore and Offer
/// buttons compete for the same footer — all at 360 pt.
///
/// The name and the description hold (`maxLines` 1 and 2, both ellipsized).
/// The action row does not: in Arabic the Ignore/Offer pair is a
/// `Row(mainAxisSize: min)` that does not wrap, and its labels are wider than
/// the English ones. This is the width and the state where a jeeber loses the
/// Offer button off the trailing edge, which is why this is one of the two
/// previews here that draws the full matrix — the EN light rendering looks
/// clean long after the other two have broken.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Requests · longest content · 360 pt',
  size: _jeeberFeedTabViewNarrowBox,
  matrix: true,
)
Widget jeeberFeedTabViewLongContent() => _jeeberFeedTabViewHosted(
  requests: [
    _jeeberFeedTabViewRequest(
      id: 'req-long',
      senderName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      tier: JeeberRequestTier.standard,
      itemsSummary:
          '2 shawarma + cola from Barbar, extra garlic, no pickles, and a '
          'large fries — call me when you arrive at the building entrance, '
          'third floor, ring twice',
      distanceFromYouKm: 12.5,
    ),
  ],
);

/// T-MOB-029 AC3: the jeeber toggled themselves off.
///
/// Seeded WITH a live request in the cubit, because the point of the state is
/// what disappears. Going offline does not just add a banner:
///
///   * the feed is replaced wholesale by `_OfflineEmptyBody` — the request in
///     the cubit is still there and is not drawn;
///   * `_feedControls()` is skipped entirely, so the search bar, the three
///     sub-tabs and the four tier chips are all gone. A jeeber who was reading
///     the Pending tab and toggles off has no visible way back to it, and no
///     indication the tabs ever existed;
///   * pull-to-refresh is dropped too (`_buildBody` returns the bare scroll
///     view), so the page's only refresh affordance goes with it.
///
/// The full matrix is on here because the banner is the page's only [Row] of
/// icon + text and the state has to survive RTL mirroring and dark mode — and
/// because "You are offline / Go online to see available requests" is printed
/// **twice**, in the banner and again in the empty body, with nothing between
/// them; at 200% text those two identical blocks are most of the screen.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Offline · feed cleared, controls hidden',
  size: _jeeberFeedTabViewPageBox,
  matrix: true,
)
Widget jeeberFeedTabViewOffline() => _jeeberFeedTabViewHosted(
  availability: AvailabilityState.offline,
  requests: [_jeeberFeedTabViewRequest(id: 'req-feed-001')],
);

/// JM-047/048 AC3: the Pending-Response sub-tab, backed by the jeeber's own
/// submitted offers.
///
/// A structurally different body under the same chrome — [_PendingOffersList]
/// brings its own leading back bar (`pending_offers_back`, the tab's stand-in
/// for an app bar it does not have) and its own `ListView`, and the tier chips
/// vanish because `_feedControls` only emits them on the Requests tab.
///
/// Two offers on purpose: one still open (price, ETA, the "Pending" awaiting
/// label and a Withdraw pill) and one the customer accepted (an outcome badge,
/// no Withdraw). Per the measurements in `pending_offer_row.dart`'s own section
/// those are 141 pt and 89 pt tall at this width, so this is also where the
/// list's ragged vertical rhythm shows up in a real list rather than in
/// isolation.
///
/// The matrix is deliberately OFF here — the row's own previews already carry
/// it, and this state is about the LIST. Switch the canvas to dark to see the
/// defect that matters: `PendingOfferRow` paints the price in
/// `colorScheme.secondaryContainer`, a container-fill role used as a
/// foreground, which measures 1.98:1 on the dark surface.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Pending · submitted offers',
  size: _jeeberFeedTabViewPageBox,
)
Widget jeeberFeedTabViewPendingOffers() => _jeeberFeedTabViewHosted(
  initialTab: JeeberFeedTab.pendingResponse,
  requests: [_jeeberFeedTabViewRequest(id: 'req-feed-001')],
  submittedOffers: const SubmittedOffersState(
    status: SubmittedOffersStatus.ready,
    offers: [
      SubmittedOffer(
        id: 'pending-offer-jeeber-001',
        requestId: 'req-feed-001',
        price: 12.5,
        currency: 'USD',
        etaMinutes: 25,
      ),
      SubmittedOffer(
        id: 'pending-offer-jeeber-002',
        requestId: 'req-feed-002',
        price: 18,
        currency: 'USD',
        etaMinutes: 40,
        status: OfferStatus.accepted,
      ),
    ],
  ),
);

/// Screen 26: the Replies tab, where accepted work lives.
///
/// The same `_FeedRequestSliver` as the Requests tab, filtered to
/// `JeeberFeedItemStatus.accepted` — but the cards are a different control
/// surface. Ignore/Offer is replaced by a single advance-delivery pill, and the
/// card's tap target no longer opens the request detail: it pushes
/// `chat-detail` keyed on the request id, which is the jeeber's only route into
/// the order conversation from this page.
///
/// The longer of the two action labels ("Heading to drop off") is used on
/// purpose — `_AcceptedAction` wraps the button in an [IntrinsicWidth] meant to
/// make it hug its label, and at phone width it does not: the label is wider
/// than the content column, so the pill renders gutter-to-gutter.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Replies · accepted work',
  size: _jeeberFeedTabViewPageBox,
)
Widget jeeberFeedTabViewReplies() => _jeeberFeedTabViewHosted(
  initialTab: JeeberFeedTab.replies,
  requests: [
    _jeeberFeedTabViewRequest(
      id: 'req-accepted',
      status: JeeberFeedItemStatus.accepted,
      action: JeeberDeliveryAction.headingToDropOff,
      senderName: 'Rami Haddad',
      tier: JeeberRequestTier.bulk,
    ),
  ],
);
