import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/active_request_card.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';

import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/client_home_repository.dart';

/// T-MOB-006: Isolated In Progress tab widget.
///
/// Renders the list of active deliveries. Each row uses [ActiveOrderCard]
/// with a status pill, ETA, and Track CTA wired to `/delivery/<id>/track`.
/// Pulls from the cubit's [ClientHomeState.inProgress] list; the cubit owns
/// loading and pull-to-refresh (hoisted to [ClientHomeScreen]).
///
/// Mock endpoint: GET /v1/delivery/active  (Mockoon :3055, useMockPrefixes=false)
class InProgressTab extends StatelessWidget {
  const InProgressTab({super.key, this.onTrack, this.onOpenChat});

  /// Called when the Track CTA is tapped. If null the tab navigates to the
  /// tracking route directly via GoRouter; pass a callback in tests to avoid
  /// the router dependency.
  final void Function(ClientHomeRequest request)? onTrack;

  /// Called when the "Open chat" CTA is tapped. If null the tab navigates to
  /// the order-chat route directly via GoRouter; pass a callback in tests to
  /// avoid the router dependency.
  final void Function(ClientHomeRequest request)? onOpenChat;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      buildWhen: _rebuildWhen,
      builder: (context, state) => _InProgressContent(
        state: state,
        onTrack: onTrack ?? (r) => _navigateToTracking(context, r),
        onOpenChat: onOpenChat ?? (r) => _navigateToChat(context, r),
      ),
    );
  }

  static bool _rebuildWhen(ClientHomeState prev, ClientHomeState next) =>
      prev.status != next.status || prev.inProgress != next.inProgress;

  /// S9 P0 (restored on feat/request-scenarios — the cycle-1 merge dropped the
  /// query-param threading while keeping its test): tracking must poll by the
  /// SERVER delivery id. The card's row id may be the REQUEST id, which 404s
  /// on `GET /v1/deliveries/<id>`; when the row carries a delivery id it rides
  /// along as `?deliveryId=` and the route resolver prefers it (mirrors
  /// [_navigateToChat]).
  static void _navigateToTracking(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    // S9 live-tracking fix (mirrors home_tab.dart): navigate with the SERVER
    // delivery id (`delivery-<offerId>`) so `GET /v1/delivery/<id>` resolves
    // instead of 404'ing on a request id. The router prefers `?deliveryId=`
    // over `:id` (resolveTrackingDeliveryId); we still set the path id
    // (delivery id when known, else request id as a best-effort fallback via
    // [ClientHomeRequest.trackingId]).
    GoRouter.of(context).pushNamed(
      'live-tracking',
      pathParameters: {'id': request.trackingId},
      queryParameters: {
        if (request.deliveryId != null && request.deliveryId!.isNotEmpty)
          'deliveryId': request.deliveryId!,
      },
    );
  }

  /// Opens the accepted order's EXISTING conversation. Routes by the parent
  /// REQUEST/correlation id ([ClientHomeRequest.chatThreadId]) — NEVER a
  /// (possibly phantom) conversationId or a delivery row id — mirroring the
  /// accept-sheet CHAT-CONTRACT: `ChatDetailScreen` resolves the thread via
  /// `GET /v1/conversations?correlationKey={requestId}`, so passing a
  /// conversationId guarantees a 404 on that first lookup (BUG-17 chat-load
  /// 404 storm). The delivery id rides along as `?deliveryId=` so the in-chat
  /// "Track order" CTA still resolves.
  static void _navigateToChat(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    final deliveryId = request.trackingId;
    GoRouter.of(context).pushNamed(
      'chat-detail',
      pathParameters: {'id': request.chatThreadId},
      queryParameters: {
        if (deliveryId.isNotEmpty) 'deliveryId': deliveryId,
      },
    );
  }
}

class _InProgressContent extends StatelessWidget {
  const _InProgressContent({
    required this.state,
    required this.onTrack,
    required this.onOpenChat,
  });

  final ClientHomeState state;
  final void Function(ClientHomeRequest) onTrack;
  final void Function(ClientHomeRequest) onOpenChat;

  @override
  Widget build(BuildContext context) {
    if (state.status == ClientHomeStatus.failed) {
      return _InProgressError(
        onRetry: () => context.read<ClientHomeCubit>().load(),
      );
    }
    if (state.status == ClientHomeStatus.loading) {
      return const _InProgressLoading();
    }
    if (state.inProgress.isEmpty) {
      return _InProgressEmpty(
        onCreateRequest: () => _openCreateRequest(context),
      );
    }
    return _InProgressList(
      requests: state.inProgress,
      onTrack: onTrack,
      onOpenChat: onOpenChat,
    );
  }

