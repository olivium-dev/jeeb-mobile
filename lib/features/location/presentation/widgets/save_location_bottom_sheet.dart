import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/saved_location.dart';

/// Result returned by [showSaveLocationBottomSheet].
class SaveLocationResult {
  const SaveLocationResult({
    required this.category,
    required this.label,
  });

  final SavedLocationCategory category;
  final String label;
}

/// Shows a bottom sheet offering to save the given lat/lng as
/// Home, Work, or Other (T-MOB-012 AC2).
///
/// Returns [SaveLocationResult] when the user taps Save, or `null` when
/// they tap Skip or dismiss the sheet.
Future<SaveLocationResult?> showSaveLocationBottomSheet(
  BuildContext context,
) {
  return showModalBottomSheet<SaveLocationResult>(
    context: context,
    // EXEMPT: OmdsBottomSheet does not expose the form-field content
    // pattern required here (radio group + text input). The sheet is
    // styled with OMDS tokens throughout (T-MOB-012).
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
    ),
    builder: (context) => const _SaveLocationSheet(),
  );
}

class _SaveLocationSheet extends StatefulWidget {
  const _SaveLocationSheet();

  @override
  State<_SaveLocationSheet> createState() => _SaveLocationSheetState();
}

class _SaveLocationSheetState extends State<_SaveLocationSheet> {
  SavedLocationCategory _category = SavedLocationCategory.home;
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHandle(),
            _buildTitle(context, l10n),
            const SizedBox(height: Spacing.medium),
            _buildCategoryPicker(context, l10n),
            const SizedBox(height: Spacing.small),
            _buildLabelField(l10n),
            const SizedBox(height: Spacing.medium),
            _buildActions(context, l10n),
            const SizedBox(height: Spacing.large),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsetsDirectional.only(top: Spacing.small),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: OmdsBorderRadius.twoXLarge,
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        0,
      ),
      child: Text(
        l10n.savedLocationsSaveSheetTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildCategoryPicker(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Spacing.large),
      child: Row(
        children: SavedLocationCategory.values
            .map((cat) => _CategoryChip(
                  category: cat,
                  selected: _category == cat,
                  onTap: () => setState(() => _category = cat),
                ))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildLabelField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Spacing.large),
      child: OmdsTextField(
        controller: _labelController,
        labelText: l10n.savedLocationsNameHint,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildActions(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Spacing.large),
      child: Row(
        children: [
          Expanded(
            child: OMDSOutlinedButton(
              text: l10n.savedLocationsSaveSheetSkip,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: Spacing.medium),
          Expanded(
            child: OmdsPrimaryButton(
              text: l10n.savedLocationsSaveSheetSave,
              onTap: () => _onSave(context, l10n),
            ),
          ),
        ],
      ),
    );
  }

  void _onSave(BuildContext context, AppLocalizations l10n) {
    final label = _labelController.text.trim().isNotEmpty
        ? _labelController.text.trim()
        : _defaultLabel(l10n, _category);
    Navigator.of(context).pop(
      SaveLocationResult(category: _category, label: label),
    );
  }

  String _defaultLabel(AppLocalizations l10n, SavedLocationCategory category) {
    switch (category) {
      case SavedLocationCategory.home:
        return l10n.savedLocationsChipHome;
      case SavedLocationCategory.work:
        return l10n.savedLocationsChipWork;
      case SavedLocationCategory.other:
        return l10n.savedLocationsChipOther;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SavedLocationCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = _label(l10n);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Spacing.xSmall),
      child: OmdsChip(
        label: label,
        onTap: onTap,
        isSelected: selected,
        icon: Icon(_icon(), size: Sizes.small),
      ),
    );
  }

  String _label(AppLocalizations l10n) {
    switch (category) {
      case SavedLocationCategory.home:
        return l10n.savedLocationsChipHome;
      case SavedLocationCategory.work:
        return l10n.savedLocationsChipWork;
      case SavedLocationCategory.other:
        return l10n.savedLocationsChipOther;
    }
  }

  IconData _icon() {
    switch (category) {
      case SavedLocationCategory.home:
        return Icons.home_rounded;
      case SavedLocationCategory.work:
        return Icons.work_rounded;
      case SavedLocationCategory.other:
        return Icons.place_rounded;
    }
  }
}
