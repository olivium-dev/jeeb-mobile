import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import 'dm_onboarding_address_field.dart';
import 'dm_onboarding_step_layout.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../application/dm_onboarding_state.dart';
import '../../domain/dm_onboarding_gateway.dart';
import '../dm_onboarding_screen.dart';

class DmOnboardingAddressStep extends StatelessWidget {
  const DmOnboardingAddressStep({super.key});

  static const Key rootKey = Key('dm-onboarding-address-step');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'dm_onboarding_address_root',
      container: true,
      child: DmOnboardingStepLayout(
        key: rootKey,
        continueIdentifier: 'dm_onboarding_continue',
        content: _AddressFields(specs: _specs(context)),
      ),
    );
  }

  List<DmAddressFieldSpec> _specs(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DmOnboardingCubit>();
    return [
      _state(l10n, cubit),
      _country(l10n, cubit),
      _street(l10n, cubit),
      _address(l10n, cubit),
    ];
  }

  DmAddressFieldSpec _state(AppLocalizations l10n, DmOnboardingCubit c) =>
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_state_field',
        label: l10n.dmOnboardingAddressStateLabel,
        hint: l10n.dmOnboardingAddressStateHint,
        onChanged: c.setStateField,
      );

  DmAddressFieldSpec _country(AppLocalizations l10n, DmOnboardingCubit c) =>
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_country_field',
        label: l10n.dmOnboardingAddressCountryLabel,
        hint: l10n.dmOnboardingAddressCountryHint,
        onChanged: c.setCountry,
      );

  DmAddressFieldSpec _street(AppLocalizations l10n, DmOnboardingCubit c) =>
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_street_field',
        label: l10n.dmOnboardingAddressStreetLabel,
        hint: l10n.dmOnboardingAddressStreetHint,
        onChanged: c.setStreet,
      );

  DmAddressFieldSpec _address(AppLocalizations l10n, DmOnboardingCubit c) =>
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_field',
        label: l10n.dmOnboardingAddressAddressLabel,
        hint: l10n.dmOnboardingAddressAddressHint,
        onChanged: c.setAddress,
      );
}

class _AddressFields extends StatelessWidget {
  const _AddressFields({required this.specs});

  final List<DmAddressFieldSpec> specs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final spec in specs)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
            child: DmOnboardingAddressField(spec: spec),
          ),
      ],
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
// Render tests: test/previews/jeeber_onboarding/dm_onboarding_address_step_preview_test.dart
// ===========================================================================
//
// The step takes no arguments at all: it reads four labels/hints from
// [AppLocalizations] and four setters from an ambient [DmOnboardingCubit], then
// hands the result to [DmOnboardingStepLayout]. Everything that can vary about
// it therefore comes from two places — the seeded cubit state and the box it is
// given — and each preview below varies exactly one of them.
//
// The cubit is built from production's own in-memory fakes
// ([StubPhotoPickerService], [FakeDmOnboardingGateway]) and is never asked to
// pick or submit, so these previews are network-free by construction rather
// than because [jeebPreviewHost] guards them. Fixture strings are the Beirut
// addresses already used by the add/edit-location previews and the
// saved-locations seam, so preview, seam and widget test describe one account.
//
// **Why every preview carries a `draft:` strip.**
// [_DmOnboardingAddressStepDraftEcho] is a fixture, not production chrome. It
// exists because the four fields render identically whether the cubit holds a
// full address or nothing at all — see the finding below — so without it two of
// these states would be the same picture, which is the "every preview shows the
// same widget" failure the preview docs warn about. It prints the draft the
// wizard would submit, the CTA mode, and the height the step was given: the
// three inputs that actually differ.
//
// **What the matrix exposes and this section cannot fix** (production code is
// out of scope for a preview):
//
// 1. **Typed text never comes back.** [DmOnboardingAddressField] builds an
//    `OmdsValidatedTextField` with a `placeholder` and an `onChanged` and no
//    controller (`dm_onboarding_address_field.dart`), so the field is
//    write-only: the value goes into the cubit and nothing ever puts it back.
//    Address → Continue → service-area → Back re-mounts this step with four
//    empty boxes over a cubit that still holds the address, and the submission
//    is built from the cubit — so a jeeber who re-types only two of the four
//    fields silently submits the old values for the other two. `Returned via
//    Back` is that state.
// 2. **The placeholder is twice the size of its own label, and truncated.**
//    The omds field defaults its text and hint to `headlineLarge` at `w700`
//    (32 pt bold) while [DmOnboardingAddressField] renders the label above it
//    in `bodyLarge` (16 pt) — so the example is shouted and the field name
//    whispered. At 390 pt wide the hint gets a 302 pt box on ONE line: measured
//    under `flutter test`, "Jasmine Tower, Apartment 12B" asks for 896 pt and
//    "برج الياسمين، شقة 12B" for 672 pt. The test's substitute font is roughly
//    1.5x wider per glyph than Inter, so read those as upper bounds — the
//    truncation itself survives the correction, and it happens at 1.0 text
//    scale, before the 200% rendering is reached.
// 3. **Continue is never gated.** The step passes no `enabled` to
//    [DmOnboardingStepLayout], so the CTA is tappable with all four fields
//    empty and `next()` advances the wizard — unlike the service-area step,
//    which requires a home base. Visible in `Fresh entry`.

