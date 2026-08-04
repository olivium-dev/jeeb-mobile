import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_cubit.dart';
import '../../application/settings_state.dart';

/// NOTIFICATIONS label + the grouped toggle card (MIDNIGHT R22 `tpl 1377`).
///
/// Every row is ONE line, and an ON toggle is the tile's second orange moment:
/// an orange track under a white knob, with a `0 0 12px` bloom — the caption's
/// "toggles glow orange when on".
class SettingsNotificationsCard extends StatelessWidget {
  const SettingsNotificationsCard({super.key, required this.state});

  /// Trailing padlock on the security-codes row (board `tpl 1397`).
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
              // TODO(midnight): l10n-queued — the tile reads "New offers";
              // this shared key ships "Offers" (doc-13 P1 copy drift).
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

/// One switch row: a [JeebListRow] whose trailing slot is the board's own
/// track, so the row padding, ink and tap target come from the kit.
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
    return Semantics(
      identifier: identifier,
      toggled: value,
      container: true,
      child: JeebListRow(
        key: rowKey,
        title: title,
        titleStyle: context.jeebText.body.copyWith(
          fontWeight: FontWeight.w600,
        ),
        padding: JeebOutlinedCard.defaultPadding,
        trailing: _ToggleTrack(value: value),
        onTap: () => onChanged(!value),
      ),
    );
  }
}

/// The board's toggle (`tpl 1382`/`tpl 1392`). Material's `Switch` draws a
/// 52×32 track with no way to reach the lit state's bloom, so the shape is
/// painted here instead of fought with.
class _ToggleTrack extends StatelessWidget {
  const _ToggleTrack({required this.value});

  /// 46×26 track, Ø20 knob inset 3 on every side.
  static const double trackWidth = 46;
  static const double trackHeight = 26;
  static const double knobDiameter = 20;
  static const double knobInset = 3;

  /// `0 0 12px rgba(215,59,0,.5)` — the ON bloom.
  static const double glowBlur = 12;
  static const double glowAlpha = 0.5;

  final bool value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roles = context.jeebRoles;
    final semantics = Theme.of(context).extension<JeebSemanticColors>()!;

    return SizedBox(
      width: trackWidth,
      height: trackHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: value ? roles.accent : semantics.glassFillPressed,
          borderRadius: OmdsBorderRadius.pill,
          boxShadow: value
              ? <BoxShadow>[
                  BoxShadow(
                    color: roles.accent.withValues(alpha: glowAlpha),
                    blurRadius: glowBlur,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(knobInset),
          child: Align(
            // Directional so the knob travels to the reading-end when on, and
            // mirrors with the layout instead of pinning itself to the right.
            alignment: value
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: SizedBox(
              width: knobDiameter,
              height: knobDiameter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.onPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
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
                // CF4 (owner-flagged): the tile reads "Door codes"; the
                // category also covers sign-in OTP, so "Security codes" stands.
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
