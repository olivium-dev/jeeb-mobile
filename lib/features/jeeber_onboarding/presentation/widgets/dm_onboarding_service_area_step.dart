import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../core/widgets/jeeb/jeeb_surface_tone.dart';
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
        JeebSectionLabel(l10n.dmOnboardingServiceAreaPrimaryLocationLabel),
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
///
/// MIDNIGHT: the panel is REST GLASS, not the opaque `surfaceContainerHighest`
/// slab it used to paint — no tile draws this preview opaque (M1 ruling 4 as
/// narrowed in wave A: solid only where a tile draws opaque).
class _HomeBaseMapPin extends StatelessWidget {
  const _HomeBaseMapPin();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.homeBase != curr.homeBase,
      builder: (context, state) {
        final base = state.homeBase;
        return Semantics(
          identifier: 'service_area_map_pin',
          image: true,
          label: l10n.dmOnboardingServiceAreaPrimaryLocationLabel,
          child: JeebOutlinedCard(
            radius: JeebRadii.lg,
            padding: EdgeInsetsDirectional.zero,
            child: SizedBox(
              height: Sizes.elevenXLarge,
              width: double.infinity,
              child: Center(child: _HomeBaseMapContent(base: base)),
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
    final theme = Theme.of(context);
    final semantic =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final l10n = AppLocalizations.of(context);
    final label = base?.label.trim() ?? '';
    final pinned = label.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          pinned ? Icons.location_on : Icons.map_outlined,
          size: Sizes.threeXLarge,
          // The one rationed orange on this step is accent PAINT on the real
          // PIN; an empty placeholder has nothing live to light (§2.2).
          color: pinned ? context.jeebRoles.accent : semantic.mutedText,
        ),
        const SizedBox(height: Spacing.xSmall),
        _HomeBaseMapLabel(
          text: pinned ? label : l10n.dmOnboardingServiceAreaMapPlaceholder,
          pinned: pinned,
        ),
      ],
    );
  }
}

class _HomeBaseMapLabel extends StatelessWidget {
  const _HomeBaseMapLabel({required this.text, required this.pinned});

  final String text;

  /// A resolved place name is live content and reads `inkSoft`; the untouched
  /// prompt is the dimmed rung and stays `mutedText` (R23's ink ladder).
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.jeebText.bodySmall.copyWith(
          color: pinned ? semantic.inkSoft : semantic.mutedText,
        ),
      ),
    );
  }
}

/// Tappable "Select location" row (`service_area_select_location`, JM-038 AC3)
/// → opens the shared location-map-pin screen, then records the pinned base.
///
/// Shaped as the board shapes every navigation row: a kit [JeebListRow] inside
/// an outlined card. The card owns no tap and no identifier, so it adds no
/// semantics node of its own — the frozen wrapper below stays the only one.
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
      child: JeebOutlinedCard(
        padding: EdgeInsetsDirectional.zero,
        child: JeebListRow(
          icon: Icons.location_on,
          title: l10n.dmOnboardingServiceAreaLocationFieldLabel,
          trailing: const _SelectLocationTrailing(),
          onTap: () => _pickHomeBase(context),
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

/// The row's end slot: the chosen-place value plus the disclosure chevron.
///
/// [JeebListRow.trailing] replaces the built-in chevron outright, so the row
/// re-declares it here at the kit's own size and muted ink.
class _SelectLocationTrailing extends StatelessWidget {
  const _SelectLocationTrailing();

  /// The kit's own `JeebListRow.chevronSize` default.
  static const double _chevronSize = 16;

  @override
  Widget build(BuildContext context) {
    // The surface tone, not a raw extension read: it degrades gracefully when
    // no Jeeb theme extension is registered and inverts on a navy card.
    final muted = JeebSurfaceTone.of(context).mutedInk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SelectLocationValue(),
        const SizedBox(width: Spacing.xSmall),
        Icon(
          DirectionalIcons.disclosure(context),
          size: _chevronSize,
          color: muted,
        ),
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
    final semantic =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final isPlaceholder = chosen.isEmpty;
    return Semantics(
      identifier: 'dm_onboarding_location_value',
      child: Text(
        isPlaceholder ? l10n.dmOnboardingServiceAreaLocationPlaceholder : chosen,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // `outline` is a 14%-white STROKE token; as ink on navy it is ~1.2:1,
        // i.e. an unreadable placeholder. The muted ink role is §9's AA pair.
        style: context.jeebText.bodySmall.copyWith(
          color:
              isPlaceholder ? semantic.mutedText : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
