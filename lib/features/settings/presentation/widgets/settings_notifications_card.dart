import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_cubit.dart';
import '../../application/settings_state.dart';

/// NOTIFICATIONS label + the grouped toggle card (redesign-2026-08 §3.6).
///
/// Every row is ONE line: the board drops the per-category subtitles the dense
/// list carried, and that single change is most of the screen's new air (R1).
class SettingsNotificationsCard extends StatelessWidget {
  const SettingsNotificationsCard({super.key, required this.state});

  /// Trailing padlock on the security-codes row (board `tpl 1212`).
  static const double lockGlyphSize = 17;

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    final notifications = state.notifications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.settingsNotificationsSection),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard.grouped(
          children: [
            _ToggleRow(
              rowKey: const Key('settings-row-notifications-offers'),
              identifier: 'settings_notifications_offers_toggle',
              title: l10n.notificationCategoryOffers,
              value: notifications.offers,
              onChanged: (v) =>
                  cubit.setNotification(NotificationCategory.offers, v),
            ),
            _ToggleRow(
              rowKey: const Key('settings-row-notifications-chat'),
              identifier: 'settings_notifications_chat_toggle',
              title: l10n.notificationCategoryChat,
              value: notifications.chat,
              onChanged: (v) =>
                  cubit.setNotification(NotificationCategory.chat, v),
            ),
            _ToggleRow(
              rowKey: const Key('settings-row-notifications-status'),
              identifier: 'settings_notifications_status_toggle',
              title: l10n.notificationCategoryStatus,
              value: notifications.status,
              onChanged: (v) =>
                  cubit.setNotification(NotificationCategory.status, v),
            ),
            // The board draws three toggles; the app has four real categories
            // (CF3), so rating reminders ship with their frozen identifier.
            _ToggleRow(
              rowKey: const Key('settings-row-notifications-ratings'),
              identifier: 'settings_notifications_ratings_toggle',
              title: l10n.notificationCategoryRatingReminders,
              value: notifications.ratingReminders,
              onChanged: (v) => cubit.setNotification(
                NotificationCategory.ratingReminders,
                v,
              ),
            ),
            const _SecurityCodesRow(),
          ],
        ),
      ],
    );
  }
}

/// One switch row. Deliberately still `OmdsSettingsSwitchRow` — the redesign
/// changes the row's copy and ink, not its a11y contract or its tap target.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.rowKey,
    required this.identifier,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Key rowKey;
  final String identifier;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: identifier,
      toggled: value,
      container: true,
      // `SwitchListTile` paints its ink on the nearest Material ancestor and
      // asserts when a coloured box sits between the two — which the card's
      // fill does. A transparent Material inside the card is the documented fix.
      child: Material(
        type: MaterialType.transparency,
        child: OmdsSettingsSwitchRow(
          key: rowKey,
          title: title,
          value: value,
          // A widget-level colour beats the Wave-0 `switchTheme`, and the OMDS
          // default is `colorScheme.primary` — i.e. a navy thumb on a navy
          // track. The board's knob is white (`tpl 1197`).
          activeColor: colorScheme.onPrimary,
          titleStyle: context.jeebText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: Spacing.medium),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// The always-on security-codes line: a fact, not a control, so it is a plain
/// row with a padlock instead of a disabled switch.
class _SecurityCodesRow extends StatelessWidget {
  const _SecurityCodesRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context).extension<JeebSemanticColors>()!.mutedText;

    return Padding(
      key: const Key('settings-row-notifications-otp'),
      padding: JeebOutlinedCard.defaultPadding,
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: l10n.notificationCategoryOtp,
                children: [
                  // The separator lives inside the ARB value so Arabic can
                  // reorder it with the qualifier.
                  TextSpan(
                    text: l10n.settingsAlwaysOnQualifier,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                ],
              ),
              style: context.jeebText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: Spacing.small),
          Icon(
            Icons.lock,
            size: SettingsNotificationsCard.lockGlyphSize,
            color: muted,
          ),
        ],
      ),
    );
  }
}
