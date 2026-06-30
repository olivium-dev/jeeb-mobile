import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/active_request_card.dart' show ClientHomeTierBadge;

/// T-MOB-007: Isolated Pending Requests tab widget.
///
/// Renders requests that are broadcast but not yet matched. Each card shows
/// an order summary, a "Searching for Jeebers…" sub-line, and a per-card
/// TTL countdown that decrements locally every second from the server-supplied
/// [ClientHomeRequest.ttlSeconds]. When TTL hits 0 the card shows "Expired"
/// with a Retry CTA.
///
/// Performance: each card manages its own [Stream.periodic] so only the
/// affected card rebuilds on each tick — no full-list setState.
///
/// Mock endpoint: GET /v1/requests?status=pending  (Mockoon :3055)
class PendingRequestsTab extends StatelessWidget {
  const PendingRequestsTab({super.key, this.onTap});

  /// Called when a card row is tapped. If null the tap is a no-op.
  final void Function(ClientHomeRequest request)? onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      buildWhen: _rebuildWhen,
      builder: (context, state) => _PendingContent(
        state: state,
        onTap: onTap,
      ),
    );
  }

  static bool _rebuildWhen(ClientHomeState prev, ClientHomeState next) =>
      prev.status != next.status || prev.pending != next.pending;
}

class _PendingContent extends StatelessWidget {
  const _PendingContent({required this.state, required this.onTap});

