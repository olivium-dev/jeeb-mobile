import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

class DmOnboardingStepLayout extends StatelessWidget {
  const DmOnboardingStepLayout({
    super.key,
    required this.content,
    required this.continueIdentifier,
    this.enabled = true,
  });

  final Widget content;

  final String continueIdentifier;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _ScrollableContent(child: content)),
          _ContinueButton(
            identifier: continueIdentifier,
            enabled: enabled,
          ),
          const SizedBox(height: Spacing.large),
        ],
      ),
    );
  }
}

class _ScrollableContent extends StatelessWidget {
  const _ScrollableContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(top: Spacing.medium),
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
        child: OmdsLoadingButton(
          text: l10n.dmOnboardingContinue,
          isLoading: state.isSubmitting,
          isEnabled: enabled && !state.isSubmitting,
          onTap: () => context.read<DmOnboardingCubit>().next(),
        ),
      ),
    );
  }
}
