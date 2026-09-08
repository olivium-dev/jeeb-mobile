import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/request_feed_cubit.dart';
import '../cubit/request_feed_state.dart';
import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';
import 'jeeber_failure_exit.dart';
import 'request_card.dart';

/// Jeeber-mode realtime delivery request feed (JEEB-66 / T-mobile-013).
///
/// Hosts the [RequestFeedCubit], drives a 1Hz UI ticker so each card with a
/// server deadline can update its countdown badge without re-emitting cubit
/// state, and surfaces accept/decline outcomes via OMDS snackbars. The cubit
/// also retires requests with real deadlines on the same cadence.
// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; live feed UI is jeeber_home/jeeber_feed_tab_view.dart (its repository stays live via DI) — see docs/project-understanding/reconciliation/orphans.md
class RequestFeedScreen extends StatelessWidget {
  const RequestFeedScreen({super.key, this.cubit});

  /// Optional pre-wired cubit. Production callers pass `null` and let the
  /// screen wire up the [FakeRequestFeedRepository] until the real gateway
  /// client lands; tests pass a configured one.
  final RequestFeedCubit? cubit;

  @override
  Widget build(BuildContext context) {
    const view = _RequestFeedView();
    if (cubit != null) {
      return BlocProvider<RequestFeedCubit>.value(
        value: cubit!,
        child: view,
      );
    }
    return BlocProvider<RequestFeedCubit>(
      create: (_) => RequestFeedCubit(
        repository: FakeRequestFeedRepository(),
        // JEBV4-342 (b02): wired through the SAME shared resolver the live
        // dashboard host uses, so if this screen is ever un-orphaned it is
        // already push-driven rather than quietly poll-only. Returns `null`
        // when DI has not run, which is this screen's normal (test) case.
        // b02 wave D: same topics as the live dashboard host, so the orphaned
        // construction cannot drift from the one that ships.
        refreshSignals: resolvePushRefreshStream(
          topics: const {RefreshTopic.feed, RefreshTopic.offers},
        ),
      )..start(),
      child: view,
    );
  }
}

class _RequestFeedView extends StatefulWidget {
  const _RequestFeedView();

  @override
  State<_RequestFeedView> createState() => _RequestFeedViewState();
}

