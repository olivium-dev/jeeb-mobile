import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/app_failure_mapper.dart';
import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/courier_position_channel.dart';
import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';
import 'live_tracking_state.dart';

const String kTrackingScreenOpenEvent = 'tracking_screen_open';

const String kTrackingPositionEvent = 'tracking_position';

const String kTrackingStreamPositionEvent = 'tracking_stream_position';

const String kTrackingStreamUnavailableEvent = 'tracking_stream_unavailable';

const String kTrackingStreamDroppedEvent = 'tracking_stream_dropped';

enum LivePositionReadCause {
  screenOpen('open'),

  push('push'),

  resume('resume'),

  retry('retry');

  const LivePositionReadCause(this.wire);

  final String wire;
}

class LiveTrackingCubit extends Cubit<LiveTrackingState> {
  LiveTrackingCubit({
    required LiveTrackingRepository repository,
    required this.deliveryId,
    Stream<void>? refreshSignals,
    HandoverCodeStore? handoverCodeStore,
    CourierPositionChannel? positionChannel,
  })  : _repository = repository,
        _refreshSignals = refreshSignals,
        _handoverCodeStore = handoverCodeStore,
        _positionChannel = positionChannel,
        super(const LiveTrackingState()) {
    Diag.event(kTrackingScreenOpenEvent, <String, Object?>{
      'deliveryId': deliveryId,
    });
    _fetchAndSchedule(LivePositionReadCause.screenOpen);
  }

  final LiveTrackingRepository _repository;
  final String deliveryId;

  final Stream<void>? _refreshSignals;

  StreamSubscription<void>? _refreshSubscription;

  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  final CourierPositionChannel? _positionChannel;

  StreamSubscription<CourierPositionFix>? _streamedPositionLeg;

  bool _positionStreamArmed = false;
  bool _positionStreamOpening = false;
  int _positionStreamGeneration = 0;
  Future<void>? _positionStreamTeardown;
  CourierPositionOpenAttempt? _positionStreamAttempt;

  @visibleForTesting
  int get debugStreamedPositionCount => _streamedPositionCount;
  int _streamedPositionCount = 0;

  @visibleForTesting
  bool get debugPositionStreamLegArmed => _streamedPositionLeg != null;

  @visibleForTesting
  int get debugPositionReadCount => _positionReadCount;
  int _positionReadCount = 0;

  bool _statusReadInFlight = false;

  bool _pendingPushEdge = false;

  bool _positionReadInFlight = false;

  LivePositionReadCause? _pendingPositionCause;

  final HandoverCodeStore? _handoverCodeStore;
  bool get _isTerminal =>
      (state.trackingInfo?.isPollTerminal ?? false) ||
      (state.trackingInfo?.isDelivered ?? false);

  Future<void> _fetchAndSchedule(LivePositionReadCause cause) async {
    await Future.wait([_hydrateHandoverCode(), _fetch(cause)]);
    _armWatchers(retryPositionStream: cause == LivePositionReadCause.retry);
  }

  Future<void> _refreshFromPush() async {
    if (isClosed || _isTerminal) return;
    if (_statusReadInFlight) {
      _pendingPushEdge = true;
      return;
    }
    _statusReadInFlight = true;
    try {
      await _fetch(LivePositionReadCause.push);
    } finally {
      _statusReadInFlight = false;
    }
    _armWatchers();
    if (!_pendingPushEdge) return;
    _pendingPushEdge = false;
    await _refreshFromPush();
  }

  Future<void> _hydrateHandoverCode() async {
    final store = _handoverCodeStore;
    if (store == null) return;
    try {
      final code = await store.read(deliveryId: deliveryId);
      if (code != null && !isClosed && !_isTerminal) {
        emit(state.copyWith(
          handoverCode: code,
          pendingEvent: state.pendingEvent,
        ));
      }
    } catch (e) {
      // Decorative: a missing code hides the row, it never faults the screen.
      Diag.event('tracking.handover_code_read_failed', <String, Object?>{
        'kind': AppFailure.of(e).kind.name,
      });
    }
  }

