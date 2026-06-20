import 'package:equatable/equatable.dart';

import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

enum ClientHomeStatus { initial, loading, ready, failed }

/// Which chip in the home-tab segmented control is selected. The three
/// values mirror the Figma copy verbatim.
enum ClientHomeTab { inProgress, pendingRequests, replies }

class ClientHomeState extends Equatable {
  const ClientHomeState({
    this.status = ClientHomeStatus.initial,
    this.greetingName,
    this.inProgress = const [],
    this.pending = const [],
    this.replies = const [],
    this.recentDeliveries = const [],
    this.query = '',
  });

  /// Coarse load phase the screen renders off.
  final ClientHomeStatus status;

  /// First name (or fallback) shown in the greeting line.
  /// `null` if the user has no name on file — the screen shows a generic
  /// "Welcome" string instead.
  final String? greetingName;

  /// Active delivery requests (the In Progress tab).
  final List<ClientHomeRequest> inProgress;

  /// Submitted requests still waiting for any offer (the Pending Requests tab).
  final List<ClientHomeRequest> pending;

  /// Requests that have at least one offer and are awaiting client acceptance
  /// (the Replies tab — the +6 avatar stack lives here).
  final List<ClientHomeRequest> replies;

  /// Recent completed deliveries for the "Order again" strip. The home tab
  /// shows at most one — the cubit caps this on emit.
  final List<RecentDeliverySummary> recentDeliveries;

  /// Free-text search query (home-disc-customer-home-search). Empty = no
  /// filter. The raw [inProgress]/[pending]/[replies] lists stay unfiltered
  /// (the server-owned snapshot); the `visible*` getters apply the query so a
  /// re-emit isn't needed when the query changes — only the query itself.
  final String query;

  /// Backward-compat alias — older tests read `activeRequests`.
  List<ClientHomeRequest> get activeRequests => inProgress;

  bool get isInProgressEmpty => inProgress.isEmpty;
  bool get isPendingEmpty => pending.isEmpty;
  bool get isRepliesEmpty => replies.isEmpty;

  /// True when a non-empty search query is active.
  bool get hasQuery => query.trim().isNotEmpty;

  /// The [inProgress] list filtered by [query] (case-insensitive substring over
  /// title / items / destination / Jeeber name).
  List<ClientHomeRequest> get visibleInProgress => _filter(inProgress);

  /// The [pending] list filtered by [query].
  List<ClientHomeRequest> get visiblePending => _filter(pending);

  /// The [replies] list filtered by [query].
  List<ClientHomeRequest> get visibleReplies => _filter(replies);

  /// Returns the RAW (unfiltered) list backing the supplied tab.
  List<ClientHomeRequest> listFor(ClientHomeTab tab) {
    switch (tab) {
      case ClientHomeTab.inProgress:
        return inProgress;
      case ClientHomeTab.pendingRequests:
        return pending;
      case ClientHomeTab.replies:
        return replies;
    }
  }

  /// Returns the FILTERED (query-applied) list backing the supplied tab.
  List<ClientHomeRequest> visibleFor(ClientHomeTab tab) {
    switch (tab) {
      case ClientHomeTab.inProgress:
        return visibleInProgress;
      case ClientHomeTab.pendingRequests:
        return visiblePending;
      case ClientHomeTab.replies:
        return visibleReplies;
    }
  }

  List<ClientHomeRequest> _filter(List<ClientHomeRequest> source) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((r) => _matches(r, q)).toList(growable: false);
  }

  bool _matches(ClientHomeRequest r, String q) {
    return r.title.toLowerCase().contains(q) ||
        (r.itemsSummary?.toLowerCase().contains(q) ?? false) ||
        r.destinationLabel.toLowerCase().contains(q) ||
        (r.jeeberName?.toLowerCase().contains(q) ?? false) ||
        (r.displayId?.toLowerCase().contains(q) ?? false);
  }

  /// Legacy alias used by older callers — true when the In Progress list is
  /// empty.
  bool get isEmpty => isInProgressEmpty;

  ClientHomeState copyWith({
    ClientHomeStatus? status,
    Object? greetingName = _sentinel,
    List<ClientHomeRequest>? inProgress,
    List<ClientHomeRequest>? pending,
    List<ClientHomeRequest>? replies,
    List<RecentDeliverySummary>? recentDeliveries,
    String? query,
  }) {
    return ClientHomeState(
      status: status ?? this.status,
      greetingName: identical(greetingName, _sentinel)
          ? this.greetingName
          : greetingName as String?,
      inProgress: inProgress ?? this.inProgress,
      pending: pending ?? this.pending,
      replies: replies ?? this.replies,
      recentDeliveries: recentDeliveries ?? this.recentDeliveries,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [
        status,
        greetingName,
        inProgress,
        pending,
        replies,
        recentDeliveries,
        query,
      ];
}

const Object _sentinel = Object();
