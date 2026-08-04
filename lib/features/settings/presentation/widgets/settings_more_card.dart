import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/diagnostics/diag.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';

/// MORE — the navigation rows the board omits but the app still owns
/// (CF2, REFUSED: they are live routes with frozen identifiers).
///
/// **doc-13 P1 restructure.** With two-line rows this band ran past the fold at
/// rest, so the board's empty band vanished and the last row was sliced in half.
/// The rows are now one line — the same rule the toggle rows above already
/// follow — which puts the whole screen inside the viewport with air to spare.
/// The subtitles were pure restatement ("Saved addresses / Quick access for
/// re-order"); the routes and identifiers are untouched, and the rows drop to
/// the kit's `11/14` navigation rung — these navigate, they are not the board's
/// `13/16` toggle rows.
class SettingsMoreCard extends StatelessWidget {
  const SettingsMoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.settingsMoreSection),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard.grouped(
          children: [
            JeebListRow(
              key: const Key('settings-row-addresses'),
              identifier: 'settings_open_addresses',
              icon: Icons.location_on,
              title: l10n.savedAddressesTitle,
              titleStyle: _titleStyle(context),
              onTap: () => context.pushNamed('settings-addresses'),
            ),
            JeebListRow(
              key: const Key('settings-row-notifications-manage'),
              identifier: 'settings-row-notifications-manage',
              icon: Icons.notifications,
              title: l10n.notificationPreferencesTitle,
              titleStyle: _titleStyle(context),
              onTap: () => context.pushNamed('settings-notifications'),
            ),
            // Dev-only diagnostics export entry (diag-persistence lane). Gated
            // on Diag.enabled (kDebugMode || JEEB_DIAG dart-define) so it NEVER
            // renders in release. Literal English strings by design — a dev tool
            // that never ships, deliberately kept out of the ARB catalogs.
            if (Diag.enabled)
              JeebListRow(
                key: const Key('settings-row-diagnostics'),
                identifier: 'settings_open_diagnostics',
                icon: Icons.bug_report,
                title: 'Diagnostics',
                titleStyle: _titleStyle(context),
                onTap: () => context.pushNamed('settings-diagnostics'),
              ),
          ],
        ),
      ],
    );
  }

  /// The screen's row title: 14/w600, matching the toggle and sign-out rows.
  TextStyle _titleStyle(BuildContext context) =>
      context.jeebText.body.copyWith(fontWeight: FontWeight.w600);
}