  static void _openCreateRequest(BuildContext context) {
    GoRouter.of(context).pushNamed('request-type');
  }
}

class _InProgressLoading extends StatelessWidget {
  const _InProgressLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('in-progress-loading'),
      child: OmdsLoadingState(),
    );
  }
}

class _InProgressError extends StatelessWidget {
  const _InProgressError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      key: const Key('in-progress-error'),
      icon: Icons.cloud_off_outlined,
      title: l10n.homeLoadFailedTitle,
      message: l10n.homeErrorRetry,
      retryLabel: l10n.homeLoadFailedRetry,
      onRetry: onRetry,
    );
  }
}

class _InProgressEmpty extends StatelessWidget {
  const _InProgressEmpty({required this.onCreateRequest});

  final VoidCallback onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      key: const Key('in-progress-empty'),
      icon: Icons.local_shipping_outlined,
      title: l10n.homeEmptyTitle,
      subtitle: l10n.homeInProgressEmpty,
      buttonText: l10n.homeEmptyCta,
      onButtonTap: onCreateRequest,
    );
  }
}

class _InProgressList extends StatelessWidget {
  const _InProgressList({
    required this.requests,
    required this.onTrack,
    required this.onOpenChat,
  });

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest) onTrack;
  final void Function(ClientHomeRequest) onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('in-progress-list'),
      children: [
        for (final r in requests)
          Semantics(
            label: _a11yLabel(context, r),
            child: ActiveOrderCard(
              request: r,
              onTap: () => onTrack(r),
              // Post-accept conversation re-entry (JM-025). Routes by the
              // parent request/correlation id (chatThreadId), NEVER the
              // conversationId — see [InProgressTab._navigateToChat] (BUG-17).
              onOpenChat: () => onOpenChat(r),
            ),
          ),
      ],
    );
  }

  String _a11yLabel(BuildContext context, ClientHomeRequest r) {
    final l10n = AppLocalizations.of(context);
    final status = _statusLabel(context, r.status);
    final eta = r.etaMinutes != null
        ? l10n.homeRequestEtaMinutes(r.etaMinutes!)
        : l10n.homeRequestEtaUnknown;
    return l10n.inProgressTabA11yLabel(r.title, status, eta);
  }

  static String _statusLabel(BuildContext context, ClientRequestStatus s) {
    final l10n = AppLocalizations.of(context);
    switch (s) {
      case ClientRequestStatus.searching:
        return l10n.requestStatusSearching;
      case ClientRequestStatus.offersReceived:
        return l10n.homeTabReplies;
      case ClientRequestStatus.accepted:
        return l10n.homeStageOrdered;
      case ClientRequestStatus.atPickup:
        return l10n.homeStagePicked;
      case ClientRequestStatus.enRoute:
        return l10n.homeStageInTransit;
      case ClientRequestStatus.delivered:
        return l10n.deliveryStageDelivered;
      case ClientRequestStatus.cancelled:
        // Terminal; filtered out of In Progress upstream, so this is a
        // defensive label only (keeps the switch exhaustive).
        return l10n.deliveryStageCancelled;
    }
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/home_client/in_progress_tab_preview_test.dart
// ===========================================================================
//
// The tab renders nothing of its own: it is a `BlocBuilder` over
// [ClientHomeCubit] that switches between four sub-states (failed → loading →
// empty → list). So every preview below is *state* seeded through the cubit,
// and the only way to seed that cubit is its repository seam.
//
// [ClientHomeCubit] takes no `seed:`, so each state here supplies a tiny local
// fake [ClientHomeRepository] with canned data — never `DioClientHomeRepository`.
// A fake that returns a `Future.value` (or one that never completes, or one
// that throws) is network-free by construction, not merely by the guard in
// [jeebPreviewHost].
//
// Fixture values are lifted verbatim from
// `test/features/home_client/in_progress_tab_test.dart` — the same
// "Pharmacy run" / "Grocery run" / `Ashrafieh, Beirut` rows that file asserts
// on — so the preview and the widget test are describing the same screen.
//
// **The box.** In production this tab is a direct child of the home `ListView`
// (`client_home_screen.dart` → `_ReadyLayout`), so it gets phone width and
// UNBOUNDED height. [_inProgressTabHosted] reproduces the unbounded axis with a
// `SingleChildScrollView`; the width comes from [JeebPreview.size] (390 pt).
//
// The width is deliberately NOT pinned with a `SizedBox` the way
// `ConfirmDeliveryActionSheet`'s previews pin 320 pt. `flutter test`
// substitutes a monospaced test font whose glyphs are all one em wide, which is
// far wider than the shipping Inter/Arabic faces; pinning 390 pt makes
// `ActiveOrderCard`'s two unguarded `Row`s (the "Open chat" + "Track my order"
// pill pair, and the three progress-step labels) overflow in CI at text scales
// where the real font still fits. Those failures would be artifacts of the test
// font, not of the widget. The canvas boxes every rendering at 390 pt with the
// REAL faces, which is where that pressure should be judged — and where the
// `EN 200% text` and `AR RTL` renderings of the matrix earn their keep, because
// neither `Row` can ellipsize, wrap or scroll: past the width they need, they
// are a hard `RenderFlex` overflow.

/// Phone width, matching the `ListView` the tab is a child of in production.
const double _inProgressTabPhoneWidth = 390;

/// One order card is ~150 pt tall; these boxes leave room for the EN 200%-text
/// rendering of the matrix to grow into before the scroll view takes over.
const Size _inProgressTabOneCardBox = Size(_inProgressTabPhoneWidth, 340);
const Size _inProgressTabTwoCardBox = Size(_inProgressTabPhoneWidth, 620);
const Size _inProgressTabPlaceholderBox = Size(_inProgressTabPhoneWidth, 360);

/// Canned snapshot, resolved on the next microtask like a real (fast) load.
class _InProgressTabSeededHomeRepository implements ClientHomeRepository {
  const _InProgressTabSeededHomeRepository(this.inProgress);

  final List<ClientHomeRequest> inProgress;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(inProgress: inProgress);
}

/// A cold load that never returns — the cubit stays in
/// [ClientHomeStatus.loading] forever, which is the only way to hold the
/// loading sub-state still long enough to look at it.
class _InProgressTabNeverResolvingHomeRepository
    implements ClientHomeRepository {
  const _InProgressTabNeverResolvingHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// A cold load that throws. The cubit only emits [ClientHomeStatus.failed] when
/// nothing is cached yet, so this fake must fail on the FIRST call — a fake that
/// succeeded once and then threw would render the list, not the error.
class _InProgressTabFailingHomeRepository implements ClientHomeRepository {
  const _InProgressTabFailingHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw StateError('preview fixture: cold home load failed');
}

/// The tab as `client_home_screen.dart` mounts it: an ambient [ClientHomeCubit]
/// above it and unbounded height below it (the canvas box supplies the width —
/// see the banner prose for why it is not pinned here).
///
/// `onTrack`/`onOpenChat` are supplied as no-ops on purpose. Left null the tab
/// falls back to `GoRouter.of(context)`, and a preview has no router — the
/// callbacks are the widget's own documented test seam.
Widget _inProgressTabHosted(ClientHomeRepository repository) =>
    BlocProvider<ClientHomeCubit>(
      create: (_) => ClientHomeCubit(
        repository: repository,
        greetingNameProvider: () => null,
      )..load(),
      child: SingleChildScrollView(
        child: InProgressTab(
          onTrack: (ClientHomeRequest _) {},
          onOpenChat: (ClientHomeRequest _) {},
        ),
      ),
    );

/// One in-progress row, shaped like `_activeRequest` in
/// `test/features/home_client/in_progress_tab_test.dart`.
ClientHomeRequest _inProgressTabRow({
  required String id,
  required String title,
  ClientRequestStatus status = ClientRequestStatus.enRoute,
  int progressStep = 2,
  ClientRequestTier tier = ClientRequestTier.flash,
  String destinationLabel = 'Ashrafieh, Beirut',
  String? itemsSummary,
  int? etaMinutes,
}) =>
    ClientHomeRequest(
      id: id,
      title: title,
      status: status,
      destinationLabel: destinationLabel,
      itemsSummary: itemsSummary,
      etaMinutes: etaMinutes,
      progressStep: progressStep,
      tier: tier,
    );

/// The happy path: two live deliveries at different points of the same journey.
///
/// Two rows rather than one because the card is a `Column` of stacked `Row`s
/// with a hairline divider underneath, and the thing that goes wrong is the
/// *rhythm* between rows — the divider, the 8 pt vertical padding, and the
/// trailing action pills lining up down the list. A single-card preview cannot
/// show that.
///
/// The second row is `accepted` (progress step 0, Express) so both the empty end
/// of the progress bar and a second tier colour are on screen at once.
@JeebPreview(
  group: 'home_client',
  name: 'Two active rows',
  size: _inProgressTabTwoCardBox,
)
Widget inProgressTabTwoRows() => _inProgressTabHosted(
      _InProgressTabSeededHomeRepository(<ClientHomeRequest>[
        _inProgressTabRow(
          id: 'ip-1',
          title: 'Pharmacy run',
          etaMinutes: 12,
        ),
        _inProgressTabRow(
          id: 'ip-2',
          title: 'Grocery run',
          status: ClientRequestStatus.accepted,
          progressStep: 0,
          tier: ClientRequestTier.express,
        ),
      ]),
    );

/// AC2: nothing in flight.
///
/// The `OmdsEmptyState` here is the tab's *whole* surface — icon, title,
/// subtitle and a primary CTA — so it is the state most sensitive to the 200%
/// rendering: four stacked elements with no scroll of their own inside the card
/// area, and the CTA is the one thing that must stay reachable.
@JeebPreview(
  group: 'home_client',
  name: 'Empty · no active deliveries',
  size: _inProgressTabPlaceholderBox,
)
Widget inProgressTabEmpty() => _inProgressTabHosted(
      const _InProgressTabSeededHomeRepository(<ClientHomeRequest>[]),
    );

/// AC6: the cold load failed.
///
/// Worth its own preview because the tab's error copy is NOT the screen's:
/// `_InProgressError` pairs `homeLoadFailedTitle` with `homeErrorRetry`
/// ("We could not load your orders. Tap to retry."), while the surrounding
/// `_FailedLayout` in `client_home_screen.dart` pairs the same title with
/// `homeLoadFailedBody`. Two different bodies under one title is exactly the
/// kind of drift only a side-by-side rendering catches.
@JeebPreview(
  group: 'home_client',
  name: 'Failed · cold load',
  size: _inProgressTabPlaceholderBox,
)
Widget inProgressTabFailed() =>
    _inProgressTabHosted(const _InProgressTabFailingHomeRepository());

/// The load is still in flight — an indeterminate spinner, centred.
///
/// Held open by a future that never completes, so it is the one preview that
/// cannot be pumped to settlement; its render test drives fixed frames instead.
/// What to check in the canvas: the spinner is *centred in the tab*, not pinned
/// to the top-left, and it survives the AR RTL dark rendering (an indicator
/// tinted `colorScheme.primary` against the dark surface is easy to lose).
@JeebPreview(
  group: 'home_client',
  name: 'Loading · spinner',
  size: Size(_inProgressTabPhoneWidth, 200),
)
Widget inProgressTabLoading() =>
    _inProgressTabHosted(const _InProgressTabNeverResolvingHomeRepository());

/// JEBV4-218 / Q-085 (ratified): a still-`searching` row — no Jeeber engaged —
/// STILL shows "Track my order", and must NOT show "Open chat".
///
/// This pair of gates has already flipped once. `ActiveOrderCard._canTrack` was
/// widened to every non-terminal status, and the risk of that widening was that
/// `_hasJeeber` would be widened with it and surface a phantom chat pill on an
/// order that has no conversation yet. Rendering the state is how that stays
/// visible: one CTA, end-aligned, alone in the action row.
@JeebPreview(
  group: 'home_client',
  name: 'Searching · track without chat',
  size: _inProgressTabOneCardBox,
)
Widget inProgressTabSearching() => _inProgressTabHosted(
      _InProgressTabSeededHomeRepository(<ClientHomeRequest>[
        _inProgressTabRow(
          id: 'ip-searching',
          title: 'Birthday cake, Hamra',
          status: ClientRequestStatus.searching,
          progressStep: 0,
          tier: ClientRequestTier.standard,
        ),
      ]),
    );

/// The layout ceiling: the longest plausible title and subtitle a real request
/// produces, on a row that shows BOTH action pills.
///
/// Three independent squeezes meet here, and each has its own failure mode:
///
/// * the header `Row` — a `Flexible` title beside a tier badge that is NOT
///   flexible, so the title must ellipsize rather than push "Flash" off the
///   trailing edge;
/// * the subtitle — `summaryLine`, which prefers the customer's own free-text
///   description over the destination, capped at one line;
/// * the action `Row` — "Open chat" + "Track my order" side by side, end-
///   aligned, with neither wrapped in a `Flexible`. At 200% text this is the
///   pair most likely to run out of width.
///
/// `enRoute` (not `accepted`) so both pills render.
@JeebPreview(
  group: 'home_client',
  name: 'Long title + both CTAs',
  size: _inProgressTabOneCardBox,
)
Widget inProgressTabLongContent() => _inProgressTabHosted(
      _InProgressTabSeededHomeRepository(<ClientHomeRequest>[
        _inProgressTabRow(
          id: 'ip-long',
          title: 'Prescription refill from Pharmacie Al-Muhandis Ashrafieh',
          itemsSummary:
              '2 boxes paracetamol, 1 kilo potato, water gallon, coffee blend',
          etaMinutes: 47,
        ),
      ]),
    );
