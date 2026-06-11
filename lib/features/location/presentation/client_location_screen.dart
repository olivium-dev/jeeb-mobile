import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'widgets/client_location_add_row.dart';
import 'widgets/client_location_option_card.dart';
import 'widgets/delivery_create_layout.dart';

/// "Client Location" screen (Figma 56539:1444) — the client picks the pickup /
/// origin location before creating a delivery request.
///
/// Renders a "Choose your location" heading, a selected "Current Location"
/// navy card (with a radio), and a "New Location" row whose circular add
/// button opens the map picker. Saved locations append below the current-
/// location card as additional selectable cards once the picker returns them
/// (state machine owned by the host / delivery-create flow — see comparison.md).
class ClientLocationScreen extends StatelessWidget {
  const ClientLocationScreen({
    super.key,
    this.onAddLocation,
    this.currentSelected = true,
    this.onSelectCurrent,
  });

  /// Invoked when the user taps the "New Location" affordance. Defaults to a
  /// back-pop so the screen is self-contained in the dev seam.
  final VoidCallback? onAddLocation;

  /// Whether the current-location card is the selected option.
  final bool currentSelected;

  /// Invoked when the user taps the current-location card.
  final VoidCallback? onSelectCurrent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: OMDSAppBar(
        title: l10n.clientLocationTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: _Body(
          currentSelected: currentSelected,
          onSelectCurrent: onSelectCurrent,
          onAddLocation: onAddLocation,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.currentSelected,
    this.onSelectCurrent,
    this.onAddLocation,
  });

  final bool currentSelected;
  final VoidCallback? onSelectCurrent;
  final VoidCallback? onAddLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: DeliveryCreateLayout.pagePadding,
      children: [
        _Heading(text: l10n.clientLocationHeading),
        const SizedBox(height: Spacing.large),
        ClientLocationOptionCard(
          label: l10n.clientLocationCurrentOption,
          selected: currentSelected,
          onTap: () => onSelectCurrent?.call(),
        ),
        const SizedBox(height: Spacing.large),
        ClientLocationAddRow(
          label: l10n.clientLocationNewOption,
          addSemanticLabel: l10n.clientLocationAddSemantic,
          onTap: () => _onAdd(context),
        ),
      ],
    );
  }

  void _onAdd(BuildContext context) {
    final handler = onAddLocation;
    if (handler != null) {
      handler();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
