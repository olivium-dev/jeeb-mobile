import 'dart:convert';

import 'package:flutter/material.dart';

import '../model/obs_event.dart';
import '../secret_redactor.dart';

/// Pure text/icon formatting for the live overlay — kept OUT of widget
/// `build()` methods so every widget stays small (flutter-function-20-line
/// -limit) and so the formatting rules have one place to be unit-tested.
///
/// Every event reaching this UI has ALREADY been redacted at capture time
/// (architecture contract §7 rule 1) and again by `ObsFileWriter`'s
/// defensive second scrub before it ever touches disk. This class applies
/// that SAME defense-in-depth pass — `SecretRedactor` — to whatever it
/// renders, so a capturer bug can never surface a raw secret on-screen
/// either, even though this overlay sits upstream of the file writer.
abstract final class ObsOverlayEventFormatter {
  /// Leading icon per signal type.
  static IconData iconFor(ObsEventType type) => switch (type) {
        ObsEventType.screen => Icons.map_outlined,
        ObsEventType.api => Icons.cloud_outlined,
        ObsEventType.notification => Icons.notifications_outlined,
        ObsEventType.interaction => Icons.touch_app_outlined,
      };

  /// Short filter-chip / section label per signal type.
  static String labelFor(ObsEventType type) => switch (type) {
        ObsEventType.screen => 'Screen',
        ObsEventType.api => 'API',
        ObsEventType.notification => 'Push',
        ObsEventType.interaction => 'Interaction',
      };

  /// One-line summary for a live-list row, redacted defensively (see class
  /// doc) even though every field it reads is already redacted upstream.
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

  /// `HH:mm:ss.SSS` in local time, for the live list's timestamp column.
  static String timeLabel(ObsEvent event) {
    final t = event.timestampUtc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.'
        '${three(t.millisecond)}';
  }

  /// Pretty-printed JSON for the tap-to-expand raw payload view. Re-scrubs
  /// the payload via [SecretRedactor.redactBody] first — the SAME defensive
  /// pass `ObsFileWriter` applies before a line ever reaches disk — so the
  /// most detailed view this overlay offers is also the most defended.
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
