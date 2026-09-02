import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'model/obs_event.dart';
import 'observability_config.dart';
import 'obs_file_writer.dart';

abstract interface class ObservabilitySink {
  void add(ObsEvent event, {bool flushNow = false});

  Future<void> flush();

  Future<void> close();

  String? get sessionFilePath;
}

final class ObsApiCapture {
  ObsApiCapture({
    required this.sessionId,
    required this.seq,
    required this.screen,
    required this.sink,
  });

  final String sessionId;
  final int seq;
  final String? screen;
  final ObservabilitySink sink;
  final Completer<void> completed = Completer<void>();
}

final class Observability {
  Observability._();

  static final Observability instance = Observability._();

  static const String _unknownSessionId = 'unknown-session';

  String? _sessionId;
  int _seq = 0;
  final Set<ObsApiCapture> _outstandingApi = <ObsApiCapture>{};
  Future<bool>? _installing;

  ObservabilityConfig get config => ObservabilityConfig.instance;

  bool get recording => kObsCompiledIn && config.enabled;

  String? get sessionId => _sessionId;

  String? currentScreen;

  int get outstandingApiCount => _outstandingApi.length;

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  @visibleForTesting
  ObservabilitySink? sink;

  @visibleForTesting
  void setSessionForTest(String value) => _sessionId = value;

  int nextSeq() => ++_seq;

  String newEventId(ObsEventType type, int seq) => '$seq-${type.name}';

  void record(ObsEvent event) {
    if (!recording || !config.signalEnabled(event.type)) return;
    _write(event);
  }

  void _write(ObsEvent event) {
    final activeSink = sink;
    if (activeSink == null) return;
    _writeTo(activeSink, event);
  }

  void _writeTo(ObservabilitySink target, ObsEvent event) {
    try {
      target.add(event, flushNow: _isFailureEvent(event));
    } catch (_) {}
  }

  ObsApiCapture? beginApiCapture() {
    final activeSession = _sessionId;
    final activeSink = sink;
    final activePath = activeSink?.sessionFilePath;
    if (!recording ||
        activeSession == null ||
        activePath == null ||
        activePath.trim().isEmpty ||
        !config.signalEnabled(ObsEventType.api)) {
      return null;
    }
    final capture = ObsApiCapture(
      sessionId: activeSession,
      seq: nextSeq(),
      screen: currentScreen,
      sink: activeSink!,
    );
    _outstandingApi.add(capture);
    return capture;
  }

  void completeApiCapture(ObsApiCapture capture, ObsApiEvent event) {
    if (!_outstandingApi.remove(capture)) return;
    try {
      _writeTo(capture.sink, event);
    } finally {
      if (!capture.completed.isCompleted) capture.completed.complete();
    }
  }

  void abandonApiCapture(ObsApiCapture capture) {
    if (!_outstandingApi.remove(capture)) return;
    if (!capture.completed.isCompleted) capture.completed.complete();
  }

  Future<void> drainOutstandingApi({required Duration timeout}) async {
    final captures = _outstandingApi.toList(growable: false);
    if (captures.isEmpty) return;
    try {
      await Future.wait(
        captures.map((capture) => capture.completed.future),
      ).timeout(timeout);
    } on TimeoutException {
      for (final capture in captures) {
        abandonApiCapture(capture);
      }
    }
  }

  void recordScreen({
    required String action,
    required String? route,
    required String? name,
    String? previousRoute,
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    if (!recording || !config.signalEnabled(ObsEventType.screen)) return;
    final seq = nextSeq();
    record(
      ObsScreenEvent(
        id: newEventId(ObsEventType.screen, seq),
        sessionId: _sessionId ?? _unknownSessionId,
        timestampUtc: clock().toUtc(),
        seq: seq,
        action: action,
        route: route,
        name: name,
        previousRoute: previousRoute,
        params: params,
      ),
    );
  }

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
    record(
      ObsNotificationEvent(
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
      ),
    );
  }

  void recordInteraction({
    required String gesture,
    String? targetId,
    String? targetLabel,
    String? screen,
    String? valuePreview,
  }) {
    if (!recording || !config.signalEnabled(ObsEventType.interaction)) return;
    final seq = nextSeq();
    record(
      ObsInteractionEvent(
        id: newEventId(ObsEventType.interaction, seq),
        sessionId: _sessionId ?? _unknownSessionId,
        timestampUtc: clock().toUtc(),
        seq: seq,
        gesture: gesture,
        targetId: targetId,
        targetLabel: targetLabel,
        screen: screen,
        valuePreview: valuePreview,
      ),
    );
  }

  Future<bool> install({
    required String role,
    Future<String?> Function()? subLookup,
    Future<Directory> Function()? baseDirectoryProvider,
  }) async {
    if (!kObsCompiledIn) return false;
    final installedPath = sink?.sessionFilePath;
    if (_sessionId != null &&
        installedPath != null &&
        installedPath.trim().isNotEmpty) {
      return true;
    }
    final pending = _installing;
    if (pending != null) return pending;
    final attempt = _performInstall(
      role: role,
      subLookup: subLookup,
      baseDirectoryProvider: baseDirectoryProvider,
    );
    _installing = attempt;
    try {
      return await attempt;
    } finally {
      if (identical(_installing, attempt)) _installing = null;
    }
  }

  Future<bool> _performInstall({
    required String role,
    Future<String?> Function()? subLookup,
    Future<Directory> Function()? baseDirectoryProvider,
  }) async {
    try {
      final mintedId = _mintSessionId(role);
      final installed = await ObsFileWriter.installAsGlobal(
        sessionId: mintedId,
        role: role,
        subLookup: subLookup,
        baseDirectoryProvider: baseDirectoryProvider,
      );
      final installedPath = installed?.sessionFilePath;
      if (installedPath == null || installedPath.trim().isEmpty) {
        _sessionId = null;
        sink = null;
        return false;
      }
      _sessionId = mintedId;
      sink = installed;
      return true;
    } catch (_) {
      _sessionId = null;
      sink = null;
      return false;
    }
  }

  Future<void> flush() async {
    final activeSink = sink;
    if (activeSink == null) return;
    try {
      await activeSink.flush();
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTest() {
    currentScreen = null;
    clock = DateTime.now;
    sink = null;
    _sessionId = null;
    _seq = 0;
    for (final capture in _outstandingApi.toList(growable: false)) {
      abandonApiCapture(capture);
    }
    _installing = null;
  }

  static bool _isFailureEvent(ObsEvent event) {
    if (event is ObsApiEvent) {
      final status = event.statusCode;
      return status == null || status >= 400;
    }
    return false;
  }

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
