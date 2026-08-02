import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/order_chat_summary.dart';
import 'auto_direction_text.dart';
import 'chat_header_expansion_store.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Collapsed to two lines to keep message list on-screen.
const int _kRequestDescriptionCollapsedLines = 2;

/// Pinned summary: locked price/ETA/tier/ref, winning Jeeber, COD reminder.
class OrderChatPinnedSummary extends StatefulWidget {
  const OrderChatPinnedSummary({
    super.key,
    required this.summary,
    required this.counterpartName,
    required this.onViewSummary,
    this.onSummaryAttentionRefresh,
    this.viewerIsJeeber = false,
  });

  final OrderChatSummary summary;

  final String counterpartName;

  /// Tap handler for the view-summary link; nullable (owner-scoped, no link for Jeeber).
  final VoidCallback? onViewSummary;

  /// Fired when customer expands strip: push-only status axis requires explicit refresh.
  final VoidCallback? onSummaryAttentionRefresh;

  /// Role of viewer: customer sees Jeeber name, Jeeber sees customer name.
  final bool viewerIsJeeber;

  @override
  State<OrderChatPinnedSummary> createState() => _OrderChatPinnedSummaryState();
}

class _OrderChatPinnedSummaryState extends State<OrderChatPinnedSummary> {
  /// Prefer human `ORD-…` ref, then derive short `#XXXXXX` from request/delivery id.
  String _referenceHeading() {
    final summary = widget.summary;
    if (summary.hasRef) return friendlyReference(summary.orderRef);
    final id =
        summary.requestId.isNotEmpty ? summary.requestId : summary.deliveryId;
    return friendlyReference(id);
  }

  String _partyName(AppLocalizations l10n) {
    if (widget.viewerIsJeeber) {
      return displayNameOrNull(widget.counterpartName) ??
          l10n.chatPartyCustomerFallback;
    }
    return displayNameOrNull(widget.summary.jeeberName) ??
        displayNameOrNull(widget.counterpartName) ??
        l10n.chatPartyJeeberFallback;
  }

  /// Maps wire spellings to delivery stage labels; unknown defaults to "Matched".
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

  /// Must use durable deliveryId/requestId, NOT _referenceHeading (key must not drift on refetch).
  String get _expansionKey {
    final summary = widget.summary;
    if (summary.deliveryId.isNotEmpty) return 'delivery:${summary.deliveryId}';
    if (summary.requestId.isNotEmpty) return 'request:${summary.requestId}';
    return 'unkeyed';
  }

  bool get _expanded =>
      ChatHeaderExpansionStore.instance.isExpanded(_expansionKey);

