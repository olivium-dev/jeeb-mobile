import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/di/injection_container.dart';
import '../gateway/dev_gateway_client.dart';
import 'dio_location_simulation_gateway.dart';
import 'location_simulation_controller.dart';
import 'location_simulation_gateway.dart';
import 'location_simulation_models.dart';

class LocationSimulatorPage extends StatefulWidget {
  const LocationSimulatorPage({
    super.key,
    this.devGatewayClient,
    this.simulationGateway,
    this.loadUsers,
    this.tickInterval = const Duration(seconds: 2),
    this.delay,
    this.clock,
  });

  final DevGatewayClient? devGatewayClient;
  final LocationSimulationGateway? simulationGateway;
  final Future<List<DevUser>> Function()? loadUsers;
  final Duration tickInterval;
  final SimulationDelay? delay;
  final SimulationClock? clock;

  @override
  State<LocationSimulatorPage> createState() => _LocationSimulatorPageState();
}

class _LocationSimulatorPageState extends State<LocationSimulatorPage>
    with WidgetsBindingObserver {
  DevGatewayClient? _devGatewayClient;
  late final Future<List<DevUser>> Function() _loadUsersCallback;
  late final LocationSimulationController _controller;
  final TextEditingController _otpController = TextEditingController();

  bool _loadingUsers = true;
  bool _loadingDeliveries = false;
  String? _usersError;
  List<DevUser> _users = const <DevUser>[];
  DevUser? _selectedUser;
  List<LocationSimulationDeliverySummary> _deliveries =
      const <LocationSimulationDeliverySummary>[];
  LocationSimulationDeliverySummary? _selectedDelivery;
  LocationSimulationMode _mode = LocationSimulationMode.fullTrip;
  double _tripDurationSeconds = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _devGatewayClient = widget.devGatewayClient;
    if (_devGatewayClient == null &&
        (widget.loadUsers == null || widget.simulationGateway == null)) {
      _devGatewayClient = DevGatewayClient();
    }
    _loadUsersCallback =
        widget.loadUsers ?? () => _devGatewayClient!.listUsers();
    final gateway =
        widget.simulationGateway ??
        DioLocationSimulationGateway(
          dio: sl<Dio>(),
          devGatewayClient: _devGatewayClient!,
        );
    _controller = LocationSimulationController(
      gateway: gateway,
      tickInterval: widget.tickInterval,
      delay: widget.delay ?? (duration) => Future<void>.delayed(duration),
      clock: widget.clock ?? () => DateTime.now().toUtc(),
    );
    unawaited(_loadUsers());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _otpController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final loaded = await _loadUsersCallback();
      final jeebers = loaded
          .where((user) => user.isJeeber && user.id.trim().isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _users = jeebers;
        _selectedUser = jeebers.isEmpty ? null : jeebers.first;
        _loadingUsers = false;
      });
      if (_selectedUser != null) {
        await _loadDeliveries(_selectedUser!);
      }
    } on DevGatewayException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingUsers = false;
        _usersError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingUsers = false;
        _usersError = 'Could not load Jeeber users: $error';
      });
    }
  }

  Future<void> _loadDeliveries(DevUser user) async {
    setState(() {
      _selectedUser = user;
      _loadingDeliveries = true;
      _deliveries = const <LocationSimulationDeliverySummary>[];
      _selectedDelivery = null;
    });
    try {
      final deliveries = await _controller.connectDriver(
        user.id,
        roles: user.roles,
      );
      if (!mounted || _selectedUser?.id != user.id) return;
      setState(() {
        _deliveries = deliveries;
        _selectedDelivery = deliveries.isEmpty ? null : deliveries.first;
        _loadingDeliveries = false;
      });
    } on LocationSimulationFailure {
      if (!mounted || _selectedUser?.id != user.id) return;
      setState(() => _loadingDeliveries = false);
    }
  }

  Future<void> _start() async {
    final delivery = _selectedDelivery;
    if (delivery == null) return;
    _otpController.clear();
    await _controller.start(
      deliveryId: delivery.id,
      mode: _mode,
      tripDuration: Duration(seconds: _tripDurationSeconds.round()),
    );
  }

  String _userLabel(DevUser user) {
    final label = user.displayName ?? user.username;
    return label.trim().isEmpty ? user.id : label;
  }

  String _deliveryLabel(LocationSimulationDeliverySummary delivery) =>
      '${delivery.id} · ${delivery.status.apiValue}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Simulator'),
        actions: [
          Tooltip(
            message: 'Refresh users',
            child: IconButton(
              key: const ValueKey('locationSimulator.refreshUsers'),
              onPressed: _selectionLocked(_controller.state)
                  ? null
                  : _loadUsers,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final state = _controller.state;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionLabel(context, 'Driver'),
              const SizedBox(height: 8),
              _buildUserPicker(state),
              const SizedBox(height: 16),
              _sectionLabel(context, 'Delivery'),
              const SizedBox(height: 8),
              _buildDeliveryPicker(state),
              const SizedBox(height: 24),
              _sectionLabel(context, 'Simulation mode'),
              const SizedBox(height: 8),
              SegmentedButton<LocationSimulationMode>(
                key: const ValueKey('locationSimulator.mode'),
                segments: const [
                  ButtonSegment<LocationSimulationMode>(
                    value: LocationSimulationMode.locationOnly,
                    icon: Icon(Icons.my_location),
                    label: Text('Location only'),
                  ),
                  ButtonSegment<LocationSimulationMode>(
                    value: LocationSimulationMode.fullTrip,
                    icon: Icon(Icons.route),
                    label: Text('Full trip'),
                  ),
                ],
                selected: <LocationSimulationMode>{_mode},
                onSelectionChanged: _selectionLocked(state)
                    ? null
                    : (selection) => setState(() => _mode = selection.single),
              ),
              const SizedBox(height: 24),
              _sectionLabel(context, 'Trip duration'),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      key: const ValueKey('locationSimulator.duration'),
                      value: _tripDurationSeconds,
                      min: 15,
                      max: 180,
                      divisions: 11,
                      label: '${_tripDurationSeconds.round()} s',
                      onChanged: _selectionLocked(state)
                          ? null
                          : (value) =>
                                setState(() => _tripDurationSeconds = value),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${_tripDurationSeconds.round()} s',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('locationSimulator.start'),
                onPressed: _canStart(state) ? _start : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start simulation'),
              ),
              if (state.phase != LocationSimulationPhase.idle ||
                  state.message != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _buildRunStatus(context, state),
              ],
              if (state.phase == LocationSimulationPhase.awaitingOtp) ...[
                const SizedBox(height: 20),
                _buildOtpInput(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserPicker(LocationSimulationState state) {
    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null) {
      return _InlineError(message: _usersError!, onRetry: _loadUsers);
    }
    if (_users.isEmpty) {
      return const Text(
        'No users with `driver` in roles[] were returned by the MSI '
        'super-login roster.',
      );
    }
    return DropdownButtonFormField<DevUser>(
      key: ValueKey('locationSimulator.driver.${_selectedUser?.id}'),
      initialValue: _selectedUser,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Acting Jeeber',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final user in _users)
          DropdownMenuItem(value: user, child: Text(_userLabel(user))),
      ],
      onChanged: _selectionLocked(state)
          ? null
          : (user) {
              if (user != null) unawaited(_loadDeliveries(user));
            },
    );
  }

  Widget _buildDeliveryPicker(LocationSimulationState state) {
    if (_loadingDeliveries) {
      return const LinearProgressIndicator(
        key: ValueKey('locationSimulator.loadingDeliveries'),
      );
    }
    if (_deliveries.isEmpty) {
      return const Text('No active assigned deliveries available.');
    }
    return DropdownButtonFormField<LocationSimulationDeliverySummary>(
      key: ValueKey('locationSimulator.delivery.${_selectedDelivery?.id}'),
      initialValue: _selectedDelivery,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Assigned delivery',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final delivery in _deliveries)
          DropdownMenuItem(
            value: delivery,
            child: Text(
              _deliveryLabel(delivery),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _selectionLocked(state)
          ? null
          : (delivery) => setState(() => _selectedDelivery = delivery),
    );
  }

  bool _canStart(LocationSimulationState state) {
    if (_selectedDelivery == null || _loadingDeliveries) return false;
    return !state.isRunning &&
        state.phase != LocationSimulationPhase.awaitingOtp;
  }

  bool _selectionLocked(LocationSimulationState state) =>
      state.isRunning || state.phase == LocationSimulationPhase.awaitingOtp;

  Widget _buildRunStatus(BuildContext context, LocationSimulationState state) {
    final point = state.currentPoint;
    final isError = state.phase == LocationSimulationPhase.failed;
    return Column(
      key: const ValueKey('locationSimulator.status'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _phaseLabel(state.phase),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (state.phase == LocationSimulationPhase.moving)
              Tooltip(
                message: 'Pause',
                child: IconButton(
                  key: const ValueKey('locationSimulator.pause'),
                  onPressed: _controller.pause,
                  icon: const Icon(Icons.pause),
                ),
              ),
            if (state.phase == LocationSimulationPhase.paused)
              Tooltip(
                message: 'Resume',
                child: IconButton(
                  key: const ValueKey('locationSimulator.resume'),
                  onPressed: _controller.resume,
                  icon: const Icon(Icons.play_arrow),
                ),
              ),
            if (state.isRunning ||
                state.phase == LocationSimulationPhase.awaitingOtp)
              Tooltip(
                message: 'Stop',
                child: IconButton(
                  key: const ValueKey('locationSimulator.stop'),
                  onPressed: _controller.stop,
                  icon: const Icon(Icons.stop),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          key: const ValueKey('locationSimulator.progress'),
          value: state.route == null ? 0 : state.progress,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _Metric(label: 'Accepted', value: '${state.acceptedUpdates}'),
            _Metric(label: 'Rejected', value: '${state.rejectedUpdates}'),
            if (state.deliveryStatus != null)
              _Metric(label: 'Status', value: state.deliveryStatus!.apiValue),
          ],
        ),
        if (point != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            '${point.coordinate.latitude.toStringAsFixed(6)}, '
            '${point.coordinate.longitude.toStringAsFixed(6)}',
            key: const ValueKey('locationSimulator.coordinate'),
          ),
        ],
        if (state.message != null) ...[
          const SizedBox(height: 12),
          Text(
            state.message!,
            key: const ValueKey('locationSimulator.message'),
            style: isError
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
        ],
      ],
    );
  }

  Widget _buildOtpInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('locationSimulator.otp'),
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Delivery OTP',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const ValueKey('locationSimulator.verifyOtp'),
          onPressed: () => _controller.verifyOtp(_otpController.text),
          child: const Text('Verify'),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label) =>
      Text(label, style: Theme.of(context).textTheme.labelMedium);

  String _phaseLabel(LocationSimulationPhase phase) => switch (phase) {
    LocationSimulationPhase.idle => 'Ready',
    LocationSimulationPhase.preparing => 'Preparing',
    LocationSimulationPhase.moving => 'Moving',
    LocationSimulationPhase.paused => 'Paused',
    LocationSimulationPhase.arrived => 'Arrived',
    LocationSimulationPhase.awaitingOtp => 'At the door',
    LocationSimulationPhase.completed => 'Delivered',
    LocationSimulationPhase.stopped => 'Stopped',
    LocationSimulationPhase.failed => 'Failed',
  };
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(label: '$label: $value', child: Text('$label  $value'));
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
