import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Countdown strip shown at the top of the broadcasting-phase chat.
///
/// Displays the seconds remaining in the offer window. When [expiresAt] is
/// null or already past, the strip is hidden. The timer updates every second
/// via an internal [Timer.periodic] so the widget is self-contained — the
/// cubit doesn't need to manage ticking.
class BroadcastTtlIndicator extends StatefulWidget {
  const BroadcastTtlIndicator({
    super.key,
    required this.expiresAt,
  });

  /// UTC instant when the current offer window closes. Pass null to hide the
  /// indicator (e.g. after the phase transitions to accepted).
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
