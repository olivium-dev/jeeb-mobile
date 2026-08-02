import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../application/active_deliveries_cubit.dart';
import '../domain/active_delivery_summary.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../domain/active_deliveries_repository.dart';

class ActiveDeliveriesBanner extends StatelessWidget {
  const ActiveDeliveriesBanner({
    super.key,
    required this.onOpenChat,
    required this.onManageDelivery,
  });

  final void Function(ActiveDeliverySummary delivery) onOpenChat;

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
              start: Spacing.medium,
              top: Spacing.xSmall,
              end: Spacing.medium,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActiveDeliveriesSummaryRow(
          expanded: _expanded,
          totalCount: widget.deliveries.length,
          l10n: widget.l10n,
          onToggle: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          const SizedBox(height: Spacing.small),
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

const int _kActiveDeliveriesSummaryTitleMaxLines = 2;

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
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.jeeberActiveDeliveriesTitle,
            maxLines: _kActiveDeliveriesSummaryTitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = delivery.title ?? l10n.jeeberActiveDeliveriesFallbackTitle;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
      child: Semantics(
        identifier: 'jeeber_active_delivery_row_${delivery.id}',
        button: true,
        child: OMDSGlassCard(
          backgroundColor: colorScheme.surfaceContainerLow,
          borderRadius: OMDSBorderRadius.lg,
          padding: EdgeInsets.zero,
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: UIConstants.dividerWidth,
          ),
          child: InkWell(
            onTap: onOpenChat,
            borderRadius: OmdsBorderRadius.large,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusChip(status: delivery.status, l10n: l10n),
                    ],
                  ),
                  if (delivery.dropoffAddress != null) ...[
                    const SizedBox(height: Spacing.xSmall),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: Sizes.small,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: Spacing.twoXSmall),
                        Expanded(
                          child: Text(
                            delivery.dropoffAddress!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Spacing.small),
                  _ActiveDeliveryCardActions(
                    deliveryId: delivery.id,
                    l10n: l10n,
                    onOpenChat: onOpenChat,
                    onManageDelivery: onManageDelivery,
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

class _ActiveDeliveryCardActions extends StatelessWidget {
  const _ActiveDeliveryCardActions({
    required this.deliveryId,
    required this.l10n,
    required this.onOpenChat,
    required this.onManageDelivery,
  });

  final String deliveryId;
  final AppLocalizations l10n;
  final VoidCallback onOpenChat;
  final VoidCallback onManageDelivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final openChat = Semantics(
      identifier: 'jeeber_active_delivery_open_chat_$deliveryId',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.jeeberActiveDeliveriesOpenChat,
        onTap: onOpenChat,
        child: _ButtonLabel(
          icon: Icon(Icons.chat_bubble_outline, color: colorScheme.onPrimary),
          label: l10n.jeeberActiveDeliveriesOpenChat,
          style: labelStyle?.copyWith(color: colorScheme.onPrimary),
        ),
      ),
    );
    final manage = Semantics(
      identifier: 'jeeber_active_delivery_manage_$deliveryId',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.jeeberActiveDeliveriesManage,
        variant: OmdsButtonVariant.outlined,
        onTap: onManageDelivery,
        child: _ButtonLabel(
          icon: const Icon(Icons.local_shipping_outlined),
          label: l10n.jeeberActiveDeliveriesManage,
          style: labelStyle?.copyWith(color: colorScheme.primary),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= Sizes.threeHundredLarge;
        if (sideBySide) {
          return Row(
            children: [
              Expanded(child: openChat),
              const SizedBox(width: Spacing.small),
              Expanded(child: manage),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            openChat,
            const SizedBox(height: Spacing.small),
            manage,
          ],
        );
      },
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.icon,
    required this.label,
    required this.style,
  });

  final Widget icon;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: Spacing.xSmall),
        Flexible(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final JeeberDeliveryStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsChip(
      label: _label(l10n, status),
      isSelected: true,
      selectedColor: colorScheme.primaryContainer,
      selectedTextColor: colorScheme.onPrimaryContainer,
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width. The height varies per state: a self-hidden banner, one
/// disclosure row and four expanded cards differ by ~600 logical pixels.
const double _activeDeliveriesBannerPhoneWidth = 390;

/// The narrow phone this team tests on (Galaxy S22, 360 logical px) — below the
/// side-by-side threshold, so its cards stack their two actions.
const double _activeDeliveriesBannerNarrowWidth = 360;

/// The just-won order, in the shape `GET /v1/deliveries?role=jeeber` returns it
/// the moment the customer accepts (status `Ordered`).
const List<ActiveDeliverySummary> _activeDeliveriesBannerWon =
    <ActiveDeliverySummary>[
      ActiveDeliverySummary(
        id: 'req-won',
        status: JeeberDeliveryStatus.ordered,
        conversationId: 'conv-won',
        title: 'Flash delivery request',
        dropoffAddress: 'Achrafieh',
      ),
    ];

/// Four deliveries, one per non-terminal status, with `d2` carrying NO title
/// and NO dropoff — the row that has to fall back to `Delivery` and drop its
const List<ActiveDeliverySummary> _activeDeliveriesBannerFour =
    <ActiveDeliverySummary>[
      ActiveDeliverySummary(
        id: 'd0',
        status: JeeberDeliveryStatus.ordered,
        conversationId: 'conv-0',
        title: 'Delivery 0',
        dropoffAddress: 'Dropoff 0',
      ),
      ActiveDeliverySummary(
        id: 'd1',
        status: JeeberDeliveryStatus.picked,
        conversationId: 'conv-1',
        title: 'Delivery 1',
        dropoffAddress: 'Dropoff 1',
      ),
      ActiveDeliverySummary(
        id: 'd2',
        status: JeeberDeliveryStatus.inTransit,
        conversationId: 'conv-2',
      ),
      ActiveDeliverySummary(
        id: 'd3',
        status: JeeberDeliveryStatus.atDoor,
        conversationId: 'conv-3',
        title: 'Delivery 3',
        dropoffAddress: 'Dropoff 3',
      ),
    ];

/// The longest plausible row: a full request title and a full street address,
/// both of which the card ellipsizes to one line.
const List<ActiveDeliverySummary> _activeDeliveriesBannerLongest =
    <ActiveDeliverySummary>[
      ActiveDeliverySummary(
        id: 'req-long',
        status: JeeberDeliveryStatus.inTransit,
        conversationId: 'conv-long',
        title: 'Flash delivery request with a rather long title #0',
        dropoffAddress: 'Building 12, Rue Verdun, Achrafieh, Beirut, Lebanon',
      ),
    ];

/// One short row, used only to read the narrow-width action layout.
const List<ActiveDeliverySummary> _activeDeliveriesBannerShort =
    <ActiveDeliverySummary>[
      ActiveDeliverySummary(
        id: 'req-360',
        status: JeeberDeliveryStatus.picked,
        conversationId: 'conv-360',
        title: 'Pharmacy run',
        dropoffAddress: 'Hamra',
      ),
    ];

/// Answers the one read this surface makes with a canned list. Never touches a
/// socket; the cubit below is seeded synchronously and never calls it, but it
/// keeps the answer correct if a refresh is ever triggered from the canvas.
class _ActiveDeliveriesBannerCannedRepository
    implements ActiveDeliveriesRepository {
  const _ActiveDeliveriesBannerCannedRepository(this.deliveries);

  final List<ActiveDeliverySummary> deliveries;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => deliveries;
}

/// The cubit the banner reads, seeded SYNCHRONOUSLY.
/// `start()` would emit a frame later, which is fine for a static card but not
/// for [_ActiveDeliveriesBannerExpanded]: its post-frame tap runs after frame
class _ActiveDeliveriesBannerSeededCubit extends ActiveDeliveriesCubit {
  _ActiveDeliveriesBannerSeededCubit(List<ActiveDeliverySummary> deliveries)
    : super(repository: _ActiveDeliveriesBannerCannedRepository(deliveries)) {
    emit(
      ActiveDeliveriesState(
        phase: ActiveDeliveriesPhase.loaded,
        deliveries: deliveries,
      ),
    );
  }
}

/// Expands the disclosure once, so the canvas opens on the delivery CARD rather
/// than on the one-line summary that hides it.
/// The expanded/collapsed bit lives in a private `State` with no seam, and
class _ActiveDeliveriesBannerExpanded extends StatefulWidget {
  const _ActiveDeliveriesBannerExpanded({required this.child});

  final Widget child;

  @override
  State<_ActiveDeliveriesBannerExpanded> createState() =>
      _ActiveDeliveriesBannerExpandedState();
}

class _ActiveDeliveriesBannerExpandedState
    extends State<_ActiveDeliveriesBannerExpanded> {
  bool _toggled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.visitChildElements(_expand);
    });
  }

  /// Depth-first to the first `OmdsButtonVariant.text` button, then stop.
  void _expand(Element element) {
    if (_toggled) return;
    final Widget candidate = element.widget;
    if (candidate is OmdsPrimaryButton &&
        candidate.variant == OmdsButtonVariant.text) {
      _toggled = true;
      candidate.onTap();
      return;
    }
    element.visitChildren(_expand);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The banner over a seeded cubit, inside the scrolling host production gives
/// it.
Widget _activeDeliveriesBannerHosted(
  List<ActiveDeliverySummary> deliveries, {
  bool expanded = false,
  double? width,
}) {
  final Widget banner = ActiveDeliveriesBanner(
    // Production pushes `/chat/:id` and `/jeeber/deliveries/:id/active`; a
    onOpenChat: (_) {},
    onManageDelivery: (_) {},
  );
  Widget content = SingleChildScrollView(
    child: expanded ? _ActiveDeliveriesBannerExpanded(child: banner) : banner,
  );
  if (width != null) {
    content = Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(width: width, child: content),
    );
  }
  return BlocProvider<ActiveDeliveriesCubit>(
    create: (_) => _ActiveDeliveriesBannerSeededCubit(deliveries),
    child: content,
  );
}

/// What a jeeber with active work actually sees: ONE disclosure row, no cards.
/// This is the whole point of the widget — active deliveries must stay
@JeebPreview(
  group: 'jeeber_active_deliveries',
  name: 'At rest · one delivery',
  size: Size(_activeDeliveriesBannerPhoneWidth, 100),
  matrix: true,
)
Widget activeDeliveriesBannerCollapsed() =>
    _activeDeliveriesBannerHosted(_activeDeliveriesBannerWon);

/// The card behind the disclosure, one tap in: the just-won `Ordered` delivery
/// the `offer_accepted` push refetch returns.
@JeebPreview(
  group: 'jeeber_active_deliveries',
  name: 'Expanded · just-won order',
  size: Size(_activeDeliveriesBannerPhoneWidth, 240),
)
Widget activeDeliveriesBannerExpanded() =>
    _activeDeliveriesBannerHosted(_activeDeliveriesBannerWon, expanded: true);

/// Four deliveries, one per non-terminal status, expanded.
/// Two things only the multi-row state can show. First, the four status chips
@JeebPreview(
  group: 'jeeber_active_deliveries',
  name: 'Expanded · four, mixed statuses',
  size: Size(_activeDeliveriesBannerPhoneWidth, 700),
)
Widget activeDeliveriesBannerExpandedMany() =>
    _activeDeliveriesBannerHosted(_activeDeliveriesBannerFour, expanded: true);

/// Layout ceiling at the WIDE branch: the longest plausible title and address
/// with the two actions side by side.
@JeebPreview(
  group: 'jeeber_active_deliveries',
  name: 'Expanded · longest content',
  size: Size(_activeDeliveriesBannerPhoneWidth, 240),
  matrix: true,
)
Widget activeDeliveriesBannerLongContent() => _activeDeliveriesBannerHosted(
  _activeDeliveriesBannerLongest,
  expanded: true,
);

/// The SAME card on a 360 px phone, where the actions stack full-width.
/// 360 is not a rounding of 390: it is the Galaxy S22 this team tests on, and
@JeebPreview(
  group: 'jeeber_active_deliveries',
  name: 'Narrow 360 · actions stack',
  size: Size(_activeDeliveriesBannerNarrowWidth, 320),
)
Widget activeDeliveriesBannerNarrow() => _activeDeliveriesBannerHosted(
  _activeDeliveriesBannerShort,
  expanded: true,
  width: _activeDeliveriesBannerNarrowWidth,
);

/// No active deliveries — the state a jeeber is in almost all of the time, and
/// an EMPTY canvas card is the pass condition, not a broken preview.
@JeebPreview(
  group: 'jeeber_active_deliveries',
  name: 'Nothing active · self-hidden',
  size: Size(_activeDeliveriesBannerPhoneWidth, 80),
)
Widget activeDeliveriesBannerHidden() =>
    _activeDeliveriesBannerHosted(const <ActiveDeliverySummary>[]);
