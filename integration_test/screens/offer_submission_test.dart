// Isolated native UI test — OfferSubmissionScreen (jeeber-offer-submission).
// The screen builds its OfferFormCubit from the injected `repository` seam and
// starts in the idle OfferFormState (no async in the constructor; submitOffer
// only fires on tap), so an inline no-op repository renders the composer
// deterministically with no DI/network. `submissionService` is a legacy dynamic
// stub the screen ignores in favour of `repository`; `walletRepository` is left
// null so the best-effort wallet read degrades (money lines still render from
// the entered price).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';

import '../support/screen_harness.dart';

class _NoopOfferRepo implements OfferSubmissionRepository {
  const _NoopOfferRepo();

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async =>
      const OfferSubmissionResult(offerId: 'offer-1', conversationId: 'conv-1');
}

OfferSubmissionScreen _screen() => OfferSubmissionScreen(
      requestId: 'req-1',
      submissionService: const Object(),
      onWithdrawn: () {},
      repository: const _NoopOfferRepo(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('jeeber-offer-submission: composer idle (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'jeeber-offer-submission__idle',
    );
  });

  testWidgets('jeeber-offer-submission: composer idle (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'jeeber-offer-submission__ar',
      locale: const Locale('ar'),
    );
  });
}
