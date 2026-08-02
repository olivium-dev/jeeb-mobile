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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';

import '../../../../core/previews/jeeb_preview.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../domain/dm_onboarding_gateway.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/jeeber_onboarding/dm_onboarding_service_area_step_preview_test.dart
// ===========================================================================
//
// The step is a pure view over one [DmOnboardingState] field — `homeBase` —
// plus `isSubmitting` for the Continue spinner. Every state below is a real
// [DmOnboardingCubit] seeded through its own API (`setHomeBase`, `next`) and
// built on the in-memory [StubPhotoPickerService] + [FakeDmOnboardingGateway]
// that already ship in `lib/`, so these previews are network-free by
// construction rather than merely by the guard in [jeebPreviewHost]. The cubit
// is seated at [DmOnboardingStep.serviceArea] so the canvas Continue runs the
// *real* coverage path against the fake gateway instead of skipping a step.
//
// The fixtures mirror the ones already in `test/dm_onboarding_screen_test.dart`
// (a pinned base, a failing coverage probe) and the saved-address seam used by
// the saved-locations chip-row previews, so the canvas and the suites describe
// the same Beirut account.
//
// ## Why this widget needs a canvas
//
// Both of its containers are fixed boxes holding text that is not, and the
// widget tests that cover this step assert semantics identifiers, not
// geometry:
//
// * `_HomeBaseMapPin` is a hard 100 pt (`Sizes.elevenXLarge`) `ClipRRect`
//   around a 40 pt icon and a wrapping caption. It does not grow with the
//   user's text-size setting, so the accessibility ceiling clips it.
// * `_SelectLocationRowBody` is `Row([Icon, gap, label, Spacer, value,
//   chevron])` with the value in a bare `Text` — no `Flexible`, no `maxLines`,
//   no ellipsis. `Spacer` gives back slack; nothing absorbs excess, so a long
//   place name pushes the chevron off the trailing edge.
//
// ## Measured on this widget
//
// Layout errors per frame, at real phone width with the production Inter faces
// loaded (`test/support/load_test_fonts.dart`) — not the square test font, so
// these are device numbers. The render test beside this file pins the three
// that matter.
//
// | state                     | 390 pt · 1.0×       | 390 pt · 200 % text     |
// |---------------------------|---------------------|-------------------------|
// | No base pinned            | clean               | map **+28 pt** (AR +68) |
// | Base pinned · geocoded    | clean               | map +28, row **+181**   |
// | Stub label ("Location")   | clean               | clean                   |
// | Long geocoded label       | row **+105 pt**     | —                       |
//
// Two things that table gives away, both worth opening the canvas for.
//
// 1. **The only pinned state that survives 200 % text is the one-word stub
//    label that ships today.** Every real place name breaks the row there, and
//    the geocoded label already breaks it at 1.0× on a 320 pt phone (+17 pt) —
//    so the row is fine only while the feature is unfinished.
// 2. **The harness cannot see any of it.** `preview_test_harness.dart` pumps
//    an 800 × 600 viewport; the long-label state that overflows by 105 pt at
//    390 lays out clean at 800. Width is the variable, and only the canvas and
//    the pinned geometry tests set it to a phone.
//
// The `size:` boxes are a phone body — 390 × 640, a 390 × 844 device minus the
// app bar and the progress header the wizard screen keeps above this step.
// Anything shorter reviews a bottom-anchored layout the user never sees.

/// A phone body: this step pins its CTA to the bottom of an `Expanded`, so it
/// only reads correctly in a full-height box.
const Size _dmOnboardingServiceAreaStepBox = Size(390, 640);

/// The geocoded label this step is *designed* for, once the map-pin screen
/// returns a resolved place. Reuses the `has_saved_addresses` seam address from
/// `test/saved_locations_screen_test.dart` so one Beirut account runs through
/// the whole preview suite.
const DmOnboardingHomeBase _dmOnboardingServiceAreaStepGeocodedBase =
    DmOnboardingHomeBase(
  lat: 33.8869,
  lng: 35.5131,
  label: 'Sassine Square, Ashrafieh',
);

/// The longest label a Lebanese reverse-geocode plausibly returns — a mall
/// parking level. Same string as the long-chip fixture in the saved-locations
/// chip-row previews, which is where it was first found to break a row.
const DmOnboardingHomeBase _dmOnboardingServiceAreaStepLongLabelBase =
    DmOnboardingHomeBase(
  lat: 33.8938,
  lng: 35.5018,
  label: 'Beirut Souks — Parking Level B2, Weygand Street',
);

/// A gateway whose coverage probe never lands — holds the step in its in-flight
/// frame for as long as the canvas is open.
class _DmOnboardingServiceAreaStepPendingGateway
    implements DmOnboardingGateway {
  const _DmOnboardingServiceAreaStepPendingGateway();

  @override
  Future<void> submit(DmOnboardingSubmission submission) =>
      Completer<void>().future;
}

