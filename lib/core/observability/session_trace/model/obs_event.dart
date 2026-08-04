library;

enum ObsEventType {
  screen,
  api,
  notification,
  interaction,
}

sealed class ObsEvent {
  const ObsEvent({
    required this.id,
    required this.sessionId,
    required this.timestampUtc,
    required this.seq,
  });

  final String id;

  final String sessionId;

  final DateTime timestampUtc;

  final int seq;

  ObsEventType get type;

  Map<String, Object?> toPayloadJson();

  Map<String, Object?> toJson() => <String, Object?>{
        'v': schemaVersion,
        'type': type.name,
        'id': id,
        'sessionId': sessionId,
        'seq': seq,
        'ts': timestampUtc.toIso8601String(),
        'payload': toPayloadJson(),
      };

  static const int schemaVersion = 1;
}

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

  final String action;

  final String? route;

  final String? name;

  final String? previousRoute;

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

  final String method;

  final String path;

  final int? statusCode;

  final int durationMs;

  final Map<String, Object?> requestHeaders;

  final Object? requestBody;

  final Map<String, Object?> responseHeaders;

  final Object? responseBody;

  final String? correlationId;

  final String? screen;

  final String? errorType;

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

  final String channel;

  final String mode;

  final String messageId;

  final String category;

  final String? title;

  final String? body;

  final String? deepLink;

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

  final String gesture;

  final String? targetId;

  final String? targetLabel;

  final String? screen;

  final int? dx;
  final int? dy;

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
