import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../core/widgets/jeeb/jeeb_system_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

class OfferStatusRequestsTab extends StatelessWidget {
  const OfferStatusRequestsTab({
    super.key,
    required this.status,
    required this.requests,
  });

  final ClientOfferStatus status;
  final List<ClientHomeRequest> requests;

  @override
  Widget build(BuildContext context) {
    final matching = requests
        .where((request) => request.offerStatuses.contains(status))
        .toList(growable: false);
    final l10n = AppLocalizations.of(context);
    if (matching.isEmpty) {
      return JeebEmptyState.compact(
        key: Key('offer-status-${status.name}-empty'),
        identifier: 'offer_status_filter_empty',
        headline: l10n.offerStatusFilterEmptyTitle,
        body: l10n.offerStatusFilterEmptyBody,
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      child: Column(
        key: Key('offer-status-${status.name}-list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < matching.length; index++) ...[
            if (index > 0) const SizedBox(height: Spacing.small),
            _OfferStatusRequestCard(request: matching[index], status: status),
          ],
        ],
      ),
    );
  }
}

class _OfferStatusRequestCard extends StatelessWidget {
  const _OfferStatusRequestCard({required this.request, required this.status});

  final ClientHomeRequest request;
  final ClientOfferStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return JeebGlassCard(
      identifier: 'offer_status_request_${request.id}',
      semanticLabel:
          '${request.displayId ?? request.title}, '
          '${offerStatusTitle(l10n, status)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.displayId ?? request.title,
            style: context.jeebText.cardTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            request.summaryLine,
            style: context.jeebText.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.small),
          JeebSystemChip.filled(
            label: offerStatusTitle(l10n, status),
            center: false,
            identifier: 'offer_status_request_${request.id}_${status.name}',
          ),
        ],
      ),
    );
  }
}

String offerStatusTitle(AppLocalizations l10n, ClientOfferStatus status) {
  return switch (status) {
    ClientOfferStatus.pending => l10n.offerStatusPendingTitle,
    ClientOfferStatus.submitted => l10n.offerStatusSubmittedTitle,
    ClientOfferStatus.edited => l10n.offerStatusEditedTitle,
    ClientOfferStatus.accepted => l10n.offerStatusAcceptedTitle,
    ClientOfferStatus.withdrawn => l10n.offerStatusWithdrawnTitle,
    ClientOfferStatus.expired => l10n.offerStatusExpiredTitle,
    ClientOfferStatus.superseded => l10n.offerStatusNotSelectedTitle,
  };
}
