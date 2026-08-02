import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/active_request_card.dart' show ClientHomeTierBadge;
import '../widgets/client_home_empty_view.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/client_home_repository.dart';

class PendingRequestsTab extends StatelessWidget {
  const PendingRequestsTab({super.key, this.onTap, this.onCreateRequest});

  final void Function(ClientHomeRequest request)? onTap;
  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      buildWhen: _rebuildWhen,
      builder: (context, state) => _PendingContent(
        state: state,
        onTap: onTap,
        onCreateRequest: onCreateRequest,
      ),
    );
  }

  static bool _rebuildWhen(ClientHomeState prev, ClientHomeState next) =>
      prev.status != next.status || prev.pending != next.pending;
}

class _PendingContent extends StatelessWidget {
  const _PendingContent({
    required this.state,
    required this.onTap,
    required this.onCreateRequest,
  });

  final ClientHomeState state;
  final void Function(ClientHomeRequest)? onTap;
  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    if (state.status == ClientHomeStatus.failed) {
      return _PendingError(
        onRetry: () => context.read<ClientHomeCubit>().load(),
      );
    }
    if (state.status == ClientHomeStatus.loading) {
      return const _PendingLoading();
    }
    if (state.pending.isEmpty) {
      return ClientHomeEmptyView(
        key: const Key('pending-empty'),
        onNewOrder: onCreateRequest ?? () => _openCreateRequest(context),
      );
    }
    return _PendingList(requests: state.pending, onTap: onTap);
  }

  static void _openCreateRequest(BuildContext context) {
    GoRouter.of(context).pushNamed('request-type');
  }
}

class _PendingLoading extends StatelessWidget {
  const _PendingLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(key: Key('pending-loading'), child: OmdsLoadingState());
  }
}

class _PendingError extends StatelessWidget {
  const _PendingError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      key: const Key('pending-error'),
      icon: Icons.cloud_off_outlined,
      title: l10n.homeLoadFailedTitle,
      message: l10n.homeErrorRetry,
      retryLabel: l10n.homeLoadFailedRetry,
      onRetry: onRetry,
    );
  }
}

class _PendingList extends StatelessWidget {
  const _PendingList({required this.requests, required this.onTap});

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest)? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('pending-requests-tab-list'),
      children: [
        for (var i = 0; i < requests.length; i++)
          Semantics(
            identifier: 'orders_home_request_row_$i',
            container: true,
            explicitChildNodes: true,
            child: PendingCountdownCard(
              request: requests[i],
              onTap: onTap != null ? () => onTap!(requests[i]) : null,
            ),
          ),
      ],
    );
  }
}

class PendingCountdownCard extends StatelessWidget {
  const PendingCountdownCard({super.key, required this.request, this.onTap});

  final ClientHomeRequest request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusLabel = request.offerCount > 0
        ? l10n.pendingCardOffersBadge(request.offerCount)
        : l10n.pendingTabSearchingLabel;
    return Semantics(
      identifier: 'pending_requests_item_${request.id}',
      button: onTap != null,
      label: l10n.pendingCardA11yLabel(
        request.displayId ?? request.title,
        statusLabel,
      ),
      child: GestureDetector(
        key: Key('pending-countdown-card-${request.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _PendingCardBody(request: request),
      ),
    );
  }
}

