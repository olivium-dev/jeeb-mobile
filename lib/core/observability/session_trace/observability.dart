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

final class Observability {
  Observability._();

  static final Observability instance = Observability._();

  static const String _unknownSessionId = 'unknown-session';

  String? _sessionId;
  int _seq = 0;

  ObservabilityConfig get config => ObservabilityConfig.instance;

  bool get recording => kObsCompiledIn && config.enabled;

  String? get sessionId => _sessionId;

  String? currentScreen;

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  @visibleForTesting
  ObservabilitySink? sink;

  int nextSeq() => ++_seq;

  String newEventId(ObsEventType type, int seq) => '$seq-${type.name}';

  void record(ObsEvent event) {
    if (!recording || !config.signalEnabled(event.type)) return;
    final activeSink = sink;
    if (activeSink == null) return;
    try {
      activeSink.add(event, flushNow: _isFailureEvent(event));
    } catch (_) {
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
    }
  }

  Future<void> flush() async {
    final activeSink = sink;
    if (activeSink == null) return;
    try {
      await activeSink.flush();
    } catch (_) {
    }
  }

  @visibleForTesting
  void resetForTest() {
    currentScreen = null;
    clock = DateTime.now;
    sink = null;
    _sessionId = null;
    _seq = 0;
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
