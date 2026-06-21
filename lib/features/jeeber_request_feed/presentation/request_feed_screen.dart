import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../cubit/request_feed_cubit.dart';
import '../cubit/request_feed_state.dart';
import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';
import 'jeeber_feed_shimmer.dart';
import 'request_card.dart';

/// Jeeber-mode realtime delivery request feed (JEEB-66 / T-mobile-013).
///
/// Hosts the [RequestFeedCubit], drives a 1Hz UI ticker so each card's
/// countdown badge updates without re-emitting cubit state, and surfaces
/// accept/decline outcomes via OMDS snackbars. The cubit also retires
/// expired requests on the same cadence — the screen's ticker is decoupled
/// because the cubit's sweep operates on `_clock()` (testable), while the
/// chrome needs a live tick to animate the seconds badge.
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
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.requestFeedTitle, centerTitle: false),
      body: SafeArea(
        child: BlocConsumer<RequestFeedCubit, RequestFeedState>(
          listenWhen: (prev, curr) => prev.lastEffect != curr.lastEffect,
          listener: _onEffect,
          builder: (context, state) => _FeedColumn(state: state, now: _now),
        ),
      ),
    );
  }

  void _onEffect(BuildContext context, RequestFeedState state) {
    final effect = state.lastEffect;
    if (effect == null) return;
    final l10n = AppLocalizations.of(context);
    showOmdsSnackbar(context, message: _effectMessage(effect, l10n));
    context.read<RequestFeedCubit>().clearEffect();
  }

  String _effectMessage(RequestActionEffect effect, AppLocalizations l10n) {
    return switch (effect.outcome) {
      RequestActionOutcome.accepted => l10n.requestFeedActionAcceptedSnack,
      RequestActionOutcome.declined => l10n.requestFeedActionDeclinedSnack,
      RequestActionOutcome.alreadyTaken => l10n.requestFeedActionTakenSnack,
      RequestActionOutcome.expired => l10n.requestFeedActionExpiredSnack,
      RequestActionOutcome.networkError =>
        l10n.requestFeedActionNetworkSnack,
    };
  }
}

class _FeedColumn extends StatelessWidget {
  const _FeedColumn({required this.state, required this.now});

  final RequestFeedState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        if (state.transport == FeedTransport.polling)
          _ReconnectingBanner(message: l10n.requestFeedReconnecting),
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
    if (state.status == RequestFeedStatus.loading && state.requests.isEmpty) {
      // home-disc-jeeber-feed-loading: shimmer skeleton on initial load
      // (project guideline prescribes list skeletons over a bare spinner).
      return const JeeberFeedShimmer();
    }
    if (state.status == RequestFeedStatus.error && state.requests.isEmpty) {
      return OmdsErrorState(
        title: l10n.requestFeedErrorTitle,
        message: l10n.requestFeedErrorLoad,
        retryLabel: l10n.requestFeedErrorRetry,
        onRetry: () => context.read<RequestFeedCubit>().refresh(),
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
    return OmdsPullToRefresh(
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

  int _secondsLeft() {
    final diff = request.expiresAt.difference(now).inSeconds;
    return diff.clamp(0, 1 << 31);
  }
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('requestFeed.reconnectingBanner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      color: theme.colorScheme.tertiaryContainer,
      child: _ReconnectingRow(message: message),
    );
  }
}

class _ReconnectingRow extends StatelessWidget {
  const _ReconnectingRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.wifi_off_outlined,
          size: Sizes.medium,
          color: theme.colorScheme.onTertiaryContainer,
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // OmdsPullToRefresh's child must be scrollable for the gesture to fire,
    // so the empty state is wrapped in a single-child scroll view sized to
    // the viewport.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: OmdsEmptyState(
            key: const Key('requestFeed.empty'),
            icon: Icons.inbox_outlined,
            title: l10n.requestFeedEmptyTitle,
            subtitle: l10n.requestFeedEmptySubtitle,
          ),
        ),
      ),
    );
  }
}
