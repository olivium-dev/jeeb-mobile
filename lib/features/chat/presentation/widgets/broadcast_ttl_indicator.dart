import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Countdown shown during broadcasting phase. Self-contained: internal Timer.periodic ticks every second.
class BroadcastTtlIndicator extends StatefulWidget {
  const BroadcastTtlIndicator({
    super.key,
    required this.expiresAt,
  });

  /// UTC instant when offer window closes; null hides indicator.
  final DateTime? expiresAt;

  @override
  State<BroadcastTtlIndicator> createState() => _BroadcastTtlIndicatorState();
}

class _BroadcastTtlIndicatorState extends State<BroadcastTtlIndicator> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _update(),
    );
  }

  @override
  void didUpdateWidget(BroadcastTtlIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    final expires = widget.expiresAt;
    if (expires == null) {
      if (mounted) setState(() => _secondsLeft = 0);
      return;
    }
    final remaining = expires.difference(DateTime.now().toUtc()).inSeconds;
    if (mounted) setState(() => _secondsLeft = remaining < 0 ? 0 : remaining);
  }

  @override
  Widget build(BuildContext context) {
    final expires = widget.expiresAt;
    if (expires == null || _secondsLeft <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('broadcast-ttl-indicator'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      color: colorScheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: Sizes.medium,
            color: colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              l10n.chatBroadcastTtlLabel(_secondsLeft),
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [BroadcastTtlIndicator] — run with

/// Canvas box for the ordinary counts: phone width, with room for the
/// 200%-text rendering to wrap into.
const Size _broadcastTtlIndicatorStripBox = Size(390, 120);

/// Canvas box for the four-digit count. Its label is the longest the widget can
/// produce — and longer again in Arabic — so it is given headroom beyond
const Size _broadcastTtlIndicatorTallStripBox = Size(390, 200);

/// Canvas box for the two hidden states. Deliberately still 390 px wide: the
/// point of these previews is that the band occupies NO height, which only
const Size _broadcastTtlIndicatorHiddenBox = Size(390, 64);

/// An expiry [seconds] from now, in UTC — the shape `broadcastExpiresAt`
/// produces.
DateTime _broadcastTtlIndicatorInSeconds(int seconds) => DateTime.now().toUtc().add(
      Duration(seconds: seconds, milliseconds: 500),
    );

/// The moment the first offer card lands: the full five-minute window, which is
/// the widest count `ChatState.broadcastExpiresAt` can legitimately derive.
@JeebPreview(group: 'chat', name: 'Fresh 5-minute window', size: _broadcastTtlIndicatorStripBox)
Widget broadcastTtlIndicatorFreshWindow() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(300));

/// The urgent end of the window, five seconds out.
/// The band is a fixed `tertiaryContainer` fill at every count — it does not
@JeebPreview(group: 'chat', name: 'Final seconds', size: _broadcastTtlIndicatorStripBox)
Widget broadcastTtlIndicatorFinalSeconds() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(5));

/// The singular boundary — the last count before the strip hides itself.
/// `chatBroadcastTtlLabel` is a flat template (`_get(...).replaceFirst`), so
@JeebPreview(group: 'chat', name: 'One second left', size: _broadcastTtlIndicatorStripBox)
Widget broadcastTtlIndicatorOneSecond() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(1));

/// Layout ceiling: a four-digit count, which a real device reaches on clock
/// skew.
@JeebPreview(group: 'chat', name: 'Clock-skewed long count', size: _broadcastTtlIndicatorTallStripBox)
Widget broadcastTtlIndicatorClockSkew() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(3900));

/// The window has already closed: `expiresAt` is thirty seconds in the past.
/// The band must collapse to nothing — never "closes in 0s", and never a
@JeebPreview(group: 'chat', name: 'Expired window', size: _broadcastTtlIndicatorHiddenBox)
Widget broadcastTtlIndicatorExpired() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(-30));

/// No window at all.
/// Production reaches this whenever `broadcastExpiresAt` returns null: the
@JeebPreview(group: 'chat', name: 'No window', size: _broadcastTtlIndicatorHiddenBox)
Widget broadcastTtlIndicatorNoWindow() =>
    const BroadcastTtlIndicator(expiresAt: null);