  final ClientHomeState state;
  final void Function(ClientHomeRequest)? onTap;

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
      return _PendingEmpty(
        onCreateRequest: () => _openCreateRequest(context),
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
    return const Center(
      key: Key('pending-loading'),
      child: OmdsLoadingState(),
    );
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

class _PendingEmpty extends StatelessWidget {
  const _PendingEmpty({required this.onCreateRequest});

  final VoidCallback onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      key: const Key('pending-empty'),
      icon: Icons.hourglass_empty_rounded,
      title: l10n.homeEmptyTitle,
      subtitle: l10n.homePendingEmpty,
      buttonText: l10n.homeEmptyCta,
      onButtonTap: onCreateRequest,
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

/// Card that owns its own 1-Hz [Stream.periodic] countdown so only this widget
/// rebuilds every second — the parent list is unaffected (AC5 of T-MOB-007).
///
/// The stream starts from [ClientHomeRequest.ttlSeconds] as the server-provided
/// baseline at fetch time, decrements by 1 each second, and stops at 0.
class PendingCountdownCard extends StatefulWidget {
  const PendingCountdownCard({
    super.key,
    required this.request,
    this.onTap,
    this.onRetry,
  });

  final ClientHomeRequest request;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  @override
  State<PendingCountdownCard> createState() => _PendingCountdownCardState();
}

class _PendingCountdownCardState extends State<PendingCountdownCard> {
  StreamSubscription<int>? _ticker;
  late int _remaining;
  bool _announcedMinute = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.request.ttlSeconds ?? 0;
    _startTicker();
  }

  void _startTicker() {
    if (_remaining <= 0) return;
    _ticker = Stream.periodic(const Duration(seconds: 1), (i) => i + 1)
        .listen(_onTick);
  }

  void _onTick(int elapsed) {
    final newVal = (_remaining - 1).clamp(0, _remaining);
    if (!mounted) return;
    setState(() => _remaining = newVal);
    if (newVal % 60 == 0 && newVal > 0 && !_announcedMinute) {
      _announcedMinute = true;
      // Polite live-region announcement every 60s (AC4 of T-MOB-007).
      // debugPrint used as a side-channel until sendAnnouncement API stabilises.
      debugPrint('a11y: pending TTL ${_ttlLabel(newVal)}');
    } else if (newVal % 60 != 0) {
      _announcedMinute = false;
    }
    if (newVal <= 0) _ticker?.cancel();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining <= 0;
    return Semantics(
      identifier: 'pending_requests_item_${widget.request.id}',
      button: widget.onTap != null,
      label: _semanticsLabel(context, isExpired),
      child: InkWell(
        key: Key('pending-countdown-card-${widget.request.id}'),
        // BUG-3: the local TTL is a COSMETIC client countdown, not the server's
        // truth. The backend may still hold the request `pending` with a live
        // offer after this hits 0, so expiry must NOT dead-lock the row — keep
        // it tappable so the customer can re-enter the waiting/offers surface
        // (which re-polls `GET /v1/offers?requestId`) instead of being trapped
        // on a dead "Expired" card while an acceptable offer waits server-side.
        onTap: widget.onTap,
        child: _PendingCardBody(
          request: widget.request,
          remaining: _remaining,
          isExpired: isExpired,
          onRetry: widget.onRetry,
        ),
      ),
    );
  }

  String _semanticsLabel(BuildContext context, bool isExpired) {
    final l10n = AppLocalizations.of(context);
    final ttl = isExpired
        ? l10n.pendingTabExpiredLabel
        : _ttlLabel(_remaining);
    return l10n.pendingCardA11yLabel(
      widget.request.displayId ?? widget.request.title,
      ttl,
    );
  }

  static String _ttlLabel(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '~$m:$s';
  }
}

class _PendingCardBody extends StatelessWidget {
  const _PendingCardBody({
    required this.request,
    required this.remaining,
    required this.isExpired,
    required this.onRetry,
  });

  final ClientHomeRequest request;
  final int remaining;
  final bool isExpired;
  final VoidCallback? onRetry;

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
          _PendingCardRow(
            request: request,
            remaining: remaining,
            isExpired: isExpired,
            onRetry: onRetry,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Spacing.small),
            child: Divider(height: 1, color: colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

class _PendingCardRow extends StatelessWidget {
  const _PendingCardRow({
    required this.request,
    required this.remaining,
    required this.isExpired,
    required this.onRetry,
  });

  final ClientHomeRequest request;
  final int remaining;
  final bool isExpired;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PendingCardHeader(request: request),
        const SizedBox(height: Spacing.twoXSmall),
        _PendingCardSummary(text: request.summaryLine),
        const SizedBox(height: Spacing.twoXSmall),
        _PendingCardTtlRow(
          remaining: remaining,
          isExpired: isExpired,
          onRetry: onRetry,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            request.displayId ?? request.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.secondaryContainer,
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
        color: theme.colorScheme.onSecondaryContainer,
        letterSpacing: 0.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PendingCardTtlRow extends StatelessWidget {
  const _PendingCardTtlRow({
    required this.remaining,
    required this.isExpired,
    required this.onRetry,
  });

  final int remaining;
  final bool isExpired;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isExpired) return _ExpiredRow(onRetry: onRetry);
    return _CountdownRow(remaining: remaining);
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');
    return Row(
      children: [
        Icon(
          Icons.access_time_outlined,
          size: Sizes.medium,
          color: theme.colorScheme.onSecondaryContainer,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          l10n.pendingTabTtlLabel(m, s),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Text(
          l10n.pendingTabSearchingLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _ExpiredRow extends StatelessWidget {
  const _ExpiredRow({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(
          l10n.pendingTabExpiredLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: Spacing.small),
          _ExpiredRetryButton(onRetry: onRetry!),
        ],
      ],
    );
  }
}

class _ExpiredRetryButton extends StatelessWidget {
  const _ExpiredRetryButton({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IntrinsicWidth(
      child: SizedBox(
        height: Sizes.twoXLarge,
        child: OmdsPrimaryButton(
          key: const Key('pending-expired-retry'),
          text: l10n.pendingTabRetryCta,
          onTap: onRetry,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('pending-reconnect-banner'),
      color: colorScheme.errorContainer,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.twoXSmall,
      ),
      child: Row(
        children: [
          // OMDS: OmdsLoadingState replaces CircularProgressIndicator (OMDS-only policy).
          OmdsLoadingState(
            size: Sizes.medium,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(
            l10n.pendingTabReconnecting,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
