import 'dart:io';

import 'package:flutter/foundation.dart';

import 'model/obs_event.dart';
import 'observability_config.dart';
import 'obs_file_writer.dart';

/// Durable sink for serialized trace events. Implemented by [ObsFileWriter].
///
/// Contract (identical spirit to `DiagPersistentSink`): fail-soft +
/// non-blocking — [add] only buffers in memory; real IO happens later on a
/// serialized chain owned by the implementation.
abstract interface class ObservabilitySink {
  /// Buffers [event]. [flushNow] hints a failure record (non-2xx api / error)
  /// should hit disk promptly. Must NEVER throw and NEVER block.
  void add(ObsEvent event, {bool flushNow = false});

  /// Forces the buffer to disk. Must never throw.
  Future<void> flush();

  /// Final flush; sink stays usable.
  Future<void> close();

  /// Absolute path of this session's JSONL file (null before start()).
  String? get sessionFilePath;
}

/// The single global entry point every capturer emits through.
///
/// Zero-cost no-op unless the tool is compiled in ([kObsCompiledIn]) AND
/// recording is enabled at runtime ([ObservabilityConfig.enabled]) — see
/// [recording]. Every capturer's hot path is expected to open with
/// `if (!Observability.instance.recording) return;` before doing any other
/// work (building an event, reading the semantics tree, etc.).
final class Observability {
  Observability._();

  static final Observability instance = Observability._();

  /// Session id used when a capturer records BEFORE [install] has minted one
  /// (a narrow cold-start race — [install] is fire-and-forget from
  /// bootstrap). The event is still recorded; it just can't be correlated to
  /// a specific session file by id.
  static const String _unknownSessionId = 'unknown-session';

  String? _sessionId;
  int _seq = 0;

  ObservabilityConfig get config => ObservabilityConfig.instance;

  /// True only when the tool is compiled in ([kObsCompiledIn]) AND
  /// runtime-enabled ([ObservabilityConfig.enabled]).
  bool get recording => kObsCompiledIn && config.enabled;

  /// Current session id (one per app run). Null until [install] resolves.
  String? get sessionId => _sessionId;

  /// Active screen route pattern; kept current by `ObsNavObserver` and
  /// stamped onto api + interaction events (mirrors `Diag.currentScreen`).
  String? currentScreen;

  /// Clock for `timestampUtc`; overridable in tests. Always used via
  /// `.toUtc()` at the call site.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// The installed sink; swappable in tests. Null until [install] resolves.
  @visibleForTesting
  ObservabilitySink? sink;

  /// Next monotonic per-session sequence number (1, 2, 3…). The api
  /// interceptor calls this at REQUEST time so concurrent calls keep
  /// ordered ids even when their responses complete out of order.
  int nextSeq() => ++_seq;

  /// Builds a `'<seq>-<type>'` event id (e.g. `'42-api'`).
  String newEventId(ObsEventType type, int seq) => '$seq-${type.name}';

  /// LOW-LEVEL ingest: checks [recording] + the per-signal toggle, then
  /// hands [event] to [sink]. The api interceptor uses this directly — it
  /// stamps `seq` itself at request time and builds the full [ObsApiEvent]
  /// before calling this. Fail-soft: a sink failure can never break a
  /// capturer's hot path.
  void record(ObsEvent event) {
    if (!recording || !config.signalEnabled(event.type)) return;
    final activeSink = sink;
    if (activeSink == null) return;
    try {
      activeSink.add(event, flushNow: _isFailureEvent(event));
    } catch (_) {
      // Fail-soft by contract — a sink failure can never break a capturer.
    }
  }

