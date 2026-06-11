import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

/// "Your Primary Location" section + tappable selector row (Figma 56591:5337).
///
/// Leading orange pin + "Location" label; trailing chosen-value (or "Select"
/// placeholder) + a directional chevron. Tapping picks the primary location;
/// in the UI-only milestone it sets a stub label so the wizard can advance.
class DmOnboardingLocationSelector extends StatelessWidget {
  const DmOnboardingLocationSelector({super.key});

  static const Key rootKey = Key('dm-onboarding-location-selector');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: rootKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dmOnboardingServiceAreaPrimaryLocationLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: Spacing.xSmall),
        const _SelectorRow(),
      ],
    );
  }
}

class _SelectorRow extends StatelessWidget {
  const _SelectorRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'dm_onboarding_location_selector',
      button: true,
      label: l10n.dmOnboardingServiceAreaLocationFieldLabel,
      child: InkWell(
        onTap: () => _onTap(context, l10n),
        child: const Padding(
          padding: EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
          child: _SelectorRowBody(),
        ),
      ),
    );
  }

  void _onTap(BuildContext context, AppLocalizations l10n) {
    // UI-only milestone: a real pick opens the geo picker via the host; here we
    // set the displayed primary-location label so Continue can enable.
    context
        .read<DmOnboardingCubit>()
        .setPrimaryLocation(l10n.dmOnboardingServiceAreaLocationFieldLabel);
  }
}

class _SelectorRowBody extends StatelessWidget {
  const _SelectorRowBody();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(Icons.location_on, color: colorScheme.primaryContainer),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          l10n.dmOnboardingServiceAreaLocationFieldLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
        ),
        const Spacer(),
        const _SelectorValue(),
        Icon(Icons.chevron_right, color: colorScheme.primary),
      ],
    );
  }
}

class _SelectorValue extends StatelessWidget {
  const _SelectorValue();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.primaryLocation != curr.primaryLocation,
      builder: (context, state) =>
          _LocationValueText(chosen: state.primaryLocation.trim()),
    );
  }
}

class _LocationValueText extends StatelessWidget {
  const _LocationValueText({required this.chosen});

  final String chosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isPlaceholder = chosen.isEmpty;
    return Semantics(
      identifier: 'dm_onboarding_location_value',
      child: Text(
        isPlaceholder ? l10n.dmOnboardingServiceAreaLocationPlaceholder : chosen,
        style: theme.textTheme.titleSmall?.copyWith(
          color: isPlaceholder
              ? theme.colorScheme.outline
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
