import '../../../notifications/domain/notification_message.dart';
import '../observability.dart';
import '../secret_redactor.dart';

/// NOTIFICATION capture — the Jeeb session-trace tool's Module 3
/// (architecture contract §4).
///
/// Turns a [NotificationMessage] into a redacted `ObsNotificationEvent` and
/// emits it through [Observability.instance]. Pure static hook helpers —
/// deliberately NOT a listener wired into any stream itself. The existing
/// push stack already owns the exact chokepoints where a `Diag.event(...)`
/// call fires for the lighter `[jeeb-diag]` stream (`_onForeground` in
/// `PushNotificationHandler`, `_route` in `NotificationDispatcher`); this
/// class is called ADDITIVELY from immediately beside those calls by the
/// integration step. Dispatch/routing/badge/history behavior is completely
/// unchanged by wiring this in — these calls only observe.
///
/// This file never imports `firebase_messaging` or
/// `flutter_local_notifications` — it depends only on the transport-agnostic
/// [NotificationMessage] domain model, exactly like the rest of the
/// notifications stack above the transport layer.
///
/// ## Exact call sites integration wires (all additive one-liners, each
/// guarded `if (kObsCompiledIn)` — see architecture contract §6 W3a/W3b):
///
///  * `lib/core/notifications/application/push_notification_handler.dart`,
///    inside `_onForeground`, right after the existing
///    `Diag.event('push_received', …)` call:
///    ```dart
///    if (kObsCompiledIn) {
///      ObsNotificationRecorder.recordReceived(message, mode: 'foreground');
///    }
///    ```
///  * `lib/core/notifications/application/notification_dispatcher.dart`,
///    inside `_route`, right after the existing
///    `Diag.event('push_tapped', …)` call (`path` is the already-resolved
///    `deepLinkForMessage(message)` result):
///    ```dart
///    if (kObsCompiledIn) {
///      ObsNotificationRecorder.recordOpened(message, deepLink: path);
///    }
///    ```
///  * `lib/core/notifications/data/firebase_messaging_transport.dart`, inside
///    `_handleForeground`, right after the `_localNotifications.show(...)`
///    call — the moment the Android heads-up banner is actually rendered
///    (FCM does not auto-display foreground messages; see that class's
///    doc). `domain` is the already-built [NotificationMessage] in scope
///    there:
///    ```dart
///    if (kObsCompiledIn) {
///      ObsNotificationRecorder.recordShown(domain);
///    }
///    ```
///
/// Every method is a total, non-throwing no-op whenever
/// `Observability.instance.recording` is false (tool not compiled in, or
/// runtime-disabled) — the same hot-path guard every other capturer opens
/// with, checked BEFORE any redaction work runs.
abstract final class ObsNotificationRecorder {
  /// Records a RECEIVED notification — the foreground `firebase_messaging`
  /// `onMessage` chokepoint (`PushNotificationHandler._onForeground`).
  ///
  /// [mode] is caller-supplied (not hardcoded here) so this same helper
  /// could, in principle, cover a future capture point using a different
  /// mode label; today integration only ever passes `'foreground'` — the
  /// FCM background isolate cannot reach this main-isolate instance (a
  /// documented v1 limitation, architecture contract §9). [channel]
  /// defaults to `'fcm'`, the origin of every RECEIVED message.
  static void recordReceived(
    NotificationMessage message, {
    required String mode,
    String channel = 'fcm',
  }) {
    _emit(message, mode: mode, channel: channel, deepLink: null);
  }

  /// Records a locally-DISPLAYED notification — the
  /// `flutter_local_notifications` `.show(...)` call inside
  /// `FirebaseMessagingTransport._handleForeground` that renders the Android
  /// heads-up banner FCM itself won't draw while the app is foregrounded (on
  /// iOS the OS displays the alert directly with no local-notification hop,
  /// so this is never called there).
  ///
  /// [channel] defaults to `'local'` to distinguish this "actually shown to
  /// the user" moment from the raw `'fcm'` receipt ([recordReceived]) that
  /// precedes it for the very same message; both share `mode: 'foreground'`
  /// since displaying the banner happens while the app is foregrounded.
  static void recordShown(
    NotificationMessage message, {
    String channel = 'local',
  }) {
    _emit(message, mode: 'foreground', channel: channel, deepLink: null);
  }

  /// Records an OPENED notification — a system-tray tap
  /// (`onMessageOpenedApp`) or a foreground-banner tap, both funneled
  /// through `NotificationDispatcher._route`.
  ///
  /// [deepLink] is the resolved go_router path the caller already computed
  /// (`deepLinkForMessage(message)`); pass `null` when the payload had no
  /// actionable destination — the dispatcher still emits a trace event for
  /// the tap itself, it just records no destination.
  static void recordOpened(
    NotificationMessage message, {
    String? deepLink,
    String channel = 'fcm',
  }) {
    _emit(message, mode: 'opened', channel: channel, deepLink: deepLink);
  }

  /// Shared build+record path for the three public entry points above.
  ///
  /// Redacts title/body/data BEFORE handing anything to
  /// [Observability.recordNotification] (architecture contract §7 rule 1 —
  /// capture-time redaction): title/body always go through the hard-floor
  /// `SecretRedactor.redactLabel`; the FCM `data` map (which routinely
  /// carries tokens/ids) goes through `SecretRedactor.redactBody`, gated by
  /// the live `ObservabilityConfig.redactionEnabled` toggle for the
  /// NON-sensitive-key precaution only — sensitive keys and secret-shaped
  /// strings are ALWAYS stripped regardless of that toggle.
  static void _emit(
    NotificationMessage message, {
    required String mode,
    required String channel,
    required String? deepLink,
  }) {
    if (!Observability.instance.recording) return;
    final full = Observability.instance.config.redactionEnabled;
    Observability.instance.recordNotification(
      channel: channel,
      mode: mode,
      messageId: message.id,
      category: message.category.name,
      title: SecretRedactor.redactLabel(message.title),
      body: SecretRedactor.redactLabel(message.body),
      deepLink: deepLink,
      data: _redactData(message.data, full: full),
    );
  }

  /// Redacts the FCM `data` map with a type-safe fallback. `SecretRedactor`
  /// is documented total/null-safe for a Map input, but this local guard
  /// means an unexpected runtime shape degrades to an empty map instead of
  /// ever throwing a cast error into a capturer's hot path.
  static Map<String, Object?> _redactData(
    Map<String, String> data, {
    required bool full,
  }) {
    final redacted = SecretRedactor.redactBody(data, full: full);
    return redacted is Map<String, Object?>
        ? redacted
        : const <String, Object?>{};
  }
}
