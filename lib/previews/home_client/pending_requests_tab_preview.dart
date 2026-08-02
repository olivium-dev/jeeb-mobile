/// Widget previews for [PendingRequestsTab] — run with
/// `flutter widget-preview start`.
///
/// The tab renders one of four mutually exclusive branches off
/// [ClientHomeState] — failed, loading, empty, list — so a preview per branch
/// is the minimum honest coverage. Each is driven the way production drives it:
/// a real [ClientHomeCubit] over a LOCAL fake [ClientHomeRepository] that
/// answers from canned data, throws, or never answers. No Dio, no DI graph, no
/// network — the guard in [jeebPreviewHost] is the net, not the plan.
///
/// Two things the previews reproduce on purpose:
///
///  * **The host is a scroll view.** In production the tab is a child of the
///    home screen's `ListView` (`_ReadyLayout._scrollChildren`), so it builds
///    under an UNBOUNDED vertical constraint and its `Column` of rows can never
///    overflow. Previewing it in a bare fixed box would invent a failure the
///    app cannot have, so [_hosted] supplies the same unbounded constraint.
///  * **Both callbacks are wired.** `onCreateRequest` matters because the empty
///    branch falls back to `GoRouter.of(context)` when it is null, and there is
///    no router in a preview; `onTap` matters because it is what makes a card
///    expose `button: true` semantics.
///
/// Fixture values (`ORD-23470`, `Achrafieh`, the 12m30s age, the 3-offer badge)
/// are lifted from `test/features/home_client/pending_requests_tab_test.dart`
/// so the canvas and the assertions describe the same rows.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/home_client/application/client_home_cubit.dart';
import '../../features/home_client/domain/client_home_repository.dart';
import '../../features/home_client/domain/client_home_request.dart';
import '../../features/home_client/presentation/tabs/pending_requests_tab.dart';
import '../harness/jeeb_preview.dart';

/// Phone width; the height varies per state because these branches differ by
/// hundreds of logical pixels (a spinner vs. an illustrated empty state).
const double _phoneWidth = 390;

/// Answers one canned snapshot. Nothing else — no latency, no second read.
class _CannedClientHomeRepository implements ClientHomeRepository {
  const _CannedClientHomeRepository(this.pending);

  final List<ClientHomeRequest> pending;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(pending: pending);
}

/// Never answers, so the cubit stays in [ClientHomeStatus.loading] forever.
/// A pending [Completer] is the whole implementation: no timer to leak and no
/// socket to open.
class _StalledClientHomeRepository implements ClientHomeRepository {
  const _StalledClientHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// Fails the COLD load, which is the only way to reach
/// [ClientHomeStatus.failed] — the cubit deliberately swallows a failed
/// refresh when data is already on screen.
class _FailingClientHomeRepository implements ClientHomeRepository {
  const _FailingClientHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw StateError('preview: gateway unreachable');
}

Widget _hosted(ClientHomeRepository repository) {
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

Widget _withPending(List<ClientHomeRequest> pending) =>
    _hosted(_CannedClientHomeRepository(pending));

/// A pending row as the gateway returns one: searching, no offers, no expiry.
ClientHomeRequest _pending({
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
@JeebPreview(name: 'Searching · two requests', size: Size(_phoneWidth, 300))
Widget pendingRequestsTabSearching() => _withPending(<ClientHomeRequest>[
  _pending(),
  _pending(
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
@JeebPreview(name: 'Offers arrived · 3 unseen', size: Size(_phoneWidth, 220))
Widget pendingRequestsTabOffers() => _withPending(<ClientHomeRequest>[
  _pending(offerCount: 3, hasNewOffers: true),
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
@JeebPreview(name: 'Longest content · no order id', size: Size(_phoneWidth, 260))
Widget pendingRequestsTabLongContent() => _withPending(<ClientHomeRequest>[
  _pending(
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
/// [_hosted] always supplies one.
@JeebPreview(name: 'Empty · no pending requests', size: Size(_phoneWidth, 480))
Widget pendingRequestsTabEmpty() => _withPending(const <ClientHomeRequest>[]);

/// Cold load, still in flight — a centred spinner and nothing else.
///
/// Deliberately has no text at all, which is the point: at 200% text the other
/// branches grow and this one does not move, so a reviewer can see that the tab
/// gives no hint of WHAT is loading. It is also the state that cannot settle,
/// so its render test drives fixed pumps instead of `pumpAndSettle`.
@JeebPreview(name: 'Loading · cold', size: Size(_phoneWidth, 200))
Widget pendingRequestsTabLoading() => _hosted(const _StalledClientHomeRepository());

/// Cold load failed: the full-screen error with a Retry CTA.
///
/// Only a COLD failure reaches here — a failed background refresh keeps the
/// previous rows on screen, and a 429 is not an error at all. Retry calls
/// `context.read<ClientHomeCubit>().load()`, so in the canvas it puts the tab
/// back into the loading state above and stays there; the fake repository has
/// nothing else to say.
@JeebPreview(name: 'Failed · cold load', size: Size(_phoneWidth, 320))
Widget pendingRequestsTabFailed() => _hosted(const _FailingClientHomeRepository());
