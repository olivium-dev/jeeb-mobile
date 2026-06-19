import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

/// wallet-charge-info (JM-054). Static, NO-payment instructional screen
/// (D92/D93): the Jeeber charges the wallet at an authorized store, gives a
/// phone number / ID, pays cash, the balance auto-updates, and the 10% platform
/// fee per accepted offer comes from that pre-charged balance — there is NO
/// in-app payment, NO card input, NO amount field, NO store directory. The
/// three forbidden affordances (`charge_info_card_input`,
/// `charge_info_amount_field`, `charge_info_store_directory`) are intentionally
/// absent and `assertNotVisible` in the JM-054 Maestro flow; do NOT add any
/// payment/amount widget here.
///
/// This screen makes NO network call (JM-054 AC: "No network call. Mock: —").
///
/// It is the honest target of every "+ Top up" CTA across the app: wallet-hub
/// `wallet_topup_cta` (JM-053), onboarding-funding `funding_topup_cta` (JM-041),
/// kyc-pending `kyc_status_topup_cta` (JM-042), insufficient-balance
/// `insufficient_topup_cta` (JM-046). When reached standalone the back CTA
/// returns to wallet-hub; when pushed from one of those callers it pops back to
/// the caller (canPop) — the JM-054 flow asserts back → `wallet_available_balance`.
///
/// Identifier contract: 65_W2_TEST_PLAN §2/§4 JM-054. Every id below is exact.
class WalletChargeInfoScreen extends StatelessWidget {
  const WalletChargeInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'charge_info_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: l10n.chargeInfoTitle, showBackButton: true),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            // Numbered, ordered instruction steps (D92/D93 charge-at-store flow).
            _Step(
              index: 1,
              id: 'charge_info_store_step',
              text: l10n.chargeInfoStoreStep,
            ),
            const SizedBox(height: Spacing.medium),
            _Step(
              index: 2,
              id: 'charge_info_identity_step',
              text: l10n.chargeInfoIdentityStep,
            ),
            const SizedBox(height: Spacing.medium),
            _Step(
              index: 3,
              id: 'charge_info_pay_cash_step',
              text: l10n.chargeInfoPayCashStep,
            ),
            const SizedBox(height: Spacing.xLarge),

            // Note 1 — balance auto-updates, no in-app payment (D92/D93).
            _Note(
              id: 'charge_info_auto_update_note',
              icon: Icons.sync_outlined,
              text: l10n.chargeInfoAutoUpdateNote,
            ),
            const SizedBox(height: Spacing.small),

            // Note 2 — 10% platform fee comes from the pre-charged balance
            // (D1 reserve-per-offer / D41 fee-only economics).
            _Note(
              id: 'charge_info_fee_note',
              icon: Icons.percent_outlined,
              text: l10n.chargeInfoFeeNote,
            ),
            const SizedBox(height: Spacing.twoXLarge),

            // EDGE: wallet-charge-info → wallet-hub (21_NAV_PLAN §C JM-054).
            // Standalone launch has nothing to pop → goNamed('wallet'); when
            // pushed by a +Top up caller (funding/kyc-pending/insufficient) it
            // pops back to that caller.
            Semantics(
              identifier: 'charge_info_back_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.chargeInfoBackCta,
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.goNamed('wallet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single ordered instruction step: a numbered badge + the step copy.
class _Step extends StatelessWidget {
  const _Step({required this.index, required this.id, required this.text});

  final int index;
  final String id;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      identifier: id,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered badge.
          Container(
            width: Sizes.xLarge,
            height: Sizes.xLarge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: Spacing.twoXSmall),
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

/// An informational note row (auto-update / fee), icon + supporting copy.
class _Note extends StatelessWidget {
  const _Note({required this.id, required this.icon, required this.text});

  final String id;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      identifier: id,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: Sizes.large, color: color),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
