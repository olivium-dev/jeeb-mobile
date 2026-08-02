import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../wallet/domain/wallet_repository.dart';

class OnboardingFundingScreen extends StatefulWidget {
  const OnboardingFundingScreen({super.key, this.repository});

  final WalletRepository? repository;

  @override
  State<OnboardingFundingScreen> createState() =>
      _OnboardingFundingScreenState();
}

class _OnboardingFundingScreenState extends State<OnboardingFundingScreen> {
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
    } catch (_) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balance = _balance;
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.fundingTitle,
        showBackButton: true,
        onBackPressed: () =>
            context.canPop() ? context.pop() : context.go('/'),
      ),
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
            Semantics(
              identifier: 'funding_topup_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.fundingTopupCta,
                variant: OmdsButtonVariant.secondary,
                onTap: () => context.goNamed('wallet-charge-info'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'funding_continue_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.fundingContinueCta,
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

String _formatMoney(double amount, String currency) {
  final value = amount.toStringAsFixed(2);
  return currency.isEmpty ? value : '$value $currency';
}
