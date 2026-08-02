import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/request_feed_cubit.dart';
import '../cubit/request_feed_state.dart';
import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';
import 'request_card.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/request_feed_screen_fixtures.dart';

class RequestFeedScreen extends StatelessWidget {
  const RequestFeedScreen({super.key, this.cubit});

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
        appBar: OMDSAppBar(title: l10n.requestFeedTitle, centerTitle: false),
        body: SafeArea(
          child: BlocConsumer<RequestFeedCubit, RequestFeedState>(
            listenWhen: (prev, curr) => prev.lastEffect != curr.lastEffect,
            listener: _onEffect,
            builder: (context, state) => _FeedColumn(state: state, now: _now),
          ),
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

  int? _secondsLeft() {
    final expiresAt = request.expiresAt;
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(now).inSeconds;
    return diff.clamp(0, 1 << 31);
  }
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('requestFeed.reconnectingBanner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),

      color: context.jeebRoles.warningContainer,
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
          color: context.jeebRoles.onWarningContainer,
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.jeebRoles.onWarningContainer,
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
// ============================= JEEB PREVIEWS =============================
/// The phone this feed is designed against (iPhone 14 / a tall Android).
const Size _requestFeedScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
const Size _requestFeedScreenCompactBox = Size(320, 568);

/// Mounts the screen the way the Dashboard host would, over a frozen cubit and
Widget _requestFeedScreenFramed(
  RequestFeedCubit cubit, {
  Size box = _requestFeedScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: box.width,
      height: box.height,
      child: RequestFeedScreen(cubit: cubit),
    ),
  );
}

/// The catalog's "Incoming — Ignore / Offer card" state, verbatim: one live
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Live request · countdown',
  size: _requestFeedScreenPhoneBox,
  matrix: true,
)
Widget requestFeedScreenLiveRequest() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.ready(
        RequestFeedScreenPreviewFixtures.incomingFeed(),
      ),
    );

/// The board is empty and the read SUCCEEDED — the catalog's "Empty" state.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Empty board',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenEmptyBoard() =>
    _requestFeedScreenFramed(RequestFeedScreenPreviewFixtures.emptyBoard());

/// The cold read FAILED with nothing on the board — the catalog's "Error"
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Load failed · retry',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenLoadFailed() =>
    _requestFeedScreenFramed(RequestFeedScreenPreviewFixtures.loadFailed());

/// The cold read still in flight — `GET /v1/jeebers/me/feed` has been issued
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Cold read in flight',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenColdRead() =>
    _requestFeedScreenFramed(RequestFeedScreenPreviewFixtures.coldRead());

/// The catalog's "Reconnecting — degraded polling transport" state: the WS
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Reconnecting · polling transport',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenReconnecting() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.degradedTransport(
        RequestFeedScreenPreviewFixtures.incomingFeed(),
      ),
    );

/// The catalog's "Pending response" and "Accepted" states, merged — because on
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Incoming · pending · accepted (identical)',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenLifecycleRows() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.ready(
        RequestFeedScreenPreviewFixtures.lifecycleFeed(),
      ),
    );

/// A refresh that failed while rows were already on screen.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Refresh failed over rows · silent',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenRefreshFailedOverRows() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.refreshFailedOverRows(
        RequestFeedScreenPreviewFixtures.staleFeed(),
      ),
    );

/// The layout ceiling on the narrowest phone the app supports: two addresses
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Longest content · compact 320',
  size: _requestFeedScreenCompactBox,
  matrix: true,
)
Widget requestFeedScreenLongestContent() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.ready(
        RequestFeedScreenPreviewFixtures.longestContentFeed(),
      ),
      box: _requestFeedScreenCompactBox,
    );
