// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../model/obs_event.dart';
import '../observability.dart';
import '../observability_config.dart';
import 'obs_overlay_tee_sink.dart';

const int _kMaxBufferedEvents = 500;

const Duration _kTick = Duration(seconds: 1);

final class ObsOverlayController extends ChangeNotifier {
  final List<ObsEvent> _events = <ObsEvent>[];
  ObsEventType? _filter;
  bool _expanded = false;
  bool _attached = false;
  String? _lastExportedPath;
  String? _lastExportMessage;
  bool _lastExportSucceeded = false;
  Timer? _ticker;

  List<ObsEvent> get filteredEvents {
    final matching =
        _filter == null ? _events : _events.where((e) => e.type == _filter);
    return matching.toList(growable: false).reversed.toList(growable: false);
  }

  ObsEventType? get filter => _filter;

  int get totalBuffered => _events.length;

  bool get expanded => _expanded;

  bool get recording => Observability.instance.recording;

  String? get lastExportedPath => _lastExportedPath;
  String? get lastExportMessage => _lastExportMessage;
  bool get lastExportSucceeded => _lastExportSucceeded;

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
    if (!kObsCompiledIn) return;
    await Observability.instance.install(role: 'devtool');
    _wrapSink();
    ObservabilityConfig.instance.enabled = true;
    notifyListeners();
  }

  void stop() {
    ObservabilityConfig.instance.enabled = false;
    notifyListeners();
  }

  Future<void> exportAndShare() async {
    await Observability.instance.flush();
    final path = Observability.instance.sink?.sessionFilePath;
    _lastExportedPath = path;
    if (path == null) {
      _lastExportSucceeded = false;
      _lastExportMessage = 'No session file yet — start recording first.';
      notifyListeners();
      return;
    }
    await _shareOrCopy(path);
    notifyListeners();
  }

  Future<void> _shareOrCopy(String path) async {
    try {
      await Share.shareXFiles(
        <XFile>[XFile(path, mimeType: 'text/plain')],
        subject: path.split('/').last,
      );
      _lastExportSucceeded = true;
      _lastExportMessage = 'Shared ${path.split('/').last}';
    } catch (_) {
      await _copyPathFallback(path);
    }
  }

  Future<void> _copyPathFallback(String path) async {
    try {
      await Clipboard.setData(ClipboardData(text: path));
      _lastExportSucceeded = true;
      _lastExportMessage = 'Share unavailable — path copied:\n$path';
    } catch (_) {
      _lastExportSucceeded = false;
      _lastExportMessage = 'Export ready at:\n$path';
    }
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
