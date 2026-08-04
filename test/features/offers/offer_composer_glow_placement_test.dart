// R17's orange radial. Board `Jeeb Rich UI.dc.html:1016` declares
// `500px 400px at 12% -8%`; un-compositing the export fits (0.119, -0.080) —
// the tile the shipped `topStart` (0.12) matches exactly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';

import '../../support/sync_app_localizations.dart';

class _InertRepo implements OfferSubmissionRepository {
  const _InertRepo();

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async => throw UnimplementedError();
}

class _StubWallet implements WalletRepository {
  const _StubWallet();

  @override
  Future<WalletBalance> fetchBalance() async => const WalletBalance(
        availableBalance: 6.40,
        affordabilityState: WalletAffordability.enough,
        reservedNow: 0,
        giftCredit: 0,
        currency: 'USD',
      );
}

void _noop() {}

void main() {
  Future<JeebMidnightField> pumpField(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        const OfferSubmissionScreen(
          requestId: 'req-1',
          submissionService: null,
          repository: _InertRepo(),
          walletRepository: _StubWallet(),
          onWithdrawn: _noop,
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    final Finder finder = find.byType(JeebMidnightField);
    expect(finder, findsOneWidget, reason: 'R17 draws exactly one field');
    return tester.widget<JeebMidnightField>(finder);
  }

  group('R17 offer composer — field glow anchor', () {
    testWidgets('declares the measured top-start anchor, not the topEnd '
        'default', (tester) async {
      final JeebMidnightField field = await pumpField(tester);

      expect(
        field.glowPlacement,
        JeebFieldGlowPlacement.topStart,
        reason: 'board 17-r17-offer-composer measures (0.119, -0.080); leaving '
            'it null inherits the default `topEnd` (0.88), a MIRRORED anchor',
      );
      expect(field.variant, JeebFieldVariant.content);
    });

    testWidgets('resolves start-side and ABOVE the top edge', (tester) async {
      final JeebMidnightField field = await pumpField(tester);
      final AlignmentDirectional anchor = field.glowPlacement!.alignment;

      expect(
        anchor.y,
        lessThan(-1),
        reason: 'fy < 0 — the anchor sits off-canvas above the top edge',
      );
      expect(anchor.resolve(TextDirection.ltr).x, lessThan(0));
    });

    testWidgets('mirrors to the end side under RTL', (tester) async {
      final JeebMidnightField field = await pumpField(
        tester,
        locale: const Locale('ar'),
      );
      final AlignmentDirectional anchor = field.glowPlacement!.alignment;

      expect(anchor.resolve(TextDirection.rtl).x, greaterThan(0));
    });
  });
}
