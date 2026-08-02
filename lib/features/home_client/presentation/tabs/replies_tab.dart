import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../client_offers/domain/offers_repository.dart';
import '../../../client_offers/presentation/widgets/offer_accept_sheet.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/replies_card.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';

import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/client_home_repository.dart';

/// JM-027 — Replies sub-tab (`my-orders`).
///
/// Renders requests where ≥1 Jeeber has replied with an offer. Each row shows
/// the stacked offerer avatars (max 3 + overflow count), an offer badge, and a
/// CTA row with two actions:
///   * `replies_check_offers_cta` → `offer-review` list (`/requests/:id/offers`,
///     JM-028). This REPLACES the old divergent `→ /chat/:id` edge the gap map
///     flagged for `my-orders` (20_GAP_MAP customer row + 21_NAV_PLAN §"185").
///   * `replies_accept_cta` → `offer-accept-confirm` sheet (`offer_accept_sheet`,
///     JM-029) [D11/D71].
///
/// Avatar images are rendered by [OmdsProfileAvatar] with network URLs to
/// benefit from the OS image cache.
///
/// WS push integration: real-time offer increments are handled by the cubit;
/// this tab rebuilds when the cubit emits a new replies list.
///
/// Mock endpoint: `GET /delivery-service/v1/requests?status=offers-received`
/// (reached via the `/v1/requests` gateway-contract path the home repository
/// already speaks; `MockGatewayClient` rewrites the prefix to :4010).
class RepliesTab extends StatefulWidget {
  const RepliesTab({super.key, this.onCheckOffers, this.onAccept});

  /// Called when `replies_check_offers_cta` is tapped. When null the tab routes
  /// to the registered `offer-review` route itself (JM-028); tests inject a
  /// callback to observe the tapped request.
  final void Function(ClientHomeRequest request)? onCheckOffers;

  /// Called when `replies_accept_cta` is tapped. When null the tab opens the
  /// `offer-accept-confirm` sheet (JM-029) via [_openAcceptConfirm]; tests
  /// inject a callback to observe the tapped request.
  final void Function(ClientHomeRequest request)? onAccept;

  @override
  State<RepliesTab> createState() => _RepliesTabState();
}

class _RepliesTabState extends State<RepliesTab> {
  // B-01 (second call site): guards against a double-tap on the reply Accept
  // CTA stacking two `offer-accept-confirm` sheets (each would open its own
  // accept flow → the double-accept surface the auditor flagged widening from
  // this home-replies entry point). True from the first tap until the sheet the
  // tap opened has closed.
  bool _openingAcceptSheet = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      buildWhen: _rebuildWhen,
      builder: (context, state) => _RepliesContent(
        state: state,
        onCheckOffers:
            widget.onCheckOffers ?? (r) => _openOfferReview(context, r),
        onAccept: widget.onAccept ?? (r) => _openAcceptConfirm(context, r),
      ),
    );
  }

  static bool _rebuildWhen(ClientHomeState prev, ClientHomeState next) =>
      prev.status != next.status || prev.replies != next.replies;

  /// JM-027 AC1: Check Offers → offer-review-list (JM-028), NOT chat.
  /// Routes to the registered `offer-review` route (`/requests/:id/offers`),
  /// keyed by the request id (the seam seeds it as `req-client-001-offers`).
  static void _openOfferReview(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    if (request.id.isEmpty) return;
    GoRouter.of(
      context,
    ).pushNamed('offer-review', pathParameters: {'id': request.id});
  }

  /// JM-027 AC2: Accept → offer-accept-confirm sheet (`offer_accept_sheet`,
  /// JM-029) [D11/D71].
  ///
  /// JM-029's `OfferAcceptSheet` (a `showModalBottomSheet`, no route —
  /// 21_NAV_PLAN §"117") has now landed, so the reply card's Accept opens it
  /// directly. The reply card only carries the [ClientHomeRequest], so we
  /// resolve the request's open offers via [OffersRepository] (the same
  /// gateway-backed read the offer-review list uses) and front the
  /// top-of-list offer on the sheet (D11/D71 comprehension gate). On any
  /// failure / no offers / no GoRouter we degrade HONESTLY to the registered
  /// `offer-review` route — where JM-028's `offer_card_<id>_accept_cta` opens
  /// the same sheet — so the nav is never a dead end.
  Future<void> _openAcceptConfirm(
    BuildContext context,
    ClientHomeRequest request,
  ) async {
    if (request.id.isEmpty) return;
    // B-01: swallow a second tap while the first is still resolving offers /
    // showing the sheet, so two accept sheets never stack.
    if (_openingAcceptSheet) return;
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<OffersRepository>()) {
      _openOfferReview(context, request);
      return;
    }
    final repository = getIt<OffersRepository>();
    _openingAcceptSheet = true;
    try {
      final snapshot = await repository.fetchOffers(request.id);
      if (!context.mounted) return;
      if (snapshot.offers.isEmpty) {
        _openOfferReview(context, request);
        return;
      }
      await OfferAcceptSheet.show(
        context,
        offer: snapshot.offers.first,
        requestId: request.id,
      );
    } catch (_) {
      // Soft-fail to the honest registered destination rather than trapping
      // the user (40_GUARDRAILS_ARCH §6.7 navigation honesty).
      if (!context.mounted) return;
      _openOfferReview(context, request);
    } finally {
      _openingAcceptSheet = false;
    }
  }
}

