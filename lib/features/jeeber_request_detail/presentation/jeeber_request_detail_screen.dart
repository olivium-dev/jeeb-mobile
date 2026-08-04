import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/formatting/friendly_reference.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../domain/services/prohibited_item_report_service.dart';

/// Jeeber request-detail hub (T-mobile-013 / T-MOB-FIX-001) — the only in-app
/// entry to the offer composer (`/jeeber/requests/:id/offer`).
///
/// MIDNIGHT M3-06: no tile was drawn. Page shape, field and CTA rung derive
/// from R17 (offer composer); the card's ink ranking from R16's feed card.
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
      backgroundColor: Colors.transparent,
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
        // R17's measured anchor: orange glow start-side, off-canvas. R17
        // declares no periwinkle wash, so none is passed.
        glowPlacement: JeebFieldGlowPlacement.topStart,
        animateDecor: false,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pop-GUARDED: a cold push-tap has nothing to pop and must not
              // blank the surface.
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

/// Section label over one grouped card. The card ends where its content ends —
/// the residual space below stays field, uncentred and unpadded (R17).
class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
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

/// The genuinely-present [FeedRequest] fields, one row each inside the grouped
/// card. G1 (sprint-009 P0): the client's own text leads, full length.
///
/// R16 ranking: the request content is the card headline (`cardTitle` w700 on
/// `onSurface`), the field name its muted qualifier. No glyph column — neither
/// R16's request card nor R17's money card draws one.
class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = request.description?.trim();
    // TODO(midnight): omitted — R16's card also carries a tier chip, an age and
    // `{distance} · {neighbourhood}`; FeedRequest carries none of the three.
    return JeebOutlinedCard.grouped(
      key: const Key('jeeber-request-detail-summary'),
      children: [
        if (description != null && description.isNotEmpty)
          Semantics(
            identifier: 'jeeber_request_detail_description',
            child: JeebListRow(
              title: description,
              titleStyle: context.jeebText.cardTitle,
              subtitle: l10n.jeeberRequestDetailSectionDescription,
              showChevron: false,
            ),
          ),
        JeebListRow(
          title: request.shortLabel,
          subtitle: l10n.jeeberRequestDetailSectionPickup,
          showChevron: false,
        ),
        JeebListRow(
          title: friendlyReference(request.id),
          subtitle: l10n.jeeberRequestDetailReference,
          showChevron: false,
        ),
      ],
    );
  }
}

/// Docked footer: the orange make-offer act over a text-rank decline.
///
/// Both neighbours draw THIS act orange (R16's freshest offer pill, R17's h58
/// docked pill), and the label is R16's — this button opens the composer.
/// Declining is the secondary WORD, not a second pill (R4/R16 ruling; the
/// `below` slot is the board's 10-style line under the docked pill).
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onMakeOffer, required this.onDecline});

  final VoidCallback onMakeOffer;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebCtaFooter.single(
      below: JeebCtaButton.text(
        label: l10n.jeeberRequestDetailDeclineButton,
        onTap: onDecline,
        identifier: 'jeeber-request-detail-decline',
      ),
      child: JeebCtaButton.accent(
        label: l10n.jeeberFeedMakeOfferAction,
        height: JeebCtaButton.primaryHeightTall,
        onTap: onMakeOffer,
        identifier: 'jeeber-request-detail-make-offer',
      ),
    );
  }
}
