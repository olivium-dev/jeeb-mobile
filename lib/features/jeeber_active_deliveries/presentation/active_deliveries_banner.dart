import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/accessibility/accessibility.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../application/active_deliveries_cubit.dart';
import '../domain/active_delivery_summary.dart';

/// The jeeber's "active deliveries" banner — the real-UI entry to an ACCEPTED
/// order (iter6 real-flow blocker fix), rebuilt to the redesign board
/// (`screens/16-jeeber-home.png` tpl 915–922) per wiring W-3.
///
/// The board pins the just-won delivery directly above the feed as ONE
/// orange-framed row: a Ø38 accent disc, `Active: {order} → {dropoff}`, the
/// status underneath, and a single navy `Manage` pill. That replaces two
/// stacked ~180dp icon buttons under a section heading — the largest visual
/// delta above the fold on this screen, and the reason a jeeber's own live job
/// used to bury the requests they are supposed to be bidding on.
///
/// Mounted at the top of the jeeber Dashboard. It renders nothing while the
/// jeeber has no active delivery, so it never disturbs the empty/feed states;
/// the moment a client accepts the jeeber's offer (`GET /v1/deliveries?role=
/// jeeber` returns the minted delivery) one card appears.
///
/// * **One delivery** → always expanded. The new card is ~64dp, so pinning it
///   cannot bury the feed, and the designer note pins the just-won job.
/// * **Two or more** → the disclosure row stays (`View all (n)` /
///   `Show less`), and every revealed row uses the same compact card.
///
/// Tapping a card opens that order's chat (`/chat/:id`, conversation already
/// exists, keyed by the request id) — the chat surface is role-aware for a
/// jeeber and exposes "Start delivery". The `Manage` pill opens the
/// active-delivery screen directly for a jeeber already past first contact.
///
/// [onOpenChat] / [onManageDelivery] are injected by the host (the Dashboard
/// tab) so this widget owns no navigation — keeping it testable and the route
/// strings in one place.
class ActiveDeliveriesBanner extends StatelessWidget {
  const ActiveDeliveriesBanner({
    super.key,
    required this.onOpenChat,
    required this.onManageDelivery,
  });

  /// Open the order chat for the tapped delivery. The argument is the chat
  /// route id (conversation id when known, else the delivery/request id — the
  /// `/chat/:id` screen resolves either).
  final void Function(ActiveDeliverySummary delivery) onOpenChat;

  /// Open the active-delivery screen for the tapped delivery (the
  /// Ordered→…→AtDoor stepper). The argument is the delivery id.
  final void Function(ActiveDeliverySummary delivery) onManageDelivery;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveDeliveriesCubit, ActiveDeliveriesState>(
      builder: (context, state) {
        if (!state.hasDeliveries) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        return Semantics(
          container: true,
          identifier: 'jeeber_active_deliveries',
          explicitChildNodes: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Spacing.xLarge,
              top: Spacing.xSmall,
              end: Spacing.xLarge,
            ),
            child: _ActiveDeliveriesCardList(
              deliveries: state.deliveries,
              onOpenChat: onOpenChat,
              onManageDelivery: onManageDelivery,
              l10n: l10n,
            ),
          ),
        );
      },
    );
  }
}

/// One pinned card when there is one job; a disclosure row above the cards when
/// there are several, so a jeeber juggling four deliveries still cannot bury
/// the incoming-request feed under them.
class _ActiveDeliveriesCardList extends StatefulWidget {
  const _ActiveDeliveriesCardList({
    required this.deliveries,
    required this.onOpenChat,
    required this.onManageDelivery,
    required this.l10n,
  });

  final List<ActiveDeliverySummary> deliveries;
  final void Function(ActiveDeliverySummary delivery) onOpenChat;
  final void Function(ActiveDeliverySummary delivery) onManageDelivery;
  final AppLocalizations l10n;

  @override
  State<_ActiveDeliveriesCardList> createState() =>
      _ActiveDeliveriesCardListState();
}

class _ActiveDeliveriesCardListState extends State<_ActiveDeliveriesCardList> {
  bool _expanded = false;

