import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/saved_location.dart';

/// Result returned by [AddEditLocationSheet.show].
class LocationFormResult {
  const LocationFormResult({
    required this.label,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String label;
  final SavedLocationCategory category;
  final double latitude;
  final double longitude;
  final String? address;
}

/// Bottom sheet for adding or editing a saved location (T-MOB-025).
///
/// When [existing] is null, the sheet is in Add mode.
/// When [existing] is non-null, the sheet pre-fills the form and is in
/// Edit mode.
///
/// EXEMPT: OmdsBottomSheet does not expose the form-field layout pattern
/// required here (label text field + category chips + coordinate fields).
/// This sheet uses Flutter's `showModalBottomSheet` with OMDS design tokens
/// throughout (T-MOB-025).
class AddEditLocationSheet extends StatefulWidget {
  const AddEditLocationSheet({super.key, this.existing});

  final SavedLocation? existing;

  static Future<LocationFormResult?> show({
    required BuildContext context,
    required SavedLocation? existing,
  }) {
    return showModalBottomSheet<LocationFormResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spacing.large),
        ),
      ),
      builder: (_) => AddEditLocationSheet(existing: existing),
    );
  }

  @override
  State<AddEditLocationSheet> createState() => _AddEditLocationSheetState();
}

class _AddEditLocationSheetState extends State<AddEditLocationSheet> {
  late SavedLocationCategory _category;
  late final TextEditingController _labelController;
  late final TextEditingController _addressController;

  // Placeholder coordinates — in production a map picker (ofl_geo_capture)
  // would provide these. For this milestone we use a text input as a
  // lightweight stand-in, same pattern as T-MOB-012.
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? SavedLocationCategory.home;
    _labelController = TextEditingController(text: e?.label ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _latController = TextEditingController(
      text: e != null ? e.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: e != null ? e.longitude.toString() : '',
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _labelController.text.trim().isNotEmpty &&
        double.tryParse(_latController.text.trim()) != null &&
        double.tryParse(_lngController.text.trim()) != null;
  }

  void _onSave(AppLocalizations l10n) {
    if (!_isValid) return;
    final lat = double.parse(_latController.text.trim());
    final lng = double.parse(_lngController.text.trim());
    final address = _addressController.text.trim();
    Navigator.of(context).pop(
      LocationFormResult(
        label: _labelController.text.trim(),
        category: _category,
        latitude: lat,
        longitude: lng,
        address: address.isEmpty ? null : address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHandle(),
              const SizedBox(height: Spacing.medium),
              _SheetTitle(
                text: isEdit
                    ? l10n.savedLocationsEdit
                    : l10n.savedLocationsAddNew,
              ),
              const SizedBox(height: Spacing.medium),
              _CategoryRow(
                selected: _category,
                onSelected: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: Spacing.medium),
              OmdsTextField(
                controller: _labelController,
                labelText: l10n.savedAddressLabelLabel,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.small),
              OmdsTextField(
                controller: _addressController,
                labelText: l10n.savedAddressLineLabel,
              ),
              const SizedBox(height: Spacing.small),
              _CoordinateRow(
                latController: _latController,
                lngController: _lngController,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: Spacing.large),
              _FormActions(
                isSaveEnabled: _isValid,
                onSave: () => _onSave(l10n),
                onCancel: () => Navigator.of(context).pop(),
                saveLabel: isEdit
                    ? l10n.savedLocationsEdit
                    : l10n.savedLocationsAddNew,
                cancelLabel: l10n.actionCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: OmdsBorderRadius.twoXLarge,
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.selected, required this.onSelected});

  final SavedLocationCategory selected;
  final ValueChanged<SavedLocationCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: SavedLocationCategory.values
          .map((cat) => _CategoryChip(
                category: cat,
                label: _label(cat, l10n),
                icon: _icon(cat),
                isSelected: selected == cat,
                onTap: () => onSelected(cat),
              ))
          .toList(growable: false),
    );
  }

  String _label(SavedLocationCategory cat, AppLocalizations l10n) {
    switch (cat) {
      case SavedLocationCategory.home:
        return l10n.savedLocationsChipHome;
      case SavedLocationCategory.work:
        return l10n.savedLocationsChipWork;
      case SavedLocationCategory.other:
        return l10n.savedLocationsChipOther;
    }
  }

  IconData _icon(SavedLocationCategory cat) {
    switch (cat) {
      case SavedLocationCategory.home:
        return Icons.home_rounded;
      case SavedLocationCategory.work:
        return Icons.work_rounded;
      case SavedLocationCategory.other:
        return Icons.place_rounded;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final SavedLocationCategory category;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Spacing.xSmall),
      child: OmdsChip(
        label: label,
        onTap: onTap,
        isSelected: isSelected,
        icon: Icon(icon, size: Sizes.small),
      ),
    );
  }
}

class _CoordinateRow extends StatelessWidget {
  const _CoordinateRow({
    required this.latController,
    required this.lngController,
    required this.onChanged,
  });

  final TextEditingController latController;
  final TextEditingController lngController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: OmdsTextField(
            controller: latController,
            labelText: l10n.savedAddressLatitudeLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: OmdsTextField(
            controller: lngController,
            labelText: l10n.savedAddressLongitudeLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.isSaveEnabled,
    required this.onSave,
    required this.onCancel,
    required this.saveLabel,
    required this.cancelLabel,
  });

  final bool isSaveEnabled;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String saveLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OMDSOutlinedButton(
            text: cancelLabel,
            onTap: onCancel,
          ),
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: OmdsPrimaryButton(
            text: saveLabel,
            isEnabled: isSaveEnabled,
            onTap: onSave,
          ),
        ),
      ],
    );
  }
}
