import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/recent_delivery_summary.dart';

class RecentDeliveryCard extends StatelessWidget {
  const RecentDeliveryCard({
    super.key,
    required this.summary,
    required this.onReorder,
  });

  final RecentDeliverySummary summary;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: _RecentDeliveryRow(summary: summary, onReorder: onReorder),
    );
  }
}

class _RecentDeliveryRow extends StatelessWidget {
  const _RecentDeliveryRow({required this.summary, required this.onReorder});

  final RecentDeliverySummary summary;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        const _RecentDeliveryIcon(),
        const SizedBox(width: Spacing.small),
        Expanded(child: _RecentDeliveryText(summary: summary)),
        const SizedBox(width: Spacing.small),
        OmdsPrimaryButton(
          key: Key('recent-delivery-reorder-${summary.id}'),
          variant: OmdsButtonVariant.text,
          text: l10n.homeReorderAction,
          onTap: onReorder,
        ),
      ],
    );
  }
}

class _RecentDeliveryIcon extends StatelessWidget {
  const _RecentDeliveryIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.xLarge,
      height: Sizes.xLarge,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Icon(
        Icons.replay_outlined,
        color: scheme.onPrimaryContainer,
        size: Sizes.large,
      ),
    );
  }
}

class _RecentDeliveryText extends StatelessWidget {
  const _RecentDeliveryText({required this.summary});

  final RecentDeliverySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecentDeliveryTitle(text: summary.title),
        const SizedBox(height: Spacing.twoXSmall),
        _RecentDeliverySubtitle(text: summary.destinationLabel),
      ],
    );
  }
}

class _RecentDeliveryTitle extends StatelessWidget {
  const _RecentDeliveryTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _RecentDeliverySubtitle extends StatelessWidget {
  const _RecentDeliverySubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
