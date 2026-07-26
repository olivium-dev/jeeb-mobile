import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/order_chat_summary.dart';
import 'auto_direction_text.dart';

/// P3: collapsed line budget for the initial-requirement row. Two lines keeps
/// the pinned strip short enough that the message list is never pushed off
/// screen (the run-22 "BOTTOM OVERFLOWED" class); a tap expands to full text.
const int _kRequestDescriptionCollapsedLines = 2;

/// Pinned authoritative-price summary strip on the accepted order-chat
/// (JM-025 AC2, D71/D11). Sits between the app bar and the message list and
/// shows the LOCKED price / ETA / tier / order-ref + the winning Jeeber, plus
/// the "Pay cash on delivery" reminder (D11 — cash is the only payment model)
/// and a "view summary" link into `order-summary-pinned` (JM-031).
///
/// This is the in-chat rendering of `order-summary-pinned` (CTO-D3: the pinned
/// summary is primarily a header widget injected into chat + tracking). The
/// figures are rendered verbatim from [summary]; the UI never recomputes them.
///
/// Identifiers (63_W1_TEST_PLAN §2.5 + §2.11):
///   `order_chat_pinned_summary`     — strip root (signature id for accepted)
///   `order_chat_view_summary_link`  — view-summary link → order-summary-pinned
///
/// JM-031 AC4 (W1 EXIT checklist): the pinned `order-summary-pinned` widget must
/// be visible in BOTH the chat AND tracking contexts. This in-chat strip IS the
/// chat-context rendering of that widget (CTO-D3), so — mirroring the
/// tracking-surface header (`OrderSummaryPinnedHeader`) which emits the same ids
/// from its own delivery model — it also carries the JM-031 signature id and the
/// asserted field ids, sourced from the `OrderChatSummary` it already holds:
///   `order_summary_pinned`       — JM-031 widget signature id (chat context)
///   `order_summary_status`       — canonical delivery-status label (run-22)
///   `order_summary_price`        — accepted COD price [D11]
///   `order_summary_jeeber_name`  — winning Jeeber name [D6]
///   `order_summary_eta`          — locked ETA
///   `order_summary_tier`         — tier label
///   `order_summary_cash_label`   — "Pay cash on delivery" reminder [D11]
class OrderChatPinnedSummary extends StatelessWidget {
  const OrderChatPinnedSummary({
    super.key,
    required this.summary,
    required this.counterpartName,
    required this.onViewSummary,
    this.viewerIsJeeber = false,
  });

  /// Locked summary fields resolved from the accepted delivery + request.
  final OrderChatSummary summary;

  /// Chat counterpart name, used when the summary carries no winner name.
  final String counterpartName;

  /// Tap handler for the view-summary link → `order-summary-pinned` (JM-031).
  /// P3: NULLABLE — the `order-summary` route is owner-scoped, so the Jeeber
  /// variant of this strip renders WITHOUT the link.
  final VoidCallback? onViewSummary;

  /// Role of the VIEWER (run-22 chat-cluster fix): the party line names the
  /// person on the OTHER side of the conversation. A customer sees the winning
  /// Jeeber's name; a Jeeber sees the customer's name. Synthetic handles
  /// (`jeeb-<hash>` / UUID / `@jeeb.internal`) are suppressed via
  /// [displayNameOrNull] and fall back to a friendly role generic. Defaults to
  /// the customer viewer — the only surface that renders the strip today.
  final bool viewerIsJeeber;

  /// The order reference heading (run-22 fix: the strip previously repeated
  /// the literal "Order summary" title as its heading AND as filler for every
  /// unresolved figure — 3× on one screen). Prefers the human `ORD-…` ref,
  /// then derives a short stable `#XXXXXX` from the request/delivery id via
  /// [friendlyReference] — never a raw UUID, never a repeated screen title.
  String _referenceHeading() {
    if (summary.hasRef) return friendlyReference(summary.orderRef);
    final id =
        summary.requestId.isNotEmpty ? summary.requestId : summary.deliveryId;
    return friendlyReference(id);
  }

  /// Role-aware counterpart display name (see [viewerIsJeeber]).
  String _partyName(AppLocalizations l10n) {
    if (viewerIsJeeber) {
      // The jeeber's counterpart is the CUSTOMER; the summary's jeeberName is
      // the viewer themselves, so it is never shown here.
      return displayNameOrNull(counterpartName) ??
          l10n.chatPartyCustomerFallback;
    }
    return displayNameOrNull(summary.jeeberName) ??
        displayNameOrNull(counterpartName) ??
        l10n.chatPartyJeeberFallback;
  }