class _PendingCardBody extends StatelessWidget {
  const _PendingCardBody({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      child: Column(
        children: [
          _PendingCardRow(request: request),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Spacing.small),
            child: Divider(
              height: UIConstants.dividerWidth,
              color: colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCardRow extends StatelessWidget {
  const _PendingCardRow({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    final createdAt = request.createdAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PendingCardHeader(request: request),
        const SizedBox(height: Spacing.twoXSmall),
        _PendingCardSummary(text: request.summaryLine),
        if (createdAt != null) ...[
          const SizedBox(height: Spacing.twoXSmall),
          _PendingCreatedAge(createdAt: createdAt),
        ],
        const SizedBox(height: Spacing.xSmall),
        if (request.offerCount > 0)
          _PendingOffersBadge(
            count: request.offerCount,
            emphasize: request.hasNewOffers,
          )
        else
          const _PendingServerStatus(),
      ],
    );
  }
}

class _PendingCardHeader extends StatelessWidget {
  const _PendingCardHeader({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            request.displayId ?? request.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierBadge(tier: request.tier),
      ],
    );
  }
}

class _PendingCardSummary extends StatelessWidget {
  const _PendingCardSummary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Text(
      text.isNotEmpty ? text : l10n.pendingTabSearchingLabel,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PendingServerStatus extends StatelessWidget {
  const _PendingServerStatus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const Key('pending-server-status'),
      children: [
        Icon(
          Icons.search_rounded,
          size: Sizes.medium,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          l10n.pendingTabSearchingLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PendingOffersBadge extends StatelessWidget {
  const _PendingOffersBadge({required this.count, required this.emphasize});

  final int count;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OmdsChip(
        key: const Key('pending-offers-badge'),
        label: l10n.pendingCardOffersBadge(count),
        icon: const Icon(Icons.local_offer_outlined),
        isSelected: emphasize,
        unselectedColor: colorScheme.primaryContainer,
        unselectedTextColor: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _PendingCreatedAge extends StatelessWidget {
  const _PendingCreatedAge({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Text(
      pendingCreatedAgeLabel(l10n, createdAt, DateTime.now()),
      key: const Key('pending-created-age'),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

@visibleForTesting
String pendingCreatedAgeLabel(
  AppLocalizations l10n,
  DateTime createdAtUtc,
  DateTime now,
) {
  const minutesInHour = 60;
  const hoursInDay = 24;
  final elapsed = now.difference(createdAtUtc);
  if (elapsed.isNegative || elapsed.inMinutes < 1) {
    return l10n.pendingCardCreatedJustNow;
  }
  if (elapsed.inMinutes < minutesInHour) {
    return l10n.pendingCardCreatedMinutes(elapsed.inMinutes);
  }
  if (elapsed.inHours < hoursInDay) {
    return l10n.pendingCardCreatedHours(elapsed.inHours);
  }
  return l10n.pendingCardCreatedDays(elapsed.inDays);
}

class PendingReconnectBanner extends StatelessWidget {
  const PendingReconnectBanner({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final roles = context.jeebRoles;
    return Container(
      key: const Key('pending-reconnect-banner'),
      color: roles.warningContainer,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.twoXSmall,
      ),
      child: Row(
        children: [
          OmdsLoadingState(size: Sizes.medium, color: roles.onWarningContainer),
          const SizedBox(width: Spacing.xSmall),
          Text(
            l10n.pendingTabReconnecting,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: roles.onWarningContainer),
          ),
        ],
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// --- PendingRequestsTab ----------------------------------------------------

/// Phone width; the height varies per state because these branches differ by
/// hundreds of logical pixels (a spinner vs. an illustrated empty state).
const double _pendingRequestsTabPhoneWidth = 390;

/// Answers one canned snapshot. Nothing else — no latency, no second read.
class _PendingRequestsTabCannedRepository implements ClientHomeRepository {
  const _PendingRequestsTabCannedRepository(this.pending);

  final List<ClientHomeRequest> pending;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(pending: pending);
}

/// Never answers, so the cubit stays in [ClientHomeStatus.loading] forever.
/// A pending [Completer] is the whole implementation: no timer to leak and no
/// socket to open.
class _PendingRequestsTabStalledRepository implements ClientHomeRepository {
  const _PendingRequestsTabStalledRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// Fails the COLD load, which is the only way to reach
/// [ClientHomeStatus.failed] — the cubit deliberately swallows a failed
/// refresh when data is already on screen.
class _PendingRequestsTabFailingRepository implements ClientHomeRepository {
  const _PendingRequestsTabFailingRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw StateError('preview: gateway unreachable');
}

Widget _pendingRequestsTabHosted(ClientHomeRepository repository) {
  return BlocProvider<ClientHomeCubit>(
    create: (_) => ClientHomeCubit(
      repository: repository,
      greetingNameProvider: () => null,
    )..load(),
    child: SingleChildScrollView(
      child: PendingRequestsTab(onTap: (_) {}, onCreateRequest: () {}),
    ),
  );
}

Widget _pendingRequestsTabWithPending(List<ClientHomeRequest> pending) =>
    _pendingRequestsTabHosted(_PendingRequestsTabCannedRepository(pending));

/// A pending row as the gateway returns one: searching, no offers, no expiry.
ClientHomeRequest _pendingRequestsTabPending({
  String id = 'pen-1',
  String? displayId = 'ORD-23470',
  String title = 'ORD-23470',
  String destinationLabel = 'Achrafieh',
  String? itemsSummary,
  ClientRequestTier tier = ClientRequestTier.express,
  int offerCount = 0,
  bool hasNewOffers = false,
  DateTime? createdAt,
}) => ClientHomeRequest(
  id: id,
  displayId: displayId,
  title: title,
  status: ClientRequestStatus.searching,
  destinationLabel: destinationLabel,
  itemsSummary: itemsSummary,
  tier: tier,
  offerCount: offerCount,
  hasNewOffers: hasNewOffers,
  createdAt: createdAt,
);

/// The default pending state, stacked twice — the shape a sender sees seconds
/// after broadcasting.
@JeebPreview(
  group: 'home_client',
  name: 'Searching · two requests',
  size: Size(_pendingRequestsTabPhoneWidth, 300),
)
Widget pendingRequestsTabSearching() =>
    _pendingRequestsTabWithPending(<ClientHomeRequest>[
      _pendingRequestsTabPending(),
      _pendingRequestsTabPending(
        id: 'pen-2',
        displayId: 'ORD-23471',
        title: 'ORD-23471',
        destinationLabel: 'Hamra',
        tier: ClientRequestTier.standard,
      ),
    ]);

/// Offers have arrived: the prominent badge REPLACES the flat "Searching…"
/// line, filled because they are unseen.
@JeebPreview(
  group: 'home_client',
  name: 'Offers arrived · 3 unseen',
  size: Size(_pendingRequestsTabPhoneWidth, 220),
)
Widget pendingRequestsTabOffers() =>
    _pendingRequestsTabWithPending(<ClientHomeRequest>[
      _pendingRequestsTabPending(offerCount: 3, hasNewOffers: true),
    ]);

/// The layout ceiling: the longest content a real request can carry.
/// A request with no `displayId` falls back to the customer's own typed title,
@JeebPreview(
  group: 'home_client',
  name: 'Longest content · no order id',
  size: Size(_pendingRequestsTabPhoneWidth, 260),
)
Widget pendingRequestsTabLongContent() =>
    _pendingRequestsTabWithPending(<ClientHomeRequest>[
      _pendingRequestsTabPending(
        id: 'pen-long',
        displayId: null,
        title:
            'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, '
            'then drop everything at the clinic on Independence Street',
        itemsSummary:
            'Two boxes of paracetamol, one bottle of cough syrup, a digital '
            'thermometer, four manoushe zaatar and a bag of vitamin C',
        tier: ClientRequestTier.flash,
        createdAt: DateTime.now().toUtc().subtract(
          const Duration(minutes: 12, seconds: 30),
        ),
      ),
    ]);

/// Nothing pending: the illustrated empty state and the first-request CTA.
/// The tallest branch by far (a 200 px illustration above a full-width button),
@JeebPreview(
  group: 'home_client',
  name: 'Empty · no pending requests',
  size: Size(_pendingRequestsTabPhoneWidth, 480),
)
Widget pendingRequestsTabEmpty() =>
    _pendingRequestsTabWithPending(const <ClientHomeRequest>[]);

/// Cold load, still in flight — a centred spinner and nothing else.
/// Deliberately has no text at all, which is the point: at 200% text the other
@JeebPreview(
  group: 'home_client',
  name: 'Loading · cold',
  size: Size(_pendingRequestsTabPhoneWidth, 200),
)
Widget pendingRequestsTabLoading() =>
    _pendingRequestsTabHosted(const _PendingRequestsTabStalledRepository());

/// Cold load failed: the full-screen error with a Retry CTA.
/// Only a COLD failure reaches here — a failed background refresh keeps the
@JeebPreview(
  group: 'home_client',
  name: 'Failed · cold load',
  size: Size(_pendingRequestsTabPhoneWidth, 320),
)
Widget pendingRequestsTabFailed() =>
    _pendingRequestsTabHosted(const _PendingRequestsTabFailingRepository());

// --- PendingCountdownCard --------------------------------------------------

/// Phone width; height clears the tallest (200% text) rendering of the plain
/// searching card.
const Size _pendingCountdownCardCardBox = Size(390, 180);

/// Phone width; height clears the extra line the offers chip adds.
const Size _pendingCountdownCardChipBox = Size(390, 200);

/// Builds the card exactly the way `_PendingList` does — the only production
/// caller — with a live `onTap`, since the tap target is the whole row.
Widget _pendingCountdownCardHosted({
  required String id,
  String? displayId = 'ORD-23470',
  String title = 'ORD-23470',
  String destinationLabel = 'Achrafieh',
  String? itemsSummary,
  ClientRequestTier tier = ClientRequestTier.express,
  int offerCount = 0,
  bool hasNewOffers = false,
  Duration? age,
}) {
  return PendingCountdownCard(
    request: ClientHomeRequest(
      id: id,
      displayId: displayId,
      title: title,
      // Membership in the pending bucket IS the status; the card never
      status: ClientRequestStatus.searching,
      destinationLabel: destinationLabel,
      itemsSummary: itemsSummary,
      tier: tier,
      offerCount: offerCount,
      hasNewOffers: hasNewOffers,
      createdAt: age == null ? null : DateTime.now().toUtc().subtract(age),
    ),
    onTap: () {},
  );
}

/// The default pending state: broadcast, no offers yet, no server timestamp.
/// This is the reference rendering every other state is read against, and the
@JeebPreview(
  group: 'home_client',
  name: 'Searching (no offers)',
  size: _pendingCountdownCardCardBox,
)
Widget pendingCountdownCardSearching() =>
    _pendingCountdownCardHosted(id: 'preview-searching');

/// The same state on the 320 pt narrow-phone floor the app still supports.
/// Worth its own card because it is the one rendering where the overflow is
@JeebPreview(
  group: 'home_client',
  name: 'Searching · 320 pt phone',
  size: Size(320, 180),
)
Widget pendingCountdownCardSearchingNarrow() => _pendingCountdownCardHosted(
      id: 'preview-narrow',
      displayId: 'ORD-31882',
    );

/// Offers have landed and the sender has not looked yet
/// (`offerCount > 0`, `hasNewOffers`).
@JeebPreview(
  group: 'home_client',
  name: 'New offers (3, unseen)',
  size: _pendingCountdownCardChipBox,
)
Widget pendingCountdownCardNewOffers() => _pendingCountdownCardHosted(
      id: 'preview-offers-new',
      displayId: 'ORD-23480',
      offerCount: 3,
      hasNewOffers: true,
    );

/// One offer, already seen (`hasNewOffers: false`) — the tonal chip.
/// Put it next to the card above: the ONLY difference production draws between
@JeebPreview(
  group: 'home_client',
  name: 'Seen offers (1, tonal)',
  size: _pendingCountdownCardChipBox,
)
Widget pendingCountdownCardSeenOffers() => _pendingCountdownCardHosted(
      id: 'preview-offers-seen',
      displayId: 'ORD-23481',
      offerCount: 1,
    );

/// A row the gateway returned WITH a `createdAt`, 12½ minutes ago.
/// The age line is a growing past fact ("Created 12 minutes ago"), never a
@JeebPreview(
  group: 'home_client',
  name: 'With created-age line',
  size: Size(390, 250),
)
Widget pendingCountdownCardCreatedAge() => _pendingCountdownCardHosted(
      id: 'preview-age',
      displayId: 'ORD-23482',
      age: const Duration(minutes: 12, seconds: 30),
    );

/// Longest plausible content, and three fallbacks firing at once.
/// * **No `displayId`** — the header degrades to the raw request `title`, which
@JeebPreview(
  group: 'home_client',
  name: 'Long content · no id · unknown tier',
  size: Size(390, 220),
)
Widget pendingCountdownCardLongContent() => _pendingCountdownCardHosted(
      id: 'preview-long',
      displayId: null,
      title: 'Two kilos of Baalbek potatoes, a 19-litre water gallon and a bag '
          'of medium-roast coffee beans from the shop next to the pharmacy',
      itemsSummary: '2 kg potatoes, 19 L water gallon, medium-roast coffee '
          'beans, 3 boxes of paracetamol, 1 pack of AA batteries',
      destinationLabel: 'Achrafieh, Sassine Square, building 12, 4th floor',
      tier: ClientRequestTier.unknown,
    );

// --- PendingReconnectBanner ------------------------------------------------

/// Reference phone width, matching the rest of this section.
const double _pendingReconnectBannerPhoneWidth = 390;

/// The narrowest phone the app still supports (and roughly what an Android
/// multi-window split leaves a foreground app).
const double _pendingReconnectBannerSmallPhoneWidth = 320;

/// Banner (64) + the stand-in list-top, with headroom for the 200% rendering.
const Size _pendingReconnectBannerPhoneBox =
    Size(_pendingReconnectBannerPhoneWidth, 140);
const Size _pendingReconnectBannerSmallPhoneBox =
    Size(_pendingReconnectBannerSmallPhoneWidth, 140);

/// Two stacked surfaces, so the height comparison fits in one canvas.
const Size _pendingReconnectBannerComparisonBox =
    Size(_pendingReconnectBannerPhoneWidth, 300);

/// Preview scaffolding — NOT part of the widget under review.
/// Stands in for the first row of the pending list so the banner has something
Widget _pendingReconnectBannerListTop(String label) => Builder(
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Text(label, style: theme.textTheme.bodySmall),
        );
      },
    );

/// Mutes the banner's indeterminate spinner — see the banner prose.
Widget _pendingReconnectBannerFrozen(Widget child) =>
    TickerMode(enabled: false, child: child);

/// The Pending tab as the banner sees it: a fixed-width column, banner first.
Widget _pendingReconnectBannerHosted({
  required bool visible,
  required String listTopLabel,
  double width = _pendingReconnectBannerPhoneWidth,
}) =>
    _pendingReconnectBannerFrozen(
      Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PendingReconnectBanner(visible: visible),
              _pendingReconnectBannerListTop(listTopLabel),
            ],
          ),
        ),
      ),
    );

/// The state users are in ~100% of the time: the socket is up and the banner is
/// not merely hidden but absent — `SizedBox.shrink()`, zero height.
@JeebPreview(
  group: 'home_client',
  name: 'Connected (collapsed)',
  size: _pendingReconnectBannerPhoneBox,
)
Widget pendingReconnectBannerHidden() => _pendingReconnectBannerHosted(
      visible: false,
      listTopLabel: 'Connected · list top',
    );

/// AC6 of T-MOB-007: the socket dropped and the tab is showing stale rows.
/// The reference reading. Note how much of the strip is chrome — the leading
@JeebPreview(
  group: 'home_client',
  name: 'Reconnecting · 390 pt',
  size: _pendingReconnectBannerPhoneBox,
)
Widget pendingReconnectBannerReconnecting() => _pendingReconnectBannerHosted(
      visible: true,
      listTopLabel: 'Reconnecting · 390 pt',
    );

/// The same banner with 70pt less to work with.
/// The [Row] holds the label with no [Flexible] and no `overflow`, so it cannot
@JeebPreview(
  group: 'home_client',
  name: 'Reconnecting · 320 pt',
  size: _pendingReconnectBannerSmallPhoneBox,
)
Widget pendingReconnectBannerNarrow() => _pendingReconnectBannerHosted(
      visible: true,
      listTopLabel: 'Reconnecting · 320 pt',
      width: _pendingReconnectBannerSmallPhoneWidth,
    );

/// Both states stacked, because the defect is the DELTA, not either state.
/// A dropped socket does not overlay anything — it inserts a 64pt block above
@JeebPreview(
  group: 'home_client',
  name: 'Height cost (connected vs reconnecting)',
  size: _pendingReconnectBannerComparisonBox,
)
Widget pendingReconnectBannerHeightCost() => _pendingReconnectBannerFrozen(
      Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          width: _pendingReconnectBannerPhoneWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const PendingReconnectBanner(visible: false),
              _pendingReconnectBannerListTop('Height cost · connected'),
              const SizedBox(height: 24),
              const PendingReconnectBanner(visible: true),
              _pendingReconnectBannerListTop('Height cost · reconnecting'),
            ],
          ),
        ),
      ),
    );
