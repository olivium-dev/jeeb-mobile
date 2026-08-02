// Shared dev-only fixtures for `OnboardingFundingScreen` (JM-041).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_05_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart`.
//
// Two kinds of fixture live here, because this screen has two independent axes
// and only one of them is data.
//
// **The wallet read.** The screen takes a `WalletRepository` through its
// constructor test seam (40_GUARDRAILS_ARCH §5.4) and calls `fetchBalance()`
// once from `initState`. The three implementations below cover the three
// outcomes that reach the UI differently — a snapshot, a typed failure, and a
// read that has not come back yet — plus the named [WalletBalance] constants the
// two surfaces share so a number shown to a designer and a number shown in the
// canvas cannot drift apart.
//
// **The navigation stack.** Every affordance on this screen leaves it:
// `funding_topup_cta` → `goNamed('wallet-charge-info')`, `funding_continue_cta`
// → `goNamed('kyc-status')`, and the app-bar arrow branches on
// `context.canPop()`. With no local `Router` the catalog's CTAs drive the REAL
// app router and drop the reviewer out of the catalog into the live app, and the
// preview canvas — which has no `Router` at all — throws the moment either CTA
// is tapped. [OnboardingFundingScreenHost] supplies a local [GoRouter] over
// stand-in destinations so both surfaces are safe to tap and so the two branches
// of `canPop()` are reviewable side by side.
//
// Everything here is local: three hand-built repositories and an in-memory
// router. No DI, no Dio, no GetIt — network-free by construction, not merely by
// the guard the two hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/wallet/domain/wallet_repository.dart';

// ─────────────────────────────────────────────────────────────────────────
// Wallet snapshots
// ─────────────────────────────────────────────────────────────────────────

/// The reference snapshot: a starter credit on file (D42) AND live reserves
/// against open offers (D1), so BOTH enrichment amounts render.
///
/// This is the one state in which the screen shows everything it can show.
const WalletBalance onboardingFundingScreenEnrichedBalance = WalletBalance(
  availableBalance: 150,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 20,
  giftCredit: 50,
  currency: 'USD',
);

/// A jeeber who has the starter credit but has not sent an offer yet, so
/// `reservedNow` is 0.
///
/// This is the FIRST state a real post-KYC jeeber is in, and the reserve card
/// silently drops its amount for it: the `> 0` guard treats "nothing reserved"
/// the same as "we do not know".
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

/// The typographic ceiling: a weak-unit currency, where the amounts are the
/// longest strings on the screen.
///
/// `_formatMoney` always renders two decimals and never groups digits, so LBP
/// amounts are ~13 characters before the currency code is appended — the widest
/// thing the layout ever has to carry, and the reason a longest-content preview
/// exists at all.
const WalletBalance onboardingFundingScreenCeilingBalance = WalletBalance(
  availableBalance: 2222222.21,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 987654.32,
  giftCredit: 1234567.89,
  currency: 'LBP',
);

// ─────────────────────────────────────────────────────────────────────────
// Wallet repositories — three outcomes, no network
// ─────────────────────────────────────────────────────────────────────────

/// Resolves immediately with [balance]. The loaded/enriched branch.
class OnboardingFundingScreenStaticWallet implements WalletRepository {
  const OnboardingFundingScreenStaticWallet(this.balance);

  final WalletBalance balance;

  @override
  Future<WalletBalance> fetchBalance() async => balance;
}

/// Throws the typed [WalletRepositoryException] the screen's fail-safe branch
/// swallows, leaving `_balance` null.
///
/// The default is [WalletFailure.network]; the screen treats every failure
/// identically, which is the contract this fixture exists to make visible.
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
///
/// Not a hypothetical: `initState` fires the fetch and the first frame is
/// painted before it can possibly return, so EVERY user sees this state. It has
/// no timer and no completer to drain, so it settles under `pumpAndSettle` like
/// any static widget.
class OnboardingFundingScreenPendingWallet implements WalletRepository {
  const OnboardingFundingScreenPendingWallet();

  @override
  Future<WalletBalance> fetchBalance() => Completer<WalletBalance>().future;
}

// ─────────────────────────────────────────────────────────────────────────
// Navigation
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
///
/// This is not cosmetic: it decides where the app-bar arrow goes, and the two
/// values send the same arrow to two different screens.
enum OnboardingFundingScreenEntry {
  /// The PRODUCTION shape. The KYC wizard chains here with
  /// `context.goNamed('onboarding-funding')`, which REPLACES the stack, and the
  /// dev-seam landing (`jeeberKycSubmitted`) pins `/jeeber/onboarding/funding`
  /// as a cold start. Either way the screen is the only page on the stack,
  /// `context.canPop()` is false, and the arrow takes the `context.go('/')`
  /// branch.
  standalone,

  /// The branch the screen's own comment describes ("Normally pushed after KYC
  /// submission"): the screen sits ON TOP of the KYC wizard, `canPop()` is true,
  /// and the arrow POPS back to it.
  ///
  /// Kept because it is half of the screen's written contract and one
  /// `pushNamed` away from being live — but note that no caller in the app
  /// pushes today.
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
          // reorders visually inside an RTL paragraph.
          textDirection: TextDirection.ltr,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [screen], on the stack named by [entry].
///
/// Stateful, and the [GoRouter] is built once and disposed with the host: a
/// router rebuilt on every frame would drop the stack the screen's `canPop()`
/// call reads. `Router.withConfig` is exactly what `MaterialApp.router` does
/// internally, so this adds a Router and nothing else — the ambient theme,
/// locale and text scale still come from the host above it.
///
/// The screen is INJECTED rather than constructed here so that both dev surfaces
/// keep building the real `OnboardingFundingScreen()` in their own source: the
/// catalog's convention is that every entry visibly renders the real screen, and
/// `tool/preview_inventory.dart` credits a preview section only when the section
/// itself constructs the widget it is named after.
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
  /// state:
  ///
  ///  * [OnboardingFundingScreenEntry.standalone] declares the funding screen
  ///    FLAT, the way `app_router.dart` does, and starts there — one page,
  ///    `canPop()` false;
  ///  * [OnboardingFundingScreenEntry.pushedOnKycWizard] declares it as a CHILD
  ///    of the KYC wizard and starts at the child, so go_router materializes
  ///    both pages — `canPop()` true.
  ///
  /// Both stacks carry the two CTA destinations, under the exact route NAMES the
  /// screen reaches for (`wallet-charge-info`, `kyc-status`); a typo in either
  /// name would throw here instead of silently no-oping.
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
            // here, which is what the wizard stack really looks like: Continue
            // `go`es to the page the arrow would have popped to.
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
