import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';

/// Immutable description of one address-step field: its semantics id, label,
/// hint, and the cubit setter to call on change. Lets the step declare its
/// five fields as data rather than five hand-written widgets.
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

/// A single labeled outlined text field for the onboarding address step
/// (Figma 56591:4109 — external label above, hint inside the outlined field).
/// One reusable widget for all four rows.
///
/// The label rides the redesign ramp (`jeebText.bodySmall`, brand navy) rather
/// than stock `bodyLarge`, so a form row reads at the same weight as the
/// board's row titles instead of competing with the step headline.
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
          style: context.jeebText.bodySmall.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
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
