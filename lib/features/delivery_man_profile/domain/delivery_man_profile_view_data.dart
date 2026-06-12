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
  final int helpfulCount;

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
  });

  final String name;
  final double rating;
  final int reviewCount;
  final String location;
  final bool isAvailable;
  final List<DeliveryReviewData> reviews;
  final String? avatarUrl;
  final bool isVerified;

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
      ];
}
