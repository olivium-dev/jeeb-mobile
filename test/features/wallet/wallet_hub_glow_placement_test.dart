// R4's orange radial. Board `Jeeb Rich UI.dc.html:258` declares
// `560px 420px at 20% -8%`; un-compositing the export fits (0.199, -0.080).
//
// Goldens tolerate 5% pixel diff, so they cannot see a mirrored anchor — this
// reads the placement off the widget.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_hub_screen.dart';

import '../../support/sync_app_localizations.dart';

class _LoadedWalletRepository implements WalletRepository {
  const _LoadedWalletRepository();

  @override
  Future<WalletBalance> fetchBalance() async => const WalletBalance(
    availableBalance: 40,
    affordabilityState: WalletAffordability.enough,
    reservedNow: 4,
    giftCredit: 5,
    currency: 'USD',
  );
}

class _NeverWalletRepository implements WalletRepository {
  const _NeverWalletRepository();

  @override
  Future<WalletBalance> fetchBalance() => Completer<WalletBalance>().future;
}

class _ApprovedGate implements JeeberKycStatusGate {
  const _ApprovedGate();

  @override
  JeeberKycStatus get status => JeeberKycStatus.approved;

  @override
  bool get isApproved => true;
}

void main() {
  Future<JeebMidnightField> pumpField(
    WidgetTester tester, {
    WalletRepository repo = const _LoadedWalletRepository(),
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: WalletHubScreen(
              repository: repo,
              kycStatusGate: const _ApprovedGate(),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    final Finder finder = find.byType(JeebMidnightField);
    expect(finder, findsOneWidget, reason: 'R4 draws exactly one field');
    return tester.widget<JeebMidnightField>(finder);
  }

  group('R4 wallet — field glow anchor', () {
    testWidgets('declares the measured top-start anchor, not the topEnd '
        'default', (tester) async {
      final JeebMidnightField field = await pumpField(tester);

      expect(
        field.glowPlacement,
        JeebFieldGlowPlacement.topStart,
        reason:
            'board 04-r4-wallet measures (0.199, -0.080); leaving it null '
            'inherits the hero default `topEnd` (0.88), a MIRRORED anchor',
      );
      expect(field.variant, JeebFieldVariant.hero);
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
      expect(anchor.resolve(TextDirection.rtl).x, greaterThan(0));
    });

    testWidgets('holds in the loading state, where the field mounts too', (
      tester,
    ) async {
      final JeebMidnightField field = await pumpField(
        tester,
        repo: const _NeverWalletRepository(),
      );

      expect(field.glowPlacement, JeebFieldGlowPlacement.topStart);
    });

    testWidgets('draws the periwinkle wash on its own ratified anchor', (
      tester,
    ) async {
      final JeebMidnightField field = await pumpField(tester);

      // The second radial is a SEPARATE layer; adopting the orange anchor must
      // not drag it along. Board `110% 65%` — end-side, mid-height, not top.
      expect(field.washPlacement, JeebFieldWashPlacement.endMid);
      expect(field.washPlacement!.fx, greaterThan(1));
      expect(field.washPlacement!.fy, closeTo(0.6503, 0.001));
      // The shipped `bottomEnd` sat this far down the 956-tall board canvas.
      expect(
        (JeebFieldWashPlacement.bottomEnd.fy - field.washPlacement!.fy) * 956,
        closeTo(335, 1),
      );
      // The orange glow is untouched by the wash move.
      expect(field.glowPlacement, JeebFieldGlowPlacement.topStart);
    });

    testWidgets('the wash holds in the loading state too', (tester) async {
      final JeebMidnightField field = await pumpField(
        tester,
        repo: const _NeverWalletRepository(),
      );

      expect(field.washPlacement, JeebFieldWashPlacement.endMid);
    });
  });
}
