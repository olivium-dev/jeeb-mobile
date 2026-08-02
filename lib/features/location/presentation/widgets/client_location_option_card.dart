import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../request_type/presentation/selectable_radio_glyph.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../l10n/app_localizations.dart';

class ClientLocationOptionCard extends StatelessWidget {
  const ClientLocationOptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'client_location_option_current',
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: OmdsBorderRadius.uiLarge,
          child: InkWell(
            borderRadius: OmdsBorderRadius.uiLarge,
            onTap: onTap,
            child: _body(scheme),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    final foreground = selected ? scheme.onPrimary : scheme.primary;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.large,
      ),
      decoration: BoxDecoration(
        borderRadius: OmdsBorderRadius.uiLarge,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _Label(label: label, color: foreground)),
          const SizedBox(width: Spacing.medium),
          SelectableRadioGlyph(selected: selected, ring: foreground),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for one option card: phone width, one card tall.
/// The card itself is 66pt (82pt at 200% text); the rest is the vertical
const Size _clientLocationOptionCardBox = Size(390, 140);

/// A taller box for the two-card group.
const Size _clientLocationOptionCardGroupBox = Size(390, 260);

/// Hosts a card inside the same horizontal gutter the Client Location screen
/// gives it (`DeliveryCreateLayout.pagePadding` → `Spacing.large` each side),
Widget _clientLocationOptionCardHosted({required String label, required bool selected}) {
  return Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: Spacing.large,
      vertical: Spacing.medium,
    ),
    child: ClientLocationOptionCard(
      label: label,
      selected: selected,
      onTap: () {},
    ),
  );
}

/// Same, but reading the label through [AppLocalizations] exactly the way
/// `CurrentLocationStatusCard` does — so the AR RTL rendering shows the real
Widget _clientLocationOptionCardHostedLocalized({
  required String Function(AppLocalizations l10n) label,
  required bool selected,
}) {
  return Builder(
    builder: (BuildContext context) => _clientLocationOptionCardHosted(
      label: label(AppLocalizations.of(context)),
      selected: selected,
    ),
  );
}

/// The resting state: an option the customer has not chosen.
/// White `surface` fill, `outlineVariant` hairline, navy `primary` label, empty
@JeebPreview(group: 'location', name: 'Unselected', size: _clientLocationOptionCardBox)
Widget clientLocationOptionCardUnselected() => _clientLocationOptionCardHostedLocalized(
      label: (AppLocalizations l10n) => l10n.clientLocationNewOption,
      selected: false,
    );

/// The chosen state: navy `primary` fill, `onPrimary` label, filled radio.
/// What "Current Location" looks like once tapped — which on this screen is
@JeebPreview(group: 'location', name: 'Selected', size: _clientLocationOptionCardBox)
Widget clientLocationOptionCardSelected() => _clientLocationOptionCardHostedLocalized(
      label: (AppLocalizations l10n) => l10n.clientLocationCurrentOption,
      selected: true,
    );

/// The layout ceiling: a user-entered saved-address label.
/// The `_SavedAddressCard` on the same screen "mirrors [ClientLocationOptionCard]
@JeebPreview(group: 'location', name: 'Long label truncates', size: _clientLocationOptionCardBox)
Widget clientLocationOptionCardLongLabel() => _clientLocationOptionCardHosted(
      label: 'Sassine Square, Ashrafieh — Building 12, 3rd floor, blue door',
      selected: false,
    );

/// The same truncation against the navy fill, with no break opportunity.
/// Map plus-codes and pasted place identifiers arrive as one unbroken token,
@JeebPreview(group: 'location', name: 'Unbreakable label', size: _clientLocationOptionCardBox)
Widget clientLocationOptionCardUnbreakableLabel() => _clientLocationOptionCardHosted(
      label: 'W2CH+8XBeirutGovernorateLebanonPlusCodeIdentifier',
      selected: true,
    );

/// A right-to-left label while the app itself is running in English.
/// Saved-address labels are user input, so an Arabic-speaking customer on an
@JeebPreview(group: 'location', name: 'RTL label under EN locale', size: _clientLocationOptionCardBox)
Widget clientLocationOptionCardRtlLabel() => _clientLocationOptionCardHosted(
      label: 'ساسين، الأشرفية (مبنى 12)',
      selected: false,
    );

/// The mutually-exclusive pair — the state a single card can never show.
/// The widget declares `inMutuallyExclusiveGroup: true`, which only means
@JeebPreview(group: 'location', name: 'Pair in one group', size: _clientLocationOptionCardGroupBox)
Widget clientLocationOptionCardPair() => const Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.large,
        vertical: Spacing.medium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClientLocationOptionCard(
            label: 'Home',
            selected: true,
            onTap: _clientLocationOptionCardNoop,
          ),
          SizedBox(height: Spacing.small),
          ClientLocationOptionCard(
            label: 'Office',
            selected: false,
            onTap: _clientLocationOptionCardNoop,
          ),
        ],
      ),
    );

void _clientLocationOptionCardNoop() {}
