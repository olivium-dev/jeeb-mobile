import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'location_route_generator.dart';
import 'location_simulation_gateway.dart';
import 'location_simulation_models.dart';

enum LocationSimulationMode { locationOnly, fullTrip }

enum LocationSimulationPhase {
  idle,
  preparing,
  moving,
  paused,
  arrived,
  awaitingOtp,
  completed,
  stopped,
  failed,
}

class LocationSimulationState extends Equatable {
  const LocationSimulationState({
    this.phase = LocationSimulationPhase.idle,
    this.mode = LocationSimulationMode.fullTrip,
    this.deliveryId,
    this.deliveryStatus,
    this.route,
    this.currentPointIndex = -1,
    this.acceptedUpdates = 0,
    this.rejectedUpdates = 0,
    this.message,
  });

  final LocationSimulationPhase phase;
  final LocationSimulationMode mode;
  final String? deliveryId;
  final LocationSimulationDeliveryStatus? deliveryStatus;
  final LocationSimulationRoute? route;
  final int currentPointIndex;
  final int acceptedUpdates;
  final int rejectedUpdates;
  final String? message;

  LocationRoutePoint? get currentPoint {
    final points = route?.points;
    if (points == null ||
        currentPointIndex < 0 ||
        currentPointIndex >= points.length) {
      return null;
    }
    return points[currentPointIndex];
  }

  double get progress {
    final count = route?.points.length ?? 0;
    if (count == 0 || currentPointIndex < 0) return 0;
    return ((currentPointIndex + 1) / count).clamp(0, 1);
  }

  bool get isRunning =>
      phase == LocationSimulationPhase.preparing ||
      phase == LocationSimulationPhase.moving ||
      phase == LocationSimulationPhase.paused;

  LocationSimulationState copyWith({
    LocationSimulationPhase? phase,
    LocationSimulationMode? mode,
    String? deliveryId,
    LocationSimulationDeliveryStatus? deliveryStatus,
    LocationSimulationRoute? route,
    int? currentPointIndex,
    int? acceptedUpdates,
    int? rejectedUpdates,
    String? message,
    bool clearMessage = false,
    bool clearRoute = false,
  }) {
    return LocationSimulationState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      deliveryId: deliveryId ?? this.deliveryId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      route: clearRoute ? null : (route ?? this.route),
      currentPointIndex: currentPointIndex ?? this.currentPointIndex,
      acceptedUpdates: acceptedUpdates ?? this.acceptedUpdates,
      rejectedUpdates: rejectedUpdates ?? this.rejectedUpdates,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    phase,
    mode,
    deliveryId,
    deliveryStatus,
    route,
    currentPointIndex,
    acceptedUpdates,
    rejectedUpdates,
    message,
  ];
}

typedef SimulationDelay = Future<void> Function(Duration duration);
typedef SimulationClock = DateTime Function();

class LocationSimulationController extends ChangeNotifier {
  LocationSimulationController({
    required LocationSimulationGateway gateway,
    LocationRouteGenerator routeGenerator = const LocationRouteGenerator(),
    Duration tickInterval = const Duration(seconds: 2),
    SimulationDelay delay = _defaultDelay,
    SimulationClock clock = _defaultClock,
  }) : _gateway = gateway,
       _routeGenerator = routeGenerator,
       _tickInterval = tickInterval,
       _delay = delay,
       _clock = clock {
    if (tickInterval <= Duration.zero) {
      throw ArgumentError.value(
        tickInterval,
        'tickInterval',
        'Must be positive.',
      );
    }
  }

  final LocationSimulationGateway _gateway;
  final LocationRouteGenerator _routeGenerator;
  final Duration _tickInterval;
  final SimulationDelay _delay;
  final SimulationClock _clock;

  LocationSimulationSession? _session;
  LocationSimulationState _state = const LocationSimulationState();
  Completer<void>? _resumeCompleter;
  int _generation = 0;
  bool _disposed = false;

  LocationSimulationState get state => _state;

