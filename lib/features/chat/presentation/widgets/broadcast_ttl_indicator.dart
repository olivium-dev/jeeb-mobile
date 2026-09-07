import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_system_chip.dart';
import '../../../../l10n/app_localizations.dart';

/// Countdown chip shown at the top of the broadcasting-phase chat.
///
/// Displays the seconds remaining in the offer window. When [expiresAt] is
/// null or already past, the chip is hidden. The timer updates every second
/// via an internal [Timer.periodic] so the widget is self-contained — the
/// cubit doesn't need to manage ticking.
///
/// The instant is read from [now], not from a hard-wired `DateTime.now()`: a
/// fixture that pins [expiresAt] must pin the other side of it too (X3).
///
/// The full-bleed `tertiaryContainer` slab is gone: a countdown is exactly
/// "what is expiring right now", which is the one thing R5 rations the accent
/// for, so it is the kit's [JeebSystemChip.accent] — an outline pill in the
/// orange, not a band of it.
class BroadcastTtlIndicator extends StatefulWidget {
  const BroadcastTtlIndicator({
    super.key,
    required this.expiresAt,
    this.now = DateTime.now,
  });

  /// UTC instant when the current offer window closes. Pass null to hide the
  /// indicator (e.g. after the phase transitions to accepted).
  final DateTime? expiresAt;

  /// Reads the instant the countdown is measured against. Production leaves
  /// the default device clock; fixtures pass a pinned instant.
  final DateTime Function() now;

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
      if (mounted && _secondsLeft != 0) setState(() => _secondsLeft = 0);
      return;
    }
    final remaining = expires.difference(widget.now().toUtc()).inSeconds;
    final next = remaining < 0 ? 0 : remaining;
    // Repainting an unchanged count would keep a pinned clock scheduling
    // frames forever, which no settle can outlast.
    if (mounted && next != _secondsLeft) setState(() => _secondsLeft = next);
  }

  @override
  Widget build(BuildContext context) {
    final expires = widget.expiresAt;
    if (expires == null || _secondsLeft <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
      child: JeebSystemChip.accent(
        key: const Key('broadcast-ttl-indicator'),
        label: l10n.chatBroadcastTtlLabel(_secondsLeft),
      ),
    );
  }
}
