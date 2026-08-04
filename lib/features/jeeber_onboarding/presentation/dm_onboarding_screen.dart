import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:dio/dio.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
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

/// Delivery-man onboarding wizard host (Figma flow 56591:5323 → 56591:4109 →
/// 56591:5337). Three pushed full-screen steps share one in-body [JeebTopBar]
/// (the title swaps per step) and one progress bar; there is no bottom nav.
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

  /// Fallback completion hook used only when no [GoRouter] is in the tree
  /// (cold deep link / widget tests). In the app the service-area Continue
  /// chains directly to KYC identity (JM-038 AC4); this is never invoked there.
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

  /// The service-area Continue probes matching find-jeebers (JM-038); use the
  /// real Dio gateway when DI is configured, falling back to the in-memory fake
  /// on cold deep links / boot tests so the wizard still renders + advances.
  DmOnboardingGateway _resolveGateway() {
    // S6 Stream C: prefer the DI-registered gateway (the canonical release
    // default).
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
          // Service-area coverage confirmed → chain to KYC identity (JM-038 AC4).
          listenWhen: (prev, curr) => !prev.coverageReady && curr.coverageReady,
          listener: _onCoverageReady,
        ),
        // JEBV4-13 P1-5: the coverage probe (and the shared photo-pick path)
        // previously emitted a one-shot DmOnboardingError with NO listener
        // anywhere in the tree, so a 404/failure left the wizard stuck with
        // zero feedback. Surface it honestly, then acknowledge so it isn't
        // replayed on the next rebuild.
        BlocListener<DmOnboardingCubit, DmOnboardingState>(
          listenWhen: (prev, curr) =>
              curr.error != null && prev.error != curr.error,
          listener: _onError,
        ),
      ],
      child: const Scaffold(
        key: DmOnboardingScreen.rootKey,
        backgroundColor: Colors.transparent,
        // MIDNIGHT (R23 carry): the KYC funnel is board-still — base wash plus
        // one quiet orange glow at the top end, no rings, no wash, no ticker.
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.topEnd,
          animateDecor: false,
          child: SafeArea(
            child: Column(
              children: [
                _OnboardingTopBar(),
                DmOnboardingProgressHeader(),
                Expanded(child: _OnboardingBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Routes service-area → KYC identity (JM-038 AC4 → JM-040). The KYC wizard
  /// lives at the `kyc-status` route (`/profile/kyc`, blueprint `kyc-identity`,
  /// per 21_NAV_PLAN). `goNamed` replaces the wizard so KYC owns Back. When no
  /// GoRouter is present (cold deep link / widget test) we fall back to the
  /// injected [onCompleted] hook so the host still resolves.
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

/// The wizard header: the kit's Ø40 tonal back circle + the start-aligned
/// `jeebText.h2` step title, on the board's 24px gutter (R23's bar exactly).
class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.step != curr.step,
      builder: (context, state) => JeebTopBar.back(
        // JM-039: canonical wizard back id (one id across every step; only one
        // step is mounted at a time, so QA can assert/tap it unambiguously).
        identifier: 'dm_onboarding_back',
        title: l10n.dmOnboardingWizardTitle,
        onLeadingPressed: () => _onBack(
          context,
          canGoBack: state.step.index > 0,
        ),
      ),
    );
  }

  /// JM-039 AC1: from the first (photo) step, Back returns to the
  /// `delivery-register-prompt` the wizard was pushed from (DELIVERY tab) —
  /// deterministically `pop()`-ing the pushed `/jeeber/onboarding` route rather
  /// than firing a non-deterministic `maybePop()`. On a later step it steps the
  /// wizard back one (photo ← address ← service-area) via the cubit. The
  /// `go('/')` branch only fires on a cold deep-link entry where nothing was
  /// pushed (no register-prompt below); it routes to the first-run/shell gate so
  /// Back never strands the user on a rootless wizard.
  ///
  /// [canGoBack] is false on the first (photo) step, where Back must leave the
  /// wizard entirely.
  void _onBack(BuildContext context, {required bool canGoBack}) {
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
