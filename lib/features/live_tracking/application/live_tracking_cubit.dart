import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
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
    _armWatchers();
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
      if (code != null && !isClosed) {
        emit(state.copyWith(handoverCode: code));
      }
    } catch (_) {
    }
  }

  Future<void> _fetch(LivePositionReadCause cause) async {
    try {
      final info =
          await _repository.fetchDeliveryStatus(deliveryId: deliveryId);
      if (!isClosed) {
        emit(state.copyWith(
          mode: LiveTrackingViewMode.ready,
          trackingInfo: info,
          clearError: true,
          pendingEvent: _detectEvent(info),
        ));
        if (_isTerminal) _retireWatchers();
      }
      if (!isClosed && !_isTerminal) await _readLivePosition(cause);
    } on LiveTrackingException catch (e) {
      if (!isClosed) {
        if (state.trackingInfo == null) {
          emit(state.copyWith(
            mode: LiveTrackingViewMode.error,
            errorMessage: _mapError(e.kind),
            errorTitle: _mapErrorTitle(e.kind),
          ));
        }
      }
    }
  }

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
      failure = e.runtimeType.toString();
    } finally {
      _positionReadInFlight = false;
    }
    if (isClosed) return;
    if (overlay != null) _positionReadCount++;
    final applied = _applyLivePosition(overlay);
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

  bool _applyLivePosition(DeliveryLivePosition? overlay) {
    if (overlay == null || isClosed || overlay.isNothingToSay) return false;
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

  void _armWatchers() {
    if (isClosed) return;
    if (_isTerminal) {
      _retireWatchers();
      return;
    }
    _refreshSubscription ??= _refreshSignals?.listen((_) => _refreshFromPush());
    unawaited(_armPositionStream());
  }

  Future<void> _armPositionStream() async {
    final channel = _positionChannel;
    if (channel == null) return;
    if (_positionStreamArmed || isClosed || _isTerminal) return;
    _positionStreamArmed = true;
    Stream<CourierPositionFix>? positions;
    Object? failure;
    try {
      positions = await channel.open(deliveryId: deliveryId);
    } catch (e) {
      failure = e;
      positions = null;
    }
    if (positions == null) {
      // D14: an unsubscribable channel used to be indistinguishable from a
      // healthy one that nobody published to. Both froze the map, silently.
      Diag.event(kTrackingStreamUnavailableEvent, <String, Object?>{
        'deliveryId': deliveryId,
        'error': ?failure?.runtimeType.toString(),
      });
      return;
    }
    if (isClosed || _isTerminal) {
      unawaited(positions.listen(null).cancel());
      return;
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

  /// D14: a leg that DIED (socket drop, backgrounding) may re-open on the next
  /// push/resume edge. A channel that never opened stays at one attempt.
  void _retirePositionStream({bool rearmable = false}) {
    final wasArmed = _streamedPositionLeg != null;
    unawaited(_streamedPositionLeg?.cancel());
    _streamedPositionLeg = null;
    if (!rearmable || !wasArmed) return;
    _positionStreamArmed = false;
    Diag.event(kTrackingStreamDroppedEvent, <String, Object?>{
      'deliveryId': deliveryId,
      'n': _streamedPositionCount,
    });
  }

  void _retireWatchers() {
    unawaited(_refreshSubscription?.cancel());
    _refreshSubscription = null;
    _retirePositionStream();
  }

  void retry() {
    if (isClosed) return;
    emit(state.copyWith(mode: LiveTrackingViewMode.loading, clearError: true));
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
    if (!isClosed) _armWatchers();
  }

  String _mapError(LiveTrackingErrorKind kind) {
    switch (kind) {
      case LiveTrackingErrorKind.network:
        return 'Unable to connect. Check your internet.';
      case LiveTrackingErrorKind.server:
        return 'Server error. Please try again.';
      case LiveTrackingErrorKind.notFound:
        return "We can't find this delivery yet. It may still be getting "
            'ready — pull to retry in a moment.';
      case LiveTrackingErrorKind.parse:
        return 'Unexpected response format.';
    }
  }

  String? _mapErrorTitle(LiveTrackingErrorKind kind) {
    switch (kind) {
      case LiveTrackingErrorKind.notFound:
        return 'Delivery not found';
      case LiveTrackingErrorKind.network:
      case LiveTrackingErrorKind.server:
      case LiveTrackingErrorKind.parse:
        return null;
    }
  }

  @override
  Future<void> close() {
    _retireWatchers();
    return super.close();
  }
}
