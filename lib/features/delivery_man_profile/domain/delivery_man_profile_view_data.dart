import 'package:equatable/equatable.dart';

/// A single review on the delivery-man public profile.
class DeliveryReviewData extends Equatable {
  const DeliveryReviewData({
    required this.id,
    required this.reviewerName,
    required this.rating,
    required this.body,
    required this.daysAgo,
    this.reviewerAvatarUrl,
    this.isVerified = true,
    this.helpfulCount = 0,
  });

  final String id;
  final String reviewerName;
  final double rating;
  final String body;
  final int daysAgo;
  final String? reviewerAvatarUrl;
  final bool isVerified;

  /// Retained on the model for compatibility but NO LONGER rendered: the
  /// Helpful/Reply controls were removed per D57 (JM-067) — jeeber reviews are
  /// immutable, read-only, with no client helpfulness/reply affordances.
  final int helpfulCount;

  /// First name only (D58 — JM-067/068). Splits on whitespace and returns the
  /// leading token; falls back to the full string when there is no whitespace.
  String get reviewerFirstName {
    final trimmed = reviewerName.trim();
    if (trimmed.isEmpty) return trimmed;
    final space = trimmed.indexOf(RegExp(r'\s'));
    return space > 0 ? trimmed.substring(0, space) : trimmed;
  }

  @override
  List<Object?> get props =>
      [id, reviewerName, rating, body, daysAgo, reviewerAvatarUrl, isVerified, helpfulCount];
}

/// Read model for the Delivery Man public profile (Figma 56580:2697, screen 27).
///
/// A read-only profile of a delivery man (Jeeber) as seen by a client. Data is
/// aggregated through the gateway (profile via user-management, reviews via
/// feedback-service). The screen renders identity + a reviews list; everything
/// here is supplied by the caller.
class DeliveryManProfileViewData extends Equatable {
  const DeliveryManProfileViewData({
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.isAvailable,
    required this.reviews,
    this.avatarUrl,
    this.isVerified = true,
    this.jeeberId,
  });

  final String name;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;
  final List<DeliveryReviewData> reviews;
  final String? avatarUrl;
  final bool isVerified;

  /// The jeeber's id, threaded through so `profile_view_all_reviews` can pass
  /// `?jeeberId=` to the reviews-list route (JM-068). Null when the source (the
  /// offer card today) does not carry it — the target then resolves the seeded
  /// jeeber (the reviews-list engineer's concern).
  final String? jeeberId;

  /// D59 cold-start: a jeeber with fewer than 5 reviews has no aggregate score
  /// shown (the score is hidden until N>=5). Threshold is the D59 floor.
  static const int coldStartThreshold = 5;

  bool get isColdStart => reviewCount < coldStartThreshold;

  @override
  List<Object?> get props => [
        name,
        rating,
        reviewCount,
        location,
        isAvailable,
        reviews,
        avatarUrl,
        isVerified,
        jeeberId,
      ];
}
