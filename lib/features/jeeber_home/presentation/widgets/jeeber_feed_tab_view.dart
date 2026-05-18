import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../jeeber_request_feed/cubit/request_feed_state.dart';
import '../../../jeeber_request_feed/data/request_feed_models.dart';
import '../../../jeeber_request_feed/presentation/request_card.dart';
import 'jeeber_home_greeting.dart';

/// Tab the Jeeber feed view is currently filtered to.
///
/// `requests` is the default — all live offers ready for accept/decline.
/// `pendingResponse` and `replies` are the two follow-up buckets in the
/// Figma design; they ship as filterable views over the same cubit list
/// until the jeeber-gateway separates the streams.
enum JeeberFeedTab { requests, pendingResponse, replies }

/// State 3 of the Jeeber home: registered, available, and at least one
/// live request in the feed.
///
/// Renders the shared greeting → OMDS search bar → OmdsFilterChips tab
/// strip → request card list. The list reads from [RequestFeedCubit] —
/// the host (the screen) is responsible for providing the cubit through
/// the widget tree.
class JeeberFeedTabView extends StatefulWidget {
  const JeeberFeedTabView({
    super.key,
    this.profileName,
    this.onOpenRequest,
  });

  static const Key rootKey = Key('jeeber-feed-tab-view-root');
  static const Key searchBarKey = Key('jeeber-feed-tab-view-search-bar');
  static const Key tabStripKey = Key('jeeber-feed-tab-view-tab-strip');
  static const Key listKey = Key('jeeber-feed-tab-view-list');

  /// Profile display name for the shared greeting.
  final String? profileName;

  /// Optional row-tap forward so the host (the screen) can decide whether
  /// to route into a request-detail page.
  final ValueChanged<DeliveryRequest>? onOpenRequest;

  @override
  State<JeeberFeedTabView> createState() => _JeeberFeedTabViewState();
}