  /// Canonical delivery-status label (deliveryStage* vocab — the same
  /// vocabulary the tracking/status surfaces use). Tolerates the wire spellings
  /// `_parseStage` in `delivery_tracking_info.dart` accepts. An absent/unknown
  /// status reads as the matched stage: the strip only renders on an accepted
  /// order, so "Matched" is the honest floor.
  String _statusLabel(AppLocalizations l10n) {
    switch (summary.statusId.trim().toLowerCase()) {
      case 'picked':
      case 'picked_up':
      case 'pickedup':
      case 'at_pickup':
        return l10n.deliveryStagePickedUp;
      case 'intransit':
      case 'in_transit':
      case 'in transit':
      case 'atdoor':
      case 'at_door':
      case 'at door':
      case 'en_route':
        return l10n.deliveryStageInTransit;
      case 'delivered':
      case 'done':
      case 'completed':
        return l10n.deliveryStageDelivered;
      case 'cancelled':
      case 'canceled':
        return l10n.deliveryStageCancelled;
      default:
        return l10n.deliveryStageMatched;
    }
  }

  String _tierLabel(AppLocalizations l10n) {
    switch (summary.tierId) {
      case 'flash':
        return l10n.tierSelectionTierFlash;
      case 'express':
        return l10n.tierSelectionTierExpress;
      case 'standard':
        return l10n.tierSelectionTierStandard;
      case 'on-the-way':
      case 'on_the_way':
        return l10n.tierSelectionTierOnTheWay;
      case 'eco':
        return l10n.tierSelectionTierEco;
      default:
        return summary.tierId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final partyName = _partyName(l10n);

    return Semantics(
      identifier: 'order_chat_pinned_summary',
      container: true,
      explicitChildNodes: true,
      // JM-031 AC4: this strip is the chat-context rendering of the
      // `order-summary-pinned` widget — expose the JM-031 signature id alongside
      // the chat signature id so the same pinned summary is assertable in both
      // the chat and tracking surfaces (W1 EXIT checklist).
      child: Semantics(
        identifier: 'order_summary_pinned',
        container: true,
        // explicitChildNodes so the descendant field ids (order_summary_price /
        // _jeeber_name / _eta / _tier / _cash_label) and the view-summary link
        // each form their OWN first-class semantics node. Without it the default
        // (false) merges every descendant's label + identifier UP into this one
        // container node, folding those ids away (JM-049 merge class).
        explicitChildNodes: true,
        child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant,
              width: UIConstants.strokeWidthThin,
            ),
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.medium,
          Spacing.small,
          Spacing.medium,
          Spacing.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row: the ORDER REFERENCE heading (run-22 fix — the strip
            // used to repeat the "Order summary" title here, as the link, and
            // as filler for every unresolved chip) + the view-summary link.
            Row(
              children: [
                Expanded(
                  child: Text(
                    _referenceHeading(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                // P3: the link is owner-scoped — the Jeeber strip renders with
                // no link at all (a null handler removes the whole node rather
                // than leaving a dead affordance).
                if (onViewSummary != null)
                  Semantics(
                    identifier: 'order_chat_view_summary_link',
                    button: true,
                    child: InkWell(
                      onTap: onViewSummary,
                      borderRadius: OmdsBorderRadius.small,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.xSmall,
                          vertical: Spacing.twoXSmall,
                        ),
                        child: Text(
                          l10n.orderChatViewSummaryLink,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            // Counterpart party name. JM-031: carries `order_summary_jeeber_name`
            // (D6) — always rendered so the field is assertable in the chat
            // context. Role-aware (run-22 fix): the customer sees the winning
            // Jeeber, the Jeeber sees the customer; synthetic handles are
            // suppressed in favor of a friendly role generic (see [_partyName]).
            Semantics(
              identifier: 'order_summary_jeeber_name',
              child: Text(
                partyName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            // P3 (b01-20260725): the INITIAL REQUIREMENT — the free text the
            // customer typed at compose. Rendered for BOTH parties (the Jeeber
            // has no other order-context surface inside chat), directly under
            // the party line and above the chips, so it is the first thing read
            // after "who". Hidden when empty — never an empty box, never a
            // "Pending" filler (the run-22 regression class).
            // Carries the JM-031 sibling id `order_summary_item` via the
            // nested-container idiom used by the cash label below, so one
            // assertion vocabulary covers all three renderings.
            if (summary.hasDescription) ...[
              const SizedBox(height: Spacing.twoXSmall),
              Semantics(
                identifier: 'order_chat_request_description',
                container: true,
                child: Semantics(
                  identifier: 'order_summary_item',
                  container: true,
                  child: _RequestDescription(text: summary.description),
                ),
              ),
            ],
            const SizedBox(height: Spacing.twoXSmall),
            Wrap(
              spacing: Spacing.xSmall,
              runSpacing: Spacing.twoXSmall,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Canonical delivery-status label (run-22 fix: content-aware
                // deliveryStage* vocabulary instead of the repeated screen
                // title as filler).
                _SummaryChip(
                  identifier: 'order_summary_status',
                  icon: Icons.route_outlined,
                  label: _statusLabel(l10n),
                ),
                // JM-031: price/ETA/tier each carry the `order_summary_*` id and
                // are always rendered (a localized "Pending" placeholder when
                // the locked field is absent — never the screen title) so the
                // chat-context summary is assertable.
                _SummaryChip(
                  identifier: 'order_summary_price',
                  icon: Icons.payments_outlined,
                  label: summary.hasPrice
                      ? summary.priceLabel
                      : l10n.orderSummaryValuePending,
                ),
                _SummaryChip(
                  identifier: 'order_summary_eta',
                  icon: Icons.schedule,
                  label: summary.hasEta
                      ? l10n.deliveryEtaMinutes(summary.etaMinutes!)
                      : l10n.orderSummaryValuePending,
                ),
                _SummaryChip(
                  identifier: 'order_summary_tier',
                  icon: Icons.local_shipping_outlined,
                  label: summary.hasTier
                      ? _tierLabel(l10n)
                      : l10n.orderSummaryValuePending,
                ),
              ],
            ),
            const SizedBox(height: Spacing.twoXSmall),
            // D11: cash on delivery is the only payment model — always shown.
            // Carries BOTH `order_chat_cash_label` (chat) and JM-031's
            // `order_summary_cash_label` so the reminder is assertable in both
            // surfaces.
            Semantics(
              identifier: 'order_chat_cash_label',
              container: true,
              explicitChildNodes: true,
              // Both ids are container nodes (mirroring the
              // order_chat_pinned_summary > order_summary_pinned pair above) so
              // each is a first-class, separately-findable node. Two nested
              // container:false annotations would collapse onto one node and
              // only one identifier would survive (JM-049 merge class).
              child: Semantics(
                identifier: 'order_summary_cash_label',
                container: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: Sizes.small,
                      color: colors.onPrimaryContainer
                          .withValues(alpha: UIConstants.opacityHigh),
                    ),
                    const SizedBox(width: Spacing.twoXSmall),
                    Flexible(
                      // D11: the dedicated cash-reminder key (run-22 fix — the
                      // strip used to reuse orderSummaryTrack, rendering a
                      // misleading "$ Track order" chip here).
                      child: Text(
                        l10n.orderChatPayCashOnDelivery,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onPrimaryContainer
                              .withValues(alpha: UIConstants.opacityHigh),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// A small icon+label chip used for each locked summary figure. When an
/// [identifier] is supplied the chip carries that `Semantics(identifier:)` so
/// the figure is assertable (JM-031 `order_summary_price/eta/tier`).
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    this.identifier,
  });

  final IconData icon;
  final String label;
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: OmdsBorderRadius.small,
        border: Border.all(
          color: colors.outlineVariant,
          width: UIConstants.strokeWidthThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.small, color: colors.primary),
          const SizedBox(width: Spacing.twoXSmall),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    final id = identifier;
    if (id == null) return chip;
    return Semantics(identifier: id, child: chip);
  }
}

/// P3: the initial-requirement row. Collapsed to
/// [_kRequestDescriptionCollapsedLines] with an ellipsis so a long description
/// can never push the message list off screen; tapping toggles full text.
/// [AutoDirectionText] applies the UAX#9 first-strong rule per string, so an
/// Arabic description reads RTL inside an English UI and vice-versa.
///
/// Stateful so the expand toggle survives the 5 s summary-poll rebuild of the
/// parent, while [OrderChatPinnedSummary] itself stays a StatelessWidget.
class _RequestDescription extends StatefulWidget {
  const _RequestDescription({required this.text});

  final String text;

  @override
  State<_RequestDescription> createState() => _RequestDescriptionState();
}

class _RequestDescriptionState extends State<_RequestDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: OmdsBorderRadius.small,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The visible text is the description ALONE; the localized "Request"
          // label rides on the icon's semantics so screen readers announce
          // "Request, 2 kilos apples…" without spending strip width on a
          // prefix that would also break RTL mirroring.
          Semantics(
            label: l10n.orderChatRequestLabel,
            child: Icon(
              Icons.inventory_2_outlined,
              size: Sizes.small,
              color: colors.onPrimaryContainer
                  .withValues(alpha: UIConstants.opacityHigh),
            ),
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Expanded(
            child: AutoDirectionText(
              widget.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
              maxLines: _expanded ? null : _kRequestDescriptionCollapsedLines,
              overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
