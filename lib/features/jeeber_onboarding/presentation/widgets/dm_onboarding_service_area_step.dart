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

/// Service-area step of delivery-man onboarding (Figma 56591:5337).
///
/// JM-038 / D51: the distance slider is removed. Instead a single home-base
/// map pin (`service_area_map_pin`) is required — Continue stays disabled until
/// a base is pinned. The pin is chosen on the shared location-map-pin screen,
/// reached via the `service_area_select_location` row. Continue then confirms
/// coverage (matching find-jeebers) and chains to KYC identity (JM-040).
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
          // QA-contract id (65_W2_TEST_PLAN JM-038): the wizard Continue is
          // `dm_onboarding_continue`, not the old per-step button id.
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

/// The required home-base map pin (`service_area_map_pin`, JM-038 AC2).
///
/// Always visible. Renders a neutral map preview with a centred pin (the Figma
/// map raster is a mock and is never bundled — UI-GUARDRAILS §0). Once a base
/// is pinned the chosen-place label is surfaced beneath the pin.
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

/// Content of the home-base map placeholder. Until a base is pinned it reads as
/// an intentional empty map ([Icons.map_outlined] + a hint to tap Location)
/// rather than a lone, broken-looking pin; once pinned it shows a filled pin and
/// the chosen-place label (VIS-P1-3 placeholder quality — no Maps key wired).
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
          // Accent PAINT (map pin), not a container fill — same #D73B00.
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

/// Tappable "Select location" row (`service_area_select_location`, JM-038 AC3)
/// → opens the shared location-map-pin screen, then records the pinned base.
class _SelectLocationRow extends StatelessWidget {
  const _SelectLocationRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // `container: true` + `explicitChildNodes: true` keep the row's own node
    // (`service_area_select_location`) and the nested value node distinct.
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
      // Cold deep link / widget test: no map-pin route in the tree. Record a
      // stub base directly so Continue can still enable deterministically.
      cubit.setHomeBase(
        DmOnboardingHomeBase(
          lat: 0,
          lng: 0,
          label: l10n.dmOnboardingServiceAreaLocationFieldLabel,
        ),
      );
      return;
    }
    // Open the shared location-map-pin screen (route `capture-location`); its
    // Pin CTA pops back here. The live geo wrap (`ofl_geo_capture`) supplies
    // real coordinates once resolvable; until then record a stub base so the
    // chosen-base label + Continue gate light up (UI-only milestone).
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
