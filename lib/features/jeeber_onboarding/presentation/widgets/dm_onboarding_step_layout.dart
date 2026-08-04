import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

/// Shared step chrome for the three onboarding steps: a scrollable content
/// area with a [content] body over the docked [JeebCtaFooter] Continue pill.
///
/// Keeps the board's 24px gutter, the flexible gap above the CTA, and the CTA
/// itself identical across photo / address / service-area steps (RAIL 4 — no
/// per-step duplication). The CTA is a [JeebCtaButton] so the final-step submit
/// spinner is handled uniformly.
class DmOnboardingStepLayout extends StatelessWidget {
  const DmOnboardingStepLayout({
    super.key,
    required this.content,
    required this.continueIdentifier,
    this.enabled = true,
  });

  /// The step's body, laid out top-anchored under the progress bar.
  final Widget content;

  /// Semantics identifier for the Continue button (per-step).
  final String continueIdentifier;

  /// Whether the Continue button is tappable (steps gate their own readiness).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _ScrollableContent(child: content)),
        JeebCtaFooter.single(
          child: _ContinueButton(
            identifier: continueIdentifier,
            enabled: enabled,
          ),
        ),
      ],
    );
  }
}

class _ScrollableContent extends StatelessWidget {
  const _ScrollableContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // 24px side gutters; `large` on top is the board's block rhythm below
      // the progress band, `medium` at the bottom keeps the last block off the
      // docked footer when the content is long enough to scroll.
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.large,
        Spacing.xLarge,
        Spacing.medium,
      ),
      child: child,
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.identifier, required this.enabled});

  final String identifier;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.isSubmitting != curr.isSubmitting,
      builder: (context, state) => Semantics(
        identifier: identifier,
        button: true,
        // MIDNIGHT: the funnel's docked CTA is ORANGE on both neighbouring
        // tiles (R23 "Submit for review", R5 "Next") — accent, not periwinkle.
        child: JeebCtaButton.accent(
          label: l10n.dmOnboardingContinue,
          isLoading: state.isSubmitting,
          isEnabled: enabled && !state.isSubmitting,
          onTap: () => context.read<DmOnboardingCubit>().next(),
        ),
      ),
    );
  }
}
