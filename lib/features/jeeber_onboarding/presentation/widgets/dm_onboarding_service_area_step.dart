import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';
import 'dm_onboarding_distance_slider.dart';
import 'dm_onboarding_location_selector.dart';
import 'dm_onboarding_step_header.dart';
import 'dm_onboarding_step_layout.dart';

/// Service-area step of delivery-man onboarding (Figma 56591:5337).
///
/// Heading + subtitle, a primary-location selector row, and a single-thumb
/// distance slider with a live "{n} km" value. Continue stays disabled until a
/// primary location is chosen (the slider always has a default).
class DmOnboardingServiceAreaStep extends StatelessWidget {
  const DmOnboardingServiceAreaStep({super.key});

  static const Key rootKey = Key('dm-onboarding-service-area-step');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) =>
          prev.hasPrimaryLocation != curr.hasPrimaryLocation,
      builder: (context, state) => DmOnboardingStepLayout(
        key: rootKey,
        continueIdentifier: 'dm_onboarding_service_area_continue_button',
        enabled: state.hasPrimaryLocation,
        content: const _ServiceAreaContent(),
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
        const DmOnboardingLocationSelector(),
        const SizedBox(height: Spacing.medium),
        const DmOnboardingDistanceSlider(),
      ],
    );
  }
}
