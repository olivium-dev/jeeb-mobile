import '../entities/feed_request.dart';

/// In-memory cache the Jeeber-side dashboard keeps warm so that a push
/// notification deep link (which only carries the request id) can recover
/// the full payload without an extra round-trip.
///
/// T-mobile-027 only exercises [findById] returning `null` (the toggle
/// screen doesn't yet host a feed). The concrete cache is filled in
/// alongside the live feed in T-mobile-013.
abstract class RequestFeedService {
  /// Returns the cached payload for [id] or `null` if it has rotated out
  /// of the feed (matched, cancelled, expired).
  FeedRequest? findById(String id);
}
