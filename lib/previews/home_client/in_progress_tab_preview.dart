/// Widget previews for [InProgressTab] — run with
/// `flutter widget-preview start`.
///
/// The tab renders nothing of its own: it is a `BlocBuilder` over
/// [ClientHomeCubit] that switches between four sub-states (failed → loading →
/// empty → list). So every preview below is *state* seeded through the cubit,
/// and the only way to seed that cubit is its repository seam.
///
/// [ClientHomeCubit] takes no `seed:`, so each state here supplies a tiny local
/// fake [ClientHomeRepository] with canned data — never `DioClientHomeRepository`.
/// A fake that returns a `Future.value` (or one that never completes, or one
/// that throws) is network-free by construction, not merely by the guard in
/// [jeebPreviewHost].
///
/// Fixture values are lifted verbatim from
/// `test/features/home_client/in_progress_tab_test.dart` — the same
/// "Pharmacy run" / "Grocery run" / `Ashrafieh, Beirut` rows that file asserts
/// on — so the preview and the widget test are describing the same screen.
///
/// **The box.** In production this tab is a direct child of the home `ListView`
/// (`client_home_screen.dart` → `_ReadyLayout`), so it gets phone width and
/// UNBOUNDED height. [_hosted] reproduces the unbounded axis with a
/// `SingleChildScrollView`; the width comes from [JeebPreview.size] (390 pt).
///
/// The width is deliberately NOT pinned with a `SizedBox` the way
/// `confirm_delivery_action_sheet_preview.dart` pins 320 pt. `flutter test`
/// substitutes a monospaced test font whose glyphs are all one em wide, which is
/// far wider than the shipping Inter/Arabic faces; pinning 390 pt makes
/// `ActiveOrderCard`'s two unguarded `Row`s (the "Open chat" + "Track my order"
/// pill pair, and the three progress-step labels) overflow in CI at text scales
/// where the real font still fits. Those failures would be artifacts of the test
/// font, not of the widget. The canvas boxes every rendering at 390 pt with the
/// REAL faces, which is where that pressure should be judged — and where the
/// `EN 200% text` and `AR RTL` renderings of the matrix earn their keep, because
/// neither `Row` can ellipsize, wrap or scroll: past the width they need, they
/// are a hard `RenderFlex` overflow.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../harness/jeeb_preview.dart';
import '../../features/home_client/application/client_home_cubit.dart';
import '../../features/home_client/domain/client_home_repository.dart';
import '../../features/home_client/domain/client_home_request.dart';
import '../../features/home_client/presentation/tabs/in_progress_tab.dart';

/// Phone width, matching the `ListView` the tab is a child of in production.
const double _phoneWidth = 390;

/// One order card is ~150 pt tall; these boxes leave room for the EN 200%-text
/// rendering of the matrix to grow into before the scroll view takes over.
const Size _oneCardBox = Size(_phoneWidth, 340);
const Size _twoCardBox = Size(_phoneWidth, 620);
const Size _placeholderBox = Size(_phoneWidth, 360);

/// Canned snapshot, resolved on the next microtask like a real (fast) load.
class _SeededHomeRepository implements ClientHomeRepository {
  const _SeededHomeRepository(this.inProgress);

  final List<ClientHomeRequest> inProgress;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(inProgress: inProgress);
}

/// A cold load that never returns — the cubit stays in
/// [ClientHomeStatus.loading] forever, which is the only way to hold the
/// loading sub-state still long enough to look at it.
class _NeverResolvingHomeRepository implements ClientHomeRepository {
  const _NeverResolvingHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// A cold load that throws. The cubit only emits [ClientHomeStatus.failed] when
/// nothing is cached yet, so this fake must fail on the FIRST call — a fake that
/// succeeded once and then threw would render the list, not the error.
class _FailingHomeRepository implements ClientHomeRepository {
  const _FailingHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw StateError('preview fixture: cold home load failed');
}

/// The tab as `client_home_screen.dart` mounts it: an ambient [ClientHomeCubit]
/// above it and unbounded height below it (the canvas box supplies the width —
/// see the library doc for why it is not pinned here).
///
/// `onTrack`/`onOpenChat` are supplied as no-ops on purpose. Left null the tab
/// falls back to `GoRouter.of(context)`, and a preview has no router — the
/// callbacks are the widget's own documented test seam.
Widget _hosted(ClientHomeRepository repository) => BlocProvider<ClientHomeCubit>(
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
ClientHomeRequest _row({
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
@JeebPreview(group: 'home_client', name: 'Two active rows', size: _twoCardBox)
Widget inProgressTabTwoRows() => _hosted(
      _SeededHomeRepository(<ClientHomeRequest>[
        _row(
          id: 'ip-1',
          title: 'Pharmacy run',
          etaMinutes: 12,
        ),
        _row(
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
@JeebPreview(group: 'home_client', name: 'Empty · no active deliveries', size: _placeholderBox)
Widget inProgressTabEmpty() =>
    _hosted(const _SeededHomeRepository(<ClientHomeRequest>[]));

/// AC6: the cold load failed.
///
/// Worth its own preview because the tab's error copy is NOT the screen's:
/// `_InProgressError` pairs `homeLoadFailedTitle` with `homeErrorRetry`
/// ("We could not load your orders. Tap to retry."), while the surrounding
/// `_FailedLayout` in `client_home_screen.dart` pairs the same title with
/// `homeLoadFailedBody`. Two different bodies under one title is exactly the
/// kind of drift only a side-by-side rendering catches.
@JeebPreview(group: 'home_client', name: 'Failed · cold load', size: _placeholderBox)
Widget inProgressTabFailed() => _hosted(const _FailingHomeRepository());

/// The load is still in flight — an indeterminate spinner, centred.
///
/// Held open by a future that never completes, so it is the one preview that
/// cannot be pumped to settlement; its render test drives fixed frames instead.
/// What to check in the canvas: the spinner is *centred in the tab*, not pinned
/// to the top-left, and it survives the AR RTL dark rendering (an indicator
/// tinted `colorScheme.primary` against the dark surface is easy to lose).
@JeebPreview(group: 'home_client', name: 'Loading · spinner', size: Size(_phoneWidth, 200))
Widget inProgressTabLoading() =>
    _hosted(const _NeverResolvingHomeRepository());

/// JEBV4-218 / Q-085 (ratified): a still-`searching` row — no Jeeber engaged —
/// STILL shows "Track my order", and must NOT show "Open chat".
///
/// This pair of gates has already flipped once. `ActiveOrderCard._canTrack` was
/// widened to every non-terminal status, and the risk of that widening was that
/// `_hasJeeber` would be widened with it and surface a phantom chat pill on an
/// order that has no conversation yet. Rendering the state is how that stays
/// visible: one CTA, end-aligned, alone in the action row.
@JeebPreview(group: 'home_client', name: 'Searching · track without chat', size: _oneCardBox)
Widget inProgressTabSearching() => _hosted(
      _SeededHomeRepository(<ClientHomeRequest>[
        _row(
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
@JeebPreview(group: 'home_client', name: 'Long title + both CTAs', size: _oneCardBox)
Widget inProgressTabLongContent() => _hosted(
      _SeededHomeRepository(<ClientHomeRequest>[
        _row(
          id: 'ip-long',
          title: 'Prescription refill from Pharmacie Al-Muhandis Ashrafieh',
          itemsSummary:
              '2 boxes paracetamol, 1 kilo potato, water gallon, coffee blend',
          etaMinutes: 47,
        ),
      ]),
    );