  void _toggle() {
    final willExpand = !_expanded;
    ChatHeaderExpansionStore.instance
        .setExpanded(_expansionKey, expanded: willExpand);
    setState(() {});
    // Expanding is the user-caused refresh moment; single-flighted to prevent bursts.
    if (willExpand) widget.onSummaryAttentionRefresh?.call();
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
      child: Semantics(
        identifier: 'order_summary_pinned',
        container: true,
        explicitChildNodes: true,
        child: DecoratedBox(
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

/// Always-visible row: reference · status · amount · expand control.
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
          // Wrap not Row: wraps at large text scales to prevent overflow.
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
              // Single accent: status chip only.
              _SummaryChip(
                identifier: 'order_summary_status',
                icon: Icons.route_outlined,
                fieldLabel: l10n.orderChatFieldStatus,
                value: statusLabel,
                accent: true,
              ),
              // Amount: bold text, not a second chip (fits better in collapsed row).
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

/// Disclosure control: 48×48 semantic target.
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

/// Expanded-only: counterpart name + owner-scoped view-summary link.
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
          // JM-031: carries `order_summary_jeeber_name`.
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
        if (viewSummary != null)
          // Flexible + ellipsis for responsive text at large scales.
          Flexible(
            child: Semantics(
              identifier: 'order_chat_view_summary_link',
              container: true,
              button: true,
              child: InkWell(
                onTap: viewSummary,
                borderRadius: OmdsBorderRadius.small,
                child: ConstrainedBox(
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

/// Cash on delivery reminder: only payment model, always shown when expanded.
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

/// Small icon+label chip for locked summary figure.
/// Not OmdsChip: needs shrink-wrapping Center and ellipsising label for header row.
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

  /// Human field name, announced but not painted.
  final String fieldLabel;

  /// Rendered value.
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

/// Initial-requirement row: collapsed to [_kRequestDescriptionCollapsedLines], tap to expand.
/// Stateful so expand toggle survives parent rebuild on summary refetch.
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
            // "Request" label on icon semantics to avoid breaking RTL and strip width.
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [OrderChatPinnedSummary] — run with

/// Collapsed, the strip is ONE 48 dp row — but at 200% text it wraps the
/// reference / status / amount onto a second line by design, so the box has to
const Size _orderChatPinnedSummaryCollapsedBox = Size(390, 180);

/// Expanded: collapsed row + party line + requirement + chips + cash reminder.
/// Sized for the 200%-text rendering, which is the tallest of the three: across
const Size _orderChatPinnedSummaryExpandedBox = Size(390, 480);

/// The initial requirement as customers actually type it: one run-on line, no
/// punctuation, well past the two-line clamp.
const String _orderChatPinnedSummaryLongDescription =
    'two kilos of red apples and one kilo of bananas plus a large sourdough '
    'loaf from the bakery counter and if they have the imported yoghurt take '
    'four of the small ones otherwise skip it and please ring the intercom '
    'twice because the doorbell has been broken since last week thank you';

/// Mirrors `_OrderChatPinnedSummaryState._expansionKey`.
/// It is duplicated rather than exposed because the store key is production
String _orderChatPinnedSummaryExpansionKeyFor(OrderChatSummary summary) {
  if (summary.deliveryId.isNotEmpty) return 'delivery:${summary.deliveryId}';
  if (summary.requestId.isNotEmpty) return 'request:${summary.requestId}';
  return 'unkeyed';
}

/// Builds the strip with its session expansion state pre-seeded.
/// [viewerIsJeeber] also drops the view-summary link, because that is how the
Widget _orderChatPinnedSummaryHosted(
  OrderChatSummary summary, {
  required String counterpartName,
  bool expanded = false,
  bool viewerIsJeeber = false,
}) {
  ChatHeaderExpansionStore.instance
      .setExpanded(_orderChatPinnedSummaryExpansionKeyFor(summary), expanded: expanded);
  return OrderChatPinnedSummary(
    summary: summary,
    counterpartName: counterpartName,
    onViewSummary: viewerIsJeeber ? null : () {},
    viewerIsJeeber: viewerIsJeeber,
  );
}

/// What every customer sees first (b02): the strip is collapsed by default, so
/// the message list survives an open keyboard.
@JeebPreview(group: 'chat', name: 'Collapsed (default)', size: _orderChatPinnedSummaryCollapsedBox)
Widget orderChatPinnedSummaryCollapsed() => _orderChatPinnedSummaryHosted(
      const OrderChatSummary(
        deliveryId: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
        requestId: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
        orderRef: 'ORD-23470',
        priceLabel: r'$12.00',
        jeeberName: 'Kamal Hajj',
        etaMinutes: 25,
        tierId: 'express',
        statusId: 'in_transit',
        description: '2 kilos apples from Spinneys',
      ),
      counterpartName: 'Kamal Hajj',
    );

/// The happy path once disclosed: every locked figure resolved.
/// Note what is NOT here — a second slab of chroma. b02 spends the header's
@JeebPreview(group: 'chat', name: 'Expanded (all fields)', size: _orderChatPinnedSummaryExpandedBox)
Widget orderChatPinnedSummaryExpanded() => _orderChatPinnedSummaryHosted(
      const OrderChatSummary(
        deliveryId: 'c1f0e2b4-8d55-4a17-9e30-5b6c7d8e9f01',
        requestId: 'c1f0e2b4-8d55-4a17-9e30-5b6c7d8e9f01',
        orderRef: 'ORD-23471',
        priceLabel: r'$12.00',
        jeeberName: 'Kamal Hajj',
        etaMinutes: 25,
        tierId: 'express',
        statusId: 'picked_up',
        description: '2 kilos apples from Spinneys',
      ),
      counterpartName: 'Kamal Hajj',
      expanded: true,
    );

/// Cold open: the chat is on screen but the summary fetch has not landed, so
/// the row carries nothing but its delivery id.
@JeebPreview(group: 'chat', name: 'Pending (nothing resolved)', size: _orderChatPinnedSummaryExpandedBox)
Widget orderChatPinnedSummaryPending() => _orderChatPinnedSummaryHosted(
      const OrderChatSummary(
        deliveryId: '5b2e8c14-77af-4a63-9c05-6d90ab7719d4',
      ),
      counterpartName: 'Kamal Hajj',
      expanded: true,
    );

/// The Jeeber leg (P3 + the run-22 role fix), which differs in two ways that
/// are easy to get backwards.
@JeebPreview(group: 'chat', name: 'Jeeber viewer (no link)', size: _orderChatPinnedSummaryExpandedBox)
Widget orderChatPinnedSummaryJeeberViewer() => _orderChatPinnedSummaryHosted(
      const OrderChatSummary(
        deliveryId: '2ab41d67-0c98-4f52-b7e1-3d5a9e0f4c88',
        orderRef: 'ORD-23472',
        priceLabel: r'$12.00',
        jeeberName: 'Kamal Hajj',
        etaMinutes: 25,
        tierId: 'flash',
        statusId: 'at_door',
        description: '2 kilos apples from Spinneys',
      ),
      counterpartName: 'jeeb-e1a35ea8a520',
      expanded: true,
      viewerIsJeeber: true,
    );

/// The layout ceiling: everything at its longest plausible value at once — a
/// long order reference, a three-part Arabic-transliterated name, a Lebanese
@JeebPreview(group: 'chat', name: 'Longest content', size: _orderChatPinnedSummaryExpandedBox)
Widget orderChatPinnedSummaryLongContent() => _orderChatPinnedSummaryHosted(
      const OrderChatSummary(
        deliveryId: '7c0a4e21-93b6-4f18-a5d2-8e1f6b40aa31',
        requestId: '7c0a4e21-93b6-4f18-a5d2-8e1f6b40aa31',
        orderRef: 'ORD-2026-0801-BEIRUT-HAMRA-0042',
        priceLabel: '1,250,000 L.L.',
        jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        etaMinutes: 185,
        tierId: 'on-the-way',
        statusId: 'in_transit',
        description: _orderChatPinnedSummaryLongDescription,
      ),
      counterpartName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      expanded: true,
    );

/// Bidi: an Arabic requirement inside an English UI (P3/M10).
/// The requirement is the only free text on this strip, so it is the only place
@JeebPreview(group: 'chat', name: 'Arabic requirement in EN UI', size: _orderChatPinnedSummaryExpandedBox)
Widget orderChatPinnedSummaryArabicDescription() => _orderChatPinnedSummaryHosted(
      const OrderChatSummary(
        deliveryId: '8d3c95f2-41ab-4c07-9e6b-2f5081bc7a19',
        orderRef: 'ORD-23473',
        priceLabel: r'$7.50',
        jeeberName: 'Kamal Hajj',
        etaMinutes: 15,
        tierId: 'standard',
        statusId: 'matched',
        description: '٢ كيلو تفاح من سبينيس',
      ),
      counterpartName: 'Kamal Hajj',
      expanded: true,
    );
