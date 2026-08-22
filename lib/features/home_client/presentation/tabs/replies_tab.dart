import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
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

class RepliesTab extends StatefulWidget {
  const RepliesTab({
    super.key,
    this.onCheckOffers,
    this.onAccept,
    this.hideWhenEmpty = false,
  });

  final void Function(ClientHomeRequest request)? onCheckOffers;

  final void Function(ClientHomeRequest request)? onAccept;

  /// Collapses to nothing instead of drawing an empty state — set when this
  /// list is one section of the merged home list, which owns that state.
  final bool hideWhenEmpty;

  @override
  State<RepliesTab> createState() => _RepliesTabState();
}

class _RepliesTabState extends State<RepliesTab> {
  bool _openingAcceptSheet = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      buildWhen: _rebuildWhen,
      builder: (context, state) => _RepliesContent(
        state: state,
        hideWhenEmpty: widget.hideWhenEmpty,
        onCheckOffers:
            widget.onCheckOffers ?? (r) => _openOfferReview(context, r),
        onAccept: widget.onAccept ?? (r) => _openAcceptConfirm(context, r),
      ),
    );
  }

  static bool _rebuildWhen(ClientHomeState prev, ClientHomeState next) =>
      prev.status != next.status || prev.replies != next.replies;

  static void _openOfferReview(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    if (request.id.isEmpty) return;
    GoRouter.of(
      context,
    ).pushNamed('offer-review', pathParameters: {'id': request.id});
  }

  Future<void> _openAcceptConfirm(
    BuildContext context,
    ClientHomeRequest request,
  ) async {
    if (request.id.isEmpty) return;
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
    required this.hideWhenEmpty,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeState state;
  final bool hideWhenEmpty;
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
    // Collapse only AFTER the failed/loading branches: an empty list during a
    // failed load still owes the reader a retry, not silence.
    if (hideWhenEmpty && state.replies.isEmpty) {
      return const SizedBox.shrink();
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
    return JeebEmptyState(
      key: const Key('replies-loading'),
      status: JeebEmptyStateStatus.loading,
      headline: AppLocalizations.of(context).homeEmptyTitle,
    );
  }
}

class _RepliesError extends StatelessWidget {
  const _RepliesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      key: const Key('replies-error'),
      status: JeebEmptyStateStatus.error,
      headline: l10n.homeLoadFailedTitle,
      body: l10n.homeErrorRetry,
      action: IntrinsicWidth(
        child: JeebCtaButton.primary(
          label: l10n.homeLoadFailedRetry,
          identifier: 'replies_retry_cta',
          expand: false,
          onTap: onRetry,
        ),
      ),
    );
  }
}

class _RepliesEmpty extends StatelessWidget {
  const _RepliesEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      key: const Key('replies-empty'),
      // Not `homeEmptyTitle`: the permanent hero prompt already asks that.
      headline: l10n.homeRepliesEmptyTitle,
      body: l10n.homeRepliesEmpty,
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
      // stretch, never the default centre: centre gives each card loose width,
      // so it shrink-wraps to its text instead of filling the gutter.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < requests.length; i++) ...[
          // Board gap 12 (02-PLAN R12). The cards used to end in a divider and
          // carry their own vertical padding; outlined cards separate
          // themselves, so the rhythm is an explicit gap now.
          if (i > 0) const SizedBox(height: Spacing.small),
          Semantics(
            label: _a11yLabel(context, requests[i]),
            child: RepliesCard(
              request: requests[i],
              onCheckOffers: () => onCheckOffers(requests[i]),
              onAccept: () => onAccept(requests[i]),
            ),
          ),
        ],
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

/// One reply row: header + two-line summary + the CTA row + divider. Phone
/// width, because the CTA row is `MainAxisAlignment.end` and only overflows
const Size _repliesTabCardBox = Size(390, 200);

/// The full-tab states (empty / error / loading) centre an icon + copy block,
/// so they need the height a tab body actually gets.
const Size _repliesTabStateBox = Size(390, 340);

/// Three stacked rows. `_RepliesList` is a bare [Column] with no scrollable of
/// its own — in production it is a child of the home `ListView`, so it may be
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
    offerAvatarUrls: List<String>.filled(avatarCount, ''),
    conversationId: 'conv-${displayId.toLowerCase()}',
  );
}

/// The Figma reference row (`+6 offers`): nine offers, three inline avatars.
/// Three things have to survive together on one line here — an ellipsizing
@JeebPreview(
  group: 'home_client',
  name: 'Nine offers · +6',
  size: _repliesTabCardBox,
)
Widget repliesTabWithOverflowCount() => _repliesTabHosted(
      _RepliesTabSeededHomeRepository(<ClientHomeRequest>[
        _repliesTabReply(displayId: 'ORD-23470', offerCount: 9),
      ]),
    );

/// Layout ceiling: the longest row the gateway can actually produce.
/// A redelivery order id long past the width of the header, a three-digit offer
@JeebPreview(
  group: 'home_client',
  name: 'Long content · +117',
  size: _repliesTabCardBox,
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
@JeebPreview(
  group: 'home_client',
  name: 'Load failed',
  size: _repliesTabStateBox,
)
Widget repliesTabFailed() =>
    _repliesTabHosted(const _RepliesTabFailingHomeRepository());

/// The read is in flight and nothing is cached.
/// This is a spinner with no text of any kind — no skeleton row, no "loading
@JeebPreview(
  group: 'home_client',
  name: 'Loading',
  size: _repliesTabStateBox,
)
Widget repliesTabLoading() =>
    _repliesTabHosted(const _RepliesTabStalledHomeRepository());
