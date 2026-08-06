import 'dart:async';
import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../diagnostics/diag.dart';
import '../../observability/session_trace/session_trace.dart';
import '../data/push_transport.dart';
import '../domain/active_chat_thread.dart';
import '../domain/foreground_push_display.dart';
import '../domain/local_push_inbox.dart';
import '../domain/notification_message.dart';
import '../domain/push_audience.dart';
import 'badge_count_cubit.dart';
import 'offer_lifecycle_signals.dart';
import 'push_refresh_signals.dart';

class PushNotificationState extends Equatable {
  const PushNotificationState({
    this.banner,
    this.history = const <NotificationMessage>[],
    this.permission = PushPermissionStatus.notDetermined,
    this.token,
  });

  final NotificationMessage? banner;

  final List<NotificationMessage> history;

  final PushPermissionStatus permission;
  final String? token;

  PushNotificationState copyWith({
    Object? banner = _sentinel,
    List<NotificationMessage>? history,
    PushPermissionStatus? permission,
    Object? token = _sentinel,
  }) {
    return PushNotificationState(
      banner: identical(banner, _sentinel)
          ? this.banner
          : banner as NotificationMessage?,
      history: history ?? this.history,
      permission: permission ?? this.permission,
      token: identical(token, _sentinel) ? this.token : token as String?,
    );
  }

  @override
  List<Object?> get props => [banner, history, permission, token];

  static const _sentinel = Object();
}

class PushNotificationHandler extends Cubit<PushNotificationState> {
  PushNotificationHandler({
    required PushTransport transport,
    required BadgeCountCubit badgeCount,
    int historyLimit = 20,
    Future<void> Function(String token)? onToken,
    PushRefreshSignals? refreshSignals,
    OfferLifecycleSignals? offerLifecycleSignals,
    LocalPushInbox? localInbox,
    Set<String> Function()? localRoles,
    Set<String> Function()? openChatThreadIds,
  })  : _openChatThreadIds =
            openChatThreadIds ?? (() => ActiveChatThread.instance.openIds),
        _transport = transport,
        _badgeCount = badgeCount,
        _historyLimit = historyLimit,
        _onToken = onToken,
        _refreshSignals = refreshSignals,
        _offerLifecycleSignals = offerLifecycleSignals,
        _localInbox = localInbox,
        _localRoles = localRoles,
        super(const PushNotificationState()) {
    _foregroundSub = transport.onForegroundMessage.listen(_onForeground);
    _openedSub = transport.onMessageOpenedApp.listen(_opensCtl.add);
    _tokenSub = transport.onTokenRefresh.listen((token) {
      emit(state.copyWith(token: token));
      _registerToken(token);
    });
  }

  final PushTransport _transport;
  final BadgeCountCubit _badgeCount;
  final int _historyLimit;
  final Future<void> Function(String token)? _onToken;
  final PushRefreshSignals? _refreshSignals;
  final OfferLifecycleSignals? _offerLifecycleSignals;
  final LocalPushInbox? _localInbox;

  final Set<String> Function()? _localRoles;

  final Set<String> Function() _openChatThreadIds;
  final _opensCtl = StreamController<NotificationMessage>.broadcast();
  final _seenIds = Queue<String>();
  static const int _seenIdsLimit = 128;

  StreamSubscription<NotificationMessage>? _foregroundSub;
  StreamSubscription<NotificationMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;

  Stream<NotificationMessage> get opens => _opensCtl.stream;

  Future<void> bootstrap() async {
    final permission = await _transport.requestPermission();
    final token = await _transport.getToken();
    if (permission != state.permission) {
      Diag.event('push_permission', <String, Object?>{
        'from': state.permission.name,
        'to': permission.name,
      });
    }
    emit(state.copyWith(permission: permission, token: token));
    if (token != null) {
      await _registerToken(token);
    }
  }

  Future<void> _registerToken(String token) async {
    final reg = _onToken;
    if (reg == null || token.isEmpty) return;
    await reg(token);
  }

  void dismissBanner() {
    if (state.banner == null) return;
    emit(state.copyWith(banner: null));
  }

  void tapBanner() {
    final banner = state.banner;
    if (banner == null) return;
    emit(state.copyWith(banner: null));
    _opensCtl.add(banner);
  }

  void clearBadge() => _badgeCount.clear();

