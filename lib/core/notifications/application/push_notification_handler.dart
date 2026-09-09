import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../diagnostics/diag.dart';
import '../../network/auth_token_store.dart';
import '../../observability/session_trace/session_trace.dart';
import '../../session/reviews_refresh_signals.dart';
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
    AuthTokenStore? tokenStore,
    ReviewsRefreshSignals? reviewsRefreshSignals,
  }) : _openChatThreadIds =
           openChatThreadIds ?? (() => ActiveChatThread.instance.openIds),
       _tokenStore = tokenStore ?? AuthTokenStore(),
       _reviewsRefreshSignals =
           reviewsRefreshSignals ?? ReviewsRefreshSignals.instance,
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
  final AuthTokenStore _tokenStore;
  final ReviewsRefreshSignals _reviewsRefreshSignals;
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
      // F12 tripwire: greppable marker distinct from the JSON Diag line.
      if (kDebugMode) {
        debugPrint(
          'JEEB-PUSH-DROPPED reason=audience_mismatch '
          'type=${message.category.name}',
        );
      }
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
    emit(
      showBanner
          ? state.copyWith(banner: message, history: history)
          : state.copyWith(history: history),
    );
    _maybeSignalStatusChange(message);
    _maybeSignalOfferLifecycle(message);
    unawaited(_maybeSignalReviewsChanged(message));
  }

  Future<void> _maybeSignalReviewsChanged(NotificationMessage message) async {
    // A generic "rating" push is a prompt, not evidence of a revealed review.
    // This is the existing owner's explicit visibility event and closed payload.
    final eventType = message.data['type'] ?? message.data['notification_type'];
    if (eventType != 'jeeb.rating_auto_revealed') return;
    try {
      final recipients = <String>{};
      final flat = message.data['user_id'];
      if (flat != null && flat.isNotEmpty) recipients.add(flat);
      for (final key in const ['payload', 'data']) {
        final raw = message.data[key];
        if (raw == null || raw.isEmpty) continue;
        final nested = jsonDecode(raw);
        if (nested is! Map) return;
        final recipient = nested['user_id'];
        if (recipient is String && recipient.isNotEmpty) {
          recipients.add(recipient);
        }
      }
      // No guessing from delivery ids, role, display name, or unbound recipients.
      if (recipients.length != 1) return;
      final actorId = await _tokenStore.userId;
      if (isClosed || actorId == null || recipients.single != actorId) return;
      // Invalidation only: the owner-filtered read decides visibility/count/score.
      _reviewsRefreshSignals.signalChanged(rateeId: actorId, source: this);
    } catch (_) {
      // Malformed routing data or unavailable session storage is not a review.
    }
  }

  void _persistNewRequest(NotificationMessage message) {
    final inbox = _localInbox;
    if (inbox == null) return;
    unawaited(
      inbox.append(
        LocalPushRecord(
          id: message.id,
          type: kNewRequestPushType,
          title: message.title,
          body: message.body,
          ts: message.receivedAt.toUtc().toIso8601String(),
          ref: message.data['requestId'] ?? message.data['request_id'],
        ),
      ),
    );
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
      // Payload-less bus: the id was read then discarded, so guarding on it
      // only stranded the pinned chat summary on a stale status.
      NotificationCategory.delivery,
      // F1 correction 4 — wallet pushes (guard-2 auto-withdraw) carry no
      // order/delivery/request id; without this they never reach _topicsFor.
      NotificationCategory.wallet,
      // D-V1: the live offer_received payload carries no request/order id, so
      // the id guard stranded the client waiting screen on "no offers yet".
      NotificationCategory.newOffer,
    };
    if (idless.contains(message.category)) {
      _refreshSignals.signal(_topicsFor(message.category));
      return;
    }
    const orderish = <NotificationCategory>{
      NotificationCategory.requestExpired,
    };
    if (!orderish.contains(message.category)) return;
    final data = message.data;
    final id =
        data['delivery_id'] ??
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
      case NotificationCategory.wallet:
        return const {RefreshTopic.wallet};
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
