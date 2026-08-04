// Shared dev-only fixtures for `OnboardingFundingScreen` (JM-041).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/wallet/domain/wallet_repository.dart';

// ─────────────────────────────────────────────────────────────────────────

/// The reference snapshot: a starter credit on file (D42) AND live reserves
/// against open offers (D1), so BOTH enrichment amounts render.
const WalletBalance onboardingFundingScreenEnrichedBalance = WalletBalance(
  availableBalance: 150,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 20,
  giftCredit: 50,
  currency: 'USD',
);

/// A jeeber who has the starter credit but has not sent an offer yet, so
const WalletBalance onboardingFundingScreenUnreservedBalance = WalletBalance(
  availableBalance: 25,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 0,
  giftCredit: 25,
  currency: 'USD',
);

/// The mirror image: the starter credit is spent (`giftCredit` 0) and every
/// remaining cent is reserved against live offers.
const WalletBalance onboardingFundingScreenGiftSpentBalance = WalletBalance(
  availableBalance: 0,
  affordabilityState: WalletAffordability.allReserved,
  reservedNow: 7.5,
  giftCredit: 0,
  currency: 'USD',
);

/// Nothing to enrich with: the snapshot loaded, but neither amount is > 0, so
/// the explainer copy carries the screen alone.
const WalletBalance onboardingFundingScreenNoCreditBalance = WalletBalance(
  availableBalance: 0,
  affordabilityState: WalletAffordability.empty,
  reservedNow: 0,
  giftCredit: 0,
  currency: 'USD',
);

/// The typographic ceiling: a weak-unit currency, where the amounts are the
const WalletBalance onboardingFundingScreenCeilingBalance = WalletBalance(
  availableBalance: 2222222.21,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 987654.32,
  giftCredit: 1234567.89,
  currency: 'LBP',
);

// ─────────────────────────────────────────────────────────────────────────

/// Resolves immediately with [balance]. The loaded/enriched branch.
class OnboardingFundingScreenStaticWallet implements WalletRepository {
  const OnboardingFundingScreenStaticWallet(this.balance);

  final WalletBalance balance;

  @override
  Future<WalletBalance> fetchBalance() async => balance;
}

/// Throws the typed [WalletRepositoryException] the screen's fail-safe branch
class OnboardingFundingScreenFailingWallet implements WalletRepository {
  const OnboardingFundingScreenFailingWallet([
    this.failure = WalletFailure.network,
  ]);

  final WalletFailure failure;

  @override
  Future<WalletBalance> fetchBalance() async {
    throw WalletRepositoryException(failure);
  }
}

/// Never completes — the read is still in flight.
class OnboardingFundingScreenPendingWallet implements WalletRepository {
  const OnboardingFundingScreenPendingWallet();

  @override
  Future<WalletBalance> fetchBalance() => Completer<WalletBalance>().future;
}

// ─────────────────────────────────────────────────────────────────────────

/// Label of the stand-in that plays the app shell — where the app-bar arrow
/// lands when there is nothing to pop (`context.go('/')`).
const String onboardingFundingScreenShellLabel = 'app shell (/) · stand-in';

/// Label of the stand-in that plays `wallet-charge-info` (JM-054), the
/// destination of `funding_topup_cta`.
const String onboardingFundingScreenChargeInfoLabel =
    'wallet-charge-info · stand-in';

/// Label of the stand-in that plays `kyc-status` (JM-042), the destination of
/// `funding_continue_cta`.
const String onboardingFundingScreenKycStatusLabel = 'kyc-status · stand-in';

/// Which navigation stack the screen is mocked on.
/// This is not cosmetic: it decides where the app-bar arrow goes, and the two
/// values send the same arrow to two different screens.
enum OnboardingFundingScreenEntry {
  /// The PRODUCTION shape. The KYC wizard chains here with
  standalone,

  /// The branch the screen's own comment describes ("Normally pushed after KYC
  pushedOnKycWizard,
}

/// A minimal, obviously-fake destination so a tap on a CTA lands somewhere
/// legible instead of throwing or escaping into the real app.
class OnboardingFundingScreenStandIn extends StatelessWidget {
  const OnboardingFundingScreenStandIn({required this.label, super.key});

  /// What this stand-in is playing — read by the render tests to tell the
  /// destinations apart.
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      body: Center(
        child: Text(
          label,
          // Forced LTR: a diagnostic, not shipped copy, and a latin route name
          textDirection: TextDirection.ltr,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [screen], on the stack named by [entry].
class OnboardingFundingScreenHost extends StatefulWidget {
  const OnboardingFundingScreenHost({
    required this.screen,
    super.key,
    this.entry = OnboardingFundingScreenEntry.standalone,
  });

  /// The real `OnboardingFundingScreen`, built by the caller.
  final Widget screen;

  final OnboardingFundingScreenEntry entry;

  @override
  State<OnboardingFundingScreenHost> createState() =>
      _OnboardingFundingScreenHostState();
}

class _OnboardingFundingScreenHostState
    extends State<OnboardingFundingScreenHost> {
  late final GoRouter _router = _buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);

  /// Mirrors the two stacks exactly, because the difference between them IS the
  GoRouter _buildRouter() {
    final GoRoute shell = GoRoute(
      path: '/',
      builder: (_, _) => const OnboardingFundingScreenStandIn(
        label: onboardingFundingScreenShellLabel,
      ),
    );
    final GoRoute chargeInfo = GoRoute(
      path: '/wallet/charge-info',
      name: 'wallet-charge-info',
      builder: (_, _) => const OnboardingFundingScreenStandIn(
        label: onboardingFundingScreenChargeInfoLabel,
      ),
    );
    switch (widget.entry) {
      case OnboardingFundingScreenEntry.standalone:
        return GoRouter(
          initialLocation: '/jeeber/onboarding/funding',
          routes: <RouteBase>[
            shell,
            chargeInfo,
            GoRoute(
              path: '/profile/kyc',
              name: 'kyc-status',
              builder: (_, _) => const OnboardingFundingScreenStandIn(
                label: onboardingFundingScreenKycStatusLabel,
              ),
            ),
            GoRoute(
              path: '/jeeber/onboarding/funding',
              builder: (_, _) => widget.screen,
            ),
          ],
        );
      case OnboardingFundingScreenEntry.pushedOnKycWizard:
        return GoRouter(
          initialLocation: '/profile/kyc/funding',
          routes: <RouteBase>[
            shell,
            chargeInfo,
            // The caller AND the `kyc-status` destination are the same route
            GoRoute(
              path: '/profile/kyc',
              name: 'kyc-status',
              builder: (_, _) => const OnboardingFundingScreenStandIn(
                label: onboardingFundingScreenKycStatusLabel,
              ),
              routes: <RouteBase>[
                GoRoute(path: 'funding', builder: (_, _) => widget.screen),
              ],
            ),
          ],
        );
    }
  }
}
