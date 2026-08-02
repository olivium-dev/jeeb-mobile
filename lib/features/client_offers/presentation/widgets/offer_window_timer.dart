import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/countdown_format.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [OfferWindowTimer] — run with

/// The width the offer list really gives the band on a 390pt phone: the
/// `ListView` in `client_offers_screen.dart` insets `Spacing.medium` (16) on
const double _offerWindowTimerContentWidth = 358;

/// Canvas box for the ordinary counts: phone width, with room for the
/// 200%-text rendering to grow into.
const Size _offerWindowTimerBandBox = Size(390, 120);

/// Canvas box for the longest label the widget can emit. Given headroom beyond
/// [_offerWindowTimerBandBox] so a wrap is visible rather than clipped by the
const Size _offerWindowTimerTallBandBox = Size(390, 180);

/// Puts the band at the width its production list really has, pinned to the
/// leading top corner the way the list stacks it.
Widget _offerWindowTimerHosted(
  Duration remaining, {
  bool expired = false,
  double width = _offerWindowTimerContentWidth,
}) =>
    Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        child: OfferWindowTimer(remaining: remaining, expired: expired),
      ),
    );

/// The state that ships for most of the window: a couple of minutes left, well
/// clear of the urgent threshold.
@JeebPreview(
  group: 'client_offers',
  name: 'Fresh window · 2:05',
  size: _offerWindowTimerBandBox,
)
Widget offerWindowTimerFreshWindow() =>
    _offerWindowTimerHosted(const Duration(minutes: 2, seconds: 5));

/// The last second that is NOT urgent — the off-by-one guard for
/// `remaining.inSeconds <= 30`.
@JeebPreview(
  group: 'client_offers',
  name: 'Threshold · 0:31',
  size: _offerWindowTimerBandBox,
)
Widget offerWindowTimerJustAboveUrgent() =>
    _offerWindowTimerHosted(const Duration(seconds: 31));

/// The exact second the band escalates: `inSeconds <= 30` turns the neutral
/// surface into the WARNING container pair.
@JeebPreview(
  group: 'client_offers',
  name: 'Urgent · 0:30',
  size: _offerWindowTimerBandBox,
)
Widget offerWindowTimerUrgent() =>
    _offerWindowTimerHosted(const Duration(seconds: 30));

/// The bottom of the window: single-digit seconds, which must be zero-padded.
/// `0:04`, not `0:4`. `test/offer_window_timer_test.dart` asserts exactly this
@JeebPreview(
  group: 'client_offers',
  name: 'Final seconds · 0:04',
  size: _offerWindowTimerBandBox,
)
Widget offerWindowTimerFinalSeconds() =>
    _offerWindowTimerHosted(const Duration(seconds: 4));

/// The terminal state — and deliberately NOT a zero countdown.
/// The screen passes the two inputs from two different authorities:
@JeebPreview(
  group: 'client_offers',
  name: 'Expired · stale 1:12 suppressed',
  size: _offerWindowTimerBandBox,
)
Widget offerWindowTimerExpired() => _offerWindowTimerHosted(
      const Duration(minutes: 1, seconds: 12),
      expired: true,
    );

/// Layout ceiling: the 24-hour window the gateway falls back to.
/// This widget used to say out loud that it was safe — *"the window cap is
@JeebPreview(
  group: 'client_offers',
  name: 'Safe-window fallback · 23:53:18',
  size: _offerWindowTimerTallBandBox,
)
Widget offerWindowTimerSafeWindowFallback() => _offerWindowTimerHosted(
      const Duration(hours: 23, minutes: 53, seconds: 18),
    );
