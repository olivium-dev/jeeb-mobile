import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/dm_onboarding_cubit.dart';
import '../application/dm_onboarding_state.dart';
import '../domain/dm_onboarding_gateway.dart';
import 'widgets/dm_onboarding_address_step.dart';
import 'widgets/dm_onboarding_photo_step.dart';
import 'widgets/dm_onboarding_progress_header.dart';
import 'widgets/dm_onboarding_service_area_step.dart';

/// Delivery-man onboarding wizard host (Figma flow 56591:5323 → 56591:4109 →
/// 56591:5337). Three pushed full-screen steps share one [OMDSAppBar] (the
/// title swaps per step) and one progress bar; there is no bottom nav.
///
/// Builds a single [DmOnboardingCubit] per visit, falling back to in-process
/// fakes when GetIt hasn't been configured (cold deep link / boot tests) so the
/// screen always renders.
class DmOnboardingScreen extends StatelessWidget {
  const DmOnboardingScreen({
    super.key,
    this.cubit,
    this.onCompleted,
    this.initialStep = DmOnboardingStep.photo,
  });

  /// Optional override — production builds a fresh cubit; widget tests inject
  /// one with controlled gateway behaviour.
  final DmOnboardingCubit? cubit;

  /// Invoked once the final step submits successfully so the host can pop or
  /// route on to KYC status.
  final VoidCallback? onCompleted;

  /// Step to start on. Production enters at [DmOnboardingStep.photo]; the
  /// deep-link / dev-seam `step` query param lets a capture land directly on a
  /// later step.
  final DmOnboardingStep initialStep;

  static const Key rootKey = Key('dm-onboarding-root');

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<DmOnboardingCubit>.value(
        value: provided,
        child: _Scaffold(onCompleted: onCompleted),
      );
    }
    return BlocProvider<DmOnboardingCubit>(
      create: (_) => DmOnboardingCubit(
        pickerService: _resolvePicker(),
        gateway: FakeDmOnboardingGateway(),
        initialStep: initialStep,
      ),
      child: _Scaffold(onCompleted: onCompleted),
    );
  }

  PhotoPickerService _resolvePicker() {
    if (sl.isRegistered<PhotoPickerService>()) {
      return sl<PhotoPickerService>();
    }
    return StubPhotoPickerService();
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return BlocListener<DmOnboardingCubit, DmOnboardingState>(
      listenWhen: (prev, curr) => !prev.isSubmitted && curr.isSubmitted,
      listener: (_, _) => onCompleted?.call(),
      child: const Scaffold(
        key: DmOnboardingScreen.rootKey,
        appBar: _OnboardingAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              DmOnboardingProgressHeader(),
              Expanded(child: _OnboardingBody()),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _OnboardingAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.step != curr.step,
      builder: (context, state) => OMDSAppBar(
        title: _titleFor(l10n, state.step),
        centerTitle: true,
        leading: _OnboardingBackButton(canGoBack: state.step.index > 0),
      ),
    );
  }

  String _titleFor(AppLocalizations l10n, DmOnboardingStep step) {
    switch (step) {
      case DmOnboardingStep.photo:
        return l10n.dmOnboardingPhotoStepTitle;
      case DmOnboardingStep.address:
        return l10n.dmOnboardingPersonalDetailsTitle;
      case DmOnboardingStep.serviceArea:
        return l10n.dmOnboardingServiceAreaTitle;
    }
  }
}

class _OnboardingBackButton extends StatelessWidget {
  const _OnboardingBackButton({required this.canGoBack});

  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'dm_onboarding_back_button',
      button: true,
      child: IconButton(
        icon: const BackButtonIcon(),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => _onBack(context, l10n),
      ),
    );
  }

  void _onBack(BuildContext context, AppLocalizations l10n) {
    if (canGoBack) {
      context.read<DmOnboardingCubit>().back();
      return;
    }
    Navigator.of(context).maybePop();
  }
}

class _OnboardingBody extends StatelessWidget {
  const _OnboardingBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.step != curr.step,
      builder: (context, state) => _stepFor(state.step),
    );
  }

  Widget _stepFor(DmOnboardingStep step) {
    switch (step) {
      case DmOnboardingStep.photo:
        return const DmOnboardingPhotoStep();
      case DmOnboardingStep.address:
        return const DmOnboardingAddressStep();
      case DmOnboardingStep.serviceArea:
        return const DmOnboardingServiceAreaStep();
    }
  }
}
