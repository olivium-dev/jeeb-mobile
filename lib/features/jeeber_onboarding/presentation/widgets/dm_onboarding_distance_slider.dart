import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

/// Distance-preference control for the service-area step (Figma 56591:5337).
///
/// Label row ("Distance Preference" + live "{n} km" value) over a single-thumb
/// slider with an orange active track and a ringed white thumb. OMDS only
/// ships a two-thumb [OMDSRangeSlider]; a single-value distance slider is an
/// OMDS gap (flag F-22-3) — themed Material [Slider] is used here with all
/// colors from `colorScheme` so it follows the brand + dark mode.
class DmOnboardingDistanceSlider extends StatelessWidget {
  const DmOnboardingDistanceSlider({super.key});

  static const Key rootKey = Key('dm-onboarding-distance-slider');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.distanceKm != curr.distanceKm,
      builder: (context, state) => Column(
        key: rootKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DistanceLabelRow(distanceKm: state.distanceKm),
          _DistanceTrack(distanceKm: state.distanceKm),
        ],
      ),
    );
  }
}

class _DistanceLabelRow extends StatelessWidget {
  const _DistanceLabelRow({required this.distanceKm});

  final int distanceKm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.dmOnboardingServiceAreaDistanceLabel,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.onSurface),
        ),
        Semantics(
          identifier: 'dm_onboarding_distance_value',
          child: Text(
            l10n.dmOnboardingServiceAreaDistanceValue(distanceKm),
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _DistanceTrack extends StatelessWidget {
  const _DistanceTrack({required this.distanceKm});

  final int distanceKm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'dm_onboarding_distance_slider',
      slider: true,
      value: l10n.dmOnboardingServiceAreaDistanceValue(distanceKm),
      child: SliderTheme(
        data: _trackTheme(colorScheme),
        // TODO(OMDS-gap): OMDS only ships two-thumb OMDSRangeSlider; needs a
        // single-value OmdsSlider so this tokenized raw Slider can be retired.
        child: Slider(
          min: DmOnboardingState.minDistanceKm.toDouble(),
          max: DmOnboardingState.maxDistanceKm.toDouble(),
          value: distanceKm.toDouble(),
          onChanged: (v) =>
              context.read<DmOnboardingCubit>().setDistanceKm(v.round()),
        ),
      ),
    );
  }

  SliderThemeData _trackTheme(ColorScheme colorScheme) {
    return SliderThemeData(
      trackHeight: UIConstants.strokeWidthThick,
      activeTrackColor: colorScheme.primaryContainer,
      inactiveTrackColor: colorScheme.primaryContainer.withValues(
        alpha: UIConstants.opacityOverlay,
      ),
      thumbColor: colorScheme.surface,
      overlayColor: colorScheme.primaryContainer.withValues(
        alpha: UIConstants.opacityPrimaryLight,
      ),
      thumbShape: const _RingThumbShape(),
    );
  }
}

/// White thumb with a thick brand-orange ring, matching the Figma slider thumb.
class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape();

  static const double _radius = Sizes.small;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final fill = Paint()..color = sliderTheme.thumbColor!;
    final ring = Paint()
      ..color = sliderTheme.activeTrackColor!
      ..style = PaintingStyle.stroke
      ..strokeWidth = UIConstants.strokeWidthThick;
    canvas.drawCircle(center, _radius, fill);
    canvas.drawCircle(center, _radius, ring);
  }
}
