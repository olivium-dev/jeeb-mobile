/// The unified, ordered event model for the Jeeb session-trace tool.
///
/// Every capturer (screen, api, notification, interaction) records ONE of the
/// four [ObsEvent] subtypes below through `Observability.instance`. Together
/// they serialize to a single per-session JSONL file (see `ObsFileWriter`):
/// one line per event, `type` discriminated, in a stable TOTAL ORDER via
/// [ObsEvent.seq] — see `docs` / the architecture contract for the full
/// rationale. This file has ZERO dependencies beyond `dart:core` so the
/// model can be imported anywhere (capturers, writer, dev UI, tests) without
/// dragging in Flutter, dio, or platform channels.
library;

/// The four signal types; serialized as the JSONL `type` discriminator.
enum ObsEventType {
  screen,
  api,
  notification,
  interaction,
}

/// Base class for every recorded session-trace event. Sealed so the writer,
/// exporter, and dev UI can switch exhaustively over the four subtypes.
sealed class ObsEvent {
  const ObsEvent({
    required this.id,
    required this.sessionId,
    required this.timestampUtc,
    required this.seq,
  });

  /// Unique per-event id. Convention: `'<seq>-<type>'` (e.g. `'42-api'`).
  final String id;

  /// The session (app run) this event belongs to; one JSONL file per session.
  final String sessionId;

  /// Capture time — ALWAYS UTC (callers pass Observability.instance.clock()).
  final DateTime timestampUtc;

  /// Monotonic per-session sequence number. Guarantees a stable TOTAL ORDER
  /// across all four signals even when timestamps collide (assigned by
  /// Observability.nextSeq()).
  final int seq;

  /// The signal-type discriminator.
  ObsEventType get type;

  /// The type-specific payload (already redacted at capture time).
  Map<String, Object?> toPayloadJson();

  /// One complete JSONL record: common envelope + `payload`.
  Map<String, Object?> toJson() => <String, Object?>{
        'v': schemaVersion,
        'type': type.name,
        'id': id,
        'sessionId': sessionId,
        'seq': seq,
        'ts': timestampUtc.toIso8601String(),
        'payload': toPayloadJson(),
      };

  /// Bump on any breaking payload change; written into every record + header.
  static const int schemaVersion = 1;
}

/// A navigation transition (push / pop / replace) captured by
/// `ObsNavObserver`. Query strings are never included — only the route
/// PATTERN, its name, its (redacted) path params, and the previous route.
final class ObsScreenEvent extends ObsEvent {
  const ObsScreenEvent({
    required super.id,
    required super.sessionId,
    required super.timestampUtc,
    required super.seq,
    required this.action,
    required this.route,
    required this.name,
    this.previousRoute,
    this.params = const <String, Object?>{},
  });

  /// 'push' | 'pop' | 'replace'.
  final String action;

  /// Route path PATTERN, query-stripped: '/orders/:id'.
  final String? route;

  /// go_router route name: 'delivery-detail'.
  final String? name;

  /// Route came-from (push/replace) or left (pop).
  final String? previousRoute;

  /// REDACTED path params.
  final Map<String, Object?> params;

  @override
  ObsEventType get type => ObsEventType.screen;

  @override
  Map<String, Object?> toPayloadJson() => <String, Object?>{
        'action': action,
        'route': route,
        'name': name,
        'prev': ?previousRoute,
        'params': params,
      };
}

/// One HTTP round-trip captured by `ObsDioInterceptor`. Every header/body
/// field is expected to already be redacted (via `SecretRedactor`) by the
/// time this event is constructed — see the architecture contract §7.
final class ObsApiEvent extends ObsEvent {
  const ObsApiEvent({
    required super.id,
    required super.sessionId,
    required super.timestampUtc,
    required super.seq,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    this.requestHeaders = const <String, Object?>{},
    this.requestBody,
    this.responseHeaders = const <String, Object?>{},
    this.responseBody,
    this.correlationId,
    this.screen,
    this.errorType,
    this.errorMessage,
  });

  /// 'GET' (uppercased).
  final String method;

  /// Query-stripped path.
  final String path;

