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
            // ~16px between labelled groups keeps the board's airy rhythm; 12
            // read as one dense block once the labels went to 12/w600.
            padding: const EdgeInsetsDirectional.only(bottom: Spacing.medium),
            child: DmOnboardingAddressField(spec: spec),
          ),
      ],
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, not shipped. Previews are tree-shaken out of release builds.

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

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Fresh entry · empty',
  size: _dmOnboardingAddressStepBox,
)
Widget dmOnboardingAddressStepEmpty() =>
    _dmOnboardingAddressStepHosted(_dmOnboardingAddressStepEmptyDraft);

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Returned via Back · draft not restored',
  size: _dmOnboardingAddressStepBox,
)
Widget dmOnboardingAddressStepDraftNotRestored() =>
    _dmOnboardingAddressStepHosted(_dmOnboardingAddressStepTypedDraft);

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Coverage probe in flight · CTA spins',
  size: _dmOnboardingAddressStepBox,
)
Widget dmOnboardingAddressStepCoverageInFlight() =>
    _dmOnboardingAddressStepHosted(
      _dmOnboardingAddressStepTypedDraftSubmitting,
    );

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Compact viewport · CTA pinned',
  size: _dmOnboardingAddressStepCompactBox,
)
Widget dmOnboardingAddressStepCompact() => _dmOnboardingAddressStepHosted(
      _dmOnboardingAddressStepEmptyDraft,
      viewportHeight: 320,
    );

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
