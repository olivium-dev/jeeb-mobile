import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// A radio-group of cancellation reasons.
///
/// Each option is keyboard-navigable and announces its selection state to
/// screen readers (AC4: reason group is keyboard-navigable; selected reason
/// announced).
class CancellationReasonGroup extends StatelessWidget {
  const CancellationReasonGroup({
    super.key,
    required this.reasons,
    required this.selectedReason,
    required this.labelOf,
    required this.onChanged,
  });

  final List<String> reasons;
  final String? selectedReason;
  final String Function(String reason) labelOf;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reason in reasons)
          _ReasonTile(
            reason: reason,
            label: labelOf(reason),
            isSelected: selectedReason == reason,
            onTap: () => onChanged(reason),
          ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String reason;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: OmdsSettingsRow(
        title: label,
        leadingIcon: isSelected
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
        leadingIconColor: isSelected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
        trailing: const SizedBox.shrink(),
        onTap: onTap,
      ),
    );
  }
}