/// Phone width and a full step's height: four labelled fields over a
/// bottom-pinned CTA is the whole screen body, not a card.
const Size _dmOnboardingAddressStepBox = Size(390, 720);

/// A small phone with the keyboard up — see [dmOnboardingAddressStepCompact].
const Size _dmOnboardingAddressStepCompactBox = Size(390, 460);

/// Room for the real app bar and progress bar above the step.
const Size _dmOnboardingAddressStepWizardBox = Size(390, 780);

/// The seam/preview account's address, split across this step's four fields.
const String _dmOnboardingAddressStepStateValue = 'Beirut Governorate';
const String _dmOnboardingAddressStepCountryValue = 'Lebanon';
const String _dmOnboardingAddressStepStreetValue = 'Rue Hamra';
const String _dmOnboardingAddressStepAddressValue = 'Sassine Square, Ashrafieh';

/// Step 2 as it is first entered: nothing typed yet.
const DmOnboardingState _dmOnboardingAddressStepEmptyDraft = DmOnboardingState(
  step: DmOnboardingStep.address,
);

/// Step 2 re-entered with the address already in the cubit.
const DmOnboardingState _dmOnboardingAddressStepTypedDraft = DmOnboardingState(
  step: DmOnboardingStep.address,
  state: _dmOnboardingAddressStepStateValue,
  country: _dmOnboardingAddressStepCountryValue,
  street: _dmOnboardingAddressStepStreetValue,
  address: _dmOnboardingAddressStepAddressValue,
);

/// The same draft while the service-area coverage probe is still in flight.
const DmOnboardingState _dmOnboardingAddressStepTypedDraftSubmitting =
    DmOnboardingState(
  step: DmOnboardingStep.address,
  state: _dmOnboardingAddressStepStateValue,
  country: _dmOnboardingAddressStepCountryValue,
  street: _dmOnboardingAddressStepStreetValue,
  address: _dmOnboardingAddressStepAddressValue,
  isSubmitting: true,
);

/// A [DmOnboardingCubit] parked on a fixed state. Both collaborators are
/// production's in-memory fakes and neither is ever called: no camera, no
/// gateway, no timers.
class _DmOnboardingAddressStepCubit extends DmOnboardingCubit {
  _DmOnboardingAddressStepCubit(DmOnboardingState seed)
      : super(
          pickerService: StubPhotoPickerService(),
          gateway: FakeDmOnboardingGateway(),
          initialStep: DmOnboardingStep.address,
        ) {
    emit(seed);
  }
}

/// Renders the draft the cubit is holding, the CTA mode, and the box the step
/// was given, as one diagnostic line.
///
/// NOT production chrome — the real screen shows [DmOnboardingProgressHeader]
/// in this slot. This exists because the step itself renders the same four
/// hint-filled boxes for every cubit state, so the line is the only on-screen
/// difference between "nothing typed" and "a full address in flight".
class _DmOnboardingAddressStepDraftEcho extends StatelessWidget {
  const _DmOnboardingAddressStepDraftEcho({required this.viewport});

  /// How the step below was framed: `full` (the whole canvas) or a fixed
  /// height, which is a real input to the layout under review.
  final String viewport;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      builder: (BuildContext context, DmOnboardingState state) => Container(
        width: double.infinity,
        color: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          _dmOnboardingAddressStepEchoLine(state, viewport),
          // Diagnostic, not copy: an ASCII/latin line reorders visually inside
          // an RTL paragraph, and these values are not translated.
          textDirection: TextDirection.ltr,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

String _dmOnboardingAddressStepEchoLine(
  DmOnboardingState state,
  String viewport,
) {
  final List<String> typed = <String>[
    state.state,
    state.country,
    state.street,
    state.address,
  ].where((String value) => value.isNotEmpty).toList();
  final String draft = typed.isEmpty ? '(empty)' : typed.join(' / ');
  final String cta = state.isSubmitting ? 'submitting' : 'idle';
  return 'draft: $draft · cta: $cta · viewport: $viewport';
}

/// A fixed-height window standing in for a short viewport, outlined so the
/// canvas shows where the simulated screen edge is.
class _DmOnboardingAddressStepViewport extends StatelessWidget {
  const _DmOnboardingAddressStepViewport({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: child,
      ),
    );
  }
}

/// Hosts the step the way [DmOnboardingScreen] does — an ambient cubit above it
/// and a bounded box around it, because [DmOnboardingStepLayout] pins its CTA
/// with an [Expanded] and cannot lay out unbounded.
Widget _dmOnboardingAddressStepHosted(
  DmOnboardingState seed, {
  double? viewportHeight,
}) {
  return BlocProvider<DmOnboardingCubit>(
    create: (_) => _DmOnboardingAddressStepCubit(seed),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DmOnboardingAddressStepDraftEcho(
          viewport:
              viewportHeight == null ? 'full' : '${viewportHeight.round()} pt',
        ),
        Expanded(
          child: viewportHeight == null
              ? const DmOnboardingAddressStep()
              : Align(
                  alignment: Alignment.topCenter,
                  child: _DmOnboardingAddressStepViewport(
                    height: viewportHeight,
                    child: const DmOnboardingAddressStep(),
                  ),
                ),
        ),
      ],
    ),
  );
}

