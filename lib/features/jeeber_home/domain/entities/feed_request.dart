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
  });

  /// Stable identifier used by the request-detail route to look up the
  /// payload from the in-memory feed cache.
  final String id;

  /// Short, single-line label for list rendering (placeholder until the
  /// realistic feed-card lands).
  final String shortLabel;

  @override
  List<Object?> get props => [id, shortLabel];
}
