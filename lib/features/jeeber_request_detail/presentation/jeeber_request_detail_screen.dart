import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/formatting/friendly_reference.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
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
///
/// redesign-2026-08: no render was drawn for this screen, so the language is
/// borrowed from its journey neighbour 17 (offer composer) — in-body
/// [JeebTopBar] over a top-aligned column at 24px gutters, one outlined card,
/// a real empty spacer, and a docked [JeebCtaFooter]. Structure, copy and
/// navigation are unchanged.
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back stays pop-GUARDED (the kit's default is
            // `Navigator.maybePop`), matching the OMDSAppBar it replaces: a
            // cold push-tap has nothing to pop and must not blank the surface.
            JeebTopBar.back(
              title: l10n.jeeberRequestDetailTitle,
              identifier: 'jeeber_request_detail_back',
            ),
            Expanded(child: _RequestSummary(request: widget.request)),
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

/// Summary of the [FeedRequest] payload: an uppercase [JeebSectionLabel] over
/// one grouped [JeebOutlinedCard] of detail rows. Surfaces the request content
/// (G1: `description` — what the customer actually asked for, rendered first
/// and in full), the pickup point, and the request reference. Richer
/// dropoff/fee/distance rows slot in here unchanged once the detail route is
/// upgraded to carry the full `DeliveryRequest` payload (a contract change,
/// out of scope here).
class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      // R1: the card ends where its content ends — the residual space below
      // stays white rather than being padded out or centred.
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.large,
        Spacing.xLarge,
        Spacing.xLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JeebSectionLabel(l10n.jeeberRequestDetailRequestSection),
          const SizedBox(height: Spacing.small),
          _RequestSummaryCard(request: request),
        ],
      ),
    );
  }
}

/// The genuinely-present fields of the [FeedRequest], one [JeebListRow] each
/// inside a grouped card (the card draws the inset dividers).
///
/// G1 (sprint-009 P0): the customer's own "What do you need?" text leads the
/// card — it is the content the jeeber is agreeing to buy/deliver, so it
/// renders FIRST, full-length (no truncation), above pickup and reference.
///
/// R4 ink ranking: the value is the fact (navy w700, the row title) and the
/// field name is its qualifier (periwinkle, the row subtitle beneath) — the
/// same shape the redesigned settings and wallet groups use.
class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = request.description?.trim();
    // TODO(redesign-24): needs gateway tier / fee / distance / dropoff on the
    // feed DTO before this card can carry 17's tier chip and money band —
    // FeedRequest holds only id + shortLabel + description. Omitted, not faked.
    return JeebOutlinedCard.grouped(
      key: const Key('jeeber-request-detail-summary'),
      children: [
        if (description != null && description.isNotEmpty)
          Semantics(
            identifier: 'jeeber_request_detail_description',
            child: JeebListRow(
              // R10: filled, single-colour glyphs — no outline variants.
              icon: Icons.shopping_bag,
              title: description,
              subtitle: l10n.jeeberRequestDetailSectionDescription,
              showChevron: false,
            ),
          ),
        JeebListRow(
          icon: Icons.place,
          title: request.shortLabel,
          subtitle: l10n.jeeberRequestDetailSectionPickup,
          showChevron: false,
        ),
        JeebListRow(
          icon: Icons.confirmation_number,
          title: friendlyReference(request.id),
          subtitle: l10n.jeeberRequestDetailReference,
          showChevron: false,
        ),
      ],
    );
  }
}

/// Docked action footer: primary "Make offer" (the offer-form entry) over an
/// outlined "Decline". Each CTA carries a Semantics identifier for Maestro QA —
/// now emitted by the kit button itself rather than an outer wrapper, so the
/// values are unchanged and there is no nested button node.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onMakeOffer, required this.onDecline});

  final VoidCallback onMakeOffer;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebCtaFooter.single(
      below: JeebCtaButton.outline(
        label: l10n.jeeberRequestDetailDeclineButton,
        onTap: onDecline,
        identifier: 'jeeber-request-detail-decline',
      ),
      child: JeebCtaButton.primary(
        label: l10n.offerSubmissionTitle,
        onTap: onMakeOffer,
        identifier: 'jeeber-request-detail-make-offer',
      ),
    );
  }
}
