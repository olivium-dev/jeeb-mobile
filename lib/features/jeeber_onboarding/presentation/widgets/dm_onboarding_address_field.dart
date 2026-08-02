import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../l10n/app_localizations.dart';
import '../../../../core/previews/jeeb_preview.dart';

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
/// (Figma 56591:4109 — external label above, periwinkle hint inside the
/// outlined field). One reusable widget for all five rows.
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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/jeeber_onboarding/dm_onboarding_address_field_preview_test.dart
// ===========================================================================
//
// The widget is pure presentation: it takes a [DmAddressFieldSpec] (semantics
// id, label, hint, setter) and renders an external label over an
// [OmdsValidatedTextField]. There is no repository and no cubit to seed, so
// these previews are network-free by construction — the only thing that varies
// between states is the copy the spec carries.
//
// Two consequences of that shape are worth stating up front, because they are
// why some obvious states are missing here:
//
// * **No filled / error state.** [DmOnboardingAddressField] passes neither a
//   `controller` nor `validations` to [OmdsValidatedTextField], so a preview
//   cannot seed typed text and the field's error affordance can never fire in
//   this screen. Adding either would be a production change, which previews
//   are not allowed to make.
// * **The hint is the layout risk, not the value.** `OmdsValidatedTextField`
//   styles both the entered text and the placeholder with `headlineLarge`
//   (32 sp, bold), while this widget's external label is `bodyLarge` (16 sp).
//   Every state below is really a question about whether the *hint* survives
//   the width `DmOnboardingAddressStep` gives it.
//
// Each preview reproduces that width: the step wraps its column in
// [Spacing.xLarge] gutters, so a field on a 390 pt phone gets 342 pt, of which
// `OmdsValidatedTextField`'s own `Spacing.medium` content padding takes another
// 40 pt — 302 pt of usable placeholder width, measured. Previewing the field
// edge-to-edge on the canvas would hide the clip that follows from it.
//
// One thing the canvas cannot show, recorded here because it came out of the
// same pass: the widget builds *two* nested text-field semantics nodes. The
// [Semantics] wrapper contributes `identifier` + `label` on the outer node,
// while the focusable/tappable node underneath it is labelled by the OMDS
// field with the **hint** text. A screen-reader user focusing the input hears
// the example address, not "Address".

/// Phone width, and just enough height for the 200% rendering.
///
/// Measured: label + field is 92 pt at 100% text and 156 pt at 200% with a
/// single-line label. Sized to 160 so the accessibility rendering fits by 4 pt
/// and any state that wraps its label visibly runs out of box.
const Size _dmOnboardingAddressFieldBox = Size(390, 160);

/// Renders one field the way `DmOnboardingAddressStep` does — inside the step's
/// horizontal gutters, stretched to the gutter width, top-aligned.
///
/// [label] and [hint] are resolved from the ambient [AppLocalizations] rather
/// than passed as literals wherever the state corresponds to real shipped copy,
/// so the AR RTL rendering shows the Arabic the jeeber actually sees instead of
/// English text in a mirrored box.
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
///
/// The baseline reading — this is the first of the four rows the address step
/// renders, and the only one whose hint comes close to fitting at 32 sp.
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
///
/// This is the state to look at first. The placeholder is single-line and
/// ellipsized, and 302 pt at 32 sp bold holds roughly 17 Latin characters
/// against this string's 28 — so it renders as "Jasmine Tower, Ap…" in English
/// and truncates the same way in Arabic ("برج الياسمين، شقة 12B"), at 100%
/// text, before any accessibility scaling. A jeeber never reads the example the
/// ARB entry was written to give them.
///
/// If a fix lands — a smaller hint style, or `hintMaxLines` — this preview is
/// where it shows up.
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
///
/// The external label is a bare [Text] with no `maxLines` and no `overflow`, so
/// it wraps freely and pushes the field down. A German/Arabic expansion of
/// "Address" is realistically 2–3× the English, and this is the state that
/// decides whether the step's four rows still fit one screen — check the 200%
/// rendering, where the label wraps and the pair outgrows the 160 pt box.
///
/// Synthetic copy, not an ARB key: no shipped label is this long *yet*.
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
///
/// Product asks for more explicit placeholders roughly every other cycle
/// ("tell them what a good address looks like"). At the current hint style the
/// answer is that it cannot be done in this widget: the reader gets about the
/// first 17 characters — "e.g. Jasmine Towe…" — and the rest is ellipsis. Worth
/// having on the canvas so the constraint is visible before the copy is
/// written, not after.
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
///
/// [DmAddressFieldSpec.hint] is a non-nullable `String`, so "no example" is
/// spelled `''` — and an empty placeholder degrades to a blank outlined box
/// with no affordance of its own. The external label is then the *only* thing
/// identifying the field, which is exactly why this widget keeps the label
/// outside the field instead of relying on the OMDS internal one.
///
/// Also the guard that an empty hint neither collapses the field's height nor
/// throws.
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
