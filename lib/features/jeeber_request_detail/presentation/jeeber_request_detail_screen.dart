import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/formatting/friendly_reference.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../domain/services/prohibited_item_report_service.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/jeeber_request_detail_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

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

class _RequestSummaryRows extends StatelessWidget {
  const _RequestSummaryRows({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = request.description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description != null && description.isNotEmpty) ...[
          Semantics(
            identifier: 'jeeber_request_detail_description',
            child: _DetailRow(
              icon: Icons.shopping_bag_outlined,
              label: l10n.jeeberRequestDetailSectionDescription,
              value: description,
            ),
          ),
          const SizedBox(height: Spacing.medium),
        ],
        _DetailRow(
          icon: Icons.adjust,
          label: l10n.jeeberRequestDetailSectionPickup,
          value: request.shortLabel,
        ),
        const SizedBox(height: Spacing.medium),
        _DetailRow(
          icon: Icons.confirmation_number_outlined,
          label: l10n.jeeberRequestDetailReference,
          value: friendlyReference(request.id),
        ),
      ],
    );
  }
}

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
        Expanded(
          child: _DetailRowText(label: label, value: value),
        ),
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
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real device plus the fixture's 1 dp
/// outline (12 dp) and its caption strip (44 dp).
const Size _jeeberRequestDetailScreenPhoneCanvas = Size(402, 888);

/// The same, for the 320 x 568 floor.
const Size _jeeberRequestDetailScreenCompactCanvas = Size(332, 612);

/// Ids handed to `onDeclined`, in tap order.
/// A "Decline request" button wired to `() {}` looks exactly like one wired to
final List<String> jeeberRequestDetailScreenDeclines = <String>[];

/// Resets [jeeberRequestDetailScreenDeclines]; the list is top-level, so one
/// test's taps would otherwise leak into the next.
void jeeberRequestDetailScreenResetDeclines() =>
    jeeberRequestDetailScreenDeclines.clear();

/// Mounts the screen the way `/jeeber/requests/:id` mounts it, in one
/// simulated [JeeberRequestDetailScreenWindow].
Widget _jeeberRequestDetailScreenHosted({
  required JeeberRequestDetailScreenWindow window,
  required FeedRequest request,
  required String payloadLabel,
}) =>
    JeeberRequestDetailScreenPreviewHost(
      window: window,
      payloadLabel: payloadLabel,
      screen: JeeberRequestDetailScreen(
        request: request,
        reportService: jeeberRequestDetailScreenReportService,
        onDeclined: jeeberRequestDetailScreenDeclines.add,
      ),
    );

/// The reference reading, and the state the Screen Catalog calls "With request
/// description (G1)": a feed-row tap on a request whose client typed what they
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · description present (G1)',
  size: _jeeberRequestDetailScreenPhoneCanvas,
  matrix: true,
)
Widget jeeberRequestDetailScreenFullRequest() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phone,
      request: JeeberRequestDetailScreenRequests.described,
      payloadLabel: 'description present (G1)',
    );

/// The catalog's second designed state: `description` is null, which is legal
/// on the feed DTO and normal on older items.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · no description (legacy payload)',
  size: _jeeberRequestDetailScreenPhoneCanvas,
)
Widget jeeberRequestDetailScreenNoDescription() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phone,
      request: JeeberRequestDetailScreenRequests.withoutDescription,
      payloadLabel: 'no description (legacy payload)',
    );

/// The longest plausible payload on the reference device: a real shopping list,
/// a pickup label with a landmark in it, and a gateway UUID.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · longest payload',
  size: _jeeberRequestDetailScreenPhoneCanvas,
  matrix: true,
)
Widget jeeberRequestDetailScreenLongest() => _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phone,
      request: JeeberRequestDetailScreenRequests.longest,
      payloadLabel: 'longest payload',
    );

/// The degraded feed payload: no description AND no pickup label.
/// `DioRequestFeedRepository` documents this shape — it degrades a feed item
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · pickup label empty (feed degrade)',
  size: _jeeberRequestDetailScreenPhoneCanvas,
)
Widget jeeberRequestDetailScreenUnlabelledPickup() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phone,
      request: JeeberRequestDetailScreenRequests.unlabelledPickup,
      payloadLabel: 'pickup label empty (feed degrade)',
    );

/// The same G1 request on the small-phone floor: 320 x 568, no system chrome.
/// The action bar's 156 dp is a much bigger bite out of a 568 dp screen than
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact 320 × 568',
  size: _jeeberRequestDetailScreenCompactCanvas,
)
Widget jeeberRequestDetailScreenCompact() => _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.compact,
      request: JeeberRequestDetailScreenRequests.described,
      payloadLabel: 'description present (G1)',
    );

/// The accessibility ceiling with the worst content: 200% text on the reference
/// phone, carrying the longest payload.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · EN 200% · longest payload',
  size: _jeeberRequestDetailScreenPhoneCanvas,
)
Widget jeeberRequestDetailScreenLargeText() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phoneLargeText,
      request: JeeberRequestDetailScreenRequests.longest,
      payloadLabel: 'longest payload',
    );

/// The worst case the app supports: the 320 dp floor at 200% text.
/// Both ceilings at once, against a bottom bar that does not shrink — 156 dp of
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact 320 × 568 · EN 200%',
  size: _jeeberRequestDetailScreenCompactCanvas,
)
Widget jeeberRequestDetailScreenCompactLargeText() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.compactLargeText,
      request: JeeberRequestDetailScreenRequests.described,
      payloadLabel: 'description present (G1)',
    );
