import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

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
/// Renders the shared greeting → OMDS search bar → OmdsFilterChips tab
/// strip → [JeeberFeedCard] list. The list reads from [RequestFeedCubit] —
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
  static const Key offlineBannerKey = Key('jeeber-feed-tab-view-offline-banner');

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
    // JEBV4-284: the fixed header stack (greeting + availability card, plus —
    // once online — the search bar + tab/tier strips) has enough natural
    // height that once the on-screen keyboard shows (search field focused)
    // and eats into the viewport, a plain Column + Expanded still overflows:
    // Expanded floors at zero, but the *non-flexible* header total alone
    // already exceeds what is left ("BOTTOM OVERFLOWED BY 100 PIXELS" on
    // SM-S921B, run-26). A CustomScrollView lets the whole body scroll
    // instead of overflow when squeezed — the same remedy `_NoRequestsScope`
    // above already applies for its own tall-content overflow (Fix 6(b)).
    return SafeArea(
      key: JeeberFeedTabView.rootKey,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: JeeberHomeGreeting(
              name: widget.profileName,
              avatarUrl: widget.profileAvatarUrl,
            ),
          ),
          // §G2/SW-23: the availability control is persistent across dashboard
          // states — the compact card renders here too, so going busy (feed
          // non-empty) never hides the online/offline switch.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.medium,
                0,
                Spacing.medium,
                Spacing.small,
              ),
              child: AvailabilityCard(
                view: avState,
                onToggle: () => context.read<AvailabilityCubit>().toggle(),
              ),
            ),
          ),
          if (isOffline) SliverToBoxAdapter(child: _OfflineBanner()),
          if (!isOffline)
            ..._feedControls().map((w) => SliverToBoxAdapter(child: w)),
          SliverFillRemaining(
            hasScrollBody: true,
            child: _feedContent(isOffline),
          ),
        ],
      ),
    );
  }

  List<Widget> _feedControls() => [
        _FeedSearchBar(onChanged: (q) => setState(() => _query = q)),
        const SizedBox(height: Spacing.small),
        _FeedTabStrip(active: _activeTab, onChanged: _onTabChanged),
        const SizedBox(height: Spacing.small),
        if (_activeTab == JeeberFeedTab.requests)
          _TierFilterStrip(
            active: _tierFilter,
            onChanged: _onTierChanged,
          ),
      ];

  Widget _feedContent(bool isOffline) {
    if (isOffline) return const _OfflineEmptyBody();
    // JM-048 AC3: the Pending-Response sub-tab is backed by the jeeber's
    // submitted offers (real data) when a [SubmittedOffersCubit] is supplied;
    // otherwise it falls back to the request-feed-derived pending view.
    if (_activeTab == JeeberFeedTab.pendingResponse &&
        widget.submittedOffersCubit != null) {
      return _PendingOffersList(
        cubit: widget.submittedOffersCubit!,
        // JM-047 AC4 (RD-2): the pending sub-tab's back edge → delivery-requests.
        // Tabs are not routes here (the feed lives inside the shell), so "back"
        // switches the active sub-tab back to Requests (jeeber-requests-home).
        onBack: () => _onTabChanged(JeeberFeedTab.requests),
      );
    }
    return _FeedRequestList(
      activeTab: _activeTab,
      tierFilter: _tierFilter,
      query: _query,
      onOpenRequest: widget.onOpenRequest,
      onMakeOffer: (req) => _onMakeOffer(context, req),
      leadingBanner: widget.leadingBanner,
    );
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
        Expanded(child: _OfflineBannerText(l10n: l10n, color: color)),
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
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
      ),
      child: OmdsFilterChips<JeeberTierFilter>(
        key: JeeberFeedTabView.tierStripKey,
        filters: _filters(l10n),
        selectedValue: active,
        onFilterChanged: onChanged,
        showCounts: false,
      ),
    );
  }

  List<OmdsFilterOption<JeeberTierFilter>> _filters(AppLocalizations l10n) => [
        OmdsFilterOption(label: l10n.jeeberFeedTierAll, value: JeeberTierFilter.all),
        OmdsFilterOption(label: l10n.jeeberFeedTierFlash, value: JeeberTierFilter.flash),
        OmdsFilterOption(label: l10n.jeeberFeedTierExpress, value: JeeberTierFilter.express),
        OmdsFilterOption(label: l10n.jeeberFeedTierStandard, value: JeeberTierFilter.standard),
      ];
}

