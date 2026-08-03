import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/client_home_empty_view.dart';
import '../widgets/client_home_tier_chip.dart';

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
    return Padding(
      // Board gutter 24 (`tpl 186`); cards are separated by a 12 gap instead of
      // the old divider (02-PLAN R12 — outline over rule).
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      child: Column(
        key: const Key('pending-requests-tab-list'),
        children: [
          for (var i = 0; i < requests.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.small),
            // JM-023 AC2: the indexed `orders_home_request_row_<n>` identifier
            // is the QA tap target for a pending request row on the Requests
            // home. It wraps (does not replace) the per-id
            // `pending_requests_item_<id>` identifier the card already exposes,
            // so both contracts stay targetable; tapping routes to
            // `waiting-no-coverage` (JM-026) via the screen-supplied [onTap].
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
        ],
      ),
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
    // Board `tpl 187`: r16, 1.5px brown outline, pad 16, NO shadow. Every one
    // of those numbers lives in the kit; the divider the card used to end with
    // is gone — the outline is what separates rows now.
    return JeebOutlinedCard(
      padding: const EdgeInsetsDirectional.all(Spacing.medium),
      child: _PendingCardRow(request: request),
    );
  }
}

class _PendingCardRow extends StatelessWidget {
  const _PendingCardRow({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    final createdAt = request.createdAt;
    // TODO(redesign-24): board shows broadcast reach + voice waveform/duration;
    // no gateway field — omitted, not faked.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PendingCardHeader(request: request),
        const SizedBox(height: Spacing.twoXSmall),
        _PendingCardSummary(text: request.summaryLine),
        const SizedBox(height: Spacing.small),
        // Meta row (board `tpl 196`): live status on the start edge, the age on
        // the end edge where the board draws its reach count.
        Row(
          children: [
            Expanded(
              // Once offers have arrived, surface them prominently instead of
              // the flat "Searching…" line. NB: on the live client-home path an
              // offer-bearing request is bucketed into Replies (offerCount>0),
              // so on the Pending tab this branch lights up for denormalised
              // counts / non-dio repositories; the searching line remains the
              // default pending state.
              child: request.offerCount > 0
                  ? _PendingOffersBadge(
                      count: request.offerCount,
                      emphasize: request.hasNewOffers,
                    )
                  : const _PendingServerStatus(),
            ),
            // Age line — shown ONLY when the server row carried a real
            // `createdAt`. It is a past-fact "created N ago" (grows over time),
            // NOT a countdown or expiry; the manufactured-deadline lie stays
            // removed.
            if (createdAt != null) ...[
              const SizedBox(width: Spacing.xSmall),
              Flexible(child: _PendingCreatedAge(createdAt: createdAt)),
            ],
          ],
        ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            request.displayId ?? request.title,
            // Role fix: `secondaryContainer` is a CONTAINER (fill) role, not
            // an ink role — as text it went illegible on dark surfaces. Titles
            // on surface read in `onSurface`.
            style: context.jeebText.cardTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierChip(tier: request.tier),
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
    final l10n = AppLocalizations.of(context);
    // Orange is correct here and nowhere else on this card: a broadcasting
    // request is R5's "happening now". `jeebRoles.accent` is the only legal
    // orange in this file (`no_raw_semantic_colors_test.dart` gates it).
    final accent = context.jeebRoles.accent;
    return Row(
      key: const Key('pending-server-status'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Board `tpl 199` draws Ø7; Sizes.xSmall (8) is the nearest token and
        // the 1px is imperceptible at this scale.
        Container(
          width: Sizes.xSmall,
          height: Sizes.xSmall,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Flexible(
          child: Text(
            l10n.pendingTabSearchingLabel,
            style: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      // UX-AUDIT §T3: meta text on the white card reads in `onSurfaceVariant`
      // (9.35:1). Periwinkle is legal only on the navy hero.
      style: context.jeebText.caption.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
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
