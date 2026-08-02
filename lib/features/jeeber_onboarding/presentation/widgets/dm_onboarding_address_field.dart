import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../l10n/app_localizations.dart';
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, and just enough height for the 200% rendering.
/// Measured: label + field is 92 pt at 100% text and 156 pt at 200% with a
const Size _dmOnboardingAddressFieldBox = Size(390, 160);

/// Renders one field the way `DmOnboardingAddressStep` does — inside the step's
/// horizontal gutters, stretched to the gutter width, top-aligned.
Widget _dmOnboardingAddressFieldHosted({
  required String Function(AppLocalizations l10n) label,
  required String Function(AppLocalizations l10n) hint,
  String identifier = 'dm_onboarding_address_preview_field',
}) {
  return Builder(
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DmOnboardingAddressField(
              spec: DmAddressFieldSpec(
                identifier: identifier,
                label: label(l10n),
                hint: hint(l10n),
                onChanged: (String _) {},
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The shortest shipped field: "State" over the hint "Iklim el kharoub".
/// The baseline reading — this is the first of the four rows the address step
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'State · shortest field',
  size: _dmOnboardingAddressFieldBox,
)
Widget dmOnboardingAddressFieldState() => _dmOnboardingAddressFieldHosted(
      identifier: 'dm_onboarding_address_state_field',
      label: (AppLocalizations l10n) => l10n.dmOnboardingAddressStateLabel,
      hint: (AppLocalizations l10n) => l10n.dmOnboardingAddressStateHint,
    );

/// The longest shipped hint: "Jasmine Tower, Apartment 12B".
/// This is the state to look at first. The placeholder is single-line and
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Address · longest shipped hint',
  size: _dmOnboardingAddressFieldBox,
)
Widget dmOnboardingAddressFieldLongestShippedHint() =>
    _dmOnboardingAddressFieldHosted(
      identifier: 'dm_onboarding_address_field',
      label: (AppLocalizations l10n) => l10n.dmOnboardingAddressAddressLabel,
      hint: (AppLocalizations l10n) => l10n.dmOnboardingAddressAddressHint,
    );

/// Worst-case translation of a label.
/// The external label is a bare [Text] with no `maxLines` and no `overflow`, so
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Long label wraps',
  size: _dmOnboardingAddressFieldBox,
)
Widget dmOnboardingAddressFieldLongLabel() => _dmOnboardingAddressFieldHosted(
      identifier: 'dm_onboarding_address_field',
      label: (AppLocalizations _) =>
          'Building name, floor, and apartment number',
      hint: (AppLocalizations l10n) => l10n.dmOnboardingAddressStreetHint,
    );

/// Longest plausible hint: guidance copy rather than a two-word example.
/// Product asks for more explicit placeholders roughly every other cycle
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Verbose hint clipped',
  size: _dmOnboardingAddressFieldBox,
)
Widget dmOnboardingAddressFieldVerboseHint() => _dmOnboardingAddressFieldHosted(
      identifier: 'dm_onboarding_address_field',
      label: (AppLocalizations l10n) => l10n.dmOnboardingAddressAddressLabel,
      hint: (AppLocalizations _) =>
          'e.g. Jasmine Tower, 3rd floor, Apartment 12B, next to the pharmacy',
    );

/// Copy gap: a spec built with no hint at all.
/// [DmAddressFieldSpec.hint] is a non-nullable `String`, so "no example" is
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Hint missing',
  size: _dmOnboardingAddressFieldBox,
)
Widget dmOnboardingAddressFieldNoHint() => _dmOnboardingAddressFieldHosted(
      identifier: 'dm_onboarding_address_street_field',
      label: (AppLocalizations l10n) => l10n.dmOnboardingAddressStreetLabel,
      hint: (AppLocalizations _) => '',
    );
