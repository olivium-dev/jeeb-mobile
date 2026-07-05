// Isolated native UI test — WalletChargeInfoScreen (wallet-charge-info,
// JM-054). A fully static, no-network instructional screen (its back/CTA only
// navigate on tap, never at build), so we pump it directly. Covers the English
// and Arabic renders.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/wallet/presentation/wallet_charge_info_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wallet-charge-info: instructions (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const WalletChargeInfoScreen(),
      'wallet-charge-info__en',
    );
  });

  testWidgets('wallet-charge-info: instructions (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const WalletChargeInfoScreen(),
      'wallet-charge-info__ar',
      locale: const Locale('ar'),
    );
  });
}
