import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

class DmAddressFieldSpec {
  const DmAddressFieldSpec({
    required this.identifier,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final String identifier;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
}

class DmOnboardingAddressField extends StatelessWidget {
  const DmOnboardingAddressField({super.key, required this.spec});

  final DmAddressFieldSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          spec.label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Semantics(
          identifier: spec.identifier,
          textField: true,
          label: spec.label,
          child: OmdsValidatedTextField(
            placeholder: spec.hint,
            onChanged: spec.onChanged,
          ),
        ),
      ],
    );
  }
}
