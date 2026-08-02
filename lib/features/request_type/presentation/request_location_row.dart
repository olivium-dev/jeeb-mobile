import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/directional_icons.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../l10n/app_localizations.dart';

class RequestLocationRow extends StatelessWidget {
  const RequestLocationRow({
    super.key,
    required this.currentLabel,
    required this.changeLabel,
    required this.onChange,
  });

  final String currentLabel;
  final String changeLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    /// TRAP: explicitChildNodes makes this a Semantics boundary; without it, merge swallows child identifiers.
    return Semantics(
      explicitChildNodes: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: _CurrentLabel(text: currentLabel)),
          const SizedBox(width: Spacing.medium),
          _ChangeAction(label: changeLabel, onTap: onChange),
        ],
      ),
    );
  }
}

class _CurrentLabel extends StatelessWidget {
  const _CurrentLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'request_type_current_location_label',
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ChangeAction extends StatelessWidget {
  const _ChangeAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_type_change_location_button',
      button: true,
      label: label,
      child: InkWell(
        borderRadius: OmdsBorderRadius.uiSmall,
        onTap: onTap,
        child: _ActionContent(label: label),
      ),
    );
  }
}

class _ActionContent extends StatelessWidget {
  const _ActionContent({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(color: scheme.primary);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xSmall,
        vertical: Spacing.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          const SizedBox(width: Spacing.twoXSmall),
          Icon(DirectionalIcons.disclosure(context),
              size: Sizes.large, color: scheme.primary),
        ],
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [RequestLocationRow] — run with

/// A list row: full phone width, and tall enough for the 200%-text rendering.
/// The row measures 44pt at 1x and 64pt at 2x, so 88 leaves headroom without
const Size _requestLocationRowBox = Size(390, 88);

/// Builds the row the way `_LocationSection` does.
/// Both labels default to the real ARB values for the current locale; pass an
Widget _requestLocationRowHosted({String? currentLabel, String? changeLabel}) =>
    Builder(
      builder: (BuildContext context) {
        final AppLocalizations l10n = AppLocalizations.of(context);
        return RequestLocationRow(
          currentLabel: currentLabel ?? l10n.requestTypeCurrentLocation,
          changeLabel: changeLabel ?? l10n.requestTypeChangeLocation,
          onChange: () {},
        );
      },
    );

/// The only state production actually renders (Figma 56535:2392): both labels
/// come from the ARB, so this is also the state that proves the row is
@JeebPreview(
  group: 'request_type',
  name: 'Localized default',
  size: _requestLocationRowBox,
)
Widget requestLocationRowDefault() => _requestLocationRowHosted();

/// The label slot holding a real place instead of the static placeholder.
/// Short enough to still fit beside the action on a 390pt phone — this is the
@JeebPreview(
  group: 'request_type',
  name: 'Resolved address',
  size: _requestLocationRowBox,
)
Widget requestLocationRowResolvedAddress() =>
    _requestLocationRowHosted(currentLabel: 'Hamra St, Beirut');

/// Layout ceiling: the longest plausible geocoded address.
/// `_CurrentLabel` sets `overflow: TextOverflow.ellipsis` and leaves `maxLines`
@JeebPreview(
  group: 'request_type',
  name: 'Long address',
  size: _requestLocationRowBox,
)
Widget requestLocationRowLongAddress() => _requestLocationRowHosted(
      currentLabel:
          'Beirut Central District, Bloc B, Building 27, Floor 4, Apartment 12',
    );

/// The action side growing instead of the label side.
/// `_ChangeAction` is not wrapped in [Flexible], so it claims its full
@JeebPreview(
  group: 'request_type',
  name: 'Long action label',
  size: _requestLocationRowBox,
)
Widget requestLocationRowLongAction() =>
    _requestLocationRowHosted(changeLabel: 'Change pickup location');

/// A label with no break opportunity — a plus code / raw coordinate token,
/// which is exactly what a reverse geocode returns when it cannot name a place.
@JeebPreview(
  group: 'request_type',
  name: 'Unbreakable token',
  size: _requestLocationRowBox,
)
Widget requestLocationRowUnbreakableToken() => _requestLocationRowHosted(
      currentLabel: '8G4Q+X9R,BeirutCentralDistrict,Lebanon',
    );