/// Step 2 as a jeeber first meets it: four empty outlined boxes showing their
/// hints, over an ENABLED Continue.
///
/// The enabled CTA is the thing to look at, not the empty boxes. This step
/// passes no `enabled` flag, so Continue accepts a completely blank address and
/// `next()` advances to the service-area step — the address ends up in the
/// submission as four empty strings. Every other gate in this wizard (photo,
/// home base) blocks its own step.
///
/// It is also where the hint typography reads worst: each placeholder is
/// `headlineLarge` bold (32 pt) under a 16 pt label, and "Jasmine Tower,
/// Apartment 12B" does not fit the field at 390 pt even at 1.0 text scale.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Fresh entry · empty',
  size: _dmOnboardingAddressStepBox,
)
Widget dmOnboardingAddressStepEmpty() =>
    _dmOnboardingAddressStepHosted(_dmOnboardingAddressStepEmptyDraft);

/// The re-entry bug, made visible: the cubit holds a full address and the four
/// fields are blank.
///
/// Reached by Continue → service-area → Back (`dm_onboarding_screen.dart`
/// steps the wizard back through the cubit, which keeps its state). The fields
/// have no controller, so nothing restores what was typed; only the `draft:`
/// strip shows that the address is still there. Two consequences: the jeeber
/// believes the work was lost, and anything they DON'T re-type is submitted with
/// its old value.
///
/// If the fields ever render "Rue Hamra" here, restoration has been wired and
/// this preview has become the happy path.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Returned via Back · draft not restored',
  size: _dmOnboardingAddressStepBox,
)
Widget dmOnboardingAddressStepDraftNotRestored() =>
    _dmOnboardingAddressStepHosted(_dmOnboardingAddressStepTypedDraft);

/// Back-pressed while the service-area coverage probe is still running.
///
/// `isSubmitting` lives on the shared wizard state and the back button is not
/// gated on it (`_OnboardingBackButton._onBack`), so the service-area probe's
/// spinner lands on THIS step's Continue: the address step shows a spinner it is
/// not responsible for, blocks its own CTA, and offers no explanation. When the
/// probe resolves, the wizard jumps to KYC from under the jeeber.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Coverage probe in flight · CTA spins',
  size: _dmOnboardingAddressStepBox,
)
Widget dmOnboardingAddressStepCoverageInFlight() =>
    _dmOnboardingAddressStepHosted(
      _dmOnboardingAddressStepTypedDraftSubmitting,
    );

/// The layout ceiling: a short viewport, as on a small phone once the keyboard
/// is up.
///
/// [DmOnboardingStepLayout] gives the fields an [Expanded]
/// [SingleChildScrollView] and pins Continue below it, so the fields must scroll
/// while the CTA stays on screen and nothing overflows. This is the state where
/// that contract is load-bearing — at full height the four fields fit and the
/// scroll view is never exercised. It holds: measured at 320 pt of window and
/// 200% text, the stack scrolls and the CTA keeps its 48 pt with no overflow.
/// What it does NOT do is tell the jeeber there is more below — there is no
/// scroll affordance, and at 200% only the first field and a half are visible.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Compact viewport · CTA pinned',
  size: _dmOnboardingAddressStepCompactBox,
)
Widget dmOnboardingAddressStepCompact() => _dmOnboardingAddressStepHosted(
      _dmOnboardingAddressStepEmptyDraft,
      viewportHeight: 320,
    );

/// The step inside its real host, the only preview here that is not a bare
/// widget on a blank surface.
///
/// [DmOnboardingScreen] supplies the "Personal Details" app bar, the 2-of-3
/// progress bar and the page gutters, which is how the step is actually met and
/// the only way to judge whether the field stack sits right under the progress
/// bar. The injected cubit means the screen never touches DI or Dio (that
/// fallback only runs when no cubit is passed).
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'In the wizard · app bar + progress',
  size: _dmOnboardingAddressStepWizardBox,
)
Widget dmOnboardingAddressStepInWizard() => DmOnboardingScreen(
      cubit:
          _DmOnboardingAddressStepCubit(_dmOnboardingAddressStepTypedDraft),
      initialStep: DmOnboardingStep.address,
    );