class _RequestFeedViewState extends State<_RequestFeedView> {
  Timer? _uiTicker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'request_feed_root',
      container: true,
      child: Scaffold(
        // The redesign's header is an in-BODY row, not a Material app bar —
        // no elevation, no surface tint, start-aligned h2 title. It sits
        // above the BlocConsumer so feed state changes never rebuild it.
        body: SafeArea(
          child: Column(
            children: [
              JeebTopBar(
                title: l10n.requestFeedTitle,
                identifier: 'request_feed_back',
              ),
              Expanded(
                child: BlocConsumer<RequestFeedCubit, RequestFeedState>(
                  listenWhen: (prev, curr) => prev.lastEffect != curr.lastEffect,
                  listener: _onStateChange,
                  builder: (context, state) =>
                      _FeedColumn(state: state, now: _now),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onStateChange(BuildContext context, RequestFeedState state) {
    final cubit = context.read<RequestFeedCubit>();
    final l10n = AppLocalizations.of(context);
    final effect = state.lastEffect;
    if (effect == null) return;
    switch (effect.outcome) {
      case RequestActionOutcome.accepted:
      case RequestActionOutcome.declined:
        showJeebSnack(
          context,
          message: effect.outcome == RequestActionOutcome.accepted
              ? l10n.requestFeedActionAcceptedSnack
              : l10n.requestFeedActionDeclinedSnack,
          identifier: 'request_feed_action_snack',
        );
      case RequestActionOutcome.alreadyTaken:
      case RequestActionOutcome.expired:
        showJeebErrorSnack(
          context,
          message: effect.outcome == RequestActionOutcome.alreadyTaken
              ? l10n.requestFeedActionTakenSnack
              : l10n.requestFeedActionExpiredSnack,
          identifier: 'request_feed_action_snack',
        );
      case RequestActionOutcome.networkError:
        final failure = effect.failure;
        // Retry the act the jeeber actually took: a declined job must never
        // come back as an accept.
        final bool retryable = failure?.isRetryable ?? true;
        showJeebErrorSnack(
          context,
          message: failure == null
              ? l10n.requestFeedActionNetworkSnack
              : failureCopy(l10n, failure).body,
          identifier: 'request_feed_action_snack',
          retryLabel: retryable ? l10n.actionRetry : null,
          onRetry: !retryable
              ? null
              : effect.action == RequestActionStatus.declining
              ? () => unawaited(cubit.decline(effect.requestId))
              : () => unawaited(cubit.accept(effect.requestId)),
        );
    }
    cubit.clearEffect();
  }
}

class _FeedColumn extends StatelessWidget {
  const _FeedColumn({required this.state, required this.now});

  final RequestFeedState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refreshError = state.refreshError;
    final cubit = context.read<RequestFeedCubit>();
    return Column(
      children: [
        if (state.transport == FeedTransport.polling)
          _ReconnectingBanner(message: l10n.requestFeedReconnecting),
        // LR-12: the rows stay and the warm failure sits still, so a polling
        // outage cannot fire one snack per tick.
        if (refreshError != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.small,
              Spacing.xLarge,
              0,
            ),
            child: JeebRefreshFailedNote(
              failure: refreshError,
              identifier: 'request_feed_refresh_failed_note',
              onDismiss: cubit.clearRefreshError,
              onRetry: () => unawaited(cubit.refresh()),
            ),
          ),
        Expanded(child: _FeedBody(state: state, now: now, l10n: l10n)),
      ],
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.state,
    required this.now,
    required this.l10n,
  });

  final RequestFeedState state;
  final DateTime now;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Illustration skeleton only on the first cold read; a refresh over rows
    // keeps the board and reports through the snackbar instead.
    if (state.status == RequestFeedStatus.loading && state.requests.isEmpty) {
      return JeebStateHost(
        child: JeebEmptyState(
          identifier: 'request_feed_loading_state',
          status: JeebEmptyStateStatus.loading,
          variant: JeebEmptyStateVariant.street,
          headline: l10n.requestFeedLoadingHeadline,
        ),
      );
    }
    if (state.status == RequestFeedStatus.error && state.requests.isEmpty) {
      final cubit = context.read<RequestFeedCubit>();
      final failure = state.error ?? const UnknownFailure();
      final exit = jeeberFailureExit(
        context,
        failure,
        l10n,
        onReload: cubit.refresh,
      );
      return JeebStateHost(
        child: JeebFailureBlock(
          failure: failure,
          identifier: 'request_feed_error_state',
          retryIdentifier: 'request_feed_retry_cta',
          exitIdentifier: 'request_feed_exit_cta',
          variant: JeebEmptyStateVariant.street,
          onRetry: () => unawaited(cubit.refresh()),
          onExit: exit.onExit,
          exitLabel: exit.label,
        ),
      );
    }
    return _FeedListOrEmpty(state: state, now: now, l10n: l10n);
  }
}

class _FeedListOrEmpty extends StatelessWidget {
  const _FeedListOrEmpty({
    required this.state,
    required this.now,
    required this.l10n,
  });

  final RequestFeedState state;
  final DateTime now;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return JeebPullToRefresh(
      onRefresh: () => context.read<RequestFeedCubit>().refresh(),
      child: state.requests.isEmpty
          ? _EmptyFeed(l10n: l10n)
          : _FeedList(state: state, now: now),
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({required this.state, required this.now});

  final RequestFeedState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RequestFeedCubit>();
    return ListView.builder(
      key: const Key('requestFeed.list'),
      padding: const EdgeInsets.symmetric(vertical: Spacing.small),
      itemCount: state.requests.length,
      itemBuilder: (_, index) => _FeedListRow(
        request: state.requests[index],
        actionStatus: state.actionStatusFor(state.requests[index].id),
        now: now,
        onAccept: () => cubit.accept(state.requests[index].id),
        onDecline: () => cubit.decline(state.requests[index].id),
      ),
    );
  }
}

class _FeedListRow extends StatelessWidget {
  const _FeedListRow({
    required this.request,
    required this.actionStatus,
    required this.now,
    required this.onAccept,
    required this.onDecline,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;
  final DateTime now;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return RequestCard(
      request: request,
      actionStatus: actionStatus,
      secondsRemaining: _secondsLeft(),
      onAccept: onAccept,
      onDecline: onDecline,
    );
  }

  int? _secondsLeft() {
    final expiresAt = request.expiresAt;
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(now).inSeconds;
    return diff.clamp(0, 1 << 31);
  }
}

/// Reconnecting is a transient attention state — self-recovering, not a
/// failure — so it keeps the warning role but stops behaving like a full-bleed
/// system error bar: an inset kit note on the page's own 24px gutter, exactly
/// as the live dashboard feed renders its offline banner.
class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.xSmall,
        Spacing.xLarge,
        0,
      ),
      child: JeebInfoNote.warning(
        key: const Key('requestFeed.reconnectingBanner'),
        icon: Icons.wifi_off_outlined,
        text: message,
      ),
    );
  }
}

/// An empty feed is not an error — "Empty ≠ dead": E3's night street, the same
/// block the live dashboard feed already draws for this exact condition.
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // FROZEN key re-homed onto the kit block; the Padding/Column that hosted it
    // existed only to carry the two hand-styled lines.
    return JeebStateHost(
      key: const Key('requestFeed.empty'),
      child: JeebEmptyState(
        identifier: 'request_feed_empty_state',
        variant: JeebEmptyStateVariant.street,
        headline: l10n.requestFeedEmptyTitle,
        body: l10n.requestFeedEmptySubtitle,
      ),
    );
  }
}
