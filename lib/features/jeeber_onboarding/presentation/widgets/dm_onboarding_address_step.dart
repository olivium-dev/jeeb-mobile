import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import 'dm_onboarding_address_field.dart';
import 'dm_onboarding_step_layout.dart';

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
