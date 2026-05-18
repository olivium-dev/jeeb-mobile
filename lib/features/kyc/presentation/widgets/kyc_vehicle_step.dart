import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/kyc_wizard_cubit.dart';
import '../../application/kyc_wizard_state.dart';
import '../../domain/vehicle_type.dart';

/// Step 3: vehicle type + registration. Tapping submit kicks off
/// [KycWizardCubit.submit] which advances to the status screen.
///
/// Vehicle types are rendered as a 2-column grid of selection cards (T-design-006
/// AC: "Vehicle type selection grid"). The cards intentionally share a
/// constant key namespace (`vehicleChipKey`) with the prior pill-chip
/// implementation so existing widget tests target them unchanged.
class KycVehicleStep extends StatefulWidget {
  const KycVehicleStep({super.key});

  static const Key registrationFieldKey = Key('kyc-vehicle-registration');
  static const Key submitButtonKey = Key('kyc-vehicle-submit');
  static const Key vehicleGridKey = Key('kyc-vehicle-grid');
  static Key vehicleChipKey(VehicleType type) =>
      ValueKey('kyc-vehicle-chip-${type.name}');

  /// Tile aspect ratio for the selection grid — wider than tall so the icon +
  /// label sit comfortably on a single line on small phones (e.g. 360dp wide).
  static const double _gridTileAspectRatio = 1.6;

  @override
  State<KycVehicleStep> createState() => _KycVehicleStepState();
}

class _KycVehicleStepState extends State<KycVehicleStep> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial =
        context.read<KycWizardCubit>().state.submission.vehicleRegistration;
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _vehicleLabel(AppLocalizations l10n, VehicleType type) {
    switch (type) {
      case VehicleType.scooter:
        return l10n.kycVehicleTypeScooter;
      case VehicleType.car:
        return l10n.kycVehicleTypeCar;
      case VehicleType.bicycle:
        return l10n.kycVehicleTypeBicycle;
      case VehicleType.onFoot:
        return l10n.kycVehicleTypeOnFoot;
    }
  }

  IconData _vehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.scooter:
        return Icons.two_wheeler_rounded;
      case VehicleType.car:
        return Icons.directions_car_rounded;
      case VehicleType.bicycle:
        return Icons.pedal_bike_rounded;
      case VehicleType.onFoot:
        return Icons.directions_walk_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<KycWizardCubit, KycWizardState>(
      builder: (context, state) {
        final cubit = context.read<KycWizardCubit>();
        final showRequiredError =
            state.error == KycWizardError.vehicleRegistrationRequired;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.kycVehicleStepTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Spacing.small),
              Text(
                l10n.kycVehicleStepSubtitle,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.large),
              GridView.builder(
                key: KycVehicleStep.vehicleGridKey,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: VehicleType.values.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: Spacing.small,
                  mainAxisSpacing: Spacing.small,
                  childAspectRatio: KycVehicleStep._gridTileAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final type = VehicleType.values[index];
                  return _VehicleSelectionCard(
                    tileKey: KycVehicleStep.vehicleChipKey(type),
                    label: _vehicleLabel(l10n, type),
                    icon: _vehicleIcon(type),
                    selected: state.submission.vehicleType == type,
                    onTap: () => cubit.setVehicleType(type),
                  );
                },
              ),
              const SizedBox(height: Spacing.large),
              OmdsTextField(
                key: KycVehicleStep.registrationFieldKey,
                controller: _controller,
                labelText: l10n.kycVehicleRegistrationLabel,
                hintText: l10n.kycVehicleRegistrationHint,
                onChanged: cubit.setVehicleRegistration,
                errorText: showRequiredError
                    ? l10n.kycVehicleRegistrationRequired
                    : null,
              ),
              const SizedBox(height: Spacing.xLarge),
              OmdsPrimaryButton(
                key: KycVehicleStep.submitButtonKey,
                text: state.step == KycWizardStep.submitting
                    ? l10n.kycWizardSubmitting
                    : l10n.kycWizardSubmit,
                isEnabled: state.canAdvanceFromVehicle &&
                    state.step != KycWizardStep.submitting,
                onTap: () => cubit.submit(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VehicleSelectionCard extends StatelessWidget {
  const _VehicleSelectionCard({
    required this.tileKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final background =
        selected ? scheme.primaryContainer : scheme.surfaceContainerLow;
    final foreground =
        selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant;
    return Semantics(
      key: tileKey,
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: background,
        borderRadius: OmdsBorderRadius.small,
        child: InkWell(
          borderRadius: OmdsBorderRadius.small,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.medium,
              vertical: Spacing.small,
            ),
            decoration: BoxDecoration(
              borderRadius: OmdsBorderRadius.small,
              border: Border.all(
                color: borderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: foreground, size: Sizes.xLarge),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: scheme.primary,
                    size: Sizes.medium,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