class _RepliesContent extends StatelessWidget {
  const _RepliesContent({
    required this.state,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeState state;
  final void Function(ClientHomeRequest) onCheckOffers;
  final void Function(ClientHomeRequest) onAccept;

  @override
  Widget build(BuildContext context) {
    if (state.status == ClientHomeStatus.failed) {
      return _RepliesError(
        onRetry: () => context.read<ClientHomeCubit>().load(),
      );
    }
    if (state.status == ClientHomeStatus.loading) {
      return const _RepliesLoading();
    }
    if (state.replies.isEmpty) {
      return const _RepliesEmpty();
    }
    return _RepliesList(
      requests: state.replies,
      onCheckOffers: onCheckOffers,
      onAccept: onAccept,
    );
  }
}

class _RepliesLoading extends StatelessWidget {
  const _RepliesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(key: Key('replies-loading'), child: OmdsLoadingState());
  }
}

class _RepliesError extends StatelessWidget {
  const _RepliesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      key: const Key('replies-error'),
      icon: Icons.cloud_off_outlined,
      title: l10n.homeLoadFailedTitle,
      message: l10n.homeErrorRetry,
      retryLabel: l10n.homeLoadFailedRetry,
      onRetry: onRetry,
    );
  }
}

class _RepliesEmpty extends StatelessWidget {
  const _RepliesEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      key: const Key('replies-empty'),
      icon: Icons.mark_chat_unread_outlined,
      title: l10n.homeEmptyTitle,
      subtitle: l10n.homeRepliesEmpty,
    );
  }
}