class _JeeberFeedTabViewState extends State<JeeberFeedTabView> {
  JeeberFeedTab _activeTab = JeeberFeedTab.requests;
  String _query = '';
  Timer? _uiTicker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: JeeberFeedTabView.rootKey,
      child: Column(
        children: [
          JeeberHomeGreeting(name: widget.profileName),
          _FeedSearchBar(onChanged: (q) => setState(() => _query = q)),
          const SizedBox(height: Spacing.small),
          _FeedTabStrip(active: _activeTab, onChanged: _onTabChanged),
          const SizedBox(height: Spacing.small),
          Expanded(
            child: _FeedRequestList(
              activeTab: _activeTab,
              query: _query,
              now: _now,
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

  // TODO(jeeb-l10n): replace once `jeeberFeedSearchHint` ARB key lands.
  static const _kSearchHint = 'Search';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: OmdsSearchBar(
        key: JeeberFeedTabView.searchBarKey,
        hintText: _kSearchHint,
        onChanged: onChanged,
      ),
    );
  }
}

class _FeedTabStrip extends StatelessWidget {
  const _FeedTabStrip({required this.active, required this.onChanged});

  final JeeberFeedTab active;
  final ValueChanged<JeeberFeedTab?> onChanged;

  // String constants pending l10n — see the jeeb-l10n TODOs across this file.
  // TODO(jeeb-l10n): wire to ARB keys once they land.
  static const _kRequests = 'Requests';
  static const _kPendingResponse = 'Pending Response';
  static const _kReplies = 'Replies';

  static const List<OmdsFilterOption<JeeberFeedTab>> _filters = [
    OmdsFilterOption<JeeberFeedTab>(
      label: _kRequests,
      value: JeeberFeedTab.requests,
    ),
    OmdsFilterOption<JeeberFeedTab>(
      label: _kPendingResponse,
      value: JeeberFeedTab.pendingResponse,
    ),
    OmdsFilterOption<JeeberFeedTab>(
      label: _kReplies,
      value: JeeberFeedTab.replies,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: OmdsFilterChips<JeeberFeedTab>(
        key: JeeberFeedTabView.tabStripKey,
        filters: _filters,
        selectedValue: active,
        onFilterChanged: onChanged,
        showCounts: false,
      ),
    );
  }
}

class _FeedRequestList extends StatelessWidget {
  const _FeedRequestList({
    required this.activeTab,
    required this.query,
    required this.now,
    required this.onOpenRequest,
  });

  final JeeberFeedTab activeTab;
  final String query;
  final DateTime now;
  final ValueChanged<DeliveryRequest>? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestFeedCubit, RequestFeedState>(
      builder: (context, state) => _FeedRequestListBody(
        state: state,
        activeTab: activeTab,
        query: query,
        now: now,
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
    required this.now,
    required this.onOpenRequest,
  });

  final RequestFeedState state;
  final JeeberFeedTab activeTab;
  final String query;
  final DateTime now;
  final ValueChanged<DeliveryRequest>? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = _visibleRequests(state.requests);
    return OmdsPullToRefresh(
      onRefresh: () => context.read<RequestFeedCubit>().refresh(),
      child: visible.isEmpty
          ? _EmptyTabState(l10n: l10n)
          : _FeedListView(
              requests: visible,
              state: state,
              now: now,
              onOpenRequest: onOpenRequest,
            ),
    );
  }

  /// Filters the cubit's request set by the active tab + search query.
  /// Tab semantics: `requests` shows everything; `pendingResponse` shows
  /// requests with an `accepting` action in flight; `replies` shows
  /// requests with a `declining` action in flight. Until the gateway
  /// returns dedicated streams this is the best approximation.
  List<DeliveryRequest> _visibleRequests(List<DeliveryRequest> source) {
    final lowered = query.trim().toLowerCase();
    return source.where((r) {
      if (lowered.isNotEmpty && !_matchesQuery(r, lowered)) return false;
      return _matchesTab(r);
    }).toList(growable: false);
  }

  bool _matchesQuery(DeliveryRequest r, String q) {
    return r.pickup.label.toLowerCase().contains(q) ||
        r.dropoff.label.toLowerCase().contains(q) ||
        (r.senderName?.toLowerCase().contains(q) ?? false);
  }

  bool _matchesTab(DeliveryRequest r) {
    final status = state.actionStatusFor(r.id);
    return switch (activeTab) {
      JeeberFeedTab.requests => true,
      JeeberFeedTab.pendingResponse =>
        status == RequestActionStatus.accepting,
      JeeberFeedTab.replies => status == RequestActionStatus.declining,
    };
  }
}

class _FeedListView extends StatelessWidget {
  const _FeedListView({
    required this.requests,
    required this.state,
    required this.now,
    required this.onOpenRequest,
  });

  final List<DeliveryRequest> requests;
  final RequestFeedState state;
  final DateTime now;
  final ValueChanged<DeliveryRequest>? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RequestFeedCubit>();
    return ListView.builder(
      key: JeeberFeedTabView.listKey,
      padding: const EdgeInsets.symmetric(vertical: Spacing.small),
      itemCount: requests.length,
      itemBuilder: (_, index) => _FeedRow(
        request: requests[index],
        state: state,
        now: now,
        onAccept: () => cubit.accept(requests[index].id),
        onDecline: () => cubit.decline(requests[index].id),
        onOpen: onOpenRequest,
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({
    required this.request,
    required this.state,
    required this.now,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
  });

  final DeliveryRequest request;
  final RequestFeedState state;
  final DateTime now;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final ValueChanged<DeliveryRequest>? onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen == null ? null : () => onOpen!(request),
      child: RequestCard(
        request: request,
        actionStatus: state.actionStatusFor(request.id),
        secondsRemaining: _secondsLeft(),
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }

  int _secondsLeft() {
    final diff = request.expiresAt.difference(now).inSeconds;
    return diff.clamp(0, 1 << 31);
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
            title: l10n.requestFeedEmptyTitle,
            subtitle: l10n.requestFeedEmptySubtitle,
          ),
        ),
      ),
    );
  }
}
