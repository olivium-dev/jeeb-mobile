import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../domain/dm_onboarding_gateway.dart';
import 'dm_onboarding_address_field.dart';
import 'dm_onboarding_photo_upload_card.dart';
import 'dm_onboarding_step_header.dart';

class DmOnboardingStepLayout extends StatelessWidget {
  const DmOnboardingStepLayout({
    super.key,
    required this.content,
    required this.continueIdentifier,
    this.enabled = true,
  });

  final Widget content;

  final String continueIdentifier;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _ScrollableContent(child: content)),
          _ContinueButton(
            identifier: continueIdentifier,
            enabled: enabled,
          ),
          const SizedBox(height: Spacing.large),
        ],
      ),
    );
  }
}

class _ScrollableContent extends StatelessWidget {
  const _ScrollableContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(top: Spacing.medium),
      child: child,
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.identifier, required this.enabled});

  final String identifier;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.isSubmitting != curr.isSubmitting,
      builder: (context, state) => Semantics(
        identifier: identifier,
        button: true,
        child: OmdsLoadingButton(
          text: l10n.dmOnboardingContinue,
          isLoading: state.isSubmitting,
          isEnabled: enabled && !state.isSubmitting,
          onTap: () => context.read<DmOnboardingCubit>().next(),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED.

/// Phone width; clears the 4:5 drop-area body at 1.0× (556 px of content plus
const Size _dmOnboardingStepLayoutPhotoBox = Size(390, 640);

/// Phone width; clears the four-field address body at 1.0× (432 + 68).
const Size _dmOnboardingStepLayoutFormBox = Size(390, 520);

/// Phone width; clears the service-area body at 1.0× (280 + 68, EN; AR is
const Size _dmOnboardingStepLayoutServiceAreaBox = Size(390, 360);

/// Deliberately short — a small phone with the keyboard up, or a fold in
const Size _dmOnboardingStepLayoutSqueezedBox = Size(390, 260);

/// The canonical QA id for the wizard CTA (65_W2_TEST_PLAN JM-038). All three
const String _dmOnboardingStepLayoutContinueId = 'dm_onboarding_continue';

/// Reused from `dm_onboarding_cubit_test.dart`: the home base its service-area
/// cases pin.
const DmOnboardingHomeBase _dmOnboardingStepLayoutBeirutBase =
    DmOnboardingHomeBase(
  lat: 33.89,
  lng: 35.50,
  label: 'Beirut',
);

class _DmOnboardingStepLayoutCubit extends DmOnboardingCubit {
  _DmOnboardingStepLayoutCubit(DmOnboardingState seed)
      : super(
          pickerService: StubPhotoPickerService(),
          gateway: FakeDmOnboardingGateway(),
          initialStep: seed.step,
        ) {
    emit(seed);
  }
}

Widget _dmOnboardingStepLayoutHosted(
  Widget content, {
  bool enabled = true,
  DmOnboardingState seed = const DmOnboardingState(),
}) {
  return BlocProvider<DmOnboardingCubit>(
    create: (_) => _DmOnboardingStepLayoutCubit(seed),
    child: DmOnboardingStepLayout(
      content: content,
      continueIdentifier: _dmOnboardingStepLayoutContinueId,
      enabled: enabled,
    ),
  );
}

class _DmOnboardingStepLayoutPhotoBody extends StatelessWidget {
  const _DmOnboardingStepLayoutPhotoBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DmOnboardingStepHeader(
          title: l10n.dmOnboardingPhotoUploadTitle,
          subtitle: l10n.dmOnboardingPhotoUploadSubtitle,
        ),
        const SizedBox(height: Spacing.xLarge),
        const DmOnboardingPhotoUploadCard(),
      ],
    );
  }
}

