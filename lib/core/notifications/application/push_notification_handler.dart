import 'dart:async';
import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/push_transport.dart';
import '../domain/notification_message.dart';
import 'badge_count_cubit.dart';

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
  })  : _transport = transport,
        _badgeCount = badgeCount,
        _historyLimit = historyLimit,
        _onToken = onToken,
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
    if (_seenIds.contains(message.id)) return;
    _seenIds.addLast(message.id);
    while (_seenIds.length > _seenIdsLimit) {
      _seenIds.removeFirst();
    }
    final history = <NotificationMessage>[message, ...state.history];
    if (history.length > _historyLimit) {
      history.removeRange(_historyLimit, history.length);
    }
    _badgeCount.increment();
    emit(state.copyWith(banner: message, history: history));
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