class _FeedSearchBar extends StatelessWidget {
  const _FeedSearchBar({required this.onChanged});

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
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium),
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
    return Semantics(
      identifier: identifier,
      button: true,
      selected: active == tab,
      child: OmdsChip(
        label: label,
        isSelected: active == tab,
        onTap: () => onChanged(tab),
      ),
    );
  }
}

class _FeedRequestList extends StatelessWidget {
  const _FeedRequestList({
    required this.activeTab,
    required this.tierFilter,
    required this.query,
    required this.onOpenRequest,
    required this.onMakeOffer,
    this.leadingBanner,
  });

  final JeeberFeedTab activeTab;
  final JeeberTierFilter tierFilter;
  final String query;
  final ValueChanged<DeliveryRequest>? onOpenRequest;
  final ValueChanged<DeliveryRequest> onMakeOffer;
  final Widget? leadingBanner;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestFeedCubit, RequestFeedState>(
      builder: (context, state) => _FeedRequestListBody(
        state: state,
        activeTab: activeTab,
        tierFilter: tierFilter,
        query: query,
        onOpenRequest: onOpenRequest,
        onMakeOffer: onMakeOffer,
        leadingBanner: leadingBanner,
      ),
    );
  }
}

class _FeedRequestListBody extends StatelessWidget {
  const _FeedRequestListBody({
    required this.state,
    required this.activeTab,
    required this.tierFilter,
    required this.query,
    required this.onOpenRequest,
    required this.onMakeOffer,
    this.leadingBanner,
  });

  final RequestFeedState state;
  final JeeberFeedTab activeTab;
  final JeeberTierFilter tierFilter;
  final String query;
  final ValueChanged<DeliveryRequest>? onOpenRequest;
  final ValueChanged<DeliveryRequest> onMakeOffer;
  final Widget? leadingBanner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = _visibleRequests(state.requests);
    return OmdsPullToRefresh(
      onRefresh: () => context.read<RequestFeedCubit>().refresh(),
      // PUSH-UI-REACTION: even when the visible tab has NO requests, render the
      // active-deliveries banner above the empty state (inside a scroll view so
      // pull-to-refresh still fires) — a just-won delivery must surface here too.
      child: visible.isEmpty
          ? _EmptyTabWithBanner(l10n: l10n, leadingBanner: leadingBanner)
          : _FeedListView(
              requests: visible,
              expiredIds: state.expiredIds,
              onOpenRequest: onOpenRequest,
              onMakeOffer: onMakeOffer,
              leadingBanner: leadingBanner,
            ),
    );
  }

  /// Filters the cubit's request set by active tab + tier filter + search
  /// query.
  List<DeliveryRequest> _visibleRequests(List<DeliveryRequest> source) {
    final lowered = query.trim().toLowerCase();
    return source.where((r) {
      if (lowered.isNotEmpty && !_matchesQuery(r, lowered)) return false;
      if (r.feedStatus != _statusForTab(activeTab)) return false;
      if (!_matchesTier(r)) return false;
      return true;
    }).toList(growable: false);
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
      JeeberTierFilter.express =>
        r.tier == JeeberRequestTier.standard,
      JeeberTierFilter.standard =>
        r.tier == JeeberRequestTier.light ||
            r.tier == JeeberRequestTier.bulk,
    };
  }

  bool _matchesQuery(DeliveryRequest r, String q) {
    return (r.senderName?.toLowerCase().contains(q) ?? false) ||
        (r.itemsSummary?.toLowerCase().contains(q) ?? false) ||
        r.pickup.label.toLowerCase().contains(q);
  }
}

