import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';

void main() {
  final ts = DateTime.utc(2026, 7, 18, 10, 30, 16, 1);

  group('ObsEvent.toJson — common envelope', () {
    test('wraps type/id/sessionId/seq/ts + the subtype payload', () {
      final event = ObsScreenEvent(
        id: '1-screen',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 1,
        action: 'push',
        route: '/orders/:id',
        name: 'order-detail',
      );
      final json = event.toJson();
      expect(json['v'], ObsEvent.schemaVersion);
      expect(json['type'], 'screen');
      expect(json['id'], '1-screen');
      expect(json['sessionId'], 's-1');
      expect(json['seq'], 1);
      expect(json['ts'], ts.toIso8601String());
      expect(json['payload'], isA<Map<String, Object?>>());
    });
  });

  group('ObsScreenEvent', () {
    test('payload carries action/route/name/params; prev omitted when null',
        () {
      final event = ObsScreenEvent(
        id: '1-screen',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 1,
        action: 'push',
        route: '/orders/:id',
        name: 'order-detail',
        params: const {'id': 'd-42'},
      );
      final payload = event.toPayloadJson();
      expect(payload['action'], 'push');
      expect(payload['route'], '/orders/:id');
      expect(payload['name'], 'order-detail');
      expect(payload['params'], {'id': 'd-42'});
      expect(payload.containsKey('prev'), isFalse);
    });

    test('prev is included when a previous route is known', () {
      final event = ObsScreenEvent(
        id: '2-screen',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 2,
        action: 'pop',
        route: '/home',
        name: 'home',
        previousRoute: '/orders/:id',
      );
      expect(event.toPayloadJson()['prev'], '/orders/:id');
    });

    test('type is screen', () {
      final event = ObsScreenEvent(
        id: '1-screen',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 1,
        action: 'push',
        route: '/x',
        name: 'x',
      );
      expect(event.type, ObsEventType.screen);
    });
  });

  group('ObsApiEvent', () {
    test('payload uses the short api key set (m/path/status/ms/…)', () {
      final event = ObsApiEvent(
        id: '3-api',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 3,
        method: 'GET',
        path: '/v1/requests',
        statusCode: 200,
        durationMs: 88,
        requestHeaders: const {'authorization': 'tok:1a2b3c4d~9f21'},
        responseBody: const {'items': 2},
        correlationId: 'corr-9',
        screen: '/',
      );
      final payload = event.toPayloadJson();
      expect(payload['m'], 'GET');
      expect(payload['path'], '/v1/requests');
      expect(payload['status'], 200);
      expect(payload['ms'], 88);
      expect(payload['reqHeaders'], {'authorization': 'tok:1a2b3c4d~9f21'});
      expect(payload['respBody'], {'items': 2});
      expect(payload['reqId'], 'corr-9');
      expect(payload['screen'], '/');
      expect(payload.containsKey('errorType'), isFalse);
      expect(payload.containsKey('errorMessage'), isFalse);
    });

    test('a transport failure records a null status + error fields', () {
      final event = ObsApiEvent(
        id: '4-api',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 4,
        method: 'POST',
        path: '/v1/orders',
        statusCode: null,
        durationMs: 5000,
        errorType: 'connectionTimeout',
        errorMessage: 'timed out',
      );
      final payload = event.toPayloadJson();
      expect(payload['status'], isNull);
      expect(payload['errorType'], 'connectionTimeout');
      expect(payload['errorMessage'], 'timed out');
    });

    test('type is api', () {
      final event = ObsApiEvent(
        id: '3-api',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 3,
        method: 'GET',
        path: '/x',
        statusCode: 200,
        durationMs: 1,
      );
      expect(event.type, ObsEventType.api);
    });
  });

  group('ObsNotificationEvent', () {
    test('payload carries channel/mode/messageId/category + optional fields',
        () {
      final event = ObsNotificationEvent(
        id: '5-notification',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 5,
        channel: 'fcm',
        mode: 'foreground',
        messageId: 'm-1',
        category: 'delivery',
        title: 'Title',
        deepLink: '/orders/d-1',
        data: const {'orderId': 'd-1'},
      );
      final payload = event.toPayloadJson();
      expect(payload['channel'], 'fcm');
      expect(payload['mode'], 'foreground');
      expect(payload['messageId'], 'm-1');
      expect(payload['category'], 'delivery');
      expect(payload['title'], 'Title');
      expect(payload['deepLink'], '/orders/d-1');
      expect(payload['data'], {'orderId': 'd-1'});
      expect(payload.containsKey('body'), isFalse);
    });

    test('type is notification', () {
      final event = ObsNotificationEvent(
        id: '5-notification',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 5,
        channel: 'fcm',
        mode: 'opened',
        messageId: 'm-1',
        category: 'delivery',
      );
      expect(event.type, ObsEventType.notification);
    });
  });

  group('ObsInteractionEvent', () {
    test('payload carries gesture + coarse position; optional fields omitted '
        'when null', () {
      final event = ObsInteractionEvent(
        id: '6-interaction',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 6,
        gesture: 'tap',
        targetId: 'submit-button',
        targetLabel: 'Submit',
        screen: '/checkout',
        dx: 120,
        dy: 480,
      );
      final payload = event.toPayloadJson();
      expect(payload['gesture'], 'tap');
      expect(payload['targetId'], 'submit-button');
      expect(payload['targetLabel'], 'Submit');
      expect(payload['screen'], '/checkout');
      expect(payload['dx'], 120);
      expect(payload['dy'], 480);
      expect(payload.containsKey('valuePreview'), isFalse);
    });

    test('a text_submit gesture never carries raw characters — preview is '
        'redacted/length-only by the CALLER; the model just stores it', () {
      final event = ObsInteractionEvent(
        id: '7-interaction',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 7,
        gesture: 'text_submit',
        valuePreview: '<redacted>',
      );
      expect(event.toPayloadJson()['valuePreview'], '<redacted>');
    });

    test('type is interaction', () {
      final event = ObsInteractionEvent(
        id: '6-interaction',
        sessionId: 's-1',
        timestampUtc: ts,
        seq: 6,
        gesture: 'tap',
      );
      expect(event.type, ObsEventType.interaction);
    });
  });

  group('exhaustive switch over ObsEvent (sealed contract)', () {
    test('every subtype is reachable in a switch with no default branch', () {
      String describe(ObsEvent event) => switch (event) {
            ObsScreenEvent() => 'screen',
            ObsApiEvent() => 'api',
            ObsNotificationEvent() => 'notification',
            ObsInteractionEvent() => 'interaction',
          };

      final screen = ObsScreenEvent(
        id: '1-screen',
        sessionId: 's',
        timestampUtc: ts,
        seq: 1,
        action: 'push',
        route: '/x',
        name: 'x',
      );
      final api = ObsApiEvent(
        id: '2-api',
        sessionId: 's',
        timestampUtc: ts,
        seq: 2,
        method: 'GET',
        path: '/x',
        statusCode: 200,
        durationMs: 1,
      );
      final notification = ObsNotificationEvent(
        id: '3-notification',
        sessionId: 's',
        timestampUtc: ts,
        seq: 3,
        channel: 'fcm',
        mode: 'opened',
        messageId: 'm',
        category: 'c',
      );
      final interaction = ObsInteractionEvent(
        id: '4-interaction',
        sessionId: 's',
        timestampUtc: ts,
        seq: 4,
        gesture: 'tap',
      );

      expect(describe(screen), 'screen');
      expect(describe(api), 'api');
      expect(describe(notification), 'notification');
      expect(describe(interaction), 'interaction');
    });
  });
}
