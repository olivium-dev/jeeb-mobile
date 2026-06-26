import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../wallet/domain/wallet_repository.dart';

/// onboarding-funding (JM-041). Starter-credit explainer shown after KYC is
/// submitted: a fixed, non-refundable starter credit usable post-KYC (D42) +
/// the reserve-10%-per-offer rule (D1). NO in-app payment (D92/D93) — top-up is
/// done at a store via wallet-charge-info. Top-up is allowed pre-approval
/// (D38/D39), so Continue lands on kyc-pending-status.
///
/// DATA (CTO-D2 wallet model): the explainer is enriched with the LIVE wallet
/// snapshot from the real backend endpoint (W1m `GET /v1/jeeb/wallet`, surfaced
/// through [WalletRepository] — `giftCredit` is the D42 starter credit,
/// `reservedNow` the sum of live 10% reserves, D1). It depends only on the
/// wallet `domain/` contract (no cross-feature `application/` import) and reads
/// `sl<WalletRepository>()` — until W1m is live the DI default is the
/// INTEGRATOR-STUB, so the explainer still renders real numbers from a
/// deterministic snapshot. The static explainer copy is the AC and is ALWAYS
/// visible — it is NEVER gated on the network call, so `funding_explainer` +
/// both CTAs survive a slow/failed wallet fetch (fail-safe,
/// 40_GUARDRAILS_ARCH §3). The live amounts only *enrich* the copy when loaded.
///
/// Edges OWNED here (21_NAV_PLAN §C JM-041):
///   onboarding-funding → wallet-charge-info  (`funding_topup_cta`)
///   onboarding-funding → kyc-pending-status  (`funding_continue_cta`)
class OnboardingFundingScreen extends StatefulWidget {
  const OnboardingFundingScreen({super.key, this.repository});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final WalletRepository? repository;

  @override
  State<OnboardingFundingScreen> createState() =>
      _OnboardingFundingScreenState();
}

class _OnboardingFundingScreenState extends State<OnboardingFundingScreen> {
  /// The live wallet snapshot, or `null` while loading / on failure. The
  /// explainer never blocks on it (fail-safe): a `null` snapshot simply hides
  /// the enrichment amounts and shows the static copy alone.
  WalletBalance? _balance;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final repo = widget.repository ?? sl<WalletRepository>();
    try {
      final balance = await repo.fetchBalance();
      if (mounted) setState(() => _balance = balance);
    } on WalletRepositoryException {
      // Fail-safe: the explainer is static copy; a failed wallet fetch must not
      // hide it. Leave `_balance` null so only the enrichment is omitted.
    } catch (_) {
      // Same — any unexpected error must not break the explainer.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balance = _balance;
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.fundingTitle, showBackButton: true),
      // `funding_explainer` is the screen ROOT (65_W2_TEST_PLAN §2 JM-041) and is
      // ALWAYS present regardless of the wallet load state — the explainer is the
      // AC, not the live numbers.
      body: Semantics(
        identifier: 'funding_explainer',
        container: true,
        explicitChildNodes: true,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            // ── Starter credit (D42) ──────────────────────────────────────
            OMDSSectionCard(
              title: l10n.fundingTitle,
              showDivider: false,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fundingStarterCreditBody,
                    style: theme.textTheme.bodyLarge,
                  ),
                  // Live enrichment: the actual D42 gift-credit amount, shown
                  // only once the wallet snapshot loads and it is non-zero.
                  if (balance != null && balance.giftCredit > 0)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(top: Spacing.small),
                      child: Semantics(
                        identifier: 'funding_starter_credit_amount',
                        child: Text(
                          _formatMoney(balance.giftCredit, balance.currency),
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.medium),
            // ── Reserve-10%-per-offer (D1) ────────────────────────────────
            OMDSSectionCard(
              title: l10n.fundingTitle,
              showDivider: false,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fundingReserveBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                  // Live enrichment: the amount currently reserved across live
                  // offers (D1), shown only when non-zero.
                  if (balance != null && balance.reservedNow > 0)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.only(top: Spacing.small),
                      child: Semantics(
                        identifier: 'funding_reserved_now_amount',
                        child: Text(
                          _formatMoney(balance.reservedNow, balance.currency),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xLarge),
            // ── Top up → wallet-charge-info (D92/D93, NO in-app pay) ───────
            Semantics(
              identifier: 'funding_topup_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.fundingTopupCta,
                variant: OmdsButtonVariant.secondary,
                // EDGE → wallet-charge-info (D92/D93, JM-054).
                onTap: () => context.goNamed('wallet-charge-info'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            // ── Continue → kyc-pending-status (top-up allowed pre-approval) ─
            Semantics(
              identifier: 'funding_continue_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.fundingContinueCta,
                // EDGE → kyc-pending-status (top-up allowed pre-approval,
                // D38/D39). The KYC wizard hosts the status view at
                // `/profile/kyc?step=status` (registered name `kyc-status`).
                // The `step=status` param is forward-compatible: JM-042 wires the
                // wizard to open the status view on it; the route resolves
                // honestly today either way.
                onTap: () => context.goNamed(
                  'kyc-status',
                  queryParameters: const {'step': 'status'},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Amount + currency. Amounts/currency codes are not translatable copy, so this
/// composes a neutral display without a new l10n key (the .arb is integrator-
/// owned and untouched here).
String _formatMoney(double amount, String currency) {
  final value = amount.toStringAsFixed(2);
  return currency.isEmpty ? value : '$value $currency';
}
