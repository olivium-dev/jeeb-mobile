import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/directional_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';
import 'dm_onboarding_step_header.dart';
import 'dm_onboarding_step_layout.dart';

class DmOnboardingServiceAreaStep extends StatelessWidget {
  const DmOnboardingServiceAreaStep({super.key});

  static const Key rootKey = Key('dm-onboarding-service-area-step');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.hasHomeBase != curr.hasHomeBase,
      builder: (context, state) => Semantics(
        identifier: 'dm_onboarding_service_area_root',
        container: true,
        explicitChildNodes: true,
        child: DmOnboardingStepLayout(
          key: rootKey,
          continueIdentifier: 'dm_onboarding_continue',
          enabled: state.hasHomeBase,
          content: const _ServiceAreaContent(),
        ),
      ),
    );
  }
}

class _ServiceAreaContent extends StatelessWidget {
  const _ServiceAreaContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DmOnboardingStepHeader(
          title: l10n.dmOnboardingServiceAreaHeading,
          subtitle: l10n.dmOnboardingServiceAreaSubtitle,
        ),
        const SizedBox(height: Spacing.xLarge),
        Text(
          l10n.dmOnboardingServiceAreaPrimaryLocationLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: Spacing.small),
        const _HomeBaseMapPin(),
        const SizedBox(height: Spacing.medium),
        const _SelectLocationRow(),
      ],
    );
  }
}

class _HomeBaseMapPin extends StatelessWidget {
  const _HomeBaseMapPin();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.homeBase != curr.homeBase,
      builder: (context, state) {
        final base = state.homeBase;
        return Semantics(
          identifier: 'service_area_map_pin',
          image: true,
          label: l10n.dmOnboardingServiceAreaPrimaryLocationLabel,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Sizes.small),
            child: Container(
              height: Sizes.elevenXLarge,
              width: double.infinity,
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: _HomeBaseMapContent(base: base),
            ),
          ),
        );
      },
    );
  }
}

class _HomeBaseMapContent extends StatelessWidget {
  const _HomeBaseMapContent({required this.base});

  final DmOnboardingHomeBase? base;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = base?.label.trim() ?? '';
    final pinned = label.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          pinned ? Icons.location_on : Icons.map_outlined,
          size: Sizes.threeXLarge,
          color: scheme.tertiary,
        ),
        const SizedBox(height: Spacing.xSmall),
        _HomeBaseMapLabel(
          text: pinned ? label : l10n.dmOnboardingServiceAreaMapPlaceholder,
        ),
      ],
    );
  }
}

class _HomeBaseMapLabel extends StatelessWidget {
  const _HomeBaseMapLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _SelectLocationRow extends StatelessWidget {
  const _SelectLocationRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'service_area_select_location',
      button: true,
      container: true,
      explicitChildNodes: true,
      label: l10n.dmOnboardingServiceAreaLocationFieldLabel,
      child: InkWell(
        onTap: () => _pickHomeBase(context),
        child: const Padding(
          padding: EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
          child: _SelectLocationRowBody(),
        ),
      ),
    );
  }

  Future<void> _pickHomeBase(BuildContext context) async {
    final cubit = context.read<DmOnboardingCubit>();
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      cubit.setHomeBase(
        DmOnboardingHomeBase(
          lat: 0,
          lng: 0,
          label: l10n.dmOnboardingServiceAreaLocationFieldLabel,
        ),
      );
      return;
    }
    await context.pushNamed('capture-location');
    if (!context.mounted) return;
    cubit.setHomeBase(
      DmOnboardingHomeBase(
        lat: 0,
        lng: 0,
        label: l10n.dmOnboardingServiceAreaLocationFieldLabel,
      ),
    );
  }
}

class _SelectLocationRowBody extends StatelessWidget {
  const _SelectLocationRowBody();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(Icons.location_on, color: scheme.tertiary),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          l10n.dmOnboardingServiceAreaLocationFieldLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
        ),
        const Spacer(),
        const _SelectLocationValue(),
        Icon(DirectionalIcons.disclosure(context), color: scheme.primary),
      ],
    );
  }
}

class _SelectLocationValue extends StatelessWidget {
  const _SelectLocationValue();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.homeBase != curr.homeBase,
      builder: (context, state) =>
          _LocationValueText(chosen: state.homeBase?.label.trim() ?? ''),
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
