import 'dart:async';
import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/push_transport.dart';
import '../domain/notification_message.dart';
import '../domain/push_token_repository.dart';
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
    PushTokenRepository? tokenRepository,
    int historyLimit = 20,
  })  : _transport = transport,
        _badgeCount = badgeCount,
        _tokenRepository = tokenRepository,
        _historyLimit = historyLimit,
        super(const PushNotificationState()) {
    _foregroundSub = transport.onForegroundMessage.listen(_onForeground);
    _openedSub = transport.onMessageOpenedApp.listen(_opensCtl.add);
    _tokenSub = transport.onTokenRefresh.listen((token) {
      emit(state.copyWith(token: token));
      // notif-push-token-registration: re-register on every rotation
      // (reinstall / restore from backup).
      unawaited(_registerToken(token));
    });
  }

  final PushTransport _transport;
  final BadgeCountCubit _badgeCount;

  /// notif-push-token-registration: registers the FCM token with the gateway
  /// (`POST /v1/devices`). Null in unit tests / before the repo lands — then
  /// registration is a no-op and the token still surfaces in state.
  final PushTokenRepository? _tokenRepository;
  final int _historyLimit;
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
    // notif-push-token-registration: register the resolved token with the
    // gateway so server-side notifications can target this install. Best-effort
    // — a failure here must not break the push chain.
    if (token != null) {
      await _registerToken(token);
    }
  }

  /// POSTs the token to the gateway via [PushTokenRepository]. Swallows errors
  /// (offline / route not yet served) — the next token-refresh re-registers.
  Future<void> _registerToken(String token) async {
    final repo = _tokenRepository;
    if (repo == null || token.isEmpty) return;
    try {
      await repo.register(token);
    } catch (_) {
      // Best-effort: device registration is non-blocking for the push chain.
    }
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