  Future<List<LocationSimulationDeliverySummary>> connectDriver(
    String jeeberUserId, {
    List<String> roles = const <String>['driver'],
  }) async {
    _cancelRun();
    final generation = _generation;
    _emit(
      const LocationSimulationState(
        phase: LocationSimulationPhase.preparing,
        message: 'Loading assigned deliveries...',
      ),
    );
    try {
      final session = await _gateway.openSession(
        jeeberUserId: jeeberUserId,
        roles: roles,
      );
      _ensureCurrent(generation);
      final deliveries = await session.listDeliveries();
      _ensureCurrent(generation);
      final active = deliveries
          .where((delivery) => !delivery.status.isTerminal)
          .toList(growable: false);
      _session = session;
      _emit(
        LocationSimulationState(
          message: active.isEmpty
              ? 'No active delivery is assigned to this driver. Choose '
                    'another driver or create and accept a disposable dev '
                    'request first.'
              : '${active.length} active ${active.length == 1 ? 'delivery' : 'deliveries'} '
                    'found. The first is selected automatically.',
        ),
      );
      return active;
    } on _SimulationCancelled {
      return const <LocationSimulationDeliverySummary>[];
    } on LocationSimulationFailure catch (failure) {
      if (generation != _generation) {
        return const <LocationSimulationDeliverySummary>[];
      }
      _session = null;
      _fail(failure.message);
      rethrow;
    }
  }

  Future<void> start({
    required String deliveryId,
    required LocationSimulationMode mode,
    required Duration tripDuration,
  }) async {
    final session = _session;
    if (session == null) {
      _fail('Select a Jeeber and load their deliveries first.');
      return;
    }
    if (tripDuration < _tickInterval) {
      _fail(
        'Trip duration must be at least ${_tickInterval.inSeconds} seconds.',
      );
      return;
    }

    _cancelRun();
    final generation = _generation;
    _emit(
      LocationSimulationState(
        phase: LocationSimulationPhase.preparing,
        mode: mode,
        deliveryId: deliveryId,
        message: 'Preparing the simulated trip...',
      ),
    );

    try {
      var delivery = await session.getDelivery(deliveryId);
      _ensureCurrent(generation);
      delivery = await _prepareDelivery(session, delivery, mode, generation);
      if (_state.phase == LocationSimulationPhase.awaitingOtp) return;

      final stepCount = math.max(
        2,
        tripDuration.inMilliseconds ~/ _tickInterval.inMilliseconds + 1,
      );
      final route = _routeGenerator.generate(
        start: delivery.pickupLocation,
        end: delivery.dropoffLocation,
        stepCount: stepCount,
        startsAt: _clock(),
        interval: _tickInterval,
      );
      final usesLoop = delivery.pickupLocation == delivery.dropoffLocation;
      _emit(
        _state.copyWith(
          phase: LocationSimulationPhase.moving,
          deliveryStatus: delivery.status,
          route: route,
          currentPointIndex: -1,
          acceptedUpdates: 0,
          rejectedUpdates: 0,
          message: usesLoop
              ? 'Pickup and drop-off match; sending an explicit synthetic loop.'
              : 'Sending simulated locations...',
        ),
      );

      for (var index = 0; index < route.points.length; index++) {
        await _waitUntilResumed(generation);
        _ensureCurrent(generation);
        final result = await _postWithRetry(
          session: session,
          deliveryId: delivery.id,
          point: route.points[index],
          generation: generation,
        );
        _ensureCurrent(generation);
        if (result.rejected > 0 || result.accepted < 1) {
          final reason = result.rejected > 0
              ? 'The gateway rejected ${result.rejected} simulated location '
                    '${result.rejected == 1 ? 'point' : 'points'}.'
              : 'The gateway did not accept the simulated location point.';
          _emit(
            _state.copyWith(
              phase: LocationSimulationPhase.failed,
              rejectedUpdates: _state.rejectedUpdates + result.rejected,
              message: '$reason The run stopped before advancing the trip.',
            ),
          );
          return;
        }
        _emit(
          _state.copyWith(
            phase: LocationSimulationPhase.moving,
            currentPointIndex: index,
            acceptedUpdates: _state.acceptedUpdates + result.accepted,
            rejectedUpdates: _state.rejectedUpdates + result.rejected,
            message: 'Location ${index + 1} of ${route.points.length} sent.',
          ),
        );
        if (index != route.points.length - 1) {
          await _delay(_tickInterval);
        }
      }

      _ensureCurrent(generation);
      if (mode == LocationSimulationMode.fullTrip) {
        await session.transitionDelivery(
          deliveryId: delivery.id,
          to: LocationSimulationDeliveryStatus.atDoor,
        );
        _ensureCurrent(generation);
        _emit(
          _state.copyWith(
            phase: LocationSimulationPhase.awaitingOtp,
            deliveryStatus: LocationSimulationDeliveryStatus.atDoor,
            message: 'Arrived at the door. Enter the delivery OTP to finish.',
          ),
        );
      } else {
        _emit(
          _state.copyWith(
            phase: LocationSimulationPhase.arrived,
            message: 'The simulated route reached the destination.',
          ),
        );
      }
    } on _SimulationCancelled {
      return;
    } on LocationSimulationFailure catch (failure) {
      if (generation == _generation) _fail(failure.message);
    } on ArgumentError catch (error) {
      if (generation == _generation) {
        _fail(error.message?.toString() ?? '$error');
      }
    } on FormatException catch (error) {
      if (generation == _generation) _fail(error.message);
    } catch (error) {
      if (generation == _generation) _fail('Simulation failed: $error');
    }
  }

