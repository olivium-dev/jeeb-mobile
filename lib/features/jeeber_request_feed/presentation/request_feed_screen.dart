import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../cubit/request_feed_cubit.dart';
import '../cubit/request_feed_state.dart';
import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';
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
      appBar: AppBar(title: Text(l10n.requestFeedTitle)),
      body: SafeArea(
        child: BlocConsumer<RequestFeedCubit, RequestFeedState>(
          listenWhen: (prev, curr) => prev.lastEffect != curr.lastEffect,
          listener: (context, state) {
            final effect = state.lastEffect;
            if (effect == null) return;
            _showEffectSnackBar(context, effect, l10n);
            context.read<RequestFeedCubit>().clearEffect();
          },
          builder: (context, state) {
            return Column(
              children: [
                if (state.transport == FeedTransport.polling)
                  _ReconnectingBanner(message: l10n.requestFeedReconnecting),
                Expanded(child: _buildBody(context, state, l10n)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    RequestFeedState state,
    AppLocalizations l10n,
  ) {
    if (state.status == RequestFeedStatus.loading && state.requests.isEmpty) {
      return const Center(child: OmdsLoadingState());
    }
    if (state.status == RequestFeedStatus.error && state.requests.isEmpty) {
      return OmdsErrorState(
        title: l10n.requestFeedErrorTitle,
        message: l10n.requestFeedErrorLoad,
        retryLabel: l10n.requestFeedErrorRetry,
        onRetry: () => context.read<RequestFeedCubit>().refresh(),
      );
    }
    return OmdsPullToRefresh(
      onRefresh: () => context.read<RequestFeedCubit>().refresh(),
      child: state.requests.isEmpty
          ? _EmptyFeed(l10n: l10n)
          : ListView.builder(
              key: const Key('requestFeed.list'),
              padding: const EdgeInsets.symmetric(vertical: Spacing.small),
              itemCount: state.requests.length,
              itemBuilder: (_, index) {
                final request = state.requests[index];
                return RequestCard(
                  request: request,
                  actionStatus: state.actionStatusFor(request.id),
                  secondsRemaining: _secondsLeft(request),
                  onAccept: () =>
                      context.read<RequestFeedCubit>().accept(request.id),
                  onDecline: () =>
                      context.read<RequestFeedCubit>().decline(request.id),
                );
              },
            ),
    );
  }

  int _secondsLeft(DeliveryRequest request) {
    final diff = request.expiresAt.difference(_now).inSeconds;
    return diff.clamp(0, 1 << 31);
  }

  void _showEffectSnackBar(
    BuildContext context,
    RequestActionEffect effect,
    AppLocalizations l10n,
  ) {
    final message = switch (effect.outcome) {
      RequestActionOutcome.accepted => l10n.requestFeedActionAcceptedSnack,
      RequestActionOutcome.declined => l10n.requestFeedActionDeclinedSnack,
      RequestActionOutcome.alreadyTaken => l10n.requestFeedActionTakenSnack,
      RequestActionOutcome.expired => l10n.requestFeedActionExpiredSnack,
      RequestActionOutcome.networkError =>
        l10n.requestFeedActionNetworkSnack,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('requestFeed.reconnectingBanner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      color: colorScheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: Sizes.medium,
            color: colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
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
