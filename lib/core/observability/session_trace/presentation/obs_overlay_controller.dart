// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../diagnostics/diag.dart';
import '../model/obs_event.dart';
import '../obs_export_bundle.dart';
import '../observability.dart';
import '../observability_config.dart';
import 'obs_overlay_tee_sink.dart';

const int _kMaxBufferedEvents = 500;

const Duration _kTick = Duration(seconds: 1);
const Duration _kStopDrainTimeout = Duration(seconds: 2);

final class ObsOverlayController extends ChangeNotifier {
  ObsOverlayController({
    Future<bool> Function()? install,
    Future<ObsExportBundle?> Function(
      String? sourcePath,
      List<ObsRecordingInterval> intervals,
    )?
    buildExportBundle,
    Future<ShareResult> Function(List<XFile> files, String subject)? share,
    DateTime Function()? clock,
    Duration stopDrainTimeout = _kStopDrainTimeout,
  }) : _install = install ?? _installDefault,
       _buildExportBundle = buildExportBundle ?? _buildExportDefault,
       _share = share ?? _shareDefault,
       _clock = clock ?? DateTime.now,
       _stopDrainTimeout = stopDrainTimeout;

  final Future<bool> Function() _install;
  final Future<ObsExportBundle?> Function(
    String? sourcePath,
    List<ObsRecordingInterval> intervals,
  )
  _buildExportBundle;
  final Future<ShareResult> Function(List<XFile> files, String subject) _share;
  final DateTime Function() _clock;
  final Duration _stopDrainTimeout;
  final List<ObsEvent> _events = <ObsEvent>[];
  final List<_MutableRecordingInterval> _recordingIntervals =
      <_MutableRecordingInterval>[];
  ObsEventType? _filter;
  bool _expanded = false;
  bool _attached = false;
  String? _lastExportedPath;
  String? _lastExportMessage;
  bool _lastExportSucceeded = false;
  String? _lastErrorMessage;
  int _transitionGeneration = 0;
  Future<void>? _activeStop;
  Future<ObsExportBundle?>? _activeSnapshot;
  Timer? _ticker;

  List<ObsEvent> get filteredEvents {
    final matching = _filter == null
        ? _events
        : _events.where((e) => e.type == _filter);
    return matching.toList(growable: false).reversed.toList(growable: false);
  }

  ObsEventType? get filter => _filter;

  int get totalBuffered => _events.length;

  bool get expanded => _expanded;

  bool get recording => Observability.instance.recording;

  String? get lastExportedPath => _lastExportedPath;
  String? get lastExportMessage => _lastExportMessage;
  bool get lastExportSucceeded => _lastExportSucceeded;
  String? get lastErrorMessage => _lastErrorMessage;

  Map<ObsEventType, int> get counts {
    final map = <ObsEventType, int>{for (final t in ObsEventType.values) t: 0};
    for (final event in _events) {
      map[event.type] = (map[event.type] ?? 0) + 1;
    }
    return map;
  }

  void attach() {
    if (!kObsCompiledIn || _attached) return;
    _attached = true;
    _wrapSink();
    _ticker = Timer.periodic(_kTick, (_) {
      _wrapSink();
      notifyListeners();
    });
  }

  void detach() {
    _ticker?.cancel();
    _ticker = null;
    if (!_attached) return;
    final current = Observability.instance.sink;
    if (current is ObsOverlayTeeSink) {
      Observability.instance.sink = current.inner;
    }
    _attached = false;
  }

  void _wrapSink() {
    final current = Observability.instance.sink;
    if (current is ObsOverlayTeeSink) return;
    Observability.instance.sink = ObsOverlayTeeSink(
      inner: current,
      onEvent: _onEvent,
    );
  }

  void _onEvent(ObsEvent event) {
    _events.add(event);
    if (_events.length > _kMaxBufferedEvents) _events.removeAt(0);
    notifyListeners();
  }

  void toggleExpanded() {
    _expanded = !_expanded;
    notifyListeners();
  }

  void setFilter(ObsEventType? type) {
    _filter = type;
    notifyListeners();
  }

  void clear() {
    _events.clear();
    notifyListeners();
  }

  Future<void> start() async {
    if (!kObsCompiledIn || recording) return;
    final generation = ++_transitionGeneration;
    if (!await _waitForTransitionBarrier(generation) || recording) return;
    _lastErrorMessage = null;
    bool installed;
    try {
      installed = await _install();
    } catch (_) {
      installed = false;
    }
    if (generation != _transitionGeneration) return;
    final installedPath = Observability.instance.sink?.sessionFilePath;
    if (!installed || installedPath == null || installedPath.trim().isEmpty) {
      ObservabilityConfig.instance.enabled = false;
      _lastErrorMessage =
          'Recording could not start because local trace storage is unavailable.';
      notifyListeners();
      return;
    }
    _wrapSink();
    ObservabilityConfig.instance.enabled = true;
    _recordingIntervals.add(_MutableRecordingInterval(_clock().toUtc()));
    final currentRoute = Observability.instance.currentScreen;
    if (currentRoute != null) {
      Observability.instance.recordScreen(
        action: 'snapshot',
        route: currentRoute,
        name: null,
      );
    }
    notifyListeners();
  }

