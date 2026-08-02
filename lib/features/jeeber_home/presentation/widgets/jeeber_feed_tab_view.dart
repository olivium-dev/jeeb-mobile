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

enum JeeberFeedTab { requests, pendingResponse, replies }

enum JeeberTierFilter { all, flash, express, standard }

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

  final String? profileName;

  final String? profileAvatarUrl;

  final JeeberFeedTab initialTab;

  final ValueChanged<DeliveryRequest>? onOpenRequest;

  final ValueChanged<DeliveryRequest>? onMakeOffer;

  final SubmittedOffersCubit? submittedOffersCubit;

  final Widget? leadingBanner;

  @override
  State<JeeberFeedTabView> createState() => _JeeberFeedTabViewState();
}

class _JeeberFeedTabViewState extends State<JeeberFeedTabView> {
  late JeeberFeedTab _activeTab = widget.initialTab;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  JeeberTierFilter _tierFilter = JeeberTierFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
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
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: JeeberHomeGreeting(
            name: widget.profileName,
            avatarUrl: widget.profileAvatarUrl,
          ),
        ),
        SliverToBoxAdapter(
          child: AvailabilityCard(
            view: avState,
            onToggle: () => context.read<AvailabilityCubit>().toggle(),
          ),
        ),
        if (isOffline) SliverToBoxAdapter(child: _OfflineBanner()),
        if (!isOffline && widget.leadingBanner != null)
          SliverToBoxAdapter(child: widget.leadingBanner!),
        if (!isOffline)
          ..._feedControls().map((w) => SliverToBoxAdapter(child: w)),
        ..._feedSlivers(isOffline),
      ],
    );
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

  List<Widget> _feedSlivers(bool isOffline) {
    if (isOffline) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: _OfflineEmptyBody()),
      ];
    }
    if (_activeTab == JeeberFeedTab.pendingResponse &&
        widget.submittedOffersCubit != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: true,
          child: _PendingOffersList(
            cubit: widget.submittedOffersCubit!,
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

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
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

  List<DeliveryRequest> _visibleRequests(List<DeliveryRequest> source) {
    final lowered = query.trim().toLowerCase();
    return source
        .where((r) {
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

class _PendingOffersList extends StatelessWidget {
  const _PendingOffersList({required this.cubit, this.onBack});

  final SubmittedOffersCubit cubit;

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
// ===========================================================================

/// A phone page. 844 pt is the iPhone 14 viewport, i.e. enough that the feed's
const Size _jeeberFeedTabViewPageBox = Size(390, 844);

/// The Galaxy S22 width — the device this project runs its final on-device
const Size _jeeberFeedTabViewNarrowBox = Size(360, 844);

/// The instant the gateway reports, as a UTC instant. The card converts to
/// device-local before formatting (SW-03); a constant keeps the canvas from
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
class _JeeberFeedTabViewOffersCubit extends SubmittedOffersCubit {
  _JeeberFeedTabViewOffersCubit(SubmittedOffersState seed)
    : super(repository: _JeeberFeedTabViewOffersRepository(seed.offers)) {
    emit(seed);
  }
}

/// The page as `jeeber_home_screen.dart` mounts it: both cubits ambient, a
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
@JeebPreview(
  group: 'jeeber_home',
  name: 'Requests · empty feed',
  size: _jeeberFeedTabViewPageBox,
)
Widget jeeberFeedTabViewEmptyFeed() => _jeeberFeedTabViewHosted();

/// The layout ceiling: the longest plausible row on the narrowest real device.
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