  Future<LocationSimulationDelivery> _prepareDelivery(
    LocationSimulationSession session,
    LocationSimulationDelivery delivery,
    LocationSimulationMode mode,
    int generation,
  ) async {
    if (delivery.status == LocationSimulationDeliveryStatus.unknown) {
      throw const LocationSimulationFailure(
        kind: LocationSimulationFailureKind.validation,
        operation: 'prepare simulated trip',
        message: 'The delivery has an unknown status and cannot be simulated.',
      );
    }
    if (delivery.status.isTerminal) {
      throw LocationSimulationFailure(
        kind: LocationSimulationFailureKind.conflict,
        operation: 'prepare simulated trip',
        message: 'The delivery is already ${delivery.status.apiValue}.',
      );
    }

    if (mode == LocationSimulationMode.locationOnly) {
      if (delivery.status != LocationSimulationDeliveryStatus.inTransit) {
        throw const LocationSimulationFailure(
          kind: LocationSimulationFailureKind.conflict,
          operation: 'prepare simulated trip',
          message: 'Location-only mode requires an InTransit delivery.',
        );
      }
      return delivery;
    }

    if (delivery.status == LocationSimulationDeliveryStatus.atDoor) {
      _emit(
        _state.copyWith(
          phase: LocationSimulationPhase.awaitingOtp,
          deliveryStatus: LocationSimulationDeliveryStatus.atDoor,
          message: 'This delivery is already at the door. Enter its OTP.',
        ),
      );
      return delivery;
    }

    var status = delivery.status;
    if (status == LocationSimulationDeliveryStatus.ordered) {
      await session.transitionDelivery(
        deliveryId: delivery.id,
        to: LocationSimulationDeliveryStatus.picked,
      );
      _ensureCurrent(generation);
      status = LocationSimulationDeliveryStatus.picked;
    }
    if (status == LocationSimulationDeliveryStatus.picked) {
      await session.transitionDelivery(
        deliveryId: delivery.id,
        to: LocationSimulationDeliveryStatus.inTransit,
      );
      _ensureCurrent(generation);
      status = LocationSimulationDeliveryStatus.inTransit;
    }
    return LocationSimulationDelivery(
      id: delivery.id,
      status: status,
      requestId: delivery.requestId,
      clientUserId: delivery.clientUserId,
      jeeberUserId: delivery.jeeberUserId,
      pickupLocation: delivery.pickupLocation,
      dropoffLocation: delivery.dropoffLocation,
    );
  }

