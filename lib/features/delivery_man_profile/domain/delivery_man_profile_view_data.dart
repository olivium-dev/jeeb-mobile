import 'package:equatable/equatable.dart';


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

  
  
  
  
  final String? jeeberId;

  
  
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