class _RepliesList extends StatelessWidget {
  const _RepliesList({
    required this.requests,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest) onCheckOffers;
  final void Function(ClientHomeRequest) onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('replies-tab-list'),
      children: [
        for (final r in requests)
          Semantics(
            label: _a11yLabel(context, r),
            child: RepliesCard(
              request: r,
              onCheckOffers: () => onCheckOffers(r),
              onAccept: () => onAccept(r),
            ),
          ),
      ],
    );
  }

  String _a11yLabel(BuildContext context, ClientHomeRequest r) {
    final l10n = AppLocalizations.of(context);
    return l10n.repliesTabA11yLabel(r.offerCount);
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/home_client/replies_tab_preview_test.dart
// ===========================================================================
//
// [RepliesTab] is a pure projection of [ClientHomeState]: it branches on
// `status` (failed → error, loading → spinner) and then on `replies.isEmpty`,
// so all four of its visual branches are reachable by seeding the cubit and
// nothing else. There is no seam to seed the cubit directly — [ClientHomeCubit]
// takes a repository, not a state — so each preview builds the cubit over a
// LOCAL fake repository declared below and calls `load()`. The three fakes
// (`_RepliesTabSeededHomeRepository`, `_RepliesTabFailingHomeRepository`,
// `_RepliesTabStalledHomeRepository`) return canned data, throw, or never
// complete respectively; none of them can reach the network, which is the rule
// rather than something [jeebPreviewHost]'s guard should have to catch.
//
// Two deliberate deviations from how production drives this tab, both so the
// canvas stays honest:
//
//  * **Explicit no-op callbacks.** `const RepliesTab()` in
//    `client_home_screen.dart` passes none, so both CTAs fall through to the
//    widget's own defaults — `GoRouter.of(context)` and
//    `GetIt.instance<OffersRepository>()`. Neither exists under the preview
//    host, so a tap in the canvas would throw instead of showing a state. The
//    previews inject empty handlers; what they review is the CTA ROW's layout,
//    not its navigation (that is `test/features/home_client/replies_tab_test.dart`'s job).
//  * **Empty avatar URLs.** [RepliesCard] renders offerer avatars through
//    `OmdsProfileAvatar` → `CachedNetworkImage`. With a URL, every preview
//    would try to fetch from a CDN the canvas cannot reach and settle on the
//    error glyph; with an empty one the avatar falls back to its initials
//    placeholder, which is both network-free and the same geometry — the
//    overlap ramp and the "+N" cluster are what this card's layout risk lives
//    in, not the image bytes.
//
// Fixture values (`ORD-234xx`, `Hamra, Beirut`, five/nine offers, three
// avatars) are lifted from `test/features/home_client/replies_tab_test.dart`
// so the canvas and the widget test describe the same rows.
//
// One state is deliberately absent: `ClientHomeStatus.initial`. Before
// `load()` runs, `_RepliesContent` falls through to `replies.isEmpty` and
// paints the SAME empty state as a finished load that found nothing — so
// "we have not asked yet" and "there are no replies" are pixel-identical.
// That is a widget-level finding, not a missing preview: `Empty` below already
// shows exactly what the pre-load frame looks like.

/// One reply row: header + two-line summary + the CTA row + divider. Phone
/// width, because the CTA row is `MainAxisAlignment.end` and only overflows
/// when the box is as narrow as a real phone.
///
/// Public because `test/previews/home_client/replies_tab_preview_test.dart`
/// pumps into this exact box — the whole point of that suite is that the
/// defects only appear at real phone width.
const Size repliesTabCardBox = Size(390, 200);

/// The full-tab states (empty / error / loading) centre an icon + copy block,
/// so they need the height a tab body actually gets.
const Size _repliesTabStateBox = Size(390, 340);

/// Three stacked rows. `_RepliesList` is a bare [Column] with no scrollable of
/// its own — in production it is a child of the home `ListView`, so it may be
/// any height. The canvas has to supply that height itself.
const Size _repliesTabListBox = Size(390, 620);

/// Canned snapshot, delivered on the next microtask. The cubit's `load()`
/// therefore passes through `loading` and lands on `ready`.
class _RepliesTabSeededHomeRepository implements ClientHomeRepository {
  const _RepliesTabSeededHomeRepository(this.replies);

  final List<ClientHomeRequest> replies;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(replies: replies);
}

/// A cold load that throws. `ClientHomeCubit._fetch` swallows the error and
/// emits `failed` only because nothing is cached yet — which is precisely the
/// condition this tab's error state is for.
class _RepliesTabFailingHomeRepository implements ClientHomeRepository {
  const _RepliesTabFailingHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw Exception('preview: home snapshot unreachable');
}

/// A read that never resolves, so the cubit stays on `loading` for as long as
/// the canvas is open. A `Completer` that is never completed holds no timer and
/// no subscription — it simply never settles.
class _RepliesTabStalledHomeRepository implements ClientHomeRepository {
  const _RepliesTabStalledHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

Widget _repliesTabHosted(ClientHomeRepository repository) {
  return BlocProvider<ClientHomeCubit>(
    create: (_) => ClientHomeCubit(
      repository: repository,
      // The Replies tab never reads the greeting; `null` keeps the fake
      // narrower than the state it feeds.
      greetingNameProvider: () => null,
    )..load(),
    child: RepliesTab(onCheckOffers: (_) {}, onAccept: (_) {}),
  );
}

/// A replies row. [avatarCount] drives how many overlapping circles render;
/// `offerCount - avatarCount` is what the "+N" cluster shows.
ClientHomeRequest _repliesTabReply({
  required String displayId,
  required int offerCount,
  int avatarCount = 3,
  String destination = 'Hamra, Beirut',
  String? itemsSummary,
}) {
  return ClientHomeRequest(
    id: displayId.toLowerCase(),
    displayId: displayId,
    title: displayId,
    status: ClientRequestStatus.offersReceived,
    destinationLabel: destination,
    itemsSummary: itemsSummary,
    tier: ClientRequestTier.express,
    offerCount: offerCount,
    // Empty strings on purpose — see the banner prose: the avatar resolves to
    // its initials placeholder instead of reaching for a CDN.
    offerAvatarUrls: List<String>.filled(avatarCount, ''),
    conversationId: 'conv-${displayId.toLowerCase()}',
  );
}

/// The Figma reference row (`+6 offers`): nine offers, three inline avatars.
///
/// Three things have to survive together on one line here — an ellipsizing
/// order id, the overlap ramp, and the `+6` counter — and the header [Row]
/// gives the id an `Expanded` while the stack takes its intrinsic width. This
/// is the state to read the AR RTL rendering of: the stack is built from
/// `PositionedDirectional`, so if the overlap ever stops mirroring, it stops
/// here first.
@JeebPreview(
  group: 'home_client',
  name: 'Nine offers · +6',
  size: repliesTabCardBox,
)
Widget repliesTabWithOverflowCount() => _repliesTabHosted(
      _RepliesTabSeededHomeRepository(<ClientHomeRequest>[
        _repliesTabReply(displayId: 'ORD-23470', offerCount: 9),
      ]),
    );

/// Layout ceiling: the longest row the gateway can actually produce.
///
/// A redelivery order id long past the width of the header, a three-digit offer
/// count (`+117`, a broadcast that went wide), and a `summaryLine` built from
/// the customer's own free-text description — the field is `maxLines: 2`, so
/// this is where the two-line clamp is either enough or visibly not.
///
/// The 200% rendering of this preview is the one that matters: `Accept` and
/// `Check Offers` are `IntrinsicWidth` pills in an end-aligned [Row] with no
/// `Wrap`, `Flexible` or `FittedBox` anywhere, so their combined width scales
/// with the text scale while the 390 dp box does not.
@JeebPreview(
  group: 'home_client',
  name: 'Long content · +117',
  size: repliesTabCardBox,
)
Widget repliesTabLongContent() => _repliesTabHosted(
      _RepliesTabSeededHomeRepository(<ClientHomeRequest>[
        _repliesTabReply(
          displayId: 'ORD-23470-EXPRESS-REDELIVERY-ATTEMPT-3',
          offerCount: 120,
          itemsSummary: '1 kilo potato, water gallon, coffee blend, two boxes '
              'of paracetamol, a phone charger and whatever else is still open '
              'at this hour near the pharmacy',
          destination: 'Rue Gouraud, Gemmayzeh, Beirut',
        ),
      ]),
    );

/// Three rows at once, spanning all three shapes of the offer cluster: one
/// offer (no `+N` badge at all — `extra == 0` hides it), five offers (`+2`) and
/// nine (`+6`).
///
/// The list is the state that shows what `_RepliesList` is: a [Column], not a
/// [ListView]. It cannot scroll and it does not lazily build, so its height is
/// entirely the host's problem — fine under the home `ListView`, and the reason
/// this preview needs a 620 dp box while every other one fits in 200.
@JeebPreview(
  group: 'home_client',
  name: 'Three replies',
  size: _repliesTabListBox,
)
Widget repliesTabMultipleReplies() => _repliesTabHosted(
      _RepliesTabSeededHomeRepository(<ClientHomeRequest>[
        _repliesTabReply(
          displayId: 'ORD-23471',
          offerCount: 1,
          avatarCount: 1,
        ),
        _repliesTabReply(displayId: 'ORD-23472', offerCount: 5),
        _repliesTabReply(displayId: 'ORD-23473', offerCount: 9),
      ]),
    );

/// No replies yet — the state a sender sees between submitting a request and
/// the first Jeeber bidding, which is most of the time they spend on this tab.
///
/// Note the title: the tab reuses `homeEmptyTitle` ("What do you need?"), the
/// NEW-ORDER prompt, over a subtitle that explains there are no replies. It
/// reads as a call to action on a tab that has no action, and it is identical
/// to the frame rendered before `load()` has returned.
@JeebPreview(
  group: 'home_client',
  name: 'Empty',
  size: _repliesTabStateBox,
)
Widget repliesTabEmpty() => _repliesTabHosted(
      const _RepliesTabSeededHomeRepository(<ClientHomeRequest>[]),
    );

/// Cold load failed: no cached snapshot, so the whole tab is replaced by the
/// error block and its Retry button.
///
/// Worth reviewing next to `Empty` — both are icon + title + copy centred in
/// the tab, and at a glance the only difference is the icon and the ink colour,
/// so the error has to carry its meaning in the copy alone.
@JeebPreview(
  group: 'home_client',
  name: 'Load failed',
  size: _repliesTabStateBox,
)
Widget repliesTabFailed() =>
    _repliesTabHosted(const _RepliesTabFailingHomeRepository());

/// The read is in flight and nothing is cached.
///
/// This is a spinner with no text of any kind — no skeleton row, no "loading
/// your replies". It is the only state of the four that tells a screen-reader
/// user nothing at all, and on a slow connection it is what fills the tab.
@JeebPreview(
  group: 'home_client',
  name: 'Loading',
  size: _repliesTabStateBox,
)
Widget repliesTabLoading() =>
    _repliesTabHosted(const _RepliesTabStalledHomeRepository());