  Future<void> _fetch(LivePositionReadCause cause) async {
    if (isClosed || _isTerminal) return;
    try {
      final info =
          await _repository.fetchDeliveryStatus(deliveryId: deliveryId);
      // A concurrent retry/resume may have already observed completion. An
      // older active response must never rewind that terminal state.
      if (isClosed || _isTerminal) return;
      final terminal = info.isPollTerminal || info.isDelivered;
      emit(state.copyWith(
        mode: LiveTrackingViewMode.ready,
        trackingInfo: info,
        clearError: true,
        clearRefreshError: true,
        lastSuccessAt: DateTime.now(),
        pendingEvent: _detectEvent(info),
        clearHandoverCode: terminal,
        streamUnavailable: terminal ? false : null,
        streamConnecting: terminal ? false : null,
      ));
      if (_isTerminal) _retireWatchers();
      if (!isClosed && !_isTerminal) await _readLivePosition(cause);
    } on LiveTrackingException catch (e) {
      if (isClosed || _isTerminal) return;
      final AppFailure failure = e.appFailure ?? _failureFor(e.kind);
      if (state.trackingInfo == null) {
        emit(state.copyWith(
          mode: LiveTrackingViewMode.error,
          failure: failure,
          errorKind: e.kind,
        ));
        return;
      }
      // Rows are already on screen: a warm failure is a note, never a rung.
      emit(state.copyWith(
        mode: LiveTrackingViewMode.ready,
        refreshError: failure,
      ));
    } catch (e) {
      if (isClosed || _isTerminal) return;
      final AppFailure failure = AppFailure.of(e);
      if (state.trackingInfo == null) {
        emit(state.copyWith(
          mode: LiveTrackingViewMode.error,
          failure: failure,
        ));
        return;
      }
      emit(state.copyWith(
        mode: LiveTrackingViewMode.ready,
        refreshError: failure,
      ));
    }
  }

  /// The kind→failure bridge for repositories that predate `appFailure:`.
  static AppFailure _failureFor(LiveTrackingErrorKind kind) => switch (kind) {
    LiveTrackingErrorKind.network => networkFailureFromReachability(),
    LiveTrackingErrorKind.notFound => const NotFoundFailure(),
    LiveTrackingErrorKind.unauthorized => const UnauthorizedFailure(),
    LiveTrackingErrorKind.forbidden => const ForbiddenFailure(),
    LiveTrackingErrorKind.rateLimited => const RateLimitedFailure(),
    LiveTrackingErrorKind.server => const ServerFailure(status: 500),
    LiveTrackingErrorKind.parse => const UnknownFailure(parse: true),
  };