  Future<LocationSimulationUpdateResult> _postWithRetry({
    required LocationSimulationSession session,
    required String deliveryId,
    required LocationRoutePoint point,
    required int generation,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await session.postLocation(deliveryId: deliveryId, point: point);
      } on LocationSimulationFailure catch (failure) {
        _ensureCurrent(generation);
        if (failure.kind == LocationSimulationFailureKind.conflict) {
          final current = await session.getDelivery(deliveryId);
          _ensureCurrent(generation);
          if (current.status != LocationSimulationDeliveryStatus.inTransit) {
            throw LocationSimulationFailure(
              kind: LocationSimulationFailureKind.conflict,
              operation: failure.operation,
              statusCode: failure.statusCode,
              message:
                  'Location streaming stopped because the delivery is '
                  '${current.status.apiValue}.',
            );
          }
        } else if (failure.kind != LocationSimulationFailureKind.network &&
            failure.kind != LocationSimulationFailureKind.server) {
          rethrow;
        }
        if (attempt == 2) rethrow;
        await _delay(Duration(seconds: 1 << attempt));
        _ensureCurrent(generation);
      }
    }
    throw const LocationSimulationFailure(
      kind: LocationSimulationFailureKind.unexpected,
      operation: 'post simulated location',
      message: 'Location retry limit was reached.',
    );
  }

  void pause() {
    if (_state.phase != LocationSimulationPhase.moving) return;
    _emit(
      _state.copyWith(
        phase: LocationSimulationPhase.paused,
        message: 'Simulation paused.',
      ),
    );
  }

  void resume() {
    if (_state.phase != LocationSimulationPhase.paused) return;
    _emit(
      _state.copyWith(
        phase: LocationSimulationPhase.moving,
        message: 'Simulation resumed.',
      ),
    );
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  void stop() {
    if (!_state.isRunning &&
        _state.phase != LocationSimulationPhase.awaitingOtp) {
      return;
    }
    _cancelRun();
    _emit(
      _state.copyWith(
        phase: LocationSimulationPhase.stopped,
        message: 'Simulation stopped.',
      ),
    );
  }

  Future<void> verifyOtp(String code) async {
    final session = _session;
    final deliveryId = _state.deliveryId;
    if (session == null ||
        deliveryId == null ||
        _state.phase != LocationSimulationPhase.awaitingOtp) {
      _fail('No delivery is waiting for an OTP.');
      return;
    }
    final normalized = code.trim();
    if (normalized.isEmpty) {
      _fail('Enter the delivery OTP.');
      return;
    }
    _cancelRun();
    final generation = _generation;
    _emit(
      _state.copyWith(
        phase: LocationSimulationPhase.preparing,
        message: 'Verifying delivery OTP...',
      ),
    );
    try {
      await session.verifyOtp(deliveryId: deliveryId, code: normalized);
      _ensureCurrent(generation);
      _emit(
        _state.copyWith(
          phase: LocationSimulationPhase.completed,
          deliveryStatus: LocationSimulationDeliveryStatus.done,
          message: 'Delivery completed through OTP verification.',
        ),
      );
    } on _SimulationCancelled {
      return;
    } on LocationSimulationFailure catch (failure) {
      if (generation != _generation) return;
      _emit(
        _state.copyWith(
          phase: LocationSimulationPhase.awaitingOtp,
          message: failure.message,
        ),
      );
    }
  }

  Future<void> _waitUntilResumed(int generation) async {
    while (_state.phase == LocationSimulationPhase.paused) {
      _resumeCompleter ??= Completer<void>();
      await _resumeCompleter!.future;
      _ensureCurrent(generation);
    }
  }

  void _cancelRun() {
    _generation++;
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  void _ensureCurrent(int generation) {
    if (generation != _generation || _disposed) {
      throw const _SimulationCancelled();
    }
  }

  void _fail(String message) {
    _emit(
      _state.copyWith(phase: LocationSimulationPhase.failed, message: message),
    );
  }

  void _emit(LocationSimulationState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRun();
    super.dispose();
  }

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);

  static DateTime _defaultClock() => DateTime.now().toUtc();
}

class _SimulationCancelled implements Exception {
  const _SimulationCancelled();
}
