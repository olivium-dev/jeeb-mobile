import 'dart:convert';

import 'package:flutter/material.dart';

import '../model/obs_event.dart';
import '../secret_redactor.dart';

abstract final class ObsOverlayEventFormatter {
  static IconData iconFor(ObsEventType type) => switch (type) {
        ObsEventType.screen => Icons.map_outlined,
        ObsEventType.api => Icons.cloud_outlined,
        ObsEventType.notification => Icons.notifications_outlined,
        ObsEventType.interaction => Icons.touch_app_outlined,
      };

  static String labelFor(ObsEventType type) => switch (type) {
        ObsEventType.screen => 'Screen',
        ObsEventType.api => 'API',
        ObsEventType.notification => 'Push',
        ObsEventType.interaction => 'Interaction',
      };

  static String summaryFor(ObsEvent event) {
    final raw = switch (event) {
      final ObsScreenEvent e => '${e.action} → ${e.route ?? e.name ?? '?'}',
      final ObsApiEvent e =>
        '${e.method} ${e.path} · ${e.statusCode ?? 'ERR'} '
            '· ${e.durationMs}ms',
      final ObsNotificationEvent e =>
        '${e.channel}/${e.mode} · ${e.category}',
      final ObsInteractionEvent e => e.targetLabel == null
          ? e.gesture
          : '${e.gesture} · ${e.targetLabel}',
    };
    return SecretRedactor.redactString(raw);
  }

  static String timeLabel(ObsEvent event) {
    final t = event.timestampUtc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.'
        '${three(t.millisecond)}';
  }

  static String prettyPayload(ObsEvent event) {
    final json = event.toJson();
    json['payload'] = SecretRedactor.redactBody(json['payload'], full: true);
    const encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(json);
    } catch (_) {
      return json.toString();
    }
  }
}
