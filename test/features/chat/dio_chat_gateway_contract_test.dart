/// Chat HTTP contract — pins the client to the routes the gateway ACTUALLY
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
      expect(data['body'], isA<String>());
      expect(data['body'], 'Deliver a parcel from Hamra to Verdun');
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

      expect(rec.count, 0);
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
      expect(OrderComposeCoordinator.composeSentinel,
          kComposeConversationSentinel);
      expect(kComposeConversationSentinel, 'new');
    });
  });

  group('DioChatGateway — participant-scoped Idempotency-Key (BUG-13)', () {
    Future<String?> keyFor(
      String currentUserId,
      DeliveryChatMessage message,
    ) async {
      final rec = _RecordingDio(body: <String, dynamic>{'id': 'srv-1'});
      final gateway =
          DioChatGateway(dio: rec.dio, currentUserId: currentUserId);
      await gateway.send(realId, message);
      return rec.single.headers['Idempotency-Key'] as String?;
    }

    test('two different senders on the SAME conversation+message index emit '
        'DIFFERENT keys (no cross-participant idempotency replay)', () async {
      const localId = 'msg-$realId-0';
      final customerKey = await keyFor('user-customer', _textDraft(localId));
      final jeeberKey = await keyFor('user-jeeber', _textDraft(localId));

      expect(customerKey, isNotNull);
      expect(jeeberKey, isNotNull);
      expect(customerKey, isNot(jeeberKey),
          reason: 'distinct senders must not share an idempotency key');
      expect(customerKey, contains('user-customer'));
      expect(jeeberKey, contains('user-jeeber'));
    });

    test('the SAME sender + message yields a STABLE key (idempotent on retry)',
        () async {
      final message = _textDraft('msg-$realId-2');
      final first = await keyFor('user-customer', message);
      final second = await keyFor('user-customer', message);
      expect(first, isNotNull);
      expect(first, second);
    });

    test('an unauthenticated sender (empty id) still scopes the key to a '
        'stable per-session token, distinct from an authenticated peer',
        () async {
      final rec = _RecordingDio(body: <String, dynamic>{'id': 'srv-1'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: '');
      final message = _textDraft('msg-$realId-0');
      await gateway.send(realId, message);
      await gateway.send(realId, message);

      final k1 = rec.requests[0].headers['Idempotency-Key'] as String?;
      final k2 = rec.requests[1].headers['Idempotency-Key'] as String?;
      expect(k1, isNotNull);
      expect(k1, k2, reason: 'retries within a session must stay idempotent');
      expect(k1, isNot('msg-$realId-0'));
      final peerKey = await keyFor('user-jeeber', _textDraft('msg-$realId-0'));
      expect(k1, isNot(peerKey));
    });
  });

  group('DioChatGateway.loadPhase — no guaranteed-404 conversationId read '
      '(BUG-14)', () {
    test('when the resolved correlation key IS the conversation id, loadPhase '
        'issues NO HTTP and degrades to broadcasting (the jeeber chat-load '
        '404 ×2)', () async {
      const conversationId = 'conv-c134f5ed';
      final rec = _RecordingDio(body: <String, dynamic>{'phase': 'accepted'});
      final gateway = DioChatGateway(
        dio: rec.dio,
        currentUserId: 'u-jeeber',
        conversationCorrelationKey: conversationId,
      );

      final phase = await gateway.loadPhase(conversationId);

      expect(rec.count, 0,
          reason: 'a conversationId-keyed correlation read 404s — skip it '
              'instead of emitting a Core-Flow 404');
      expect(phase, ConversationPhase.broadcasting);
    });

    test('a DISTINCT resolved correlation key (== request id) still issues the '
        'phase read (customer path unchanged)', () async {
      const conversationId = 'conv-c134f5ed';
      const requestId = 'req-7f7287d2';
      final rec = _RecordingDio(body: <String, dynamic>{'phase': 'accepted'});
      final gateway = DioChatGateway(
        dio: rec.dio,
        currentUserId: 'u-customer',
        conversationCorrelationKey: requestId,
      );

      final phase = await gateway.loadPhase(conversationId);

      expect(rec.count, 1);
      expect(rec.single.path, '/v1/conversations');
      expect(rec.single.queryParameters['correlationKey'], requestId);
      expect(phase, ConversationPhase.accepted);
    });
  });

  group('DioChatGateway — P4/P5 image attachment wire contract', () {
    DeliveryChatMessage imageDraft(String ref) => DeliveryChatMessage.image(
          id: 'm-img-1',
          author: ChatAuthor.me,
          sentAt: DateTime.utc(2026, 1, 1),
          status: MessageStatus.sending,
          url: ref,
          caption: 'here it is',
        );

    test('send of an image posts {"kind":"image","payload":{url,caption}} with '
        'the participant-scoped Idempotency-Key', () async {
      final rec = _RecordingDio(body: <String, dynamic>{'id': 'srv-img'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      await gateway.send(realId, imageDraft('chat_attachment/aa.jpg'));

      expect(rec.count, 1);
      expect(rec.single.path, '/v1/conversations/$realId/messages');
      final data = rec.single.data as Map<String, Object?>;
      expect(data['kind'], 'image');
      expect(data['payload'], <String, Object?>{
        'url': 'chat_attachment/aa.jpg',
        'caption': 'here it is',
      });
      expect(data.containsKey('bytes'), isFalse);
      expect(
        rec.single.headers['Idempotency-Key'],
        'm-img-1-u-u-1',
        reason: 'the key stays scoped to the authenticated sender',
      );
    });

    test('the chat surface never emits kind:"photo" once a CDN ref exists',
        () async {
      final rec = _RecordingDio(body: <String, dynamic>{'id': 'srv-img'});
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      await gateway.send(realId, imageDraft('chat_attachment/bb.jpg'));

      final data = rec.single.data as Map<String, Object?>;
      expect(
        data['kind'],
        isNot('photo'),
        reason: 'the pre-fix build posted a bytes-less `photo`, which persisted '
            'an invisible empty bubble on the peer',
      );
    });

    test('a legacy wire `photo` decodes to an `image` placeholder, NOT an '
        'invisible empty text bubble', () async {
      final rec = _RecordingDio(
        body: <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{
              'message_id': 'srv-legacy',
              'author_id': 'u-peer',
              'kind': 'photo',
              'payload': <String, dynamic>{'caption': ''},
              'created_at': '2026-06-30T10:31:00Z',
            },
          ],
        },
      );
      final gateway = DioChatGateway(dio: rec.dio, currentUserId: 'u-1');

      final history = await gateway.loadHistory(realId);

      expect(history, hasLength(1));
      final m = history.single;
      expect(
        m.kind,
        MessageKind.image,
        reason: 'rows the broken build already persisted must stay VISIBLE as '
            'an unavailable-image placeholder, not decode to an empty text '
            'bubble that renders as nothing',
      );
      expect(m.imageUrl, '');
      expect(m.text, '');
    });
  });
}
