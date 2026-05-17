import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

/// Active delivery card. Renders one row of a sender's in-flight request:
/// title, status pill, optional Jeeber name, optional ETA, tap-to-open.
class ActiveRequestCard extends StatelessWidget {
  const ActiveRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  final ClientHomeRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusLabel = _statusLabel(l10n, request.status);
    final etaLabel = request.etaMinutes != null
        ? l10n.homeRequestEtaMinutes(request.etaMinutes!)
        : l10n.homeRequestEtaUnknown;
    return Semantics(
      button: true,
      label: l10n.homeRequestCardSemanticLabel(
        title: request.title,
        status: statusLabel,
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Spacing.medium),
        child: InkWell(
          key: Key('active-request-card-${request.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(Spacing.medium),
          child: Container(
            padding: const EdgeInsets.all(Spacing.medium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Spacing.medium),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitleRow(title: request.title, statusLabel: statusLabel),
                const SizedBox(height: Spacing.xSmall),
                _DestinationRow(label: request.destinationLabel),
                const SizedBox(height: Spacing.xSmall),
                _FooterRow(
                  jeeberName: request.jeeberName,
                  etaLabel: etaLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _statusLabel(AppLocalizations l10n, ClientRequestStatus s) {
    switch (s) {
      case ClientRequestStatus.searching:
        return l10n.requestStatusSearching;
      case ClientRequestStatus.offersReceived:
        return l10n.requestStatusOffers;
      case ClientRequestStatus.accepted:
        return l10n.requestStatusAccepted;
      case ClientRequestStatus.atPickup:
        return l10n.requestStatusPickup;
      case ClientRequestStatus.enRoute:
        return l10n.requestStatusEnRoute;
    }
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title, required this.statusLabel});

  final String title;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.small),
        _StatusPill(label: statusLabel),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Spacing.large),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.location_on_outlined,
            size: Sizes.medium, color: scheme.onSurfaceVariant),
        const SizedBox(width: Spacing.twoXSmall),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.jeeberName, required this.etaLabel});

  final String? jeeberName;
  final String etaLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        if (jeeberName != null) ...[
          Icon(Icons.person_outline,
              size: Sizes.medium, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              l10n.homeRequestJeeberAssigned(jeeberName!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Spacing.small),
        ],
        const Spacer(),
        Icon(Icons.schedule,
            size: Sizes.medium, color: scheme.primary),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          etaLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
