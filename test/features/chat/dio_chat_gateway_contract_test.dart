/// Chat HTTP contract — pins the client to the routes the gateway ACTUALLY
/// mounts and proves the compose sentinel (`new`) never leaves the device.
///
/// Bug 1 (wrong prefix): send + loadHistory + loadPhase previously targeted
/// `/v1/chat/jeeb/conversations/{id}[/messages]` → 404 (that prefix is mounted
/// only for conversation *create*). The gateway serves messages at
/// `/v1/conversations/{id}/messages` and per-conversation reads via
/// `GET /v1/conversations?correlationKey={id}` — see
/// `docs/sprints/sprint-006/order-create-trace.md` §3 (route map) and §6.
///
/// Bug 2 (compose `new` sentinel): the first composed message must NEVER be
/// POSTed to `/v1/conversations/new/messages` (no such route; no conversation
/// exists pre-accept). Its content is carried as the created request's
/// description by `OrderComposeCoordinator`; in-thread sends resume against the
/// SERVER-MINTED conversation id once a Jeeber accepts.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/order_compose_coordinator.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';

/// Records every outbound request and resolves a canned [body]/[status].
class _RecordingDio {
  _RecordingDio({Object? body, int status = 200}) {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(data: body, statusCode: status, requestOptions: options),
          );
        },
      ),
    );
  }

  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];

  int get count => requests.length;
  RequestOptions get single => requests.single;
}

DeliveryChatMessage _textDraft(String id) => DeliveryChatMessage.text(
      id: id,
      author: ChatAuthor.me,
      sentAt: DateTime.utc(2026, 1, 1),
      status: MessageStatus.sending,
      text: 'Deliver a parcel from Hamra to Verdun',
    );

