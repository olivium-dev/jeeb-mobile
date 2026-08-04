import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../core/widgets/jeeb/jeeb_system_chip.dart';
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
    // §2.7: the wait is the empty illustration's own breathing skeleton.
    return JeebEmptyState(
      key: const Key('pending-loading'),
      status: JeebEmptyStateStatus.loading,
      headline: AppLocalizations.of(context).homeEmptyTitle,
    );
  }
}

class _PendingError extends StatelessWidget {
  const _PendingError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      key: const Key('pending-error'),
      status: JeebEmptyStateStatus.error,
      headline: l10n.homeLoadFailedTitle,
      body: l10n.homeErrorRetry,
      action: IntrinsicWidth(
        child: JeebCtaButton.primary(
          label: l10n.homeLoadFailedRetry,
          identifier: 'pending_retry_cta',
          expand: false,
          onTap: onRetry,
        ),
      ),
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
      // Board gutter 24; glass cards are separated by a 12 gap.
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
    // R1's active-request card: rest glass, `lg` radius, pad 16, no lift.
    return JeebGlassCard(
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
    // TODO(midnight): the tile draws a voice waveform mark and a "12 Jeebers
    // reached" count; neither field is on the wire — omitted, not faked.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PendingCardHeader(request: request),
        const SizedBox(height: Spacing.twoXSmall),
        _PendingCardSummary(text: request.summaryLine),
        const SizedBox(height: Spacing.small),
        // Meta row: tier chip, live status, then the age on the end edge where
        // the tile draws its reach count.
        Row(
          children: [
            ClientHomeTierChip(tier: request.tier),
            const SizedBox(width: Spacing.xSmall),
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
    return Text(
      request.displayId ?? request.title,
      style: context.jeebText.cardTitle.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
    // request is the tile's "happening now" accent (budget §2.2). STATIC —
    // 03-MOTION-NOTES §R1 measures zero animation on this dot.
    final accent = context.jeebRoles.accent;
    return Row(
      key: const Key('pending-server-status'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // The tile draws Ø7; Sizes.xSmall (8) is the nearest token.
        Container(
          width: Sizes.xSmall,
          height: Sizes.xSmall,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: JeebShadows.glowDot,
          ),
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Flexible(
          child: Text(
            l10n.pendingTabBroadcastingLabel,
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
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: JeebSystemChip(
        key: const Key('pending-offers-badge'),
        label: l10n.pendingCardOffersBadge(count),
        // Unseen offers are the live event; a seen count is a settled fact.
        tone: emphasize
            ? JeebSystemChipTone.accent
            : JeebSystemChipTone.filled,
        center: false,
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
          // M4/Q2: §2.7 has no sub-compact form and the kit is frozen, so the
          // one-line banner keeps a role-tinted mark. Ruling pending.
          OmdsLoadingState(size: Sizes.medium, color: roles.onWarningContainer),
          const SizedBox(width: Spacing.xSmall),
          Text(
            l10n.pendingTabReconnecting,
            key: const Key('pending-reconnect-label'),
            style: context.jeebText.caption.copyWith(
              color: roles.onWarningContainer,
            ),
          ),
        ],
      ),
    );
  }
}
