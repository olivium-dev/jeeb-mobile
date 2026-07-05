// Isolated native UI test — CustomerProfileScreen (routed customer-profile /
// ProfileTab body). Pumps the screen directly with fake view-data.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('customer-profile: rated verified customer (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const CustomerProfileScreen(
        data: CustomerProfileViewData(
          name: 'Sami Fawaz',
          email: 'sami@example.com',
          isVerified: true,
          rating: 4.8,
          ratingCount: 42,
        ),
      ),
      'customer-profile__rated',
    );
  });

  testWidgets('customer-profile: jeeber customer (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const CustomerProfileScreen(
        data: CustomerProfileViewData(
          name: 'Kamal Hajj',
          email: 'kamal@example.com',
          isVerified: true,
          isJeeber: true,
          rating: 4.9,
          ratingCount: 130,
        ),
      ),
      'customer-profile__jeeber-ar',
      locale: const Locale('ar'),
    );
  });
}
