import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

// Preview-only.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../domain/dm_onboarding_gateway.dart';

class DmOnboardingProgressHeader extends StatelessWidget {
  const DmOnboardingProgressHeader({super.key});

  static const Key rootKey = Key('dm-onboarding-progress');

  static const double barHeight = Spacing.small;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: _stepChanged,
      builder: (context, state) => _ProgressBar(state: state),
    );
  }

  bool _stepChanged(DmOnboardingState prev, DmOnboardingState curr) =>
      prev.step != curr.step || prev.isSubmitted != curr.isSubmitted;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.state});

  final DmOnboardingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'dm_onboarding_progress',
      value: l10n.dmOnboardingStepProgressLabel(
        current: state.currentStepNumber,
        total: DmOnboardingState.totalSteps,
      ),
      child: _ProgressBarTrack(completedSteps: state.completedSteps),
    );
  }
}

class _ProgressBarTrack extends StatelessWidget {
  const _ProgressBarTrack({required this.completedSteps});

  final int completedSteps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: DmOnboardingProgressHeader.rootKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.small,
        Spacing.xLarge,
        Spacing.xSmall,
      ),
      child: OMDSStepperProgress(
        totalSteps: DmOnboardingState.totalSteps,
        completedSteps: completedSteps,
        height: DmOnboardingProgressHeader.barHeight,
        borderRadius: DmOnboardingProgressHeader.barHeight / 2,
      ),
    );
  }
}
// ============================= JEEB PREVIEWS =============================

/// Phone width with room for captions.
const Size _dmOnboardingProgressHeaderBox = Size(390, 128);

/// [DmOnboardingCubit] pinned to one state for preview.
class _DmOnboardingProgressHeaderSeededCubit extends DmOnboardingCubit {
  _DmOnboardingProgressHeaderSeededCubit(DmOnboardingState seed)
      : super(
          pickerService: StubPhotoPickerService(),
          gateway: FakeDmOnboardingGateway(),
          initialStep: seed.step,
        ) {
    emit(seed);
  }
}

/// Render header with caption naming the state.
Widget _dmOnboardingProgressHeaderHosted(
  String caption,
  DmOnboardingState seed,
) {
  return BlocProvider<DmOnboardingCubit>(
    create: (_) => _DmOnboardingProgressHeaderSeededCubit(seed),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const DmOnboardingProgressHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xLarge,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// Entry state: bar empty.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Step 1 · photo',
  size: _dmOnboardingProgressHeaderBox,
)
Widget dmOnboardingProgressHeaderStepPhoto() =>
    _dmOnboardingProgressHeaderHosted(
      'Step 1 of 3 — bar empty',
      const DmOnboardingState(),
    );

/// One step done: 1/3 filled.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Step 2 · address',
  size: _dmOnboardingProgressHeaderBox,
)
Widget dmOnboardingProgressHeaderStepAddress() =>
    _dmOnboardingProgressHeaderHosted(
      'Step 2 of 3 — one third',
      const DmOnboardingState(step: DmOnboardingStep.address),
    );

/// Last step: 2/3 filled.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Step 3 · service area',
  size: _dmOnboardingProgressHeaderBox,
)
Widget dmOnboardingProgressHeaderStepServiceArea() =>
    _dmOnboardingProgressHeaderHosted(
      'Step 3 of 3 — two thirds',
      const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        homeBase: DmOnboardingHomeBase(
          lat: 33.8938,
          lng: 35.5018,
          label: 'Beirut, Lebanon',
        ),
      ),
    );

/// Submitting state: bar unchanged.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Submitting on step 3',
  size: _dmOnboardingProgressHeaderBox,
)
Widget dmOnboardingProgressHeaderSubmitting() =>
    _dmOnboardingProgressHeaderHosted(
      'Submitting — bar unchanged',
      const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        homeBase: DmOnboardingHomeBase(
          lat: 33.8938,
          lng: 35.5018,
          label: 'Beirut, Lebanon',
        ),
        isSubmitting: true,
      ),
    );

/// Terminal state: full bar.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Submitted · full bar',
  size: _dmOnboardingProgressHeaderBox,
)
Widget dmOnboardingProgressHeaderSubmitted() =>
    _dmOnboardingProgressHeaderHosted(
      'Submitted — bar full',
      const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        isSubmitted: true,
      ),
    );