  void acknowledgeRefreshError() {
    if (isClosed) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  /// UX-11: a null read is not "no news" — three in a row means the pin the
  /// map is drawing is stale enough to say so.
  static const int kPositionMissesBeforeLost = 3;
  int _consecutivePositionMisses = 0;

  Future<void> _readLivePosition(LivePositionReadCause cause) async {
    if (isClosed || _isTerminal) return;
    final repo = _repository;
    if (repo is! LivePositionSource) return;
    if (_positionReadInFlight) {
      _pendingPositionCause = cause;
      return;
    }
    final source = repo as LivePositionSource;
    _positionReadInFlight = true;
    DeliveryLivePosition? overlay;
    String? failure;
    try {
      overlay = await source.fetchLivePosition(deliveryId: deliveryId);
    } catch (e) {
      failure = AppFailure.of(e).kind.name;
    } finally {
      _positionReadInFlight = false;
    }
    if (isClosed || _isTerminal) return;
    if (overlay != null) _positionReadCount++;
    var applied = _applyLivePosition(overlay);
    if (applied) {
      _consecutivePositionMisses = 0;
    } else {
      _consecutivePositionMisses++;
      if (_consecutivePositionMisses >= kPositionMissesBeforeLost) {
        applied = _applyLivePosition(_lostOverlay());
      }
    }
    Diag.event(kTrackingPositionEvent, <String, Object?>{
      'deliveryId': deliveryId,
      'cause': cause.wire,
      'applied': applied,
      'lat': overlay?.jeeberPosition?.lat,
      'lng': overlay?.jeeberPosition?.lng,
      'polyline': overlay?.polyline.length ?? 0,
      'stale': overlay?.stale,
      'positionStatus': overlay?.status?.wire,
      'error': ?failure,
    });
    final pending = _pendingPositionCause;
    if (pending == null) return;
    _pendingPositionCause = null;
    await _readLivePosition(pending);
  }

  DeliveryLivePosition _lostOverlay() {
    final since = state.lastSuccessAt;
    return DeliveryLivePosition(
      status: PositionFreshness.lost,
      stale: true,
      secondsSinceUpdate: since == null
          ? null
          : DateTime.now().difference(since).inSeconds.toDouble(),
    );
  }

  bool _applyLivePosition(DeliveryLivePosition? overlay) {
    if (overlay == null || isClosed || _isTerminal || overlay.isNothingToSay) {
      return false;
    }
    final current = state.trackingInfo;
    if (current == null) return false;
    emit(state.copyWith(
      trackingInfo: current.withLivePosition(
        jeeberPosition: overlay.jeeberPosition,
        polyline: overlay.polyline,
        stale: overlay.stale,
        secondsSinceUpdate: overlay.secondsSinceUpdate,
        status: overlay.status,
      ),
    ));
    return true;
  }

  LiveTrackingEvent _detectEvent(DeliveryTrackingInfo info) {
    final prev = state.trackingInfo?.currentStage;
    final next = info.currentStage;
    if (next == TrackingStage.delivered &&
        prev != TrackingStage.delivered) {
      return LiveTrackingEvent.deliveredAutoAdvance;
    }
    if (prev == next) return LiveTrackingEvent.none;
    if (next == TrackingStage.atDoor) return LiveTrackingEvent.jeeberAtDoor;
    if (next == TrackingStage.inTransit) {
      return LiveTrackingEvent.jeeberOnTheWay;
    }
    return LiveTrackingEvent.none;
  }

  void _armWatchers({bool retryPositionStream = false}) {
    if (isClosed) return;
    if (_isTerminal) {
      _retireWatchers();
      return;
    }
    _refreshSubscription ??= _refreshSignals?.listen((_) => _refreshFromPush());
    unawaited(_armPositionStream(retry: retryPositionStream));
  }

  /// Reconnect only on an explicit action or a lifecycle edge, never a timer.
  Future<void> retryPositionStream() => _armPositionStream(retry: true);

  Future<void> _armPositionStream({bool retry = false}) async {
    final channel = _positionChannel;
    if (channel == null) return;
    if (isClosed || _isTerminal || _positionStreamOpening ||
        _streamedPositionLeg != null || (_positionStreamArmed && !retry)) {
      return;
    }
    _positionStreamArmed = true;
    _positionStreamOpening = true;
    final generation = ++_positionStreamGeneration;
    emit(state.copyWith(streamConnecting: true, pendingEvent: state.pendingEvent));
    Stream<CourierPositionFix>? positions;
    CourierPositionOpenFailure? openFailure;
    Object? failure;
    try {
      // Do not overlap a replacement connection with a retiring subscription.
      await _positionStreamTeardown;
      if (isClosed || _isTerminal || generation != _positionStreamGeneration) {
        return;
      }
      if (channel is CancellableCourierPositionChannel) {
        final attempt = (channel as CancellableCourierPositionChannel)
            .openAttempt(deliveryId: deliveryId);
        _positionStreamAttempt = attempt;
        final result = await attempt.result;
        positions = result.positions;
        openFailure = result.failure;
      } else if (channel is CourierPositionChannelOutcome) {
        final result = await (channel as CourierPositionChannelOutcome)
            .openWithOutcome(deliveryId: deliveryId);
        positions = result.positions;
        openFailure = result.failure;
      } else {
        positions = await channel.open(deliveryId: deliveryId);
      }
    } catch (e) {
      failure = e;
      positions = null;
    } finally {
      if (generation == _positionStreamGeneration) {
        _positionStreamAttempt = null;
        _positionStreamOpening = false;
        if (!isClosed) {
          emit(state.copyWith(streamConnecting: false, pendingEvent: state.pendingEvent));
        }
      }
    }
    // A status change or teardown may have overtaken the asynchronous open.
    // Even a late successful join must release its socket, never re-arm a Done screen.
    if (isClosed || _isTerminal || generation != _positionStreamGeneration) {
      await positions?.listen(null).cancel();
      return;
    }
    if (positions == null) {
      // D14: an unsubscribable channel used to be indistinguishable from a
      // healthy one that nobody published to. Both froze the map, silently.
      Diag.event(kTrackingStreamUnavailableEvent, <String, Object?>{
        'deliveryId': deliveryId,
        'failure': ?openFailure?.name,
        'error': ?failure?.runtimeType.toString(),
      });
      if (!isClosed) {
        emit(state.copyWith(
          streamUnavailable: true,
          streamFailure: openFailure ?? CourierPositionOpenFailure.unavailable,
          pendingEvent: state.pendingEvent,
        ));
      }
      return;
    }
    if (!isClosed && state.streamUnavailable) {
      emit(state.copyWith(streamUnavailable: false, pendingEvent: state.pendingEvent));
    }
    _streamedPositionLeg = positions.listen(
      _onStreamedPosition,
      onError: (Object _, StackTrace _) =>
          _retirePositionStream(rearmable: true),
      onDone: () => _retirePositionStream(rearmable: true),
      cancelOnError: false,
    );
  }

  void _onStreamedPosition(CourierPositionFix fix) {
    if (isClosed || _isTerminal) return;
    _streamedPositionCount++;
    _consecutivePositionMisses = 0;
    final applied = _applyLivePosition(DeliveryLivePosition(
      jeeberPosition: GpsPoint(lat: fix.lat, lng: fix.lng),
      stale: false,
      secondsSinceUpdate: 0,
      status: PositionFreshness.live,
    ));
    Diag.event(kTrackingStreamPositionEvent, <String, Object?>{
      'deliveryId': deliveryId,
      'lat': fix.lat,
      'lng': fix.lng,
      'applied': applied,
      'n': _streamedPositionCount,
    });
  }

  /// A dropped channel is visible and can reopen on the next lifecycle/action
  /// edge. Closing/terminal transitions also invalidate any asynchronous open.
  void _retirePositionStream({bool rearmable = false}) {
    final wasArmed = _streamedPositionLeg != null;
    if (rearmable && !wasArmed) return;
    _positionStreamGeneration++;
    _positionStreamOpening = false;
    final attempt = _positionStreamAttempt;
    _positionStreamAttempt = null;
    final cancellation = _streamedPositionLeg?.cancel();
    if (attempt != null || cancellation != null) {
      _positionStreamTeardown = Future.wait<void>([
        ?_positionStreamTeardown,
        if (attempt != null) attempt.cancel(),
        ?cancellation,
      ]).then((_) {});
    }
    _streamedPositionLeg = null;
    if (!isClosed) {
      emit(state.copyWith(
        streamConnecting: false,
        streamUnavailable: rearmable && !_isTerminal,
        streamFailure: rearmable ? CourierPositionOpenFailure.connectFailed : null,
        pendingEvent: state.pendingEvent,
      ));
    }
    if (!rearmable || !wasArmed) return;
    _positionStreamArmed = false;
    Diag.event(kTrackingStreamDroppedEvent, <String, Object?>{
      'deliveryId': deliveryId,
      'n': _streamedPositionCount,
    });
  }

  void _retireWatchers() {
    _pendingPushEdge = false;
    _pendingPositionCause = null;
    unawaited(_refreshSubscription?.cancel());
    _refreshSubscription = null;
    _retirePositionStream();
  }

  void retry() {
    if (isClosed || _isTerminal) return;
    _consecutivePositionMisses = 0;
    emit(state.copyWith(
      mode: LiveTrackingViewMode.loading,
      clearError: true,
      clearRefreshError: true,
    ));
    _fetchAndSchedule(LivePositionReadCause.retry);
  }

  Future<void> refreshNow() async {
    if (isClosed) return;
    if (_isTerminal) return;
    if (_statusReadInFlight) return;
    _statusReadInFlight = true;
    try {
      await _fetch(LivePositionReadCause.resume);
    } finally {
      _statusReadInFlight = false;
    }
    if (!isClosed) _armWatchers(retryPositionStream: true);
  }



  @override
  Future<void> close() async {
    _retireWatchers();
    await super.close();
    await _positionStreamTeardown;
  }
}