class _FeedListView extends StatelessWidget {
  const _FeedListView({
    required this.requests,
    required this.expiredIds,
    required this.onOpenRequest,
    required this.onMakeOffer,
    this.leadingBanner,
  });

  final List<DeliveryRequest> requests;

  /// G3: ids in their expired-linger window — their card renders the faded
  /// "Expired" state (actions inert) until the cubit's sweep collapses it.
  final Set<String> expiredIds;

  final ValueChanged<DeliveryRequest>? onOpenRequest;
  final ValueChanged<DeliveryRequest> onMakeOffer;

  /// PUSH-UI-REACTION: an optional card rendered as the first, scrolling item
  /// above the request rows (self-hides to zero height when empty).
  final Widget? leadingBanner;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RequestFeedCubit>();
    // JM-048: the FIRST incoming row exposes the screen-level
    // `feed_make_offer_cta` so the QA flow taps an unambiguous make-offer CTA
    // — never an expired card, whose offer affordance is inert.
    final firstIncomingIndex = requests.indexWhere(
      (r) =>
          r.feedStatus == JeeberFeedItemStatus.incoming &&
          !expiredIds.contains(r.id),
    );
    // Offset every request row by one when a leading banner rides at index 0, so
    // the make-offer-cta / expired logic stays keyed to the request itself.
    final hasBanner = leadingBanner != null;
    final leadCount = hasBanner ? 1 : 0;
    return ListView.builder(
      key: JeeberFeedTabView.listKey,
      padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
      itemCount: requests.length + leadCount,
      itemBuilder: (context, rawIndex) {
        if (hasBanner && rawIndex == 0) return leadingBanner!;
        final index = rawIndex - leadCount;
        return JeeberFeedCard(
          request: requests[index],
          isExpired: expiredIds.contains(requests[index].id),
        // JM-048: card tap opens detail; the "Offer" button routes through the
        // KYC gate / composer (D38), distinct from a plain detail open.
        // POST-ACCEPT ENTRY POINT: an ACCEPTED (Replies-tab) card is the
        // jeeber's surface for a delivery whose offer the customer accepted —
        // tapping it opens the order conversation (chat-detail keyed on the
        // request id == correlationKey, resolved against the live gateway),
        // NOT the pre-offer make-offer/decline detail.
        onTap: requests[index].feedStatus == JeeberFeedItemStatus.accepted
            ? () => GoRouter.of(context).pushNamed(
                  'chat-detail',
                  pathParameters: {'id': requests[index].id},
                )
            : onOpenRequest == null
                ? null
                : () => onOpenRequest!(requests[index]),
        onIgnore: () => cubit.decline(requests[index].id),
        onOffer: () => onMakeOffer(requests[index]),
        onAdvanceStatus: () => cubit.accept(requests[index].id),
          exposeMakeOfferId: index == firstIncomingIndex,
        );
      },
    );
  }
}

/// The empty-tab state with the active-deliveries banner riding above it inside
/// a scroll view (so pull-to-refresh still fires and a just-won delivery shows
/// even when the visible tab has no requests). Falls back to the bare, centered
/// empty state when no banner is injected.
class _EmptyTabWithBanner extends StatelessWidget {
  const _EmptyTabWithBanner({required this.l10n, this.leadingBanner});

  final AppLocalizations l10n;
  final Widget? leadingBanner;

  @override
  Widget build(BuildContext context) {
    final banner = leadingBanner;
    if (banner == null) return _EmptyTabState(l10n: l10n);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              banner,
              OmdsEmptyState(
                icon: Icons.inbox_outlined,
                title: l10n.jeeberFeedEmptyTitle,
                subtitle: l10n.jeeberFeedEmptySubtitle,
              ),
            ],
          ),
        ),
      ),
    );
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
      return _PendingEmptyState(
        l10n: AppLocalizations.of(context),
      );
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
        child: BackButton(
          onPressed: onBack ?? () {},
        ),
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
