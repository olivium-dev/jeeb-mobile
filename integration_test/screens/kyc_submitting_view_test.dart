// Isolated native UI test — KycSubmittingView (the KYC upload-in-flight state).
// A pure stateless view (icon + headline + body + a perpetual OmdsLoadingState
// spinner) with no cubit/service seam, so it's pumped directly. The spinner
// never settles; the harness's bounded-pump fallback shoots it anyway. Wrapped
// in a Scaffold so the live-region column lays out inside a Material surface.
// Captures the submitting state en + ar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_submitting_view.dart';

import '../support/screen_harness.dart';

Widget _screen() => const Scaffold(body: Center(child: KycSubmittingView()));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kyc-submitting-view: submitting (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'kyc-submitting-view__submitting',
    );
  });

  testWidgets('kyc-submitting-view: submitting (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'kyc-submitting-view__submitting-ar',
      locale: const Locale('ar'),
    );
  });
}
