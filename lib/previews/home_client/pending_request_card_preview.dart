/// Widget previews for [PendingRequestCard] — run with
/// `flutter widget-preview start`.
///
/// The card is a pure function of one [ClientHomeRequest]: no cubit, no
/// repository, no clock. Every state below is therefore a plain value object,
/// which makes these previews network-free by construction rather than by the
/// guard in [jeebPreviewHost].
///
/// Fixture values mirror `test/features/home_client/pending_requests_tab_test.dart`
/// (`ORD-234xx` / `Achrafieh` / express tier) so a reviewer comparing the card
/// against its sibling `PendingCountdownCard` is looking at the same data.
///
/// The states that matter are the ones where the *derived* strings move:
/// `displayId ?? title` for the header and [ClientHomeRequest.summaryLine] for
/// the subtitle — the latter deliberately falls back to the destination and can
/// come back empty, which the card renders as a blank line.
library;

import 'package:flutter/material.dart';

import '../../features/home_client/domain/client_home_request.dart';
import '../../features/home_client/presentation/widgets/pending_request_card.dart';
import '../harness/jeeb_preview.dart';

/// A pending row is a list item, not a card with its own surface: phone width,
/// header + two summary lines + divider.
const Size _rowBox = Size(390, 120);

/// The same box with headroom for the two-line summary the long-content state
/// fills.
const Size _tallRowBox = Size(390, 140);

/// Fixture in the shape the live `GET /v1/requests?status=pending` row arrives
/// in — a pending request has no jeeber, no ETA and no progress.
ClientHomeRequest _pending({
  String id = 'pen-1',
  String? displayId = 'ORD-23470',
  String title = 'ORD-23470',
  String destinationLabel = 'Achrafieh',
  String? itemsSummary,
  ClientRequestTier tier = ClientRequestTier.express,
}) =>
    ClientHomeRequest(
      id: id,
      displayId: displayId,
      title: title,
      destinationLabel: destinationLabel,
      itemsSummary: itemsSummary,
      status: ClientRequestStatus.searching,
      tier: tier,
    );

Widget _hosted(ClientHomeRequest request) => PendingRequestCard(
      request: request,
      onTap: () {},
    );

/// The happy path: a server-issued order id, a tier badge, and the destination
/// standing in for a missing items list.
///
/// This is what a sender sees in the seconds after submitting, before any
/// Jeeber replies.
@JeebPreview(name: 'Searching', size: _rowBox)
Widget pendingRequestCardSearching() => _hosted(_pending());

/// No `displayId` on the row — the header falls back to [title].
///
/// Also the G1 echo guard, made visible: `itemsSummary` here is byte-identical
/// to the header (the customer's own "What do you need?" text became both), so
/// [ClientHomeRequest.summaryLine] must drop to the destination instead of
/// printing the same sentence twice. If this preview ever shows
/// "Pharmacy run for Mom" on both lines, that guard has regressed.
@JeebPreview(name: 'No display id (title fallback)', size: _rowBox)
Widget pendingRequestCardTitleFallback() => _hosted(
      _pending(
        id: 'pen-2',
        displayId: null,
        title: 'Pharmacy run for Mom',
        itemsSummary: 'Pharmacy run for Mom',
        destinationLabel: 'Achrafieh, Beirut',
      ),
    );

/// The degenerate row: no items list AND no destination label, which the live
/// list produces when the gateway omits both.
///
/// [ClientHomeRequest.summaryLine] returns `''` and this card renders it
/// verbatim — an empty second line under the order id. The sibling
/// `PendingCountdownCard` substitutes the localized "Searching for Jeebers…"
/// for exactly this case; this card does not. Kept as a preview because the
/// blank line is invisible in code review and obvious on the canvas.
@JeebPreview(name: 'Empty summary line', size: _rowBox)
Widget pendingRequestCardEmptySummary() => _hosted(
      _pending(
        id: 'pen-3',
        displayId: 'ORD-23471',
        title: 'ORD-23471',
        destinationLabel: '',
        tier: ClientRequestTier.standard,
      ),
    );

/// A tier the app does not know — the forward-compat case for a backend that
/// introduces a new tier mid-deploy.
///
/// `ClientRequestTier.parse` maps anything unrecognised to `unknown`, and the
/// class doc promises "a neutral chip so the screen never crashes". What
/// actually renders is an EMPTY label: the badge silently disappears and the
/// header claims its space. Nothing crashes, but the row loses its only
/// classifier.
@JeebPreview(name: 'Unknown tier badge', size: _rowBox)
Widget pendingRequestCardUnknownTier() => _hosted(
      _pending(
        id: 'pen-4',
        displayId: 'ORD-23472',
        title: 'ORD-23472',
        destinationLabel: 'Hamra',
        tier: ClientRequestTier.unknown,
      ),
    );

/// Layout ceiling: the longest header and items list the compose flow can
/// realistically produce, on the widest badge (Flash).
///
/// The header is `maxLines: 1` inside an [Expanded] and the summary is
/// `maxLines: 2` — both must ellipsize without pushing the tier badge off the
/// trailing edge. This is the state the AR RTL and 200%-text renderings of the
/// matrix exist for: the EN light rendering still looks fine long after the
/// other two have broken.
@JeebPreview(name: 'Long content overflow', size: _tallRowBox)
Widget pendingRequestCardLongContent() => _hosted(
      _pending(
        id: 'pen-5',
        displayId: 'ORD-23473 Beirut Souks pickup, Achrafieh drop-off',
        title: 'ORD-23473',
        itemsSummary: '1 kilo potato, water gallon, coffee blend, '
            '2 boxes paracetamol, 500g halloumi, laundry detergent',
        destinationLabel: 'Achrafieh',
        tier: ClientRequestTier.flash,
      ),
    );
