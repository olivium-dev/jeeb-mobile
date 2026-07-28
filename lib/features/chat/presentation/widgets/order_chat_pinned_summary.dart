import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/order_chat_summary.dart';
import 'auto_direction_text.dart';
import 'chat_header_expansion_store.dart';

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
/// ## b02 chat-header redesign — what changed and why
///
/// The owner's verdict on the previous strip was that it complied with neither
/// Material Design, nor accessibility, nor contrast. All three were true and
/// they shared one root:
///
/// * **M3.** The strip was a full-bleed slab of `primaryContainer` stacked
///   directly on top of a second full-bleed slab (the offer-accepted banner).
///   Two competing blocks of chroma is not how M3 expresses hierarchy — *tonal
///   elevation* is. The strip now sits on `surfaceContainerHigh`, one tonal
///   step above the `surface` the message list is painted on, closed by an
///   `outline` hairline, and spends its chroma on exactly ONE accent: the
///   status chip.
/// * **Contrast.** The widget was already using M3 roles correctly; the palette
///   was wrong (`primaryContainer` was the tone-40 brand fill under white ink,
///   4.65:1 — and 3.85:1 once `UIConstants.opacityHigh` was applied to the
///   foreground, which is what made "Pay cash on delivery" unreadable). The
///   palette is fixed in `app_theme.dart`; the fades are gone from here.
///   **No foreground in this widget is alpha-faded.** Hierarchy is carried by
///   role (`onSurface` vs `onSurfaceVariant`) and by type size, never opacity.
/// * **Accessibility.** The expand control is a real 48×48 target with a
///   semantic label; the view-summary link is padded to 48 dp; every chip
///   carries a `"<field>: <value>"` accessible name, so the two "Pending" chips
///   are no longer indistinguishable to a screen reader.
/// * **Height.** Collapsed by default to ONE 48 dp row — reference, status,
///   amount — so the message list survives an open keyboard. The choice is
///   remembered for the session by [ChatHeaderExpansionStore].
///
/// Identifiers (63_W1_TEST_PLAN §2.5 + §2.11):
///   `order_chat_pinned_summary`     — strip root (signature id for accepted)
///   `order_chat_summary_expand`     — expand/collapse control (b02)
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
///
/// `order_summary_status` and `order_summary_price` ride in the COLLAPSED row.
/// The remaining field ids are disclosed by `order_chat_summary_expand`, so a
/// driver that asserts them taps the expand control first (see
/// `.maestro/flows/jm-025-order-chat.yaml` / `jm-031-order-summary-pinned.yaml`).
class OrderChatPinnedSummary extends StatefulWidget {
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

  @override
  State<OrderChatPinnedSummary> createState() => _OrderChatPinnedSummaryState();
}

class _OrderChatPinnedSummaryState extends State<OrderChatPinnedSummary> {
  /// The order reference heading (run-22 fix: the strip previously repeated
  /// the literal "Order summary" title as its heading AND as filler for every
  /// unresolved figure — 3× on one screen). Prefers the human `ORD-…` ref,
  /// then derives a short stable `#XXXXXX` from the request/delivery id via
  /// [friendlyReference] — never a raw UUID, never a repeated screen title.
  String _referenceHeading() {
    final summary = widget.summary;
    if (summary.hasRef) return friendlyReference(summary.orderRef);
    final id =
        summary.requestId.isNotEmpty ? summary.requestId : summary.deliveryId;
    return friendlyReference(id);
  }

  /// Role-aware counterpart display name (see
  /// [OrderChatPinnedSummary.viewerIsJeeber]).
  String _partyName(AppLocalizations l10n) {
    if (widget.viewerIsJeeber) {
      // The jeeber's counterpart is the CUSTOMER; the summary's jeeberName is
      // the viewer themselves, so it is never shown here.
      return displayNameOrNull(widget.counterpartName) ??
          l10n.chatPartyCustomerFallback;
    }
    return displayNameOrNull(widget.summary.jeeberName) ??
        displayNameOrNull(widget.counterpartName) ??
        l10n.chatPartyJeeberFallback;
  }

