import 'dart:async';
import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../diagnostics/diag.dart';
import '../../observability/session_trace/session_trace.dart';
import '../data/push_transport.dart';
import '../domain/local_push_inbox.dart';
import '../domain/notification_message.dart';
import '../domain/push_audience.dart';
import 'badge_count_cubit.dart';
import 'offer_lifecycle_signals.dart';
import 'push_refresh_signals.dart';

/// View-model state surfaced to [PushBannerHost] and the dispatcher.
class PushNotificationState extends Equatable {
  const PushNotificationState({
    this.banner,
    this.history = const <NotificationMessage>[],
    this.permission = PushPermissionStatus.notDetermined,
    this.token,
  });

  /// The currently-displayed foreground banner. `null` when there's
  /// nothing to show (initial state, or after a dismiss/timeout).
  final NotificationMessage? banner;

  /// Recently-received foreground messages, newest first. Capped by the
  /// handler so memory doesn't grow unbounded.
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

/// Cubit that fans the transport's streams into UI-ready state.
///
/// - Listens to [PushTransport.onForegroundMessage] and emits a banner +
///   pushes a copy onto the history ring, deduplicating by message id.
/// - Surfaces [PushTransport.onMessageOpenedApp] as the [opens] stream so
///   the dispatcher can route to the right screen without having to know
///   about the transport.
/// - Owns badge-count side-effects (so the cubit-to-cubit coupling lives
///   in one place; the shell just reads `BadgeCountCubit`).
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
  })  : _transport = transport,
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
    // PUSH-FIX (iter6): on every token rotation, re-register the new token
    // with the backend so server-side pushes keep targeting this install.
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

  /// P1 (b01-20260725) defence-in-depth: returns the role(s) this session
  /// currently holds, so a foreground push whose `audience_role` doesn't
  /// match can be suppressed before it touches banner/badge/inbox state.
  /// `null` (not wired) or an empty result means "unknown" and the matcher
  /// fails OPEN — see `domain/push_audience.dart`.
  final Set<String> Function()? _localRoles;
  final _opensCtl = StreamController<NotificationMessage>.broadcast();
  final _seenIds = Queue<String>();
  // Bound the dedup set so a noisy server can't grow this without limit.
  static const int _seenIdsLimit = 128;

  StreamSubscription<NotificationMessage>? _foregroundSub;
  StreamSubscription<NotificationMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;

  /// Stream of messages opened from the system tray. The dispatcher
  /// subscribes here; UI widgets should not.
  Stream<NotificationMessage> get opens => _opensCtl.stream;

  /// Request permission + fetch the current token. Called by the
  /// dispatcher during init so failures here don't crash the cubit's
  /// constructor path.
  Future<void> bootstrap() async {
    final permission = await _transport.requestPermission();
    final token = await _transport.getToken();
    // Diagnostic seam (diag-persistence lane): surface push-permission state
    // transitions (notDetermined → granted/denied, and any later change on a
    // re-bootstrap) so a device run explains "why did no push arrive". Only
    // the enum name is logged — never the token (that would violate the
    // redaction contract; the token is scrubbed by Diag anyway).
    if (permission != state.permission) {
      Diag.event('push_permission', <String, Object?>{
        'from': state.permission.name,
        'to': permission.name,
      });
    }
    emit(state.copyWith(permission: permission, token: token));
    // PUSH-FIX (iter6): register the freshly-fetched token with the backend
    // so the push-notification service has a (device -> token) row to send to.
    if (token != null) {
      await _registerToken(token);
    }
  }

  /// Best-effort backend registration hop. Never throws — a failure (e.g. the
  /// user is not authenticated yet) is swallowed by [_onToken]; the token is
  /// re-registered on the next bootstrap / refresh.
  Future<void> _registerToken(String token) async {
    final reg = _onToken;
    if (reg == null || token.isEmpty) return;
    await reg(token);
  }

  /// Dismiss the foreground banner without performing the deep-link.
  void dismissBanner() {
    if (state.banner == null) return;
    emit(state.copyWith(banner: null));
  }

  /// User tapped the foreground banner. Clears the banner and routes
  /// the tap through [opens] so the dispatcher handles navigation in
  /// exactly one place.
  void tapBanner() {
    final banner = state.banner;
    if (banner == null) return;
    emit(state.copyWith(banner: null));
    _opensCtl.add(banner);
  }

  /// Clear the in-app badge count. Called when the user enters the
  /// inbox / notifications screen.
  void clearBadge() => _badgeCount.clear();

  void _onForeground(NotificationMessage message) {
    Diag.event('push_received', <String, Object?>{
      'mode': 'foreground',
      'id': message.id,
      'category': message.category.name,
    });
    // Session-trace observability tool (devtool-only, Module 3): richer,
    // redacted RECEIVED event alongside the `[jeeb-diag]` line above. Runs
    // ALONGSIDE it, never replacing it; a hard no-op (tree-shaken out) in a
    // production build.
    if (kObsCompiledIn) {
      ObsNotificationRecorder.recordReceived(message, mode: 'foreground');
    }
    // P1 (b01-20260725) defence-in-depth: drop a push whose audience_role
    // this session's roles don't match, BEFORE any dedup/badge/inbox/banner
    // state is touched. Display-level only — the gateway fan-out is the
    // authoritative fix; this never suppresses a background-isolate OS tray
    // banner (FCM renders that before Dart runs) and never drops a
    // non-newRequest category (the matcher fails open on payloads with no
    // audience hint, which is every other push type today).
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
    // G3: tag new-request pushes so the shell's Dashboard-tab badge counts
    // exactly the unseen open requests (chat/offer pushes only bump the
    // inbox total).
    final isNewRequest = message.category == NotificationCategory.newRequest;
    _badgeCount.increment(isNewRequest: isNewRequest);
    // G3: mirror the background-isolate persistence for a FOREGROUND new_request
    // so the durable inbox row + badge survive an app kill BEFORE the jeeber
    // acts (the server inbox has no new_request source to re-pull it from).
    if (isNewRequest) _persistNewRequest(message);
    emit(state.copyWith(banner: message, history: history));
    _maybeSignalStatusChange(message);
    _maybeSignalOfferLifecycle(message);
  }

  /// Best-effort durable write of a `new_request` push to the on-device inbox
  /// store (G3). Fire-and-forget — a storage failure must never disrupt the
  /// banner/badge path. No-op when no store is wired (unit tests).
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

  /// A foreground `offer_accepted` / `offer_lost` push carrying a flat `offerId`
  /// is a customer decision on one of this jeeber's submitted offers. Signal the
  /// lifecycle bus so the pending-offers list flips that row's badge and
  /// re-pulls (sprint-009). No id → no signal (the tap still routes to the list
  /// via [deepLinkForMessage], which needs no id).
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

  /// A foreground order-ish push (gateway `type=delivery|accept|offer|
  /// request_expired|try_expand_tier`)
  /// carrying an order/delivery/request id is an order status change. Signal the
  /// refresh bus so the customer's In Progress list and any live tracking
  /// surface re-pull promptly — instead of waiting up to the 10s home poll.
  ///
  /// PUSH-UI-REACTION (2026-07-05): an `offer_accepted` push ALSO fires this bus.
  /// When the customer accepts this jeeber's offer, the jeeber now owns an ACTIVE
  /// delivery — the Dashboard "Your active deliveries" card must re-pull
  /// immediately. On-device evidence: the jeeber received the `offer_accepted`
  /// push in the foreground yet the card did not appear until a force-restart,
  /// because the ActiveDeliveriesCubit backing that card reacted to NO push and
  /// leaned solely on its slow 10s wall-clock poll. No id is required here — the
  /// card just re-pulls its own snapshot (`GET /v1/deliveries?role=jeeber`); the
  /// tap-time deep-link keeps its own id handling in [deepLinkForMessage].
  void _maybeSignalStatusChange(NotificationMessage message) {
    if (_refreshSignals == null) return;
    if (message.category == NotificationCategory.offerAccepted) {
      _refreshSignals.signalStatusChange();
      return;
    }
    // P2: `offer` and the expiry events used to arrive here inside the
    // `delivery` bucket, so splitting them out MUST preserve the refresh
    // signal — otherwise the customer's Home/Replies surface stops re-pulling
    // on a foreground new-offer push and falls back to the slow wall-clock
    // poll (`home_tab.dart:54-56` → ClientHomeCubit). Behaviour for every
    // payload is byte-identical to pre-P2.
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
    _refreshSignals.signalStatusChange();
  }

  @override
  Future<void> close() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenSub?.cancel();
    await _opensCtl.close();
    await _transport.dispose();
    return super.close();
  }

  /// Alias for [close]. The root widget (`JeebApp`) calls `dispose()` on
  /// every owned object during teardown — exposing it here keeps the
  /// cleanup path uniform with the other non-Cubit handlers it owns.
  Future<void> dispose() => close();
}
