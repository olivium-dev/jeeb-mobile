// M5 audit B2 — R4 draws ZERO animated elements (03-MOTION-NOTES §R4), so a
// landed top-up plays no mark. This replaces `wallet_topup_confirmed_motion_test`,
// which pinned the retired `success-check.json` one-shot from `08-MOTION-SPEC`.
//
// The confirmation the board DOES draw is the balance figure itself, so that is
// what these assert: the number rises, and nothing on the screen ticks.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/wallet/application/wallet_hub_cubit.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_hub_screen.dart';

import '../../support/sync_app_localizations.dart';

/// Serves a balance the test can raise between reloads.
class _MutableWalletRepository implements WalletRepository {
  _MutableWalletRepository(this.available);

  double available;

  @override
  Future<WalletBalance> fetchBalance() async => WalletBalance(
    availableBalance: available,
    affordabilityState: WalletAffordability.enough,
    reservedNow: 4,
    giftCredit: 5,
    currency: 'USD',
  );
}

class _FakeKycGate implements JeeberKycStatusGate {
  const _FakeKycGate();

  @override
  JeeberKycStatus get status => JeeberKycStatus.approved;

  @override
  bool get isApproved => true;
}

Future<void> _pumpHub(
  WidgetTester tester,
  WalletRepository repo, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    wrapForTest(
      Builder(
        builder: (context) => MediaQuery(
          // copyWith, never a bare MediaQueryData — a fresh one would zero the
          // surface size and the hub would have nothing to lay out in.
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: WalletHubScreen(
            repository: repo,
            kycStatusGate: const _FakeKycGate(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Re-reads the balance through the screen's own cubit — the exact path
/// pull-to-refresh takes, without the gesture's timing noise.
Future<void> _reload(WidgetTester tester) async {
  // Any element BELOW WalletHubScreen — the screen itself sits above the
  // BlocProvider it creates in build().
  final BuildContext context = tester.element(find.byType(CustomScrollView));
  await context.read<WalletHubCubit>().refresh();
  // The bloc stream delivers on a later microtask/frame than the awaited call.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a landed top-up plays NO mark — R4 animates nothing', (
    tester,
  ) async {
    final repo = _MutableWalletRepository(40);
    await _pumpHub(tester, repo);
    repo.available = 65;

    await _reload(tester);

    expect(find.byType(LottieBuilder), findsNothing);
    // No ticker anywhere on the loaded wallet, on the frame the raise lands
    // and two seconds later — the retired one-shot ran 1.1s.
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('the raised balance IS the confirmation', (tester) async {
    final repo = _MutableWalletRepository(40);
    await _pumpHub(tester, repo);
    expect(
      find.descendant(
        of: find.bySemanticsIdentifier('wallet_available_balance'),
        matching: find.textContaining('40'),
      ),
      findsOneWidget,
    );
    repo.available = 65;

    await _reload(tester);

    expect(
      find.descendant(
        of: find.bySemanticsIdentifier('wallet_available_balance'),
        matching: find.textContaining('65'),
      ),
      findsOneWidget,
    );
    // The hub stays fully usable — nothing occludes it while the number moves.
    expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);
  });

  testWidgets('a cold load is still too — no enter beat on first paint', (
    tester,
  ) async {
    await _pumpHub(tester, _MutableWalletRepository(40));

    expect(find.byType(LottieBuilder), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
