import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

/// Countdown badge above the offer list. Reads `Duration` rather than wall
/// clock so the cubit owns "now" and tests can drive expiry deterministically.
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
    // Semantic roles: expired = error (terminal), urgent = warning (attention),
    // otherwise neutral surface. Urgent previously misused the error pair.
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
                : l10n.offersWindowRemaining(_format(remaining)),
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// Formats `Duration` as `m:ss`. Above an hour the minutes overflow rather
  /// than promoting to `h:mm:ss` — the window cap is always under 30 min so a
  /// 3-digit minute count never appears in practice.
  static String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