void main() {
  const realId = 'req-real-abc123';

  group('DioChatGateway — gateway-mounted path contract (bug 1)', () {
    test('send POSTs to /v1/conversations/{id}/messages (NOT the chat/jeeb '
        'create prefix)', () async {
      final rec = _RecordingDio(body: <String, dynamic>{'id': 'srv-1'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      await gateway.send(realId, _textDraft('m-1'));

      expect(rec.count, 1);
      expect(rec.single.method, 'POST');
      expect(rec.single.path, '/v1/conversations/$realId/messages');
      // The historical 404 path must be gone.
      expect(rec.single.path, isNot(contains('/v1/chat/jeeb/conversations')));
    });

    test('loadHistory GETs /v1/conversations/{id}/messages', () async {
      final rec = _RecordingDio(body: <String, dynamic>{'items': <dynamic>[]});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      await gateway.loadHistory(realId);

      expect(rec.count, 1);
      expect(rec.single.method, 'GET');
      expect(rec.single.path, '/v1/conversations/$realId/messages');
      expect(rec.single.path, isNot(contains('/v1/chat/jeeb/conversations')));
    });

    test('loadPhase GETs /v1/conversations?correlationKey={id} and parses '
        'phase', () async {
      final rec =
          _RecordingDio(body: <String, dynamic>{'phase': 'accepted'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      final phase = await gateway.loadPhase(realId);

      expect(rec.count, 1);
      expect(rec.single.method, 'GET');
      expect(rec.single.path, '/v1/conversations');
      expect(rec.single.queryParameters['correlationKey'], realId);
      expect(rec.single.path, isNot(contains('/v1/chat/jeeb/conversations')));
      expect(phase, ConversationPhase.accepted);
    });

    test('loadPhase queries the RESOLVED correlation key (== request id), NOT '
        'the conversation id it is opened on (physical-run8 READ 404 #2)',
        () async {
      // Post-accept the screen opens the thread on the conversation id but
      // resolved the request id (correlation_key) during resolution. The chat
      // -service reads the conversation ONLY by its correlation key, so posting
      // the conversation id as `correlationKey` 404s. The gateway must use the
      // host-supplied correlation key for the phase read.
      const conversationId = 'conv-a7b86160';
      const resolvedRequestId = 'req-d9366a8a';
      final rec =
          _RecordingDio(body: <String, dynamic>{'phase': 'broadcasting'});
      final gateway = DioChatGateway(
        dio: rec.dio,
        currentUserId: 'u-1',
        conversationCorrelationKey: resolvedRequestId,
      );

      await gateway.loadPhase(conversationId);

      expect(rec.count, 1);
      expect(rec.single.path, '/v1/conversations');
      expect(rec.single.queryParameters['correlationKey'], resolvedRequestId);
      expect(
        rec.single.queryParameters['correlationKey'],
        isNot(conversationId),
        reason: 'the conversationId-keyed lookup is the run-8 404 shape',
      );
    });

    test('loadPhase falls back to the id argument when no correlation key is '
        'supplied (legacy callers / tests unchanged)', () async {
      final rec =
          _RecordingDio(body: <String, dynamic>{'phase': 'accepted'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      await gateway.loadPhase(realId);

      expect(rec.single.queryParameters['correlationKey'], realId);
    });
  });

  group('DioChatGateway — message payload + parse shape (bug 3)', () {
    test('send serializes a TEXT message body as a String (FROZEN '
        'AppendMessageBody), not an object', () async {
      final rec = _RecordingDio(body: <String, dynamic>{'message_id': 'srv-1'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      await gateway.send(realId, _textDraft('m-1'));

      final data = rec.single.data as Map<String, Object?>;
      expect(data['kind'], 'text');
      // The bug: body was sent as `{text: ...}` (object) → gateway 400
      // ("$.body could not be converted to System.String"). It must be a String.
      expect(data['body'], isA<String>());
      expect(data['body'], 'Deliver a parcel from Hamra to Verdun');
      // `author_id` is stamped from the JWT — the stale `senderId` is gone.
      expect(data.containsKey('senderId'), isFalse);
    });

    test('loadHistory parses the FROZEN snake_case JeebMessageResponse '
        '(message_id / author_id / string body)', () async {
      final rec = _RecordingDio(
        body: <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{
              'message_id': 'srv-9',
              'author_id': 'u-1', // == currentUserId → me
              'kind': 'text',
              'body': 'on my way',
              'created_at': '2026-06-30T10:31:00Z',
            },
          ],
        },
      );
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      final history = await gateway.loadHistory(realId);

      expect(history, hasLength(1));
      expect(history.single.text, 'on my way');
      expect(history.single.author, ChatAuthor.me);
    });
  });

  group('DioChatGateway — compose sentinel never reaches the wire (bug 2)', () {
    test('send to the `new` sentinel issues NO HTTP and locally acks the '
        'message', () async {
      final rec = _RecordingDio(body: <String, dynamic>{'id': 'srv-x'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      final ack = await gateway.send(
        OrderComposeCoordinator.composeSentinel, // 'new'
        _textDraft('m-compose'),
      );

      // Zero requests — the first composed line is NEVER POSTed to `/new`.
      expect(rec.count, 0);
      // Optimistic bubble resolves cleanly (its content is carried as the
      // created request's description).
      expect(ack.status, MessageStatus.sent);
      expect(ack.id, 'm-compose');
    });

    test('send to an empty id issues NO HTTP', () async {
      final rec = _RecordingDio(body: <String, dynamic>{'id': 'srv-x'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      await gateway.send('', _textDraft('m-empty'));

      expect(rec.count, 0);
    });

    test('loadHistory on the sentinel returns empty with NO HTTP', () async {
      final rec = _RecordingDio(body: <String, dynamic>{'items': <dynamic>[]});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      final history =
          await gateway.loadHistory(OrderComposeCoordinator.composeSentinel);

      expect(rec.count, 0);
      expect(history, isEmpty);
    });

    test('loadPhase on the sentinel returns broadcasting with NO HTTP',
        () async {
      final rec = _RecordingDio(body: <String, dynamic>{'phase': 'accepted'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      final phase =
          await gateway.loadPhase(OrderComposeCoordinator.composeSentinel);

      expect(rec.count, 0);
      expect(phase, ConversationPhase.broadcasting);
    });

    test('the canonical sentinel constant is shared across layers', () {
      // The coordinator alias and the domain constant must agree so the
      // create-flow and the HTTP guard can never drift apart.
      expect(OrderComposeCoordinator.composeSentinel,
          kComposeConversationSentinel);
      expect(kComposeConversationSentinel, 'new');
    });
  });
}