  /// Builds + records an [ObsScreenEvent]. No-op when not [recording] or the
  /// screen signal is toggled off.
  void recordScreen({
    required String action,
    required String? route,
    required String? name,
    String? previousRoute,
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    if (!recording || !config.signalEnabled(ObsEventType.screen)) return;
    final seq = nextSeq();
    record(ObsScreenEvent(
      id: newEventId(ObsEventType.screen, seq),
      sessionId: _sessionId ?? _unknownSessionId,
      timestampUtc: clock().toUtc(),
      seq: seq,
      action: action,
      route: route,
      name: name,
      previousRoute: previousRoute,
      params: params,
    ));
  }

  /// Builds + records an [ObsNotificationEvent]. No-op when not [recording]
  /// or the notification signal is toggled off.
  void recordNotification({
    required String channel,
    required String mode,
    required String messageId,
    required String category,
    String? title,
    String? body,
    String? deepLink,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    if (!recording || !config.signalEnabled(ObsEventType.notification)) {
      return;
    }
    final seq = nextSeq();
    record(ObsNotificationEvent(
      id: newEventId(ObsEventType.notification, seq),
      sessionId: _sessionId ?? _unknownSessionId,
      timestampUtc: clock().toUtc(),
      seq: seq,
      channel: channel,
      mode: mode,
      messageId: messageId,
      category: category,
      title: title,
      body: body,
      deepLink: deepLink,
      data: data,
    ));
  }

  /// Builds + records an [ObsInteractionEvent]. No-op when not [recording]
  /// or the interaction signal is toggled off.
  void recordInteraction({
    required String gesture,
    String? targetId,
    String? targetLabel,
    String? screen,
    int? dx,
    int? dy,
    String? valuePreview,
  }) {
    if (!recording || !config.signalEnabled(ObsEventType.interaction)) return;
    final seq = nextSeq();
    record(ObsInteractionEvent(
      id: newEventId(ObsEventType.interaction, seq),
      sessionId: _sessionId ?? _unknownSessionId,
      timestampUtc: clock().toUtc(),
      seq: seq,
      gesture: gesture,
      targetId: targetId,
      targetLabel: targetLabel,
      screen: screen,
      dx: dx,
      dy: dy,
      valuePreview: valuePreview,
    ));
  }

  /// Installs the session: mints a sessionId, builds+starts the
  /// [ObsFileWriter], wires it as [sink]. FIRE-AND-FORGET from bootstrap —
  /// total (never throws); hard no-op when [kObsCompiledIn] is false or a
  /// session is already installed. [role]/[subLookup] mirror
  /// `DiagFileSink.installAsGlobal`.
  ///
  /// NOTE: unlike `Diag.persistentSink`, [sink] is wired only once the
  /// writer resolves (not before) — an event recorded during that narrow
  /// async gap is a fail-soft no-op (see [_unknownSessionId] and [record]).
  /// In practice this window closes long before any screen has rendered.
  Future<void> install({
    required String role,
    Future<String?> Function()? subLookup,
    Future<Directory> Function()? baseDirectoryProvider,
  }) async {
    if (!kObsCompiledIn || _sessionId != null) return;
    try {
      final mintedId = _mintSessionId(role);
      _sessionId = mintedId;
      sink = await ObsFileWriter.installAsGlobal(
        sessionId: mintedId,
        role: role,
        subLookup: subLookup,
        baseDirectoryProvider: baseDirectoryProvider,
      );
    } catch (_) {
      // Fail-soft by contract — install must never break bootstrap.
    }
  }

  /// Flushes the sink (called on app pause/detach). No-op when none
  /// installed. Fail-soft: a broken sink can never surface into the
  /// lifecycle handler.
  Future<void> flush() async {
    final activeSink = sink;
    if (activeSink == null) return;
    try {
      await activeSink.flush();
    } catch (_) {
      // Fail-soft by contract — see class doc.
    }
  }

  /// Restores production defaults. Call from a test `tearDown`. Does NOT
  /// reset [ObservabilityConfig.instance] — call its own `reset()` too when
  /// a test also needs the runtime toggles restored.
  @visibleForTesting
  void resetForTest() {
    currentScreen = null;
    clock = DateTime.now;
    sink = null;
    _sessionId = null;
    _seq = 0;
  }

  /// True for events whose persistence should be flushed promptly — a
  /// non-2xx/transport-failed api call — so a crash right after cannot lose
  /// the evidence. Mirrors `Diag._isFailureRecord`.
  static bool _isFailureEvent(ObsEvent event) {
    if (event is ObsApiEvent) {
      final status = event.statusCode;
      return status == null || status >= 400;
    }
    return false;
  }

  /// `<isoStamp>-<role>`, e.g. `2026-07-18T10-30-15-123Z-client` — the
  /// filesystem-safe stem `ObsFileWriter` names the session file after (see
  /// `ObsFileWriter.dirName`), and the value stamped onto every event's
  /// `sessionId`. Mirrors `DiagFileSink`'s stamp format exactly.
  String _mintSessionId(String role) {
    final stamp = _isoStamp(clock().toUtc());
    final safeRole = role.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '$stamp-$safeRole';
  }

  static String _isoStamp(DateTime utc) {
    String p2(int n) => n.toString().padLeft(2, '0');
    String p3(int n) => n.toString().padLeft(3, '0');
    return '${utc.year}-${p2(utc.month)}-${p2(utc.day)}'
        'T${p2(utc.hour)}-${p2(utc.minute)}-${p2(utc.second)}-'
        '${p3(utc.millisecond)}Z';
  }
}