  /// Null on transport failure/timeout.
  final int? statusCode;

  final int durationMs;

  /// REDACTED.
  final Map<String, Object?> requestHeaders;

  /// REDACTED (Map/List/String/num/null).
  final Object? requestBody;

  /// REDACTED.
  final Map<String, Object?> responseHeaders;

  /// REDACTED, truncated to config.maxBodyBytes.
  final Object? responseBody;

  /// x-correlation-id / x-request-id (opaque, not a secret).
  final String? correlationId;

  /// Active route at CALL time.
  final String? screen;

  /// DioExceptionType.name on failure, else null.
  final String? errorType;

  /// REDACTED short message, no secrets.
  final String? errorMessage;

  @override
  ObsEventType get type => ObsEventType.api;

  @override
  Map<String, Object?> toPayloadJson() => <String, Object?>{
        'm': method,
        'path': path,
        'status': statusCode,
        'ms': durationMs,
        'reqHeaders': requestHeaders,
        'reqBody': requestBody,
        'respHeaders': responseHeaders,
        'respBody': responseBody,
        'reqId': ?correlationId,
        'screen': ?screen,
        'errorType': ?errorType,
        'errorMessage': ?errorMessage,
      };
}

/// A push-notification lifecycle moment (received / opened) captured by
/// `ObsNotificationRecorder`. The FCM `data` map often carries tokens/ids, so
/// [data] MUST already be redacted by the time this event is constructed.
final class ObsNotificationEvent extends ObsEvent {
  const ObsNotificationEvent({
    required super.id,
    required super.sessionId,
    required super.timestampUtc,
    required super.seq,
    required this.channel,
    required this.mode,
    required this.messageId,
    required this.category,
    this.title,
    this.body,
    this.deepLink,
    this.data = const <String, Object?>{},
  });

  /// 'fcm' | 'local'.
  final String channel;

  /// 'foreground' | 'background' | 'opened'.
  final String mode;

  final String messageId;

  /// NotificationCategory.name.
  final String category;

  /// REDACTED.
  final String? title;

  /// REDACTED.
  final String? body;

  /// Resolved route on open, else null.
  final String? deepLink;

  /// REDACTED FCM data map.
  final Map<String, Object?> data;

  @override
  ObsEventType get type => ObsEventType.notification;

  @override
  Map<String, Object?> toPayloadJson() => <String, Object?>{
        'channel': channel,
        'mode': mode,
        'messageId': messageId,
        'category': category,
        'title': ?title,
        'body': ?body,
        'deepLink': ?deepLink,
        'data': data,
      };
}

/// A user interaction (tap / drag / text focus / text submit) captured by
/// `ObsInteractionObserver` via the always-published semantics tree.
/// Keystrokes and raw text-field contents are NEVER captured — [valuePreview]
/// is a redacted/length-only summary at most, never raw characters.
final class ObsInteractionEvent extends ObsEvent {
  const ObsInteractionEvent({
    required super.id,
    required super.sessionId,
    required super.timestampUtc,
    required super.seq,
    required this.gesture,
    this.targetId,
    this.targetLabel,
    this.screen,
    this.dx,
    this.dy,
    this.valuePreview,
  });

  /// 'tap' | 'double_tap' | 'long_press' | 'drag' | 'text_focus' | 'text_submit'.
  final String gesture;

  /// Semantics identifier if resolvable.
  final String? targetId;

  /// Semantics label, REDACTED.
  final String? targetLabel;

  /// Active route.
  final String? screen;

  /// Coarse pointer position, rounded to int; null for non-pointer gestures.
  final int? dx;
  final int? dy;

  /// TEXT ONLY: `'<redacted>'` by default; never raw chars for sensitive
  /// fields.
  final String? valuePreview;

  @override
  ObsEventType get type => ObsEventType.interaction;

  @override
  Map<String, Object?> toPayloadJson() => <String, Object?>{
        'gesture': gesture,
        'targetId': ?targetId,
        'targetLabel': ?targetLabel,
        'screen': ?screen,
        'dx': ?dx,
        'dy': ?dy,
        'valuePreview': ?valuePreview,
      };
}