/// Builds the cubit the way the wizard screen does, minus the network.
///
/// [confirmCoverage] presses Continue for you: `next()` on the service-area
/// step runs the coverage probe, which is the only route to `isSubmitting` and
/// the only route to [DmOnboardingError.submitFailed].
DmOnboardingCubit _dmOnboardingServiceAreaStepCubit({
  DmOnboardingHomeBase? base,
  DmOnboardingGateway? gateway,
  bool confirmCoverage = false,
}) {
  final DmOnboardingCubit cubit = DmOnboardingCubit(
    pickerService: StubPhotoPickerService(),
    gateway: gateway ?? FakeDmOnboardingGateway(),
    initialStep: DmOnboardingStep.serviceArea,
  );
  if (base != null) cubit.setHomeBase(base);
  if (confirmCoverage) unawaited(cubit.next());
  return cubit;
}

/// Hosts the step under its own cubit, with a one-line fixture caption beneath.
///
/// The caption is preview-only chrome, and it is there for the render test: the
/// step prints the chosen place label TWICE — once as the map caption, once as
/// the selector-row value — so no fixture string in this section is unique in
/// the tree, and `expectedText` would have nothing to pin each state by. Same
/// trick the saved-locations chip-row previews use for their three blank
/// states.
///
/// The cubit is built inside `create` so every canvas card owns one, and
/// `BlocProvider` closes it when the card goes away.
Widget _dmOnboardingServiceAreaStepHosted(
  DmOnboardingCubit Function() create, {
  required String fixture,
}) {
  return BlocProvider<DmOnboardingCubit>(
    create: (_) => create(),
    child: Column(
      children: <Widget>[
        const Expanded(child: DmOnboardingServiceAreaStep()),
        _DmOnboardingServiceAreaStepCaption(fixture),
      ],
    ),
  );
}

class _DmOnboardingServiceAreaStepCaption extends StatelessWidget {
  const _DmOnboardingServiceAreaStepCaption(this.text);

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

/// The entry state, and the one every Jeeber sees first: nothing pinned.
///
/// This is the JM-038 AC2 gate — `hasHomeBase` is false, so Continue is dimmed
/// and the wizard cannot advance. Two things to read here that the widget tests
/// do not.
///
/// **The gate is a colour and nothing else.** `_ContinueButton` wraps the CTA in
/// `Semantics(identifier: 'dm_onboarding_continue', button: true)` and passes
/// `isEnabled: false` only to `OmdsLoadingButton`, which spends it on a
/// 60 %-alpha fill and a null `onTap`. Nothing sets `enabled:` on the node, so
/// the semantics tree says "Continue, button" with no disabled state — measured
/// in the preview test — and no copy anywhere on the step says a location is
/// required. A screen-reader user gets a button that silently does nothing.
///
/// **The map placeholder does not survive 200 % text.** The box is a hard 100 pt
/// under a `ClipRRect`, holding a 40 pt icon, an 8 pt gap and the wrapping hint
/// "Tap Location to set your home base". At 1.0× that is ~62 pt and fits; at
/// 200 % it overflows by 28 pt (68 pt in Arabic) and the hint is cut — the one
/// string that tells the user how to get past the gate.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'No base pinned · Continue disabled',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepUnpinned() =>
    _dmOnboardingServiceAreaStepHosted(
      _dmOnboardingServiceAreaStepCubit,
      fixture: 'fixture: no home base',
    );

/// A base pinned with a resolved place name — the state the design is drawn for.
///
/// `hasHomeBase` lights Continue, the map icon swaps `map_outlined` →
/// `location_on`, and the caption under the pin becomes the place name. The
/// same string then appears twice, under the pin and as the row value; that
/// redundancy is the design, not a duplicated widget.
///
/// **Read this one at 320 pt too, not just in the 390 pt box.** A 25-character
/// address is 178 pt of row value, and the row runs out at 320 pt — measured
/// +17 pt over, which puts the chevron off the trailing edge. At 200 % text it
/// is 181 pt over at 390 pt. Nothing truncates, because the value `Text` has no
/// `Flexible` and no `maxLines`; see [dmOnboardingServiceAreaStepLongLabel] for
/// the same failure at ordinary text size.
///
/// Also the only preview where the row value is a real address, so it is the
/// one to check the row's colour split in: label on `onSecondaryContainer`,
/// value on `onSurface`, two roles on one line, which in the AR RTL **dark**
/// rendering must still read as one row rather than two greys.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Base pinned · geocoded label',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepPinned() =>
    _dmOnboardingServiceAreaStepHosted(
      () => _dmOnboardingServiceAreaStepCubit(
        base: _dmOnboardingServiceAreaStepGeocodedBase,
      ),
      fixture: 'fixture: geocoded label',
    );

/// **What actually ships today.** The pinned label is the word "Location".
///
/// `_pickHomeBase` records `DmOnboardingHomeBase(lat: 0, lng: 0, label:
/// l10n.dmOnboardingServiceAreaLocationFieldLabel)` on BOTH paths — after the
/// `capture-location` screen pops, and in the no-router fallback — because no
/// reverse geocode is wired yet. So the row reads "Location … Location", the
/// map caption reads "Location", and the coordinates are (0, 0), a point in the
/// Gulf of Guinea. Tapping the row in the canvas reproduces it live: a preview
/// has no `GoRouter` above it, so the fallback branch is the one that runs.
///
/// It is also, by accident, the only pinned state that survives 200 % text —
/// one short word is the only value this row can hold at the accessibility
/// ceiling. The layout is passing because the feature is unfinished.
///
/// Seeded through [AppLocalizations] rather than a hardcoded 'Location' so the
/// AR RTL rendering shows what an Arabic Jeeber actually gets — "الموقع" beside
/// "الموقع" — instead of an English string that would hide the repetition.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Pinned by the map screen · stub label',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepStubLabel() => Builder(
      builder: (BuildContext context) {
        final String label = AppLocalizations.of(context)
            .dmOnboardingServiceAreaLocationFieldLabel;
        return _dmOnboardingServiceAreaStepHosted(
          () => _dmOnboardingServiceAreaStepCubit(
            base: DmOnboardingHomeBase(lat: 0, lng: 0, label: label),
          ),
          fixture: 'fixture: stub base recorded on pop',
        );
      },
    );

