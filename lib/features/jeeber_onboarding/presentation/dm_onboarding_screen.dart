import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:dio/dio.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/dm_onboarding_cubit.dart';
import '../application/dm_onboarding_state.dart';
import '../data/dio_dm_onboarding_gateway.dart';
import '../domain/dm_onboarding_gateway.dart';
import 'widgets/dm_onboarding_address_step.dart';
import 'widgets/dm_onboarding_photo_step.dart';
import 'widgets/dm_onboarding_progress_header.dart';
import 'widgets/dm_onboarding_service_area_step.dart';

class DmOnboardingScreen extends StatelessWidget {
  const DmOnboardingScreen({
    super.key,
    this.cubit,
    this.onCompleted,
    this.initialStep = DmOnboardingStep.photo,
  });

  final DmOnboardingCubit? cubit;

  final VoidCallback? onCompleted;

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
        gateway: _resolveGateway(),
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

  DmOnboardingGateway _resolveGateway() {
    if (sl.isRegistered<DmOnboardingGateway>()) {
      return sl<DmOnboardingGateway>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioDmOnboardingGateway(sl<Dio>());
    }
    return FakeDmOnboardingGateway();
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<DmOnboardingCubit, DmOnboardingState>(
          listenWhen: (prev, curr) => !prev.coverageReady && curr.coverageReady,
          listener: _onCoverageReady,
        ),
        BlocListener<DmOnboardingCubit, DmOnboardingState>(
          listenWhen: (prev, curr) =>
              curr.error != null && prev.error != curr.error,
          listener: _onError,
        ),
      ],
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

  void _onCoverageReady(BuildContext context, DmOnboardingState _) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.goNamed('kyc-status');
      return;
    }
    onCompleted?.call();
  }

  void _onError(BuildContext context, DmOnboardingState state) {
    final l10n = AppLocalizations.of(context);
    final message = switch (state.error) {
      DmOnboardingError.submitFailed => l10n.dmOnboardingCoverageCheckFailed,
      DmOnboardingError.photoPickFailed => l10n.dmOnboardingPhotoPickFailed,
      null => null,
    };
    if (message != null) {
      showOmdsErrorSnackbar(context, message: message);
    }
    context.read<DmOnboardingCubit>().acknowledgeError();
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
    return Semantics(
      identifier: 'dm_onboarding_back',
      button: true,
      child: IconButton(
        icon: const BackButtonIcon(),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => _onBack(context),
      ),
    );
  }

  void _onBack(BuildContext context) {
    if (canGoBack) {
      context.read<DmOnboardingCubit>().back();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
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