  /// Below this count the list has nothing to disclose — the single card IS
  /// the summary, and a `View all (1)` row above it is pure ceremony.
  static const int _disclosureThreshold = 2;

  @override
  Widget build(BuildContext context) {
    final needsDisclosure = widget.deliveries.length >= _disclosureThreshold;
    final showCards = !needsDisclosure || _expanded;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (needsDisclosure)
          _ActiveDeliveriesSummaryRow(
            expanded: _expanded,
            totalCount: widget.deliveries.length,
            l10n: widget.l10n,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        if (showCards) ...[
          if (needsDisclosure) const SizedBox(height: Spacing.xSmall),
          for (final delivery in widget.deliveries)
            _ActiveDeliveryCard(
              delivery: delivery,
              onOpenChat: () => widget.onOpenChat(delivery),
              onManageDelivery: () => widget.onManageDelivery(delivery),
              l10n: widget.l10n,
            ),
        ],
      ],
    );
  }
}

/// Max visible lines for the compact active-deliveries summary title before it
/// ellipsizes.
const int _kActiveDeliveriesSummaryTitleMaxLines = 2;

/// One-row disclosure that keeps several jobs discoverable without giving them
/// more initial vertical weight than the incoming-request task.
class _ActiveDeliveriesSummaryRow extends StatelessWidget {
  const _ActiveDeliveriesSummaryRow({
    required this.expanded,
    required this.totalCount,
    required this.l10n,
    required this.onToggle,
  });

  final bool expanded;
  final int totalCount;
  final AppLocalizations l10n;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.jeeberActiveDeliveriesTitle,
            maxLines: _kActiveDeliveriesSummaryTitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: context.jeebText.cardTitle.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: Spacing.small),
        Semantics(
          identifier: 'jeeber_active_deliveries_view_all',
          child: OmdsPrimaryButton(
            variant: OmdsButtonVariant.text,
            text: expanded
                ? l10n.jeeberActiveDeliveriesShowLess
                : l10n.jeeberActiveDeliveriesViewAll(totalCount),
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
        ),
      ],
    );
  }
}