/// The layout ceiling: a full reverse-geocoded place name, at ordinary text
/// size.
///
/// Measured +105 pt over the row at 390 pt — the striped overflow bar, with the
/// chevron pushed past the trailing edge. `Spacer` can only give back the slack
/// it holds; once the value is wider than that there is nothing left to give,
/// and the bare `Text` has no ellipsis to fall back on.
///
/// Read the map caption below the pin while you are here: it is centred, wraps
/// freely, and looks perfectly healthy with the same string. A reviewer
/// checking the pin alone would pass this state.
///
/// The 800 pt harness viewport lays this out clean, which is why the render
/// test measures it at a phone width instead.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Long geocoded label · row overflow',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepLongLabel() =>
    _dmOnboardingServiceAreaStepHosted(
      () => _dmOnboardingServiceAreaStepCubit(
        base: _dmOnboardingServiceAreaStepLongLabelBase,
      ),
      fixture: 'fixture: long geocoded label',
    );

/// Continue tapped: the coverage probe (`find-jeebers` against the home base)
/// is in flight.
///
/// `OmdsLoadingButton` swaps its label for an indeterminate spinner and drops
/// `onTap`, which is the double-submit guard. Check the CTA keeps its 48 pt
/// height across the swap — it is animated, so a height change reads as a jump
/// — and check the spinner is visible at all: it inherits `onPrimary` against
/// the same fill dimmed to 60 %, the contrast pairing already flagged on
/// `ConfirmDeliveryActionSheet`.
///
/// Note what does NOT change: the map, the row and the chevron stay live and
/// tappable throughout, so a Jeeber can re-pin the base while the check for the
/// previous one is still running.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Checking coverage · CTA spinner',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepCheckingCoverage() =>
    _dmOnboardingServiceAreaStepHosted(
      () => _dmOnboardingServiceAreaStepCubit(
        base: _dmOnboardingServiceAreaStepGeocodedBase,
        gateway: const _DmOnboardingServiceAreaStepPendingGateway(),
        confirmCoverage: true,
      ),
      fixture: 'fixture: coverage probe never lands',
    );

/// The coverage probe failed (JEBV4-13 P1-5) — and this step shows nothing.
///
/// The cubit emits `DmOnboardingError.submitFailed`, but its only listener is
/// `DmOnboardingScreen`, which raises a `SnackBar` and acknowledges the error.
/// The step itself is identical to [dmOnboardingServiceAreaStepPinned]: spinner
/// gone, Continue live again, nothing saying the attempt failed. Put the two
/// cards side by side in the canvas — if you can tell them apart, an error
/// surface has been added since this was written.
///
/// That is the state to hold in mind when reviewing this step in isolation: it
/// is not self-sufficient, and lifting it out of the wizard screen — into a
/// sheet, into a different host — silently loses its only failure feedback.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Coverage check failed · no in-step surface',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepCoverageFailed() =>
    _dmOnboardingServiceAreaStepHosted(
      () => _dmOnboardingServiceAreaStepCubit(
        base: _dmOnboardingServiceAreaStepGeocodedBase,
        gateway: FakeDmOnboardingGateway(shouldFail: true),
        confirmCoverage: true,
      ),
      fixture: 'fixture: coverage probe throws',
    );
