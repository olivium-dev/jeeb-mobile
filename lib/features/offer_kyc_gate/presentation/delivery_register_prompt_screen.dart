import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

/// delivery-register-prompt (JM-044, route `/jeeber/register-prompt`). The
/// standalone "register as a delivery person" prompt the offer-KYC gate's
/// `gate_register_link` navigates to (RD-1 fix). It renders the
/// `delivery_register_prompt` root UNCONDITIONALLY — unlike the DELIVERY tab
/// body, whose register-prompt vs feed is gate-state-dependent (a `pending`
/// jeeber's tab renders `jeeber_feed_root`, which is why `gate_register_link`
/// must NOT pop back to the tab — 66_W2_QA RD-1).
///
/// The "Register now" CTA chains into the delivery-man onboarding wizard
/// (`jeeber-onboarding`, JM-039); back returns to the gate / shell.
///
/// Semantics ids:
///   `delivery_register_prompt`        — screen root (the id JM-044 AC3 asserts)
///   `delivery_register_prompt_cta`    — "Register now" → jeeber-onboarding
///   `delivery_register_prompt_back`   — back → shell
class DeliveryRegisterPromptScreen extends StatelessWidget {
  const DeliveryRegisterPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'delivery_register_prompt',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.offerKycGateTitle,
          showBackButton: true,
          // JEBV4-13 P1-6: without an explicit destination, OMDSAppBar's
          // default `maybePop()` no-ops when this screen is the stack root
          // (reached via `go`), leaving the AppBar back arrow dead. Mirror
          // the screen's own `delivery_register_prompt_back` exit.
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
              Icons.delivery_dining_outlined,
              size: Sizes.sixXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.offerKycGateHeadline,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.small),
            Text(
              l10n.offerKycGateBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.xLarge),
            Semantics(
              identifier: 'delivery_register_prompt_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.gateStartKycCta,
                onTap: () => context.goNamed('jeeber-onboarding'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'delivery_register_prompt_back',
              button: true,
              container: true,
              child: TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                child: Text(l10n.gateBackCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
