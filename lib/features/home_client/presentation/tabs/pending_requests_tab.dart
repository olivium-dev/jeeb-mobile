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

/// T-MOB-007: Isolated Pending Requests tab widget.
///
/// Renders requests that are broadcast but not yet matched. Each card shows
/// an order summary and a "Searching for Jeebers…" status derived from its
/// authoritative server-side `pending` bucket. The live gateway list carries
/// no expiry timestamp, so this surface deliberately does not manufacture a
/// client deadline. A server-terminal request is removed on the next snapshot.
///
/// Mock endpoint: GET /v1/requests?status=pending  (Mockoon :3055)
class PendingRequestsTab extends StatelessWidget {
  const PendingRequestsTab({super.key, this.onTap, this.onCreateRequest});

  /// Called when a card row is tapped. If null the tap is a no-op.
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
          // JM-023 AC2: the indexed `orders_home_request_row_<n>` identifier is
          // the QA tap target for a pending request row on the Requests home.
          // It wraps (does not replace) the per-id `pending_requests_item_<id>`
          // identifier the card already exposes, so both contracts stay
          // targetable; tapping routes to `waiting-no-coverage` (JM-026) via
          // the screen-supplied [onTap].
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

/// Backward-compatible public card name retained for callers/tests from the
/// original countdown implementation. Status is now server-owned: membership
/// in this list means the repository observed a live pending request.
class PendingCountdownCard extends StatelessWidget {
  const PendingCountdownCard({super.key, required this.request, this.onTap});

