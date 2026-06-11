import '../domain/delivery_man_profile_view_data.dart';

/// Deterministic fixture for the Delivery Man profile dev-seam capture path
/// (`jeeb.route=/profile/delivery-man`). Mirrors the Figma comp (Kamal Hajj,
/// 4.3 over a large review base, two visible reviews) so a single dev APK
/// renders screen 27 without a rebuild. Debug-only.
abstract final class DevDeliveryManProfileFixtures {
  static const String _lorem =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ut leo '
      'facilisis, mollis dolor bibendum, tempor dolor. Lorem ipsum dolor sit '
      'amet, consectetur adipiscing elit.';

  static const DeliveryManProfileViewData sample = DeliveryManProfileViewData(
    name: 'Kamal Hajj',
    rating: 4.3,
    reviewCount: 113,
    location: 'Lebanon',
    isAvailable: true,
    avatarUrl: 'https://i.pravatar.cc/150?img=33',
    reviews: [
      DeliveryReviewData(
        id: 'r1',
        reviewerName: 'Karl Assaf',
        rating: 4,
        body: _lorem,
        daysAgo: 2,
        reviewerAvatarUrl: 'https://i.pravatar.cc/150?img=15',
        helpfulCount: 24,
      ),
      DeliveryReviewData(
        id: 'r2',
        reviewerName: 'Karl Assaf',
        rating: 4,
        body: _lorem,
        daysAgo: 2,
        reviewerAvatarUrl: 'https://i.pravatar.cc/150?img=15',
        helpfulCount: 24,
      ),
    ],
  );
}
