// Isolated native UI test — DeliveryManProfileScreen (routed delivery-man-profile).
// Pure view-data constructor; pumped directly with fake reviews.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';

import '../support/screen_harness.dart';

DeliveryReviewData _review(String id, String name, int rating, String body, int days) =>
    DeliveryReviewData(
      id: id,
      reviewerName: name,
      rating: rating.toDouble(),
      body: body,
      daysAgo: days,
      isVerified: true,
      helpfulCount: rating,
    );

const _name = 'Kamal Hajj';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delivery-man-profile: with reviews (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      DeliveryManProfileScreen(
        data: DeliveryManProfileViewData(
          name: _name,
          rating: 4.3,
          reviewCount: 3,
          location: 'Hamra, Beirut',
          isAvailable: true,
          jeeberId: 'user-jeeber-002',
          reviews: [
            _review('r1', 'Sami', 5, 'Fast and polite. Great delivery!', 2),
            _review('r2', 'Nadia', 4, 'On time, package intact.', 5),
            _review('r3', 'Omar', 4, 'Good communication throughout.', 9),
          ],
        ),
      ),
      'delivery-man-profile__with-reviews',
    );
  });

  testWidgets('delivery-man-profile: no reviews / cold-start (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const DeliveryManProfileScreen(
        data: DeliveryManProfileViewData(
          name: _name,
          rating: 0,
          reviewCount: 0,
          location: 'Hamra, Beirut',
          isAvailable: false,
          jeeberId: 'user-jeeber-002',
          reviews: [],
        ),
      ),
      'delivery-man-profile__no-reviews-ar',
      locale: const Locale('ar'),
    );
  });
}
