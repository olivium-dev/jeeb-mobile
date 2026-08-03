import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
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
/// redesign-2026-08: re-skinned onto the Jeeb kit alongside its gate — in-body
/// [JeebTopBar], start-aligned `jeebText` headline/body, and the two exits
/// docked in a [JeebCtaFooter] under a real `flex: 1` band of white. The
/// centred `delivery_dining` hero glyph was dropped: the board carries no
/// oversized outline icon on any of its 24 screens, and it was the single
/// element that made this prompt read as a different product from the KYC
/// wizard it leads into. No flow, copy, affordance or identifier changed.
///
/// Semantics ids:
///   `delivery_register_prompt`         — screen root (the id JM-044 AC3 asserts)
///   `delivery_register_prompt_cta`     — "Register now" → jeeber-onboarding
///   `delivery_register_prompt_back`    — back → shell
///   `delivery_register_prompt_top_back`— the redesign's new top-bar circle.
///     Deliberately NOT `delivery_register_prompt_back`: that id is already
///     owned by the in-body CTA below, and two nodes sharing one identifier
///     break both Maestro's `tapOn: id` and `find.bySemanticsIdentifier`.
class DeliveryRegisterPromptScreen extends StatelessWidget {
  const DeliveryRegisterPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'delivery_register_prompt',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        // No Material app bar: the redesign's header is a body row.
        body: SafeArea(
          child: Column(
            children: [
              JeebTopBar.back(
                title: l10n.offerKycGateTitle,
                identifier: 'delivery_register_prompt_top_back',
                // JEBV4-13 P1-6: without an explicit destination the kit's
                // default `maybePop()` no-ops when this screen is the stack
                // root (reached via `go`), leaving the back circle dead. Mirror
                // the screen's own `delivery_register_prompt_back` exit.
                onLeadingPressed: () => _back(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    Spacing.xLarge,
                    Spacing.large,
                    Spacing.xLarge,
                    Spacing.large,
                  ),
                  // Top-aligned: the lower band stays plain white.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.offerKycGateHeadline,
                        style: context.jeebText.h1
                            .copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: Spacing.xSmall),
                      Text(
                        l10n.offerKycGateBody,
                        // NOT periwinkle: periwinkle-on-white is a documented
                        // AA failure (color_role_contrast_test.dart).
                        style: context.jeebText.body
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              JeebCtaFooter.single(
                below: Semantics(
                  identifier: 'delivery_register_prompt_back',
                  button: true,
                  container: true,
                  child: JeebCtaButton.text(
                    label: l10n.gateBackCta,
                    contentPadding: EdgeInsetsDirectional.zero,
                    onTap: () => _back(context),
                  ),
                ),
                child: Semantics(
                  identifier: 'delivery_register_prompt_cta',
                  button: true,
                  container: true,
                  child: JeebCtaButton.primary(
                    label: l10n.gateStartKycCta,
                    onTap: () => context.goNamed('jeeber-onboarding'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Back to whatever pushed the prompt, or the shell root when it is the
  /// stack root (it is reached via `go`, so `canPop()` is usually false).
  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/');
}
