import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Radio-group of cancellation reasons (keyboard-navigable, announced to screen readers).
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
    // Backend reason code for stable identifier across i18n/reorder.
    return Semantics(
      identifier: 'cancellation_reason_$reason',
      container: true,
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