  void _onForeground(NotificationMessage message) {
    Diag.event('push_received', <String, Object?>{
      'mode': 'foreground',
      'id': message.id,
      'category': message.category.name,
    });
    // Session-trace observability tool (devtool-only, Module 3): richer,
    if (kObsCompiledIn) {
      ObsNotificationRecorder.recordReceived(message, mode: 'foreground');
    }
    final roles = _localRoles?.call() ?? const <String>{};
    if (!isPushAudienceMatch(message.data, roles)) {
      Diag.event('push_suppressed', <String, Object?>{
        'id': message.id,
        'category': message.category.name,
        'audience_role': message.data['audience_role'],
        'reason': 'audience_mismatch',
      });
      return;
    }
    if (_seenIds.contains(message.id)) return;
    _seenIds.addLast(message.id);
    while (_seenIds.length > _seenIdsLimit) {
      _seenIds.removeFirst();
    }
    final history = <NotificationMessage>[message, ...state.history];
    if (history.length > _historyLimit) {
      history.removeRange(_historyLimit, history.length);
    }
    final isNewRequest = message.category == NotificationCategory.newRequest;
    _badgeCount.increment(isNewRequest: isNewRequest);
    if (isNewRequest) _persistNewRequest(message);
    final showBanner = shouldShowForegroundPush(
      category: message.category,
      data: message.data,
      openChatThreadIds: _openChatThreadIds(),
    );
    emit(showBanner
        ? state.copyWith(banner: message, history: history)
        : state.copyWith(history: history));
    _maybeSignalStatusChange(message);
    _maybeSignalOfferLifecycle(message);
  }

  void _persistNewRequest(NotificationMessage message) {
    final inbox = _localInbox;
    if (inbox == null) return;
    unawaited(inbox.append(LocalPushRecord(
      id: message.id,
      type: kNewRequestPushType,
      title: message.title,
      body: message.body,
      ts: message.receivedAt.toUtc().toIso8601String(),
      ref: message.data['requestId'] ?? message.data['request_id'],
    )));
  }

  void _maybeSignalOfferLifecycle(NotificationMessage message) {
    final bus = _offerLifecycleSignals;
    if (bus == null) return;
    final accepted = message.category == NotificationCategory.offerAccepted;
    final lost = message.category == NotificationCategory.offerLost;
    if (!accepted && !lost) return;
    final offerId = message.data['offerId'] ?? message.data['offer_id'];
    if (offerId == null || offerId.isEmpty) return;
    bus.signal(OfferLifecycleEvent(offerId: offerId, accepted: accepted));
  }

  void _maybeSignalStatusChange(NotificationMessage message) {
    if (_refreshSignals == null) return;
    // robustness, not a workaround for a missing field. Routing it past the guard
    const idless = <NotificationCategory>{
      NotificationCategory.offerAccepted,
      NotificationCategory.newRequest,
      NotificationCategory.chat,
    };
    if (idless.contains(message.category)) {
      _refreshSignals.signal(_topicsFor(message.category));
      return;
    }
    const orderish = <NotificationCategory>{
      NotificationCategory.delivery,
      NotificationCategory.newOffer,
      NotificationCategory.requestExpired,
    };
    if (!orderish.contains(message.category)) return;
    final data = message.data;
    final id = data['delivery_id'] ??
        data['order_id'] ??
        data['requestId'] ??
        data['request_id'];
    if (id == null || id.isEmpty) return;
    _refreshSignals.signal(_topicsFor(message.category));
  }

  static Set<RefreshTopic> _topicsFor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.chat:
        return const {RefreshTopic.chat};
      case NotificationCategory.newRequest:
        return const {RefreshTopic.feed};
      case NotificationCategory.delivery:
        return const {RefreshTopic.order};
      case NotificationCategory.offerAccepted:
      case NotificationCategory.newOffer:
      case NotificationCategory.requestExpired:
        return const {RefreshTopic.order, RefreshTopic.offers};
      case NotificationCategory.offerLost:
      case NotificationCategory.kyc:
      case NotificationCategory.rating:
      case NotificationCategory.settings:
      case NotificationCategory.dispute:
      case NotificationCategory.support:
      case NotificationCategory.other:
        return _everyTopic;
    }
  }

  static final Set<RefreshTopic> _everyTopic = RefreshTopic.values.toSet();

  @override
  Future<void> close() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenSub?.cancel();
    await _opensCtl.close();
    await _transport.dispose();
    return super.close();
  }

  Future<void> dispose() => close();
}
