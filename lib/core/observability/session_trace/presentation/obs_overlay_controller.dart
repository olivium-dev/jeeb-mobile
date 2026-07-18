// ignore_for_file: invalid_use_of_visible_for_testing_member
//
// This file is the one sanctioned place outside tests that reads/writes
// `Observability.instance.sink`. The field is marked `@visibleForTesting`
// because its PRIMARY purpose is swapping in a fake for unit tests, but its
// type (`ObservabilitySink?`) is a deliberately swappable seam — see the
// architecture contract §3.2 ("swappable in tests") — and wrapping it in a
// non-invasive tee is the only way a devtool overlay can observe the live
// event stream without modifying the frozen `Observability` class. Every
// touch point below is additive (it decorates, never replaces, behavior).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../model/obs_event.dart';
import '../observability.dart';
import '../observability_config.dart';
import 'obs_overlay_tee_sink.dart';

/// Max events kept in the live overlay's in-memory buffer; oldest dropped
/// first once exceeded. Bounds memory for a long-running devtool session —
/// it has no effect on the durable JSONL file, which the real writer
/// paginates/rotates independently (see `ObsFileWriter`).
const int _kMaxBufferedEvents = 500;

/// How often the controller re-verifies its sink wrapping and refreshes
/// UI-only state (the recording indicator) even absent new events. Cheap (a
/// single `is` check) and only ever runs while a devtool overlay is mounted.
/// NOT a UI animation/transition, so `UIConstants.animation*` does not apply
/// here (those tokenize motion speed; this tokenizes a background poll
/// cadence) — this is this controller's own named, documented constant, the
/// same deliberate-exception pattern `ObsOverlayPanel` uses for its
/// screen-fraction sizing.
const Duration _kTick = Duration(seconds: 1);

/// Devtool-only view-model behind `ObsOverlayHost`.
///
/// This controller never captures anything itself — modules 1-4 (nav
/// observer, dio interceptor, notification recorder, interaction observer)
/// do that. It only OBSERVES what already flows to
/// `Observability.instance.sink` (via a non-invasive [ObsOverlayTeeSink])
/// and drives the two runtime knobs the frozen core exposes:
/// `ObservabilityConfig.enabled` (start/stop) and
/// `Observability.instance.install` (idempotent session bootstrap).
final class ObsOverlayController extends ChangeNotifier {
  final List<ObsEvent> _events = <ObsEvent>[];
  ObsEventType? _filter;
  bool _expanded = false;
  bool _attached = false;
  String? _lastExportedPath;
  String? _lastExportMessage;
  bool _lastExportSucceeded = false;
  Timer? _ticker;

  /// Buffered events, newest first, filtered by [filter].
  List<ObsEvent> get filteredEvents {
    final matching =
        _filter == null ? _events : _events.where((e) => e.type == _filter);
    return matching.toList(growable: false).reversed.toList(growable: false);
  }

  /// The active type filter; null means "all four signal types".
  ObsEventType? get filter => _filter;

  /// Total buffered events ACROSS all four types, ignoring [filter] — what
  /// `clear()` actually discards, so the "Clear" control can show a count
  /// that matches its own effect rather than the currently-filtered count.
  int get totalBuffered => _events.length;

  /// Whether the panel (vs. just the toggle bubble) is showing.
  bool get expanded => _expanded;

  /// Live pass-through of the core recording switch — always fresh, never
  /// cached, so the UI can't drift from `ObservabilityConfig.enabled`.
  bool get recording => Observability.instance.recording;

  String? get lastExportedPath => _lastExportedPath;
  String? get lastExportMessage => _lastExportMessage;
  bool get lastExportSucceeded => _lastExportSucceeded;

  /// Per-type counts across the buffered window, for the filter chips.
  Map<ObsEventType, int> get counts {
    final map = <ObsEventType, int>{for (final t in ObsEventType.values) t: 0};
    for (final event in _events) {
      map[event.type] = (map[event.type] ?? 0) + 1;
    }
    return map;
  }

  /// Wraps the current sink so this controller also observes the live
  /// stream, and starts the freshness/self-heal tick. Additive, idempotent,
  /// and a hard no-op outside a devtool build. Call from `State.initState`.
  void attach() {
    if (!kObsCompiledIn || _attached) return;
    _attached = true;
    _wrapSink();
    _ticker = Timer.periodic(_kTick, (_) {
      _wrapSink();
      notifyListeners();
    });
  }

  /// Unwraps the sink this controller wrapped and stops ticking. Call from
  /// `State.dispose` (before `dispose()`, which also calls this defensively).
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

  /// Re-wraps `Observability.instance.sink` with a tee if it isn't already
  /// ours. Self-heals against the (narrow, cold-start-only) case where a
  /// later `Observability.install` call replaces the sink after [attach].
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

  /// Toggles between the collapsed bubble and the expanded panel.
  void toggleExpanded() {
    _expanded = !_expanded;
    notifyListeners();
  }

  /// Filters the live list to one signal type, or null for all four.
  void setFilter(ObsEventType? type) {
    _filter = type;
    notifyListeners();
  }

  /// Clears the LIVE, in-memory list this overlay displays. The durable
  /// JSONL session file is untouched — `ObservabilitySink` intentionally
  /// exposes no delete/truncate operation (architecture contract §3.5), so
  /// "clear" scopes to what the overlay shows, not what is already on disk.
  void clear() {
    _events.clear();
    notifyListeners();
  }

  /// "Start": ensures a session exists (idempotent — a no-op in the normal
  /// wiring, where `Bootstrap.minimal()` has already installed one) then
  /// flips the runtime recording switch on.
  Future<void> start() async {
    if (!kObsCompiledIn) return;
    await Observability.instance.install(role: 'devtool');
    _wrapSink();
    ObservabilityConfig.instance.enabled = true;
    notifyListeners();
  }

  /// "Stop": flips the runtime recording switch off. The session id and
  /// file stay intact — a later [start] resumes the SAME session rather
  /// than minting a new one (`Observability.install` is one-shot per run).
  void stop() {
    ObservabilityConfig.instance.enabled = false;
    notifyListeners();
  }

  /// "Export / Share": flushes the sink to disk, then hands the session
  /// file to the platform share sheet; falls back to copying the path to
  /// the clipboard if sharing throws (mirrors `DiagnosticsScreen._share`'s
  /// fail-soft precedent in `lib/core/diagnostics/diagnostics_screen.dart`).
  /// Always records the resolved path so the UI can show/copy it even if
  /// both the share sheet and the clipboard write fail.
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
        // 'text/plain' matches `DiagnosticsScreen.defaultShareLauncher`'s
        // choice for the analogous diag `.jsonl` file — JSONL IS plain text,
        // and this keeps share-target compatibility identical to the
        // already-shipped precedent rather than introducing an unproven
        // custom mime type.
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
