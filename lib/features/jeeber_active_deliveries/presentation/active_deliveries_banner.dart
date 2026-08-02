import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../application/active_deliveries_cubit.dart';
import '../domain/active_delivery_summary.dart';

class ActiveDeliveriesBanner extends StatelessWidget {
  const ActiveDeliveriesBanner({
    super.key,
    required this.onOpenChat,
    required this.onManageDelivery,
  });

  final void Function(ActiveDeliverySummary delivery) onOpenChat;

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
            padding: const EdgeInsetsDirectional.only(
              start: Spacing.medium,
              top: Spacing.xSmall,
              end: Spacing.medium,
            ),
            child: _ActiveDeliveriesCardList(
              deliveries: state.deliveries,
              onOpenChat: onOpenChat,
              onManageDelivery: onManageDelivery,
              l10n: l10n,
            ),
          ),
        );
      },
    );
  }
}

class _ActiveDeliveriesCardList extends StatefulWidget {
  const _ActiveDeliveriesCardList({
    required this.deliveries,
    required this.onOpenChat,
    required this.onManageDelivery,
    required this.l10n,
  });

  final List<ActiveDeliverySummary> deliveries;
  final void Function(ActiveDeliverySummary delivery) onOpenChat;
  final void Function(ActiveDeliverySummary delivery) onManageDelivery;
  final AppLocalizations l10n;

  @override
  State<_ActiveDeliveriesCardList> createState() =>
      _ActiveDeliveriesCardListState();
}

class _ActiveDeliveriesCardListState extends State<_ActiveDeliveriesCardList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActiveDeliveriesSummaryRow(
          expanded: _expanded,
          totalCount: widget.deliveries.length,
          l10n: widget.l10n,
          onToggle: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          const SizedBox(height: Spacing.small),
          for (final delivery in widget.deliveries)
            _ActiveDeliveryCard(
              delivery: delivery,
              onOpenChat: () => widget.onOpenChat(delivery),
              onManageDelivery: () => widget.onManageDelivery(delivery),
              l10n: widget.l10n,
            ),
        ],
      ],
    );
  }
}

const int _kActiveDeliveriesSummaryTitleMaxLines = 2;

class _ActiveDeliveriesSummaryRow extends StatelessWidget {
  const _ActiveDeliveriesSummaryRow({
    required this.expanded,
    required this.totalCount,
    required this.l10n,
    required this.onToggle,
  });

  final bool expanded;
  final int totalCount;
  final AppLocalizations l10n;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.jeeberActiveDeliveriesTitle,
            maxLines: _kActiveDeliveriesSummaryTitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Semantics(
          identifier: 'jeeber_active_deliveries_view_all',
          child: OmdsPrimaryButton(
            variant: OmdsButtonVariant.text,
            text: expanded
                ? l10n.jeeberActiveDeliveriesShowLess
                : l10n.jeeberActiveDeliveriesViewAll(totalCount),
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
      child: Semantics(
        identifier: 'jeeber_active_delivery_row_${delivery.id}',
        button: true,
        child: OMDSGlassCard(
          backgroundColor: colorScheme.surfaceContainerLow,
          borderRadius: OMDSBorderRadius.lg,
          padding: EdgeInsets.zero,
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: UIConstants.dividerWidth,
          ),
          child: InkWell(
            onTap: onOpenChat,
            borderRadius: OmdsBorderRadius.large,
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
                    deliveryId: delivery.id,
                    l10n: l10n,
                    onOpenChat: onOpenChat,
                    onManageDelivery: onManageDelivery,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveDeliveryCardActions extends StatelessWidget {
  const _ActiveDeliveryCardActions({
    required this.deliveryId,
    required this.l10n,
    required this.onOpenChat,
    required this.onManageDelivery,
  });

  final String deliveryId;
  final AppLocalizations l10n;
  final VoidCallback onOpenChat;
  final VoidCallback onManageDelivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final openChat = Semantics(
      identifier: 'jeeber_active_delivery_open_chat_$deliveryId',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.jeeberActiveDeliveriesOpenChat,
        onTap: onOpenChat,
        child: _ButtonLabel(
          icon: Icon(Icons.chat_bubble_outline, color: colorScheme.onPrimary),
          label: l10n.jeeberActiveDeliveriesOpenChat,
          style: labelStyle?.copyWith(color: colorScheme.onPrimary),
        ),
      ),
    );
    final manage = Semantics(
      identifier: 'jeeber_active_delivery_manage_$deliveryId',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.jeeberActiveDeliveriesManage,
        variant: OmdsButtonVariant.outlined,
        onTap: onManageDelivery,
        child: _ButtonLabel(
          icon: const Icon(Icons.local_shipping_outlined),
          label: l10n.jeeberActiveDeliveriesManage,
          style: labelStyle?.copyWith(color: colorScheme.primary),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
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

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.icon,
    required this.label,
    required this.style,
  });

  final Widget icon;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: Spacing.xSmall),
        Flexible(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final JeeberDeliveryStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsChip(
      label: _label(l10n, status),
      isSelected: true,
      selectedColor: colorScheme.primaryContainer,
      selectedTextColor: colorScheme.onPrimaryContainer,
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
      case JeeberDeliveryStatus.cancelled:
        return l10n.activeDeliveryCancelledTitle;
      case JeeberDeliveryStatus.expired:
        return l10n.activeDeliveryExpiredTitle;
      case JeeberDeliveryStatus.disputed:
        return l10n.activeDeliveryDisputedTitle;
    }
  }
}