  Future<bool> _waitForTransitionBarrier(int generation) async {
    while (generation == _transitionGeneration) {
      final snapshotting = _activeSnapshot;
      if (snapshotting != null) {
        try {
          await snapshotting;
        } catch (_) {}
        continue;
      }
      final stopping = _activeStop;
      if (stopping != null) {
        await stopping;
        continue;
      }
      return true;
    }
    return false;
  }

  Future<void> stop() {
    final existing = _activeStop;
    if (existing != null) return existing;
    _transitionGeneration++;
    final wasRecording = recording;
    ObservabilityConfig.instance.enabled = false;
    if (wasRecording) _closeOpenInterval(_clock().toUtc());
    notifyListeners();
    late final Future<void> completion;
    completion = _drainAndFlush().whenComplete(() {
      if (identical(_activeStop, completion)) _activeStop = null;
    });
    _activeStop = completion;
    return completion;
  }

  Future<void> _drainAndFlush() async {
    await Observability.instance.drainOutstandingApi(
      timeout: _stopDrainTimeout,
    );
    await Observability.instance.flush();
  }

  static Future<bool> _installDefault() =>
      Observability.instance.install(role: 'devtool');

  Future<void> exportAndShare() async {
    _lastExportSucceeded = false;
    ObsExportBundle? bundle;
    try {
      bundle = await _createExportSnapshot();
    } catch (_) {
      _lastExportedPath = null;
      _lastExportMessage = 'Export failed; no trace file was shared.';
      notifyListeners();
      return;
    }
    _lastExportedPath = bundle?.obsPath;
    if (bundle == null) {
      _lastExportSucceeded = false;
      _lastExportMessage = 'No session file yet — start recording first.';
      notifyListeners();
      return;
    }
    await _shareBundle(bundle);
    notifyListeners();
  }

  Future<ObsExportBundle?> _createExportSnapshot() {
    final existing = _activeSnapshot;
    if (existing != null) return existing;
    final completer = Completer<ObsExportBundle?>();
    final snapshot = completer.future;
    _activeSnapshot = snapshot;
    unawaited(_completeExportSnapshot(completer, snapshot));
    return snapshot;
  }

  Future<void> _completeExportSnapshot(
    Completer<ObsExportBundle?> completer,
    Future<ObsExportBundle?> snapshot,
  ) async {
    try {
      await stop();
      await Future.wait(<Future<void>>[
        Observability.instance.flush(),
        Diag.flushPersistent(),
      ]);
      final now = _clock().toUtc();
      final bundle = await _buildExportBundle(
        Observability.instance.sink?.sessionFilePath,
        _exportIntervals(now),
      );
      completer.complete(bundle);
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      if (identical(_activeSnapshot, snapshot)) _activeSnapshot = null;
    }
  }

  Future<void> _shareBundle(ObsExportBundle bundle) async {
    final paths = bundle.paths;
    try {
      final result = await _share(
        paths
            .map((path) => XFile(path, mimeType: 'application/x-ndjson'))
            .toList(),
        paths.first.split('/').last,
      );
      switch (result.status) {
        case ShareResultStatus.success:
          _lastExportSucceeded = true;
          _lastExportMessage = 'Shared ${paths.length} local trace file(s).';
        case ShareResultStatus.dismissed:
          _lastExportSucceeded = false;
          _lastExportMessage =
              'Sharing was cancelled; snapshots remain in cache.';
        case ShareResultStatus.unavailable:
          _lastExportSucceeded = false;
          _lastExportMessage =
              'Sharing is unavailable; snapshots remain in cache.';
      }
    } catch (_) {
      _lastExportSucceeded = false;
      _lastExportMessage = 'Sharing failed; snapshots remain in cache.';
    }
  }

  static Future<ShareResult> _shareDefault(List<XFile> files, String subject) =>
      Share.shareXFiles(files, subject: subject);

  static Future<ObsExportBundle?> _buildExportDefault(
    String? sourcePath,
    List<ObsRecordingInterval> intervals,
  ) => ObsExportBundleBuilder.create(
    obsSourcePath: sourcePath,
    intervals: intervals,
  );

  void _closeOpenInterval(DateTime endUtc) {
    if (_recordingIntervals.isEmpty) return;
    final latest = _recordingIntervals.last;
    latest.endUtc ??= endUtc;
  }

  List<ObsRecordingInterval> _exportIntervals(DateTime nowUtc) {
    return _recordingIntervals
        .map(
          (interval) => ObsRecordingInterval(
            startUtc: interval.startUtc,
            endUtc: interval.endUtc ?? nowUtc,
          ),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _transitionGeneration++;
    detach();
    super.dispose();
  }
}

final class _MutableRecordingInterval {
  _MutableRecordingInterval(this.startUtc);

  final DateTime startUtc;
  DateTime? endUtc;
}
