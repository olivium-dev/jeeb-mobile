// Isolated native UI test — DeliveryRegisterPromptScreen
// (delivery-register-prompt, JM-044). A fully static prompt (its CTA/back only
// navigate on tap, never at build), so we pump it directly. Covers the English
// and Arabic renders.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delivery-register-prompt: prompt (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const DeliveryRegisterPromptScreen(),
      'delivery-register-prompt__en',
    );
  });

  testWidgets('delivery-register-prompt: prompt (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const DeliveryRegisterPromptScreen(),
      'delivery-register-prompt__ar',
      locale: const Locale('ar'),
    );
  });
}
