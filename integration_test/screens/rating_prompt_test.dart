// Isolated native UI test — rating-prompt (RatingPromptScreen). Legacy
// redirect-only placeholder: a "coming soon" empty-state page behind an
// OMDSAppBar (the deliverable UI ships under T-MOB-RATING-001). We pump it with
// a literal deliveryId and screenshot the single state it renders.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/deep_link_targets/rating_prompt_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rating-prompt: placeholder (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const RatingPromptScreen(deliveryId: 'DLV-1'),
      'rating-prompt__placeholder',
    );
  });
}
