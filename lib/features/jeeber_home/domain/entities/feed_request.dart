import 'package:equatable/equatable.dart';

/// A request surfaced by the matching engine for a Jeeber to consider.
///
/// T-mobile-027 only needs the type to exist so the dashboard's feed-row
/// tap callback compiles; the actual feed UI (and the realistic fields
/// like pickup/dropoff/distance) land with T-mobile-013. Keep this lean
/// so it doesn't accrue speculative shape.
class FeedRequest extends Equatable {
  const FeedRequest({
    required this.id,
    required this.shortLabel,
    this.description,
  });

  /// Stable identifier used by the request-detail route to look up the
  /// payload from the in-memory feed cache.
  final String id;

  /// Short, single-line label for list rendering (placeholder until the
  /// realistic feed-card lands).
  final String shortLabel;

  /// G1 (sprint-009 P0): the customer's own "What do you need?" text — the
  /// content the jeeber is agreeing to buy/deliver. Carried from the feed
  /// item's `description` (the gateway feed DTO requires it) so the request
  /// detail can render it prominently. Null on legacy/edge payloads.
  final String? description;

  @override
  List<Object?> get props => [id, shortLabel, description];
}
