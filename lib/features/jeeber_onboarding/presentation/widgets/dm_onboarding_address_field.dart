import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';

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
/// MIDNIGHT: the label is the kit's `JeebSectionLabel` — R6's shipped treatment
/// for a label above an input. It replaces a `colorScheme.primary` ink that was
/// navy in pass 1 and is now the brand orange.
class DmOnboardingAddressField extends StatelessWidget {
  const DmOnboardingAddressField({super.key, required this.spec});

  final DmAddressFieldSpec spec;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JeebSectionLabel(spec.label),
        const SizedBox(height: Spacing.xSmall),
        Semantics(
          identifier: spec.identifier,
          textField: true,
          label: spec.label,
          // R23's field. `OmdsValidatedTextField` defaults its text AND hint to
          // `headlineLarge` w700 over an opaque navy fill — off the §6 ramp.
          child: OmdsTextField(
            hintText: spec.hint,
            borderRadius: JeebRadii.md,
            onChanged: spec.onChanged,
          ),
        ),
      ],
    );
  }
}
