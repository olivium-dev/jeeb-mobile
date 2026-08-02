import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/countdown_format.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

class OfferWindowTimer extends StatelessWidget {
  const OfferWindowTimer({
    super.key,
    required this.remaining,
    required this.expired,
  });

  final Duration remaining;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final roles = context.jeebRoles;
    final isUrgent = !expired && remaining.inSeconds <= 30;
    final foreground = expired
        ? roles.onErrorContainer
        : isUrgent
            ? roles.onWarningContainer
            : colors.onSurface;
    final background = expired
        ? roles.errorContainer
        : isUrgent
            ? roles.warningContainer
            : colors.surfaceContainerHighest;
    return Container(
      key: const Key('offer-window-timer'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            expired ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: Sizes.medium,
            color: foreground,
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(
            expired
                ? l10n.offersWindowExpired
                : l10n.offersWindowRemaining(
                    CountdownFormat.format(remaining),
                  ),
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

}
