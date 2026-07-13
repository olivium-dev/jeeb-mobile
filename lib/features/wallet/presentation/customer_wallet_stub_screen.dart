import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

/// customer-wallet stub (JEBV4-303 / F6 role-bleed).
///
/// The Jeeber wallet-hub ([WalletHubScreen], `/wallet`) is a BIDDING wallet: it
/// calls `/v1/jeeb/wallet`, `/v1/jeeb/wallet/ledger` and `/v1/jeeb/earnings`,
/// and its copy ("Top up to bid", "the customer pays YOU") only makes sense for
/// a jeeber. A pure customer (no active jeeber role) tapping the top-bar wallet
/// chip must NOT land there — it exposed jeeber-only money surfaces and an
/// Earnings-403 dead-end (role-bleed on A33).
///
/// This customer-appropriate stub is what the wallet chip routes a client to
/// instead. It performs NO network calls and explains the product truth: Jeeb is
/// cash-on-delivery, so there is no in-app balance to top up — the customer pays
/// their Jeeber directly in cash when the order arrives (D11, the same cash-only
/// invariant the offer card / receipt already state).
///
/// Semantics ids:
///   `customer_wallet_stub`      — screen root (QA target for the role-gate).
///   `customer_wallet_stub_done` — the "Got it" CTA (back to the shell).
class CustomerWalletStubScreen extends StatelessWidget {
  const CustomerWalletStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'customer_wallet_stub',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.customerWalletStubTitle,
          showBackButton: true,
          // The chip reaches this via stack-REPLACING `goNamed('customer-wallet')`,
          // so there is usually nothing to pop — fall back to the shell rather
          // than leave an empty Navigator (mirrors the wallet-hub back guard).
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            Icon(
              Icons.payments_outlined,
              size: Sizes.sixXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.customerWalletStubHeadline,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.small),
            Text(
              l10n.customerWalletStubBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.large),
            Container(
              padding: const EdgeInsets.all(Spacing.medium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: OmdsBorderRadius.uiMedium,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.local_atm_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.customerWalletStubCodTitle,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: Spacing.twoXSmall),
                        Text(
                          l10n.customerWalletStubCodBody,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xLarge),
            Semantics(
              identifier: 'customer_wallet_stub_done',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.customerWalletStubDoneCta,
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
