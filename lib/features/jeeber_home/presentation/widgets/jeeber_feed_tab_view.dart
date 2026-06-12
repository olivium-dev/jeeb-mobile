import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
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
  static const Key listKey = Key('jeeber-feed-tab-view-list');

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
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: JeeberFeedTabView.rootKey,
      child: Column(
        children: [
          JeeberHomeGreeting(
            name: widget.profileName,
            avatarUrl: widget.profileAvatarUrl,
          ),
          _FeedSearchBar(onChanged: (q) => setState(() => _query = q)),
          const SizedBox(height: Spacing.small),
          _FeedTabStrip(active: _activeTab, onChanged: _onTabChanged),
          const SizedBox(height: Spacing.small),
          Expanded(
            child: _FeedRequestList(
              activeTab: _activeTab,
              query: _query,
              onOpenRequest: widget.onOpenRequest,
            ),
          ),
        ],
      ),
    );
  }

  void _onTabChanged(JeeberFeedTab? next) {
    if (next == null || next == _activeTab) return;
    setState(() => _activeTab = next);
  }
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
    required this.query,
    required this.onOpenRequest,
  });

  final JeeberFeedTab activeTab;
  final String query;
  final ValueChanged<DeliveryRequest>? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestFeedCubit, RequestFeedState>(
      builder: (context, state) => _FeedRequestListBody(
        state: state,
        activeTab: activeTab,
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
    required this.query,
    required this.onOpenRequest,
  });

  final RequestFeedState state;
  final JeeberFeedTab activeTab;
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

  /// Filters the cubit's request set by the active tab + search query. Tab
  /// → [JeeberFeedItemStatus] mapping keeps the Figma chip semantics: the
  /// `requests` chip shows incoming cards, `pendingResponse` shows offered
  /// cards, `replies` shows accepted cards with delivery actions.
  List<DeliveryRequest> _visibleRequests(List<DeliveryRequest> source) {
    final lowered = query.trim().toLowerCase();
    return source.where((r) {
      if (lowered.isNotEmpty && !_matchesQuery(r, lowered)) return false;
      return r.feedStatus == _statusForTab(activeTab);
    }).toList(growable: false);
  }

  JeeberFeedItemStatus _statusForTab(JeeberFeedTab tab) => switch (tab) {
        JeeberFeedTab.requests => JeeberFeedItemStatus.incoming,
        JeeberFeedTab.pendingResponse => JeeberFeedItemStatus.pendingResponse,
        JeeberFeedTab.replies => JeeberFeedItemStatus.accepted,
      };

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
