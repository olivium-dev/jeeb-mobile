import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/availability_cubit.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import '../../../jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../jeeber_request_feed/cubit/request_feed_state.dart';
import '../../../jeeber_request_feed/data/request_feed_models.dart';
import '../../../jeeber_request_feed/presentation/jeeber_feed_card.dart';
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
  });

  static const Key rootKey = Key('jeeber-feed-tab-view-root');
  static const Key searchBarKey = Key('jeeber-feed-tab-view-search-bar');
  static const Key tabStripKey = Key('jeeber-feed-tab-view-tab-strip');
  static const Key tierStripKey = Key('jeeber-feed-tab-view-tier-strip');
  static const Key listKey = Key('jeeber-feed-tab-view-list');
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

  @override
  State<JeeberFeedTabView> createState() => _JeeberFeedTabViewState();
}

class _JeeberFeedTabViewState extends State<JeeberFeedTabView> {
  late JeeberFeedTab _activeTab = widget.initialTab;
  JeeberTierFilter _tierFilter = JeeberTierFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvailabilityCubit, AvailabilityViewState>(
      builder: (context, avState) => _buildBody(context, avState),
    );
  }

  Widget _buildBody(BuildContext context, AvailabilityViewState avState) {
    final isOffline = avState.status.state != AvailabilityState.online;
    return SafeArea(
      key: JeeberFeedTabView.rootKey,
      child: Column(
        children: [
          JeeberHomeGreeting(
            name: widget.profileName,
            avatarUrl: widget.profileAvatarUrl,
          ),
          if (isOffline) _OfflineBanner(),
          if (!isOffline) ..._feedControls(),
          Expanded(child: _feedContent(isOffline)),
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
    return _FeedRequestList(
      activeTab: _activeTab,
      tierFilter: _tierFilter,
      query: _query,
      onOpenRequest: widget.onOpenRequest,
    );
  }

  void _onTabChanged(JeeberFeedTab? next) {
    if (next == null || next == _activeTab) return;
    setState(() => _activeTab = next);
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
      color: Theme.of(context).colorScheme.errorContainer,
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
    final color = Theme.of(context).colorScheme.onErrorContainer;
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

class _FeedTabStrip extends StatelessWidget {
  const _FeedTabStrip({required this.active, required this.onChanged});

  final JeeberFeedTab active;
  final ValueChanged<JeeberFeedTab?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
      ),
      child: OmdsFilterChips<JeeberFeedTab>(
        key: JeeberFeedTabView.tabStripKey,
        filters: _filters(l10n),
        selectedValue: active,
        onFilterChanged: onChanged,
        showCounts: false,
      ),
    );
  }

  List<OmdsFilterOption<JeeberFeedTab>> _filters(AppLocalizations l10n) => [
        OmdsFilterOption<JeeberFeedTab>(
          label: l10n.jeeberFeedFilterRequests,
          value: JeeberFeedTab.requests,
        ),
        OmdsFilterOption<JeeberFeedTab>(
          label: l10n.jeeberFeedFilterPendingResponse,
          value: JeeberFeedTab.pendingResponse,
        ),
        OmdsFilterOption<JeeberFeedTab>(
          label: l10n.jeeberFeedFilterReplies,
          value: JeeberFeedTab.replies,
        ),
      ];
}

class _FeedRequestList extends StatelessWidget {
  const _FeedRequestList({
    required this.activeTab,
    required this.tierFilter,
    required this.query,
    required this.onOpenRequest,
  });

  final JeeberFeedTab activeTab;
  final JeeberTierFilter tierFilter;
  final String query;
  final ValueChanged<DeliveryRequest>? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestFeedCubit, RequestFeedState>(
      builder: (context, state) => _FeedRequestListBody(
        state: state,
        activeTab: activeTab,
        tierFilter: tierFilter,
        query: query,
        onOpenRequest: onOpenRequest,
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
  });

  final RequestFeedState state;
  final JeeberFeedTab activeTab;
  final JeeberTierFilter tierFilter;
  final String query;
  final ValueChanged<DeliveryRequest>? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = _visibleRequests(state.requests);
    return OmdsPullToRefresh(
      onRefresh: () => context.read<RequestFeedCubit>().refresh(),
      child: visible.isEmpty
          ? _EmptyTabState(l10n: l10n)
          : _FeedListView(requests: visible, onOpenRequest: onOpenRequest),
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
  const _FeedListView({required this.requests, required this.onOpenRequest});

  final List<DeliveryRequest> requests;
  final ValueChanged<DeliveryRequest>? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RequestFeedCubit>();
    return ListView.builder(
      key: JeeberFeedTabView.listKey,
      padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
      itemCount: requests.length,
      itemBuilder: (_, index) => JeeberFeedCard(
        request: requests[index],
        onTap: onOpenRequest == null
            ? null
            : () => onOpenRequest!(requests[index]),
        onIgnore: () => cubit.decline(requests[index].id),
        onOffer: onOpenRequest == null
            ? null
            : () => onOpenRequest!(requests[index]),
        onAdvanceStatus: () => cubit.accept(requests[index].id),
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
