import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_snapshot.dart';

/// Single-line banner above the status content shown only for terminal
/// lifecycle states. Active deliveries don't render it (returning null is
/// the screen's responsibility; this widget renders a SizedBox otherwise so
/// it can sit safely inside a Column).
///
/// redesign-2026-08: the hand-rolled container is [JeebInfoNote] now. The tone
/// split is unchanged and still deliberate — completed is a SUCCESS state (it
/// was the brand tertiary orange before the sprint-009 sweep), cancelled keeps
/// the soft error family — and the kit resolves both off `jeebRoles`, so the
/// semantic-role guard this file is pinned to holds by construction.
class DeliveryLifecycleBanner extends StatelessWidget {
  const DeliveryLifecycleBanner({super.key, required this.lifecycle});

  static const Key rootKey = Key('delivery-status-lifecycle-banner');

  final DeliveryLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCompleted = lifecycle == DeliveryLifecycle.completed;
    final isCancelled = lifecycle == DeliveryLifecycle.cancelled;
    if (!isCompleted && !isCancelled) {
      return const SizedBox.shrink();
    }
    // Filled glyphs (R10) — the outline pair reads as decoration at this size.
    if (isCompleted) {
      return JeebInfoNote.success(
        key: rootKey,
        icon: Icons.check_circle,
        text: l10n.deliveryCompletedBanner,
      );
    }
    return JeebInfoNote.error(
      key: rootKey,
      icon: Icons.cancel,
      text: l10n.deliveryCancelledBanner,
    );
  }
}
