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

  /// Whether the wizard has a previous step to fall back to. `false` on the
  /// first (photo) step, where Back must leave the wizard entirely.
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // JM-039: canonical wizard back id (one id across every step; only one
      // step is mounted at a time, so QA can assert/tap it unambiguously).
      identifier: 'dm_onboarding_back',
      button: true,
      child: IconButton(
        icon: const BackButtonIcon(),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => _onBack(context),
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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/jeeber_onboarding/dm_onboarding_screen_preview_test.dart
// ===========================================================================
//
// [DmOnboardingScreen] is the wizard HOST: the app bar whose title swaps per
// step, the shared back button, the progress bar, and — the part that exists
// nowhere else — the two [BlocListener]s that turn the cubit's one-shot errors
// into a SnackBar and its `coverageReady` edge into a route change. The three
// steps have their own preview sections; these previews are for what only the
// host can show.
//
// The fixtures are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/dm_onboarding_screen_fixtures.dart`, shared
// with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_04_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". Every one of them is a [DmOnboardingCubit] built on
// `StubPhotoPickerService` + an in-memory gateway, so these previews are
// network-free by construction; the `CatalogNetworkGuard` in [jeebPreviewHost]
// is a net, not the plan. Handing the screen an explicit `cubit:` is also what
// keeps it off GetIt — with a null cubit `_resolveGateway()` reaches for
// `sl<DmOnboardingGateway>()` and then for a `DioDmOnboardingGateway` around
// the live `sl<Dio>()`.
//
// Four things about this harness are worth knowing before editing it.
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest, exactly as they do in the Screen Catalog — and that nesting
//    moves the one thing these previews exist for. `ScaffoldMessenger` presents
//    a SnackBar in the ROOT Scaffold of a nested set only
//    (`ScaffoldMessengerState._isRoot`), so in the canvas the two error states
//    below paint their message across the HOST, outside the phone frame, at a
//    position it can never occupy on a device. Read the copy from these cards,
//    never the placement; the render test measures the toast band and
//    translates it onto the frame to make the device claim.
//  * **The frame is pinned in the TREE, not just in `size:`.** The `size:` on
//    [JeebPreview] boxes the canvas; [_DmOnboardingScreenHost] pins the same
//    width in the widget tree so the render tests measure a phone instead of
//    the 800 x 600 test surface. Height is pinned too, but that surface is
//    600 pt, so a box asking for 844 is enforced down to what the host has;
//    the COMPACT box (320 x 568) fits and is therefore exact.
//  * **The cubit is owned, not borrowed.** `DmOnboardingScreen(cubit: …)`
//    wraps a provided cubit in `BlocProvider.value`, which does NOT close it.
//    [_DmOnboardingScreenHost] is a `StatefulWidget` so each card builds its
//    cubit once in `initState` — before the wizard's error listener mounts,
//    which is what lets the two error states land — and closes it in
//    `dispose`.
//  * **Tapping is mostly not previewing.** There is no [GoRouter] above a
//    preview card, so Back on step 1 (`context.canPop()`) throws, and a
//    successful Continue on step 3 falls through to a null `onCompleted` and
//    does nothing. Back on steps 2 and 3 is real — it is a cubit call — and
//    the service-area selector row really does pin its stub base.
//
// ## What these previews surface in the screen
//
//  * **The failure message covers the control it is asking you to press
//    again.** `showOmdsErrorSnackbar` raises a FLOATING SnackBar, bottom-
//    anchored to the Scaffold presenting it; `DmOnboardingStepLayout` pins
//    Continue to the bottom of that same Scaffold. The render test measures
//    the toast band, translates it onto the phone frame (see the nesting note
//    above) and asserts the two overlap — so for the toast's four seconds
//    "Couldn't check coverage for this area. Please try again." sits on top of
//    the only way to try again.
//  * **After those four seconds nothing is left.** The error is one-shot: the
//    listener calls `acknowledgeError()` immediately, the SnackBar times out,
//    and the wizard is pixel-identical to a step that was never submitted.
//    Put [dmOnboardingScreenCoverageFailed] beside
//    [dmOnboardingScreenServiceArea] once the toast has gone and there is no
//    difference to see.
//  * **`coverageReady` is a one-shot edge with no reset.** The listener fires
//    on `!prev.coverageReady && curr.coverageReady`, nothing ever clears the
//    flag, and `_confirmCoverage` re-emits `coverageReady: true` on every
//    later Continue. So if the FIRST hand-off does not navigate — no router
//    above the screen, which is precisely the catalog/canvas case, and also
//    the cold-deep-link case whenever `onCompleted` is null — the last step is
//    dead for the rest of the visit: the probe re-runs, the flag is already
//    true, and the listener never fires again.

/// The phone this wizard is designed against (Figma 56591:5323 / 4109 / 5337).
const Size _dmOnboardingScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _dmOnboardingScreenCompactBox = Size(320, 568);

/// Hosts the wizard at a device-sized frame, under a cubit it owns, with a
/// one-line fixture caption beneath.
///
/// The caption is preview-only chrome and it is there for the render test: the
/// wizard's copy is fixed per step, and four of the seven states below are the
/// SAME step differing only in `isSubmitting` / `error` / the pinned label —
/// which the step prints twice, so it is not unique in the tree either. Without
/// a caption `expectedText` would have nothing to pin them by. Same device the
/// step-level previews in this feature use.
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
    // have their failure microtask land AFTER `_Scaffold`'s listeners exist.
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
///
/// The whole wizard chrome in one card: the centred "Image" app-bar title, the
/// shared `dm_onboarding_back` arrow, the progress bar, and a Continue gated on
/// a photo nobody has taken yet.
///
/// This is the one the matrix is for, and it is the app bar and the bar under
/// it that pay for it — the title is centred against a leading-only actions
/// row, and the progress bar draws its fill on a raw `Canvas` from
/// `Offset(0, …)`, which does not flip for text direction. In the AR RTL
/// rendering the bar therefore fills from the LEFT, i.e. it EMPTIES as the
/// Jeeber advances, while the `EdgeInsetsDirectional` padding around it mirrors
/// correctly. Step 1 also reports zero completed steps, so the bar here is
/// blank in both directions.
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
///
/// The only step whose Continue is NOT gated: `DmOnboardingAddressStep` passes
/// no `enabled`, so it defaults to true and every field can be left blank. The
/// four values still go to the gateway as the submission's `state`, `country`,
/// `street` and `address`. Nothing on the step says they are optional either,
/// so this card is the whole of what the user is told.
///
/// Read it beside step 1: the two steps are indistinguishable except for the
/// title and the bar, and only one of them will let you past.
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
///
/// The empty map reads as an intentional empty map ("Tap Location to set your
/// home base") rather than a broken pin, and Continue is dimmed until a base is
/// recorded. This is the state the two service-area error previews below have
/// to be compared against — it is what they both decay back to.
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
///
/// `OmdsLoadingButton` swaps its label for an indeterminate spinner and drops
/// `onTap`, which is the double-submit guard. Note what does NOT change: the
/// app bar's back arrow, the map and the selector row all stay live, so a
/// Jeeber can step back out of the wizard — or re-pin the base — while the
/// check for the previous one is still running, and nothing cancels it.
///
/// Its render test cannot use `pumpAndSettle`: an indeterminate
/// `CircularProgressIndicator` never settles. See the dedicated pump-once
/// group in the test file.
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
///
/// Before the fix this emitted a one-shot [DmOnboardingError.submitFailed] with
/// NO listener anywhere in the tree, and the wizard simply sat there. The
/// listener in [_Scaffold] is the fix, and this card is the only place in the
/// repo it can be SEEN — `dmOnboardingServiceAreaStepCoverageFailed` renders
/// the same cubit state with no host above it and shows nothing at all.
///
/// Two things to read here rather than in the step's own previews:
///
///  * the copy. The toast's PLACEMENT in this card is a host artifact — the
///    nested preview Scaffold presents it, so it paints outside the phone
///    frame. On a device it is bottom-anchored to the wizard's own Scaffold,
///    which is where `DmOnboardingStepLayout` has already pinned Continue; the
///    render test measures that band and asserts the overlap;
///  * it is all there is. `acknowledgeError()` runs immediately, so after four
///    seconds this card is [dmOnboardingScreenServiceArea] with a base pinned —
///    a failed submission and a never-attempted one look identical.
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
///
/// `DmOnboardingError.photoPickFailed` is raised for a denied camera
/// permission (and for any hardware/IO failure); the host answers with
/// "Couldn't use that photo. Please try again." — copy that describes a bad
/// photo, not a permission the OS will never re-prompt for, and which offers no
/// route to Settings. The user is left on a step whose Continue is still gated
/// on the photo they cannot take.
///
/// A user CANCELLING the camera is deliberately not previewed: the cubit
/// swallows `PhotoPickFailure.cancelled`, so it produces no state and no toast.
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
///
/// The label is printed twice — centred under the map pin, where it wraps and
/// looks healthy, and as the selector row's value, where `_SelectLocationRowBody`
/// puts it in a bare `Text` with no `Flexible`, no `maxLines` and no ellipsis.
/// At 320 pt the row runs out and the chevron is pushed off the trailing edge;
/// the step's own previews measure it at +105 pt on a 390 pt phone.
///
/// Read the AR RTL and 200% renderings rather than the English one: the English
/// stays plausible long after the other two have stopped fitting, and at 200%
/// the map placeholder clips its own caption inside a hard 100 pt `ClipRRect`.
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
