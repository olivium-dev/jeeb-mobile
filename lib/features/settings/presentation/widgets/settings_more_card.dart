import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/diagnostics/diag.dart';
import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';

/// MORE — the navigation rows the board omits but the app still owns
/// (redesign-2026-08 §3.7 / CF2).
///
/// Saved addresses, notification preferences and the dev-only diagnostics entry
/// are live routes with frozen identifiers; dropping them to match the board
/// would delete working navigation, so they are re-homed under one label.
/// Subtitles stay here — these rows navigate, they do not toggle.
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
              subtitle: l10n.savedAddressesSubtitle,
              onTap: () => context.pushNamed('settings-addresses'),
            ),
            JeebListRow(
              key: const Key('settings-row-notifications-manage'),
              identifier: 'settings-row-notifications-manage',
              icon: Icons.notifications,
              title: l10n.notificationPreferencesTitle,
              subtitle: l10n.notificationPreferencesRowSubtitle,
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
                subtitle: 'Session logs · dev builds only',
                onTap: () => context.pushNamed('settings-diagnostics'),
              ),
          ],
        ),
      ],
    );
  }
}
