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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/dm_onboarding_screen_fixtures.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone this wizard is designed against (Figma 56591:5323 / 4109 / 5337).
const Size _dmOnboardingScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _dmOnboardingScreenCompactBox = Size(320, 568);

/// Hosts the wizard at a device-sized frame, under a cubit it owns, with a
/// one-line fixture caption beneath.
/// The caption is preview-only chrome and it is there for the render test: the
class _DmOnboardingScreenHost extends StatefulWidget {
  const _DmOnboardingScreenHost({
    required this.create,
    required this.fixture,
    this.box = _dmOnboardingScreenPhoneBox,
  });

  /// Builds the cubit for this card. Called once, in `initState`.
  final DmOnboardingCubit Function() create;

  /// The caption under the frame — the one string unique to this state.
  final String fixture;

  /// Device frame pinned in the tree, not just requested from the canvas.
  final Size box;

  @override
  State<_DmOnboardingScreenHost> createState() => _DmOnboardingScreenHostState();
}

class _DmOnboardingScreenHostState extends State<_DmOnboardingScreenHost> {
  late final DmOnboardingCubit _cubit;

  @override
  void initState() {
    super.initState();
    // Before the subtree — so the fixtures that press Continue / the camera
    _cubit = widget.create();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: widget.box.width,
        height: widget.box.height,
        child: Column(
          children: <Widget>[
            Expanded(child: DmOnboardingScreen(cubit: _cubit)),
            _DmOnboardingScreenCaption(widget.fixture),
          ],
        ),
      ),
    );
  }
}

class _DmOnboardingScreenCaption extends StatelessWidget {
  const _DmOnboardingScreenCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

/// Step 1 of 3 — the entry state, and the first thing a Jeeber who tapped
/// "become a Jeeber" sees.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Step 1 · Photo · nothing chosen',
  size: _dmOnboardingScreenPhoneBox,
  matrix: true,
)
Widget dmOnboardingScreenPhotoStep() => const _DmOnboardingScreenHost(
      create: DmOnboardingScreenPreviewFixtures.photoStep,
      fixture: 'fixture: step 1, no photo chosen',
    );

/// Step 2 of 3 — "Personal Details": four empty labelled fields over the same
/// pinned Continue.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Step 2 · Personal details · empty',
  size: _dmOnboardingScreenPhoneBox,
)
Widget dmOnboardingScreenAddressStep() => const _DmOnboardingScreenHost(
      create: DmOnboardingScreenPreviewFixtures.addressStep,
      fixture: 'fixture: step 2, empty address',
    );

/// Step 3 of 3 — "Service Area", nothing pinned. The JM-038 AC2 gate.
/// The empty map reads as an intentional empty map ("Tap Location to set your
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Step 3 · Service area · no home base',
  size: _dmOnboardingScreenPhoneBox,
)
Widget dmOnboardingScreenServiceArea() => const _DmOnboardingScreenHost(
      create: DmOnboardingScreenPreviewFixtures.serviceAreaStep,
      fixture: 'fixture: step 3, no home base',
    );

/// Continue tapped on the last step: the coverage probe (`find-jeebers`
/// against the pinned home base) is in flight and never lands.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Step 3 · Checking coverage',
  size: _dmOnboardingScreenPhoneBox,
)
Widget dmOnboardingScreenCheckingCoverage() => const _DmOnboardingScreenHost(
      create: DmOnboardingScreenPreviewFixtures.checkingCoverage,
      fixture: 'fixture: step 3, coverage probe never lands',
    );

/// The JEBV4-13 P1-5 regression, made visible: the coverage probe failed.
/// Before the fix this emitted a one-shot [DmOnboardingError.submitFailed] with
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Step 3 · Coverage check failed',
  size: _dmOnboardingScreenPhoneBox,
)
Widget dmOnboardingScreenCoverageFailed() => const _DmOnboardingScreenHost(
      create: DmOnboardingScreenPreviewFixtures.coverageFailed,
      fixture: 'fixture: step 3, coverage probe throws',
    );

/// The other half of the same contract: the camera pick failed on step 1.
/// `DmOnboardingError.photoPickFailed` is raised for a denied camera
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Step 1 · Camera permission denied',
  size: _dmOnboardingScreenPhoneBox,
)
Widget dmOnboardingScreenPhotoPickDenied() => const _DmOnboardingScreenHost(
      create: DmOnboardingScreenPreviewFixtures.photoPickDenied,
      fixture: 'fixture: step 1, camera permission denied',
    );

/// The layout ceiling, on the narrowest phone the app supports: a full
/// reverse-geocoded place name in the wizard's own frame.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Longest content · compact 320',
  size: _dmOnboardingScreenCompactBox,
  matrix: true,
)
Widget dmOnboardingScreenLongestContent() => const _DmOnboardingScreenHost(
      create: DmOnboardingScreenPreviewFixtures.longestContent,
      fixture: 'fixture: step 3, longest geocoded label',
      box: _dmOnboardingScreenCompactBox,
    );
