// Wave-3 motion wiring (08-MOTION-SPEC §2.5, screen 23): `success-check.json`
// fires ONCE when a top-up lands on the wallet hub.
//
// There is no in-app top-up transaction (D92/D93 — cash at a store, the balance
// auto-updates), so the honest signal is a reload that returns MORE available
// balance than the reload before it. These tests pin exactly that: the cold
// load never fires it, an unchanged reload never fires it, and a raised balance
// fires it once, non-blocking.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/wallet/application/wallet_hub_cubit.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_hub_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/widgets/wallet_topup_confirmed_mark.dart';

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

/// Steps past the mark's host-owned 1.8s lifetime. Deliberately independent of
/// the composition: the dismissal must not need the player to have loaded.
Future<void> _advance(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
}

Finder _markLottie() => find.descendant(
  of: find.byType(WalletTopUpConfirmedMark),
  matching: find.byType(LottieBuilder),
);

void main() {
  testWidgets('the cold load never fires the mark — there is no "before"', (
    tester,
  ) async {
    await _pumpHub(tester, _MutableWalletRepository(40));

    expect(find.byType(WalletTopUpConfirmedMark), findsNothing);
  });

  testWidgets('a reload at the same balance is not a top-up', (tester) async {
    final repo = _MutableWalletRepository(40);
    await _pumpHub(tester, repo);

    await _reload(tester);

    expect(find.byType(WalletTopUpConfirmedMark), findsNothing);
  });

  testWidgets('a reload that RAISED the balance plays the one-shot mark', (
    tester,
  ) async {
    final repo = _MutableWalletRepository(40);
    await _pumpHub(tester, repo);
    repo.available = 65;

    await _reload(tester);

    expect(find.byType(WalletTopUpConfirmedMark), findsOneWidget);
    // One-shot: driven by a controller, never handed a repeating player.
    expect(tester.widget<LottieBuilder>(_markLottie()).controller, isNotNull);
    // The hub stays fully usable underneath — the mark never takes a hit.
    expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_available_balance'),
        findsOneWidget);
  });

  testWidgets('the mark retires itself — the hub is never left occluded', (
    tester,
  ) async {
    final repo = _MutableWalletRepository(40);
    await _pumpHub(tester, repo);
    repo.available = 65;
    await _reload(tester);
    expect(find.byType(WalletTopUpConfirmedMark), findsOneWidget);

    await _advance(tester);

    expect(find.byType(WalletTopUpConfirmedMark), findsNothing);
  });

  testWidgets('reduce-motion still confirms, without animating', (
    tester,
  ) async {
    final repo = _MutableWalletRepository(40);
    await _pumpHub(tester, repo, disableAnimations: true);
    repo.available = 65;

    await _reload(tester);

    // The confirmation is NOT withheld from a11y users; it settles at once —
    // no ticker ever runs, only the host's dismissal timer.
    expect(find.byType(WalletTopUpConfirmedMark), findsOneWidget);
    await _advance(tester);
    expect(find.byType(WalletTopUpConfirmedMark), findsNothing);
  });
}
