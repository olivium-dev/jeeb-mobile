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

/// Lean summary of the [FeedRequest] payload. The entity is intentionally
/// minimal today (`id` + `shortLabel`); richer pickup/dropoff fields land with
/// the realistic feed-card ticket and slot in here without touching the CTAs.
class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.jeeberRequestDetailSectionDescription,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: Spacing.small),
          Text(
            request.shortLabel,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
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