  /// Canonical delivery-status label (deliveryStage* vocab — the same
  /// vocabulary the tracking/status surfaces use). Tolerates the wire spellings
  /// `_parseStage` in `delivery_tracking_info.dart` accepts. An absent/unknown
  /// status reads as the matched stage: the strip only renders on an accepted
  /// order, so "Matched" is the honest floor.
  String _statusLabel(AppLocalizations l10n) {
    switch (widget.summary.statusId.trim().toLowerCase()) {
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
    switch (widget.summary.tierId) {
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
        return widget.summary.tierId;
    }
  }

  bool get _expanded =>
      ChatHeaderExpansionStore.instance.isExpanded(_referenceHeading());

  void _toggle() {
    ChatHeaderExpansionStore.instance
        .setExpanded(_referenceHeading(), expanded: !_expanded);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final expanded = _expanded;

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
        child: DecoratedBox(
          // M3 tonal elevation, NOT a slab of chroma: one step above the
          // `surface` the message list paints on, closed by an `outline`
          // hairline so the boundary itself clears 3:1 (the tonal step alone is
          // ~1.2:1 in light mode and would read as no boundary at all).
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            border: Border(
              bottom: BorderSide(
                color: colors.outline,
                width: UIConstants.dividerWidth,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.medium,
              Spacing.twoXSmall,
              Spacing.twoXSmall,
              Spacing.twoXSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _CollapsedRow(
                  reference: _referenceHeading(),
                  statusLabel: _statusLabel(l10n),
                  priceLabel: widget.summary.hasPrice
                      ? widget.summary.priceLabel
                      : l10n.orderSummaryValuePending,
                  expanded: expanded,
                  onToggle: _toggle,
                ),
                if (expanded) ...[
                  const SizedBox(height: Spacing.twoXSmall),
                  _PartyRow(
                    partyName: _partyName(l10n),
                    onViewSummary: widget.onViewSummary,
                  ),
                  // P3 (b01-20260725): the INITIAL REQUIREMENT — the free text
                  // the customer typed at compose. Rendered for BOTH parties
                  // (the Jeeber has no other order-context surface inside chat).
                  // Hidden when empty — never an empty box, never a "Pending"
                  // filler (the run-22 regression class). Carries the JM-031
                  // sibling id `order_summary_item` via the nested-container
                  // idiom used by the cash label below.
                  if (widget.summary.hasDescription) ...[
                    const SizedBox(height: Spacing.twoXSmall),
                    Semantics(
                      identifier: 'order_chat_request_description',
                      container: true,
                      child: Semantics(
                        identifier: 'order_summary_item',
                        container: true,
                        child: _RequestDescription(
                          text: widget.summary.description,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Spacing.twoXSmall),
                  Wrap(
                    spacing: Spacing.xSmall,
                    runSpacing: Spacing.twoXSmall,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // JM-031: ETA/tier each carry the `order_summary_*` id and
                      // are always rendered (a localized "Pending" placeholder
                      // when the locked field is absent — never the screen
                      // title) so the chat-context summary is assertable.
                      _SummaryChip(
                        identifier: 'order_summary_eta',
                        icon: Icons.schedule,
                        fieldLabel: l10n.orderChatFieldEta,
                        value: widget.summary.hasEta
                            ? l10n.deliveryEtaMinutes(widget.summary.etaMinutes!)
                            : l10n.orderSummaryValuePending,
                      ),
                      _SummaryChip(
                        identifier: 'order_summary_tier',
                        icon: Icons.local_shipping_outlined,
                        fieldLabel: l10n.orderChatFieldTier,
                        value: widget.summary.hasTier
                            ? _tierLabel(l10n)
                            : l10n.orderSummaryValuePending,
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.twoXSmall),
                  const _CashOnDeliveryRow(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The always-visible row: reference · status · amount · expand control.
///
/// This is the whole header when collapsed, and it is deliberately ONE 48 dp
/// row — the height of its own touch targets, nothing added. The reference is
/// the flexible element: at large text scales the chips keep their intrinsic
/// size and the reference ellipsises, so the row can never overflow
/// horizontally.
class _CollapsedRow extends StatelessWidget {
  const _CollapsedRow({
    required this.reference,
    required this.statusLabel,
    required this.priceLabel,
    required this.expanded,
    required this.onToggle,
  });

  final String reference;
  final String statusLabel;
  final String priceLabel;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          // A `Wrap`, not a `Row`: at large text scales the three elements stop
          // fitting on one line, and a Row would report a horizontal overflow
          // (measured at text scale 1.3). Wrapping to a second line is the
          // responsive answer and keeps every element at full size — nothing is
          // squeezed, nothing is clipped, and the header simply becomes two
          // rows tall for a user who asked for larger type.
          child: Wrap(
            spacing: Spacing.xSmall,
            runSpacing: Spacing.twoXSmall,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                identifier: 'order_chat_summary_reference',
                container: true,
                child: Text(
                  reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              // THE single accent on this header (M3: one accent, not two
              // competing slabs). Fed by the push-driven summary refetch in
              // `chat_detail_screen` — that consumer is unchanged.
              _SummaryChip(
                identifier: 'order_summary_status',
                icon: Icons.route_outlined,
                fieldLabel: l10n.orderChatFieldStatus,
                value: statusLabel,
                accent: true,
              ),
              // The amount is EMPHASIS, not a second accent: a chip here would
              // put two bordered capsules side by side, and (measured) the two
              // chips plus the reference are 423 dp of content in a 343 dp row,
              // which pushes the collapsed header onto a second line. Bold text
              // in the on-surface role carries it in ~60 dp.
              Semantics(
                identifier: 'order_summary_price',
                container: true,
                label: l10n.orderChatFieldValueA11y(
                  l10n.orderChatFieldPrice,
                  priceLabel,
                ),
                child: ExcludeSemantics(
                  child: Text(
                    priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _ExpandToggle(expanded: expanded, onToggle: onToggle),
      ],
    );
  }
}

/// The disclosure control. A real 48×48 target ([Sizes.fourXLarge]) with an
/// explicit, state-dependent semantic label — the previous strip had no
/// disclosure control at all, and its only tap target (the description row) was
/// an unlabelled `InkWell`.
class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'order_chat_summary_expand',
      container: true,
      button: true,
      label: expanded
          ? l10n.orderChatSummaryCollapse
          : l10n.orderChatSummaryExpand,
      child: InkWell(
        onTap: onToggle,
        borderRadius: OmdsBorderRadius.pill,
        child: SizedBox(
          width: Sizes.fourXLarge,
          height: Sizes.fourXLarge,
          child: Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: Sizes.xLarge,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Expanded-only: counterpart party name + the owner-scoped view-summary link.
class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.partyName, required this.onViewSummary});

  final String partyName;
  final VoidCallback? onViewSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final viewSummary = onViewSummary;
    return Row(
      children: [
        Expanded(
          // JM-031: carries `order_summary_jeeber_name` (D6). Role-aware
          // (run-22 fix): the customer sees the winning Jeeber, the Jeeber sees
          // the customer.
          child: Semantics(
            identifier: 'order_summary_jeeber_name',
            container: true,
            child: Text(
              partyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
        // P3: the link is owner-scoped — the Jeeber strip renders with no link
        // at all (a null handler removes the whole node rather than leaving a
        // dead affordance).
        if (viewSummary != null)
          // Flexible + ellipsis: at a 2.0 text scale on a 320 dp phone the link
          // alone is wider than the row, and a rigid child would overflow.
          Flexible(
            child: Semantics(
              identifier: 'order_chat_view_summary_link',
              container: true,
              button: true,
              child: InkWell(
                onTap: viewSummary,
                borderRadius: OmdsBorderRadius.small,
                child: ConstrainedBox(
                  // WCAG 2.2 target size: this used to be a bare ~20 dp text
                  // run.
                  constraints: const BoxConstraints(
                    minWidth: Sizes.fourXLarge,
                    minHeight: Sizes.fourXLarge,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: Spacing.xSmall,
                      ),
                      child: Text(
                        l10n.orderChatViewSummaryLink,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// D11: cash on delivery is the only payment model — always shown when the
/// header is expanded.
///
/// Carries BOTH `order_chat_cash_label` (chat) and JM-031's
/// `order_summary_cash_label` so the reminder is assertable in both surfaces.
///
/// The foreground is `onSurfaceVariant` at FULL strength. It used to be
/// `onPrimaryContainer` faded to `UIConstants.opacityHigh` over the saturated
/// container — 3.85:1, below AA, which is why this line was reported
/// unreadable. Hierarchy here is a role and a type size, never an alpha.
class _CashOnDeliveryRow extends StatelessWidget {
  const _CashOnDeliveryRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'order_chat_cash_label',
      container: true,
      explicitChildNodes: true,
      // Both ids are container nodes (mirroring the
      // order_chat_pinned_summary > order_summary_pinned pair above) so each is
      // a first-class, separately-findable node. Two nested container:false
      // annotations would collapse onto one node and only one identifier would
      // survive (JM-049 merge class).
      child: Semantics(
        identifier: 'order_summary_cash_label',
        container: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_money,
              size: Sizes.medium,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.twoXSmall),
            Flexible(
              // D11: the dedicated cash-reminder key (run-22 fix — the strip
              // used to reuse orderSummaryTrack, rendering a misleading
              // "$ Track order" chip here).
              child: Text(
                l10n.orderChatPayCashOnDelivery,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small icon+label chip for one locked summary figure.
///
/// Two variants, and only two, because M3 hierarchy on this header is carried
/// by ONE accent:
///   * [accent] — `primaryContainer` / `onPrimaryContainer`. The status chip
///     only. This is the header's single spot of chroma.
///   * default  — `surfaceContainerLowest` under an `outline` hairline. Reads
///     as an inset neutral chip against the `surfaceContainerHigh` header.
///
/// Accessibility: the visible label alone is ambiguous — an unresolved ETA and
/// an unresolved tier both read "Pending", and a screen-reader user hearing
/// "Pending, Pending" learns nothing. The node's accessible name is therefore
/// always `"<field>: <value>"` ([fieldLabel] + [value]), and the decorative inner
/// tree is excluded so that name is what is announced.
///
/// **Why this is not `OmdsChip`.** It was, and it could not stay. `OmdsChip`
/// renders its label in an unbounded `Text` and centres the capsule with a
/// `Center`, which EXPANDS to its constraints. In a header row that produced
/// two measured defects: every chip claimed the full line width (343 dp) and
/// pushed its siblings onto the next row, and once tightened to its intrinsic
/// width the un-ellipsisable label overflowed by 33 px at a 2.0 text scale.
/// This chip is the same visual capsule built from the same OMDS tokens
/// ([Spacing], [Sizes], [OmdsBorderRadius], [UIConstants]) and the same M3
/// roles, with a shrink-wrapping `Center(widthFactor: 1)` and an ellipsising
/// label. Folding those two properties back into `OmdsChip` is the right
/// long-term fix and belongs in `omds-flutter`, not here.
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.identifier,
    required this.icon,
    required this.fieldLabel,
    required this.value,
    this.accent = false,
  });

  final String identifier;
  final IconData icon;

  /// The human field name ("Status", "Price", …) — announced, not painted.
  final String fieldLabel;

  /// The rendered value ("In transit", "Pending", …).
  final String value;

  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final foreground = accent ? colors.onPrimaryContainer : colors.onSurface;
    return Semantics(
      identifier: identifier,
      container: true,
      label: l10n.orderChatFieldValueA11y(fieldLabel, value),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          // WCAG 2.2 target size, the same floor `OmdsChip` enforces.
          constraints: const BoxConstraints(minHeight: Sizes.fourXLarge),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: Spacing.xSmall,
                vertical: Spacing.twoXSmall,
              ),
              decoration: BoxDecoration(
                color: accent
                    ? colors.primaryContainer
                    : colors.surfaceContainerLowest,
                borderRadius: OmdsBorderRadius.pill,
                // A chip fill one tonal step from its own header is a ~1.1:1
                // edge in light mode; the border is what makes the component
                // boundary perceivable, so it is a full-strength role, not a
                // tint.
                border: Border.all(
                  color: accent ? colors.onPrimaryContainer : colors.outline,
                  width: UIConstants.dividerWidth,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: Sizes.medium, color: foreground),
                  const SizedBox(width: Spacing.twoXSmall),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// P3: the initial-requirement row. Collapsed to
/// [_kRequestDescriptionCollapsedLines] with an ellipsis so a long description
/// can never push the message list off screen; tapping toggles full text.
/// [AutoDirectionText] applies the UAX#9 first-strong rule per string, so an
/// Arabic description reads RTL inside an English UI and vice-versa.
///
/// Stateful so the expand toggle survives the push-driven summary refetch
/// rebuild of the parent.
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
    return Semantics(
      button: true,
      label: _expanded
          ? l10n.orderChatRequestCollapse
          : l10n.orderChatRequestExpand,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: OmdsBorderRadius.small,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The visible text is the description ALONE; the localized
            // "Request" label rides on the icon's semantics so screen readers
            // announce "Request, 2 kilos apples…" without spending strip width
            // on a prefix that would also break RTL mirroring.
            Semantics(
              label: l10n.orderChatRequestLabel,
              child: Icon(
                Icons.inventory_2_outlined,
                size: Sizes.medium,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: Spacing.twoXSmall),
            Expanded(
              child: AutoDirectionText(
                widget.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                ),
                maxLines: _expanded ? null : _kRequestDescriptionCollapsedLines,
                overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
