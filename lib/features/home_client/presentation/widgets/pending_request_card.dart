import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/client_home_request.dart';
import 'active_request_card.dart' show ClientHomeTierBadge;

/// Pending-requests row matching the Figma design (node 56535:1783).
///
/// The pending list is intentionally leaner than the In-Progress card: there
/// is no avatar, no progress bar and no CTA — just the order id, an items
/// summary, the tier badge, and a hairline divider. A request lands here once
/// the sender has submitted it but before any Jeeber has replied with an offer.
class PendingRequestCard extends StatelessWidget {
  const PendingRequestCard({
    super.key,
    required this.request,
    this.onTap,
  });

  final ClientHomeRequest request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'pending_requests_item_${request.id}',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: Column(
            children: [
              _PendingRow(request: request),
              Padding(
                padding: const EdgeInsetsDirectional.only(top: Spacing.small),
                child: Divider(height: 1, color: colorScheme.outlineVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PendingHeader(request: request),
        const SizedBox(height: Spacing.twoXSmall),
        _PendingSummary(text: request.summaryLine),
      ],
    );
  }
}

class _PendingHeader extends StatelessWidget {
  const _PendingHeader({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            request.displayId ?? request.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.secondaryContainer,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierBadge(tier: request.tier),
      ],
    );
  }
}

class _PendingSummary extends StatelessWidget {
  const _PendingSummary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
        letterSpacing: 0.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
