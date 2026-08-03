import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/client_home_request.dart';
import 'active_request_card.dart' show ClientHomeTierBadge;

import '../../../../core/previews/jeeb_preview.dart';

/// Pending-requests row: order id, items summary, tier badge, and divider.
/// Appears after submit, before any Jeeber replies.
class PendingRequestCard extends StatelessWidget {
  const PendingRequestCard({
    super.key,
    required this.request,
    this.onTap,
  });

  final ClientHomeRequest request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'pending_requests_item_${request.id}',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: Column(
            children: [
              _PendingRow(request: request),
              Padding(
                padding: const EdgeInsetsDirectional.only(top: Spacing.small),
                child: Divider(height: 1, color: colorScheme.outlineVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PendingHeader(request: request),
        const SizedBox(height: Spacing.twoXSmall),
        _PendingSummary(text: request.summaryLine),
      ],
    );
  }
}

class _PendingHeader extends StatelessWidget {
  const _PendingHeader({required this.request});

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
              color: theme.colorScheme.primary,
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

class _PendingSummary extends StatelessWidget {
  const _PendingSummary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A pending row is a list item, not a card with its own surface: phone width,
/// header + two summary lines + divider.
const Size _pendingRequestCardRowBox = Size(390, 120);

/// The same box with headroom for the two-line summary the long-content state
/// fills.
const Size _pendingRequestCardTallRowBox = Size(390, 140);

/// Fixture in the shape the live `GET /v1/requests?status=pending` row arrives
/// in — a pending request has no jeeber, no ETA and no progress.
ClientHomeRequest _pendingRequestCardPending({
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

Widget _pendingRequestCardHosted(ClientHomeRequest request) =>
    PendingRequestCard(
      request: request,
      onTap: () {},
    );

/// The happy path: a server-issued order id, a tier badge, and the destination
/// standing in for a missing items list.
@JeebPreview(
  group: 'home_client',
  name: 'Searching',
  size: _pendingRequestCardRowBox,
)
Widget pendingRequestCardSearching() =>
    _pendingRequestCardHosted(_pendingRequestCardPending());

/// No `displayId` on the row — the header falls back to [title].
/// Also the G1 echo guard, made visible: `itemsSummary` here is byte-identical
@JeebPreview(
  group: 'home_client',
  name: 'No display id (title fallback)',
  size: _pendingRequestCardRowBox,
)
Widget pendingRequestCardTitleFallback() => _pendingRequestCardHosted(
      _pendingRequestCardPending(
        id: 'pen-2',
        displayId: null,
        title: 'Pharmacy run for Mom',
        itemsSummary: 'Pharmacy run for Mom',
        destinationLabel: 'Achrafieh, Beirut',
      ),
    );

/// The degenerate row: no items list AND no destination label, which the live
/// list produces when the gateway omits both.
@JeebPreview(
  group: 'home_client',
  name: 'Empty summary line',
  size: _pendingRequestCardRowBox,
)
Widget pendingRequestCardEmptySummary() => _pendingRequestCardHosted(
      _pendingRequestCardPending(
        id: 'pen-3',
        displayId: 'ORD-23471',
        title: 'ORD-23471',
        destinationLabel: '',
        tier: ClientRequestTier.standard,
      ),
    );

/// A tier the app does not know — the forward-compat case for a backend that
/// introduces a new tier mid-deploy.
@JeebPreview(
  group: 'home_client',
  name: 'Unknown tier badge',
  size: _pendingRequestCardRowBox,
)
Widget pendingRequestCardUnknownTier() => _pendingRequestCardHosted(
      _pendingRequestCardPending(
        id: 'pen-4',
        displayId: 'ORD-23472',
        title: 'ORD-23472',
        destinationLabel: 'Hamra',
        tier: ClientRequestTier.unknown,
      ),
    );

/// Layout ceiling: the longest header and items list the compose flow can
/// realistically produce, on the widest badge (Flash).
@JeebPreview(
  group: 'home_client',
  name: 'Long content overflow',
  size: _pendingRequestCardTallRowBox,
)
Widget pendingRequestCardLongContent() => _pendingRequestCardHosted(
      _pendingRequestCardPending(
        id: 'pen-5',
        displayId: 'ORD-23473 Beirut Souks pickup, Achrafieh drop-off',
        title: 'ORD-23473',
        itemsSummary: '1 kilo potato, water gallon, coffee blend, '
            '2 boxes paracetamol, 500g halloumi, laundry detergent',
        destinationLabel: 'Achrafieh',
        tier: ClientRequestTier.flash,
      ),
    );
