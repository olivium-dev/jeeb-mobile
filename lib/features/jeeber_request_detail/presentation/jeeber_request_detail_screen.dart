import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../domain/services/prohibited_item_report_service.dart';

/// T-mobile-013 / T-MOB-FIX-001: Jeeber request-detail hub.
///
/// Reached from the dashboard feed-row tap (in-app `extra` payload) and from a
/// matching push-notification deep link. This is the ONLY in-app entry to the
/// offer-composition form (`/jeeber/requests/:id/offer`), so it owns the
/// "Make offer" CTA. The route already wires the offer form's `onSubmitted`
/// to `/chat`, so this screen only has to launch it.
class JeeberRequestDetailScreen extends StatefulWidget {
  const JeeberRequestDetailScreen({
    super.key,
    required this.request,
    required this.reportService,
    required this.onDeclined,
  });

  final FeedRequest request;
  final ProhibitedItemReportService reportService;
  final ValueChanged<String> onDeclined;

  @override
  State<JeeberRequestDetailScreen> createState() =>
      _JeeberRequestDetailScreenState();
}

class _JeeberRequestDetailScreenState extends State<JeeberRequestDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.jeeberRequestDetailTitle,
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _RequestSummary(request: widget.request),
            ),
            _ActionBar(
              onMakeOffer: _openOfferForm,
              onDecline: () => widget.onDeclined(widget.request.id),
            ),
          ],
        ),
      ),
    );
  }

  void _openOfferForm() {
    context.pushNamed(
      'jeeber-offer-submission',
      pathParameters: {'id': widget.request.id},
    );
  }
}

/// Summary of the [FeedRequest] payload, laid out with the same
/// `OMDSSectionCard` + detail-row idiom as the client-side delivery-details
/// card. [FeedRequest] is intentionally minimal (`id` + `shortLabel`, where
/// `shortLabel` carries the pickup label the feed row set), so this surfaces
/// ONLY those two real fields — the pickup point and the request reference —
/// rather than the prior single flat line. Richer pickup/dropoff/fee/distance
/// rows slot in here unchanged once the detail route is upgraded to carry the
/// full `DeliveryRequest` payload (a contract change, out of scope here).
class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: OMDSSectionCard(
        key: const Key('jeeber-request-detail-summary'),
        title: l10n.jeeberRequestDetailRequestSection,
        content: _RequestSummaryRows(request: request),
      ),
    );
  }
}

/// The genuinely-present fields of the [FeedRequest], one detail row each.
class _RequestSummaryRows extends StatelessWidget {
  const _RequestSummaryRows({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailRow(
          icon: Icons.adjust,
          label: l10n.jeeberRequestDetailSectionPickup,
          value: request.shortLabel,
        ),
        const SizedBox(height: Spacing.medium),
        _DetailRow(
          icon: Icons.confirmation_number_outlined,
          label: l10n.jeeberRequestDetailReference,
          value: request.id,
        ),
      ],
    );
  }
}

/// Icon-badge + label + value row, mirroring the client delivery-details card
/// idiom so jeeber and client detail screens read consistently.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRowBadge(icon: icon),
        const SizedBox(width: Spacing.medium),
        Expanded(child: _DetailRowText(label: label, value: value)),
      ],
    );
  }
}

class _DetailRowBadge extends StatelessWidget {
  const _DetailRowBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.twoXLarge,
      height: Sizes.twoXLarge,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: Sizes.medium,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _DetailRowText extends StatelessWidget {
  const _DetailRowText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: Sizes.threeXSmall),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Bottom action area: primary "Make offer" (the offer-form entry) and an
/// outlined "Decline". Each CTA carries a Semantics identifier for Maestro QA.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onMakeOffer, required this.onDecline});

  final VoidCallback onMakeOffer;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            identifier: 'jeeber-request-detail-make-offer',
            button: true,
            child: OmdsPrimaryButton(
              text: l10n.offerSubmissionTitle,
              onTap: onMakeOffer,
            ),
          ),
          const SizedBox(height: Spacing.small),
          Semantics(
            identifier: 'jeeber-request-detail-decline',
            button: true,
            child: OmdsPrimaryButton(
              text: l10n.jeeberRequestDetailDeclineButton,
              variant: OmdsButtonVariant.outlined,
              onTap: onDecline,
            ),
          ),
        ],
      ),
    );
  }
}
