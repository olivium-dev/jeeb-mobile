import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../application/active_deliveries_cubit.dart';
import '../domain/active_delivery_summary.dart';

/// The jeeber's "active deliveries" banner — the real-UI entry to an ACCEPTED
/// order (iter6 real-flow blocker fix).
///
/// Mounted at the top of the jeeber Dashboard (above the pending-feed home). It
/// renders nothing while the jeeber has no active delivery, so it never
/// disturbs the empty/feed states; the moment a client accepts the jeeber's
/// offer (`GET /v1/deliveries?role=jeeber` returns the minted delivery) one
/// card appears. Tapping a card opens that order's chat (`/chat/:id`,
/// conversation already exists, keyed by the request id) — and the chat surface
/// is already role-aware for a jeeber: it exposes "Start delivery" →
/// `/jeeber/deliveries/:id/active`, which drives Ordered→…→AtDoor→Done→rating.
/// A secondary "Manage delivery" affordance opens the active-delivery screen
/// directly for a jeeber already past first contact.
///
/// [onOpenChat] / [onManageDelivery] are injected by the host (the Dashboard
/// tab) so this widget owns no navigation — keeping it testable and the route
/// strings in one place.
// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; live banner is jeeber_home's own implementation — see docs/project-understanding/reconciliation/orphans.md
class ActiveDeliveriesBanner extends StatelessWidget {
  const ActiveDeliveriesBanner({
    super.key,
    required this.onOpenChat,
    required this.onManageDelivery,
  });

  /// Open the order chat for the tapped delivery. The argument is the chat
  /// route id (conversation id when known, else the delivery/request id — the
  /// `/chat/:id` screen resolves either).
  final void Function(ActiveDeliverySummary delivery) onOpenChat;

  /// Open the active-delivery screen for the tapped delivery (the
  /// Ordered→…→AtDoor stepper). The argument is the delivery id.
  final void Function(ActiveDeliverySummary delivery) onManageDelivery;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveDeliveriesCubit, ActiveDeliveriesState>(
      builder: (context, state) {
        if (!state.hasDeliveries) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        return Semantics(
          container: true,
          identifier: 'jeeber_active_deliveries',
          explicitChildNodes: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.medium,
              Spacing.medium,
              Spacing.medium,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.jeeberActiveDeliveriesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Spacing.small),
                for (final delivery in state.deliveries)
                  _ActiveDeliveryCard(
                    delivery: delivery,
                    onOpenChat: () => onOpenChat(delivery),
                    onManageDelivery: () => onManageDelivery(delivery),
                    l10n: l10n,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({
    required this.delivery,
    required this.onOpenChat,
    required this.onManageDelivery,
    required this.l10n,
  });

  final ActiveDeliverySummary delivery;
  final VoidCallback onOpenChat;
  final VoidCallback onManageDelivery;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = delivery.title ?? l10n.jeeberActiveDeliveriesFallbackTitle;
    return Semantics(
      identifier: 'jeeber_active_delivery_row_${delivery.id}',
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: Spacing.small),
        child: InkWell(
          // Tapping the card opens the chat — the primary entry the blocker
          // stranded the jeeber out of. "Start/Manage delivery" lives in the
          // chat and on the secondary button.
          onTap: onOpenChat,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusChip(status: delivery.status, l10n: l10n),
                  ],
                ),
                if (delivery.dropoffAddress != null) ...[
                  const SizedBox(height: Spacing.xSmall),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: Sizes.small,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Spacing.twoXSmall),
                      Expanded(
                        child: Text(
                          delivery.dropoffAddress!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: Spacing.small),
                _ActiveDeliveryCardActions(
                  l10n: l10n,
                  onOpenChat: onOpenChat,
                  onManageDelivery: onManageDelivery,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's two action buttons ("Open chat" + "Manage delivery"), laid out
/// responsively so the non-ellipsizing OMDS button labels never right-overflow
/// on a narrow card.
///
/// [OmdsPrimaryButton] renders its icon + label in a `mainAxisSize.min` Row with
/// a plain (non-ellipsizing) `Text`, so an `Expanded` box narrower than that
/// intrinsic width lets the button content paint past its edge (the 39px
/// right-overflow observed on SM-S921B). Below the side-by-side threshold we
/// stack the two buttons full-width — each then has the whole card width and
/// fits its icon+label; at/above it we keep the original side-by-side Row.
class _ActiveDeliveryCardActions extends StatelessWidget {
  const _ActiveDeliveryCardActions({
    required this.l10n,
    required this.onOpenChat,
    required this.onManageDelivery,
  });

  final AppLocalizations l10n;
  final VoidCallback onOpenChat;
  final VoidCallback onManageDelivery;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final openChat = OmdsPrimaryButton(
      text: l10n.jeeberActiveDeliveriesOpenChat,
      icon: Icon(Icons.chat_bubble_outline, color: colorScheme.onPrimary),
      onTap: onOpenChat,
    );
    final manage = OmdsPrimaryButton(
      text: l10n.jeeberActiveDeliveriesManage,
      variant: OmdsButtonVariant.outlined,
      icon: const Icon(Icons.local_shipping_outlined),
      onTap: onManageDelivery,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two icon+label buttons need ~300+ logical px to sit side by side
        // without clipping their labels; below that (every standard phone card
        // width) stack them so neither overflows.
        final sideBySide = constraints.maxWidth >= Sizes.threeHundredLarge;
        if (sideBySide) {
          return Row(
            children: [
              Expanded(child: openChat),
              const SizedBox(width: Spacing.small),
              Expanded(child: manage),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            openChat,
            const SizedBox(height: Spacing.small),
            manage,
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final JeeberDeliveryStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Sizes.xSmall),
      ),
      child: Text(
        _label(l10n, status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  static String _label(AppLocalizations l10n, JeeberDeliveryStatus status) {
    switch (status) {
      case JeeberDeliveryStatus.ordered:
        return l10n.activeDeliveryStatusOrdered;
      case JeeberDeliveryStatus.picked:
        return l10n.activeDeliveryStatusPicked;
      case JeeberDeliveryStatus.inTransit:
        return l10n.activeDeliveryStatusInTransit;
      case JeeberDeliveryStatus.atDoor:
        return l10n.activeDeliveryStatusAtDoor;
      case JeeberDeliveryStatus.done:
        return l10n.activeDeliveryStatusDone;
    }
  }
}