class _DmOnboardingStepLayoutAddressBody extends StatelessWidget {
  const _DmOnboardingStepLayoutAddressBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final DmOnboardingCubit cubit = context.read<DmOnboardingCubit>();
    final List<DmAddressFieldSpec> specs = <DmAddressFieldSpec>[
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_state_field',
        label: l10n.dmOnboardingAddressStateLabel,
        hint: l10n.dmOnboardingAddressStateHint,
        onChanged: cubit.setStateField,
      ),
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_country_field',
        label: l10n.dmOnboardingAddressCountryLabel,
        hint: l10n.dmOnboardingAddressCountryHint,
        onChanged: cubit.setCountry,
      ),
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_street_field',
        label: l10n.dmOnboardingAddressStreetLabel,
        hint: l10n.dmOnboardingAddressStreetHint,
        onChanged: cubit.setStreet,
      ),
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_field',
        label: l10n.dmOnboardingAddressAddressLabel,
        hint: l10n.dmOnboardingAddressAddressHint,
        onChanged: cubit.setAddress,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final DmAddressFieldSpec spec in specs)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
            child: DmOnboardingAddressField(spec: spec),
          ),
      ],
    );
  }
}

class _DmOnboardingStepLayoutServiceAreaBody extends StatelessWidget {
  const _DmOnboardingStepLayoutServiceAreaBody({this.homeBaseLabel});

  final String? homeBaseLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String? pinned = homeBaseLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DmOnboardingStepHeader(
          title: l10n.dmOnboardingServiceAreaHeading,
          subtitle: l10n.dmOnboardingServiceAreaSubtitle,
        ),
        const SizedBox(height: Spacing.xLarge),
        Text(
          l10n.dmOnboardingServiceAreaPrimaryLocationLabel,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: Spacing.small),
        // Geometry copied from `_HomeBaseMapPin` / `_HomeBaseMapContent`:
        ClipRRect(
          borderRadius: BorderRadius.circular(Sizes.small),
          child: Container(
            height: Sizes.elevenXLarge,
            width: double.infinity,
            alignment: Alignment.center,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  pinned == null ? Icons.map_outlined : Icons.location_on,
                  size: Sizes.threeXLarge,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(height: Spacing.xSmall),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: Spacing.medium,
                  ),
                  child: Text(
                    pinned ?? l10n.dmOnboardingServiceAreaMapPlaceholder,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Photo step · Continue gated',
  size: _dmOnboardingStepLayoutPhotoBox,
)
Widget dmOnboardingStepLayoutPhotoGated() => _dmOnboardingStepLayoutHosted(
      const _DmOnboardingStepLayoutPhotoBody(),
      enabled: false,
    );

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Address step · Continue live',
  size: _dmOnboardingStepLayoutFormBox,
)
Widget dmOnboardingStepLayoutAddressForm() => _dmOnboardingStepLayoutHosted(
      const _DmOnboardingStepLayoutAddressBody(),
    );

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Service area · gated, short viewport',
  size: _dmOnboardingStepLayoutSqueezedBox,
)
Widget dmOnboardingStepLayoutServiceAreaGated() =>
    _dmOnboardingStepLayoutHosted(
      const _DmOnboardingStepLayoutServiceAreaBody(),
      enabled: false,
    );

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Service area · home base pinned',
  size: _dmOnboardingStepLayoutServiceAreaBox,
)
Widget dmOnboardingStepLayoutServiceAreaPinned() =>
    _dmOnboardingStepLayoutHosted(
      const _DmOnboardingStepLayoutServiceAreaBody(homeBaseLabel: 'Beirut'),
      seed: const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        homeBase: _dmOnboardingStepLayoutBeirutBase,
      ),
    );

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Coverage check in flight',
  size: _dmOnboardingStepLayoutServiceAreaBox,
)
Widget dmOnboardingStepLayoutSubmitting() => _dmOnboardingStepLayoutHosted(
      const _DmOnboardingStepLayoutServiceAreaBody(homeBaseLabel: 'Beirut'),
      seed: const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        homeBase: _dmOnboardingStepLayoutBeirutBase,
        isSubmitting: true,
      ),
    );