  final ClientHomeRequest request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The a11y status mirrors what the card shows: the offers count once offers
    // exist, otherwise the honest server-owned "searching" state. Default
    // (offerCount == 0) keeps the pre-existing label verbatim.
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
        // Age line — shown ONLY when the server row carried a real `createdAt`.
        // It is a past-fact "created N ago" (grows over time), NOT a countdown
        // or expiry; the manufactured-deadline lie stays removed.
        if (createdAt != null) ...[
          const SizedBox(height: Spacing.twoXSmall),
          _PendingCreatedAge(createdAt: createdAt),
        ],
        const SizedBox(height: Spacing.xSmall),
        // Once offers have arrived, surface them prominently instead of the flat
        // "Searching…" line. NB: on the live client-home path an offer-bearing
        // request is bucketed into Replies (offerCount>0), so on the Pending tab
        // this branch lights up for denormalised counts / non-dio repositories;
        // the searching line remains the default pending state.
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
            // Role fix: `secondaryContainer` is a CONTAINER (fill) role, not
            // an ink role — as text it went illegible on dark surfaces. Titles
            // on surface read in `onSurface`.
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

/// Prominent "N offers" badge shown on a pending card once offers have already
/// arrived, in place of the flat "Searching…" line. Emphasised (filled) when
/// [emphasize] — the request's unseen-offers flag — is set, softer (tonal)
/// otherwise. Display-only: the whole card row stays the single tap target.
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

/// Age line ("Created 12 minutes ago") derived from the server [createdAt]
/// instant. Uses the device clock only to age a PAST fact; it never counts
/// down to a fabricated deadline. Rendered by the caller only when a real
/// timestamp exists.
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

/// Builds the pending-card age label from a server [createdAtUtc] instant and
/// the current [now]. Pure + deterministic so it can be unit-tested with fixed
/// times. Only ever renders a PAST "created N ago": a future/negative delta
/// (clock skew) and anything under a minute both degrade to "just now" — there
/// is deliberately no future-facing countdown here.
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

/// Faint reconnect banner shown at the top of the Pending tab when the
/// WebSocket is disconnected (AC6 of T-MOB-007).
class PendingReconnectBanner extends StatelessWidget {
  const PendingReconnectBanner({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    // Reconnecting is a transient attention state → semantic warning role, not
    // the error pair (kept for terminal failures).
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
          // OMDS: OmdsLoadingState replaces CircularProgressIndicator (OMDS-only policy).
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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/home_client/pending_requests_tab_preview_test.dart ·
// test/previews/home_client/pending_countdown_card_preview_test.dart ·
// test/previews/home_client/pending_reconnect_banner_preview_test.dart
// ===========================================================================
//
// This file declares THREE previewed widgets, so the section carries three
// families. Every name below is prefixed with the widget it belongs to
// (`pendingRequestsTab…`, `pendingCountdownCard…`, `pendingReconnectBanner…`)
// — all three declared a `_hosted` and two declared a `_phoneWidth`, so the
// fixtures would otherwise collide outright.
//
// ---------------------------------------------------------------------------
// PendingRequestsTab
// ---------------------------------------------------------------------------
//
// The tab renders one of four mutually exclusive branches off
// [ClientHomeState] — failed, loading, empty, list — so a preview per branch
// is the minimum honest coverage. Each is driven the way production drives it:
// a real [ClientHomeCubit] over a LOCAL fake [ClientHomeRepository] that
// answers from canned data, throws, or never answers. No Dio, no DI graph, no
// network — the guard in [jeebPreviewHost] is the net, not the plan.
//
// Two things the previews reproduce on purpose:
//
//  * **The host is a scroll view.** In production the tab is a child of the
//    home screen's `ListView` (`_ReadyLayout._scrollChildren`), so it builds
//    under an UNBOUNDED vertical constraint and its `Column` of rows can never
//    overflow. Previewing it in a bare fixed box would invent a failure the
//    app cannot have, so [_pendingRequestsTabHosted] supplies the same
//    unbounded constraint.
//  * **Both callbacks are wired.** `onCreateRequest` matters because the empty
//    branch falls back to `GoRouter.of(context)` when it is null, and there is
//    no router in a preview; `onTap` matters because it is what makes a card
//    expose `button: true` semantics.
//
// Fixture values (`ORD-23470`, `Achrafieh`, the 12m30s age, the 3-offer badge)
// are lifted from `test/features/home_client/pending_requests_tab_test.dart`
// so the canvas and the assertions describe the same rows.
//
// ---------------------------------------------------------------------------
// PendingCountdownCard
// ---------------------------------------------------------------------------
//
// [PendingCountdownCard] is a pure view over one [ClientHomeRequest]: no
// cubit, no repository, no image fetch. Every fixture below is a plain value
// object, so these previews are network-free by construction rather than
// merely by the guard in [jeebPreviewHost].
//
// The fixture values reuse `test/features/home_client/pending_requests_tab_test.dart`
// (`ORD-23470` / Achrafieh / Express / 12 min 30 s old) so the canvas and the
// widget test describe the same card.
//
// Despite the name there is no countdown here. The gateway list carries no
// expiry instant, so the card renders the server-owned "Searching for
// Jeebers…" line and — only when the row carried a real `createdAt` — a
// past-fact "Created N ago". If a preview ever shows "Expired", the
// manufactured-deadline lie has come back.
//
// **Read the canvas knowing this: the "Searching for Jeebers…" row overflows
// on real phone widths.** `_PendingServerStatus` is a
// `Row(children: [Icon, SizedBox, Text])` in which the `Text` is neither
// `Flexible` nor `Expanded` and sets no `overflow`, so it always claims its
// full single-line intrinsic width and the row runs off the card. Measured on
// this widget, not guessed — overflow in logical px, `Searching` fixture:
//
// | text scale | 320 pt | 360 pt | 390 pt | 430 pt |
// |------------|-------:|-------:|-------:|-------:|
// | EN 1.0×    |    7   |    —   |    —   |    —   |
// | EN 1.3×    |   86   |   46   |   16   |    —   |
// | EN 1.5×    |  139   |   99   |   69   |   29   |
// | EN 2.0×    |  271   |  231   |  201   |  161   |
// | AR 2.0×    |  116   |   76   |   46   |    6   |
//
// So the DEFAULT state of the Pending tab already stripes at 100% text on a
// 320 pt phone, and from roughly 1.25× on a 390 pt one. The offers-badge
// states never overflow — `OmdsChip` wraps its own label — which is exactly
// why the two are previewed side by side.
//
// Nothing in `test/` sees this: widget tests pump into an 800×600 viewport at
// 1.0× text, where the same row has ~440 px to spare. That gap — real device
// width versus test viewport — is the whole reason these previews are worth
// opening, so the `size:` boxes below are real phone widths (390 pt, plus one
// at the 320 pt floor) rather than something roomy enough to look clean. The
// render tests inherit the same 800 px viewport and stay green; the stripes
// are a canvas finding, not a test failure.
//
// ---------------------------------------------------------------------------
// PendingReconnectBanner
// ---------------------------------------------------------------------------
//
// The banner is a pure function of one bool (`visible`): no cubit, no
// repository, no clock. Nothing here can reach the network by construction,
// well before the guard in [jeebPreviewHost] gets a say.
//
// Because the widget has only two content states, the interesting axis is not
// the data — it is the BOX. This banner is the first thing in the Pending tab,
// so what a reviewer needs to see is how much vertical space it steals from
// the list when the socket drops, and whether its [Row] still fits on the
// narrowest phone the app supports. Each preview therefore pins a device width
// and stacks a stand-in list-top under the banner; see
// [_pendingReconnectBannerListTop].
//
// Two things about that harness are worth knowing before editing it:
//
// * **The spinner is frozen.** `OmdsLoadingState` is an indeterminate
//   [CircularProgressIndicator], which never stops scheduling frames — the
//   render tests' `pumpAndSettle` would hang forever on it.
//   [_pendingReconnectBannerFrozen] mutes the ticker, which also makes the
//   canvas rendering deterministic. A still preview wants a still spinner
//   anyway.
// * **The widths are real widgets, not just canvas hints.** The `size` on
//   [JeebPreview] sizes the canvas, but the render tests pump at the default
//   800x600 surface, where every layout trivially fits. The explicit
//   [SizedBox] is what makes both readings agree.

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
///
/// Two rows rather than one on purpose: the list is a `Column` of
/// `Semantics`-wrapped cards separated by the card's own trailing `Divider`,
/// and a single row cannot show whether that separator reads as a divider or
/// as a stray underline. Each row must render ITS OWN server-derived status —
/// the regression `pending_requests_tab_test.dart` pins with
/// `findsNWidgets(2)`.
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
///
/// Worth its own preview because it is the one row variant whose status line
/// changes shape rather than just its text — a chip with a leading icon where
/// the other states put an icon + label row. `hasNewOffers` drives the filled
/// vs. tonal fill, and the tonal pair (`primaryContainer` on
/// `onPrimaryContainer`) is exactly the kind of contrast the AR-dark rendering
/// of the matrix exists to check.
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
///
/// A request with no `displayId` falls back to the customer's own typed title,
/// which is free text and can be far longer than an order id; the summary line
/// then carries the full items list, and a stale request also grows an age
/// line. All three stack in one card. The header is the interesting one — it is
/// `Expanded(title) + ClientHomeTierBadge`, and the badge is NOT flexible, so
/// this is where a long title meets an untruncatable tier label. Read the AR
/// RTL and 200%-text renderings of this preview, not the EN one: the English
/// rendering stays plausible long after the other two have broken.
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
///
/// The tallest branch by far (a 200 px illustration above a full-width button),
/// and the one that regressed before — it used to render a bare
/// `hourglass_empty` icon. It is also the branch that reaches for
/// `GoRouter.of(context)` when `onCreateRequest` is null, which is why
/// [_pendingRequestsTabHosted] always supplies one.
@JeebPreview(
  group: 'home_client',
  name: 'Empty · no pending requests',
  size: Size(_pendingRequestsTabPhoneWidth, 480),
)
Widget pendingRequestsTabEmpty() =>
    _pendingRequestsTabWithPending(const <ClientHomeRequest>[]);

/// Cold load, still in flight — a centred spinner and nothing else.
///
/// Deliberately has no text at all, which is the point: at 200% text the other
/// branches grow and this one does not move, so a reviewer can see that the tab
/// gives no hint of WHAT is loading. It is also the state that cannot settle,
/// so its render test drives fixed pumps instead of `pumpAndSettle`.
@JeebPreview(
  group: 'home_client',
  name: 'Loading · cold',
  size: Size(_pendingRequestsTabPhoneWidth, 200),
)
Widget pendingRequestsTabLoading() =>
    _pendingRequestsTabHosted(const _PendingRequestsTabStalledRepository());

/// Cold load failed: the full-screen error with a Retry CTA.
///
/// Only a COLD failure reaches here — a failed background refresh keeps the
/// previous rows on screen, and a 429 is not an error at all. Retry calls
/// `context.read<ClientHomeCubit>().load()`, so in the canvas it puts the tab
/// back into the loading state above and stays there; the fake repository has
/// nothing else to say.
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
///
/// Defaults mirror the pending fixture in
/// `test/features/home_client/pending_requests_tab_test.dart`.
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
      // recomputes it from a client clock.
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
///
/// This is the reference rendering every other state is read against, and the
/// one that carries the overflow above at its most ordinary — 201 px of stripes
/// in the EN 200% rendering at 390 pt. Check three things in the canvas: the
/// searching line stays localized in AR (`البحث عن جِيبرين…`, never English);
/// no age line appears at all, because a missing `createdAt` is UNKNOWN rather
/// than zero-age; and the word "Expired" appears nowhere.
@JeebPreview(
  group: 'home_client',
  name: 'Searching (no offers)',
  size: _pendingCountdownCardCardBox,
)
Widget pendingCountdownCardSearching() =>
    _pendingCountdownCardHosted(id: 'preview-searching');

/// The same state on the 320 pt narrow-phone floor the app still supports.
///
/// Worth its own card because it is the one rendering where the overflow is
/// visible in the **EN light, 100% text** column — the reading a reviewer
/// actually trusts. At 320 pt the searching row is already 7 px too wide before
/// any accessibility setting is touched, so this is not an a11y-ceiling
/// curiosity: it ships to every small-phone user on the default surface of the
/// client home.
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
///
/// The chip REPLACES the searching line rather than joining it, which is also
/// the fix-by-accident for the overflow above: `OmdsChip` wraps its own label,
/// so this state survives 2.0× text at 320 pt intact. Emphasised (filled) here.
///
/// Note this state is unreachable through the live client-home path — an
/// offer-bearing request is bucketed into Replies — so the canvas is the only
/// place most engineers will ever see it.
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
///
/// Put it next to the card above: the ONLY difference production draws between
/// "3 new offers you have not seen" and "1 offer you already read" is
/// `OmdsChip.isSelected`, i.e. a fill. In the AR RTL **dark** rendering, check
/// that the unselected `primaryContainer` fill is still distinguishable from
/// the card surface — if it is not, the unseen/seen distinction is invisible.
/// It also exercises the singular plural form (`1 offer` / `عرض واحد`).
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
///
/// The age line is a growing past fact ("Created 12 minutes ago"), never a
/// countdown — a future timestamp from clock skew degrades to "just now"
/// instead of going negative. It is also the tallest state: the label has no
/// `maxLines`, so at 200% text it wraps to a second line and the card grows
/// from 129 px to 237 px, which is why this box is the deepest one here.
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
///
/// * **No `displayId`** — the header degrades to the raw request `title`, which
///   is the customer's own free-text "What do you need?" line. It is
///   `Expanded` + `maxLines: 1` + ellipsis, so it must truncate rather than
///   push the tier badge off the trailing edge; in AR RTL the ellipsis has to
///   land on the *left*.
/// * **`itemsSummary` present and different from the header** — `summaryLine`
///   prefers it over the destination, at `maxLines: 2`. A second ellipsis to
///   check for mirroring.
/// * **`ClientRequestTier.unknown`** — the mid-deploy fallback for a tier the
///   app has not shipped yet. `ClientHomeTierBadge` renders an EMPTY `Text` for
///   it, so the header keeps a `Spacing.xSmall` gap trailing a badge that draws
///   nothing. Cheap to spot here, invisible in a widget test.
///
/// The searching row overflows in this state too — same root cause, and worth
/// seeing that a long header does nothing to relieve it.
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
///
/// Stands in for the first row of the pending list so the banner has something
/// to push down. Without it "collapses to nothing" and "renders a 64pt strip"
/// look identical on an empty canvas.
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
///
/// Worth a preview precisely because it should be invisible: if this ever
/// reserves space, every pending list on every phone starts 64pt lower for no
/// reason. Compare against [pendingReconnectBannerHeightCost].
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
///
/// The reference reading. Note how much of the strip is chrome — the leading
/// `OmdsLoadingState` keeps its default `EdgeInsets.all(Spacing.large)`, so a
/// 16pt spinner claims a 56pt box and drives the whole banner to 64pt tall for
/// one 16pt line of text.
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
///
/// The [Row] holds the label with no [Flexible] and no `overflow`, so it cannot
/// ellipsize or wrap: it fits until it doesn't, and then it stripes. This is the
/// width where that margin gets thin, and it is the AR RTL rendering of this
/// preview — Arabic sets slightly wider here, and the matrix never renders
/// Arabic AND 200% together — that is worth actually looking at.
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
///
/// A dropped socket does not overlay anything — it inserts a 64pt block above
/// the list, so every row jumps down by four times the height of the line of
/// text that caused it, and jumps back on reconnect. On a flaky connection that
/// is a list that will not hold still under the user's thumb.
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