/// The board's pinned job (tpl 915–922): a 2px accent frame, the Ø38 scooter
/// disc, one title line, one status line, one navy pill.
class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({
    required this.delivery,
    required this.onOpenChat,
    required this.onManageDelivery,
    required this.l10n,
  });

  final ActiveDeliverySummary delivery;
  final VoidCallback onOpenChat;
  final VoidCallback onManageDelivery;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
      // The frozen row id rides the kit card, which emits it as one
      // `Semantics(identifier:, button:, container:, explicitChildNodes:)`
      // node — value-identical to the hand-rolled wrapper it replaces, and the
      // explicit child nodes are what keep the two action ids queryable.
      child: JeebAccentFrameCard(
        identifier: 'jeeber_active_delivery_row_${delivery.id}',
        // Tapping the card opens the chat — the primary entry the iter6
        // blocker stranded the jeeber out of.
        onTap: onOpenChat,
        child: Row(
          children: [
            const _VehicleDisc(),
            const SizedBox(width: Spacing.small),
            Expanded(
              // The whole title block IS the open-chat affordance; the id sits
              // on it (not on the card root, which the row id owns) so both
              // stay independently tappable by Maestro.
              child: Semantics(
                identifier: 'jeeber_active_delivery_open_chat_${delivery.id}',
                button: true,
                label: l10n.jeeberActiveDeliveriesOpenChat,
                onTap: onOpenChat,
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CardTitle(delivery: delivery, l10n: l10n),
                      const SizedBox(height: Spacing.twoXSmall),
                      _StatusLine(status: delivery.status, l10n: l10n),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.small),
            // Flexible, not fixed: "Manage delivery" is a long label in EN and
            // longer in AR, and on a 360dp handset a rigid pill would push the
            // row past the card edge. It ellipsizes before the row overflows.
            Flexible(
              child: _ManagePill(
                deliveryId: delivery.id,
                label: l10n.jeeberActiveDeliveriesManage,
                onTap: onManageDelivery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ø38 accent disc — the one orange fill this card is allowed (R5).
class _VehicleDisc extends StatelessWidget {
  const _VehicleDisc();

  @override
  Widget build(BuildContext context) {
    final roles = context.jeebRoles;
    return Container(
      width: Sizes.threeXLarge,
      height: Sizes.threeXLarge,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: roles.accent),
      child: Icon(Icons.two_wheeler, size: Sizes.large, color: roles.onAccent),
    );
  }
}

/// `Active: {order} → {dropoff}` — two spans, never one hardcoded arrow: the
/// connector is resolved from the ambient direction so it still points at the
/// destination once the row mirrors in Arabic.
class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.delivery, required this.l10n});

  final ActiveDeliverySummary delivery;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final subject = delivery.title ?? l10n.jeeberActiveDeliveriesFallbackTitle;
    final destination = delivery.dropoffAddress?.trim();
    final head = '${l10n.jeeberActiveLabel}: $subject';
    final arrow = Directionality.of(context) == TextDirection.rtl ? '←' : '→';
    return Text(
      destination == null || destination.isEmpty
          ? head
          : '$head $arrow $destination',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.jeebText.body.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// The status word, folded out of its own chip and into the subtitle.
///
// TODO(redesign-24): the board also reads "· $8 cash on arrival" here.
// `ActiveDeliverySummary` has no amount field and `GET /v1/deliveries?role=
// jeeber` sends none, so the figure is omitted, not faked.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.l10n});

  final JeeberDeliveryStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Text(
      _label(l10n, status),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.jeebText.bodySmall.copyWith(
        color:
            (Theme.of(context).extension<JeebSemanticColors>() ??
                    JeebSemanticColors.light())
                .mutedText,
      ),
    );
  }

  static String _label(AppLocalizations l10n, JeeberDeliveryStatus status) {
    switch (status) {
      case JeeberDeliveryStatus.ordered:
        return l10n.activeDeliveryStatusOrdered;
      case JeeberDeliveryStatus.picked:
        return l10n.activeDeliveryStatusPicked;
      case JeeberDeliveryStatus.inTransit:
        return l10n.activeDeliveryStatusInTransit;
      case JeeberDeliveryStatus.atDoor:
        return l10n.activeDeliveryStatusAtDoor;
      case JeeberDeliveryStatus.done:
        return l10n.activeDeliveryStatusDone;
      case JeeberDeliveryStatus.cancelled:
        return l10n.activeDeliveryCancelledTitle;
      case JeeberDeliveryStatus.expired:
        return l10n.activeDeliveryExpiredTitle;
      case JeeberDeliveryStatus.disputed:
        return l10n.activeDeliveryDisputedTitle;
    }
  }
}

/// The navy pill at the card's end edge (the board's `Manage`). Its frozen
/// identifier is what the jeeber flows tap, so it stays a distinct node inside
/// the card.
///
/// `JeebCtaButton` rather than the `JeebSelectChip` the sibling pills use: the
/// kit chip's label is a rigid `Text` in a `mainAxisSize.min` Row, and
/// "Manage delivery" (longer still in Arabic) then overflows a one-row card on
/// a 360dp handset — the exact defect `jeeber_dashboard_overflow_test` was
/// written for. The CTA's label ellipsizes under a bounded width instead.
class _ManagePill extends StatelessWidget {
  const _ManagePill({
    required this.deliveryId,
    required this.label,
    required this.onTap,
  });

  /// Between the board's 33 and the kit's 56: a card-row pill, not a footer
  /// CTA. `MinTapTarget` still guarantees the 48dp target around it.
  static const double pillHeight = 40;

  final String deliveryId;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'jeeber_active_delivery_manage_$deliveryId',
      button: true,
      container: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(
          onTap: onTap,
          child: JeebCtaButton.primary(
            key: Key('jeeber-active-manage-$deliveryId'),
            label: label,
            height: pillHeight,
            expand: false,
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.medium,
            ),
            labelStyle: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
