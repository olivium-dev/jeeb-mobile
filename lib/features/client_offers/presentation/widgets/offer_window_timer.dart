import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/countdown_format.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../core/widgets/jeeb/jeeb_meter.dart';
import '../../../../l10n/app_localizations.dart';

/// The offer-window strip above the list (redesign-2026-08 screen 11).
///
/// One line that merges the two facts the customer is waiting on — how many
/// bids have landed and how long the window still has — plus a meter that makes
/// the countdown legible at a glance. Reads a `Duration` rather than a wall
/// clock so the cubit owns "now" and tests can drive expiry deterministically.
///
/// Three states, and only the first is drawn on the board:
///  * **normal** — `accent` tone, an Ø8 orange dot, the merged strip string and
///    the meter;
///  * **urgent** (≤30s) — `warning` tone, a timer glyph. A sprint-009 semantic
///    fix: attention is warning, not error;
///  * **expired** — `error` tone, the terminal copy, no meter (there is nothing
///    left to measure).
class OfferWindowTimer extends StatelessWidget {
  const OfferWindowTimer({
    super.key,
    required this.remaining,
    required this.expired,
    this.offerCount = 0,
    this.progress,
  });

  /// Seconds at or below which the window reads as urgent.
  static const int urgentThresholdSeconds = 30;

  /// Time left on the server-stamped display deadline, already clamped to
  /// non-negative by the state.
  final Duration remaining;

  /// True only when the latest server snapshot says the request expired.
  final bool expired;

  /// How many live bids are in the list — the strip's leading fact.
  final int offerCount;

  /// Fraction of the observed window still left, or **null when the app has no
  /// honest denominator** (the gateway sends a deadline, never a window
  /// length). Null renders the meter's track with no fill; it never guesses.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final roles = context.jeebRoles;
    final text = context.jeebText;
    final isUrgent = !expired && remaining.inSeconds <= urgentThresholdSeconds;

    final tone = expired
        ? JeebInfoNoteTone.error
        : isUrgent
            ? JeebInfoNoteTone.warning
            : JeebInfoNoteTone.accent;
    final foreground = expired
        ? roles.onErrorContainer
        : isUrgent
            ? roles.onWarningContainer
            : colors.onSurface;

    final label = Text(
      expired
          ? l10n.offersWindowExpired
          : l10n.offersWindowStrip(
              offerCount,
              CountdownFormat.format(remaining),
            ),
      style: text.bodySmall.copyWith(
        fontWeight: FontWeight.w700,
        color: foreground,
        // A countdown that reflows every second is unreadable — fix the digit
        // advance so only the glyphs change.
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return JeebInfoNote(
      key: const Key('offer-window-timer'),
      tone: tone,
      // The board's normal state leads with a bare orange dot; the two
      // attention states keep the timer glyph they were given in sprint-009,
      // because a coloured dot alone does not read as "this ran out".
      leading: expired || isUrgent
          ? Icon(
              expired ? Icons.timer_off_outlined : Icons.timer_outlined,
              size: JeebInfoNote.stripIconSize,
              color: foreground,
            )
          : _WindowDot(color: roles.accent),
      label: label,
      // Nothing left to measure once the window is gone.
      trailing: expired ? null : JeebMeter(value: progress),
      identifier: 'offer_review_window_strip',
    );
  }
}

/// The Ø8 accent dot the board draws at the head of the strip.
class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: Sizes.xSmall,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
