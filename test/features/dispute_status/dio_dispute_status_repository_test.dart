// Unit tests for DioDisputeStatusRepository (JM-065). Locks the compliment-

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/dispute_status/data/dio_dispute_status_repository.dart';
import 'package:jeeb_mobile/features/dispute_status/domain/dispute_status_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio mockDio;
  late DioDisputeStatusRepository repo;

  setUp(() {
    mockDio = _MockDio();
    repo = DioDisputeStatusRepository(mockDio);
  });

  void stubGet(Map<String, dynamic> data, {int statusCode = 200}) {
    when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        data: data,
        statusCode: statusCode,
      ),
    );
  }

  void stubThrow(DioException e) {
    when(() => mockDio.get<Map<String, dynamic>>(any())).thenThrow(e);
  }

  test('normalizes a legacy open dispute to pending', () async {
    stubGet({
      'id': 'dsp-1',
      'status': 'open',
      'reason': 'damaged',
      'comment': 'box was crushed',
      'photos': ['a.jpg', 'b.jpg'],
      'voiceUrl': 'v.m4a',
      'deliveryId': 'req-9',
      'evidence': {
        'chatSnapshotUrl': 'snap.json',
        'chatMessageCount': 8,
        'timeline': [
          {'status': 'picked'},
          {'status': 'in_transit'},
        ],
      },
      'createdAt': '2026-06-18T10:00:00Z',
    });

    final d = await repo.fetchDispute('dsp-1');

    expect(d.id, 'dsp-1');
    expect(d.state, DisputeState.pending);
    expect(d.orderRef, 'req-9');
    expect(d.evidence.reason, 'damaged');
    expect(d.evidence.comment, 'box was crushed');
    expect(d.evidence.photoCount, 2);
    expect(d.evidence.hasVoice, isTrue);
    expect(d.evidence.hasChatSnapshot, isTrue);
    expect(d.evidence.chatMessageCount, 8);
    expect(d.evidence.timelineCount, 2);
    expect(d.evidence.hasAny, isTrue);
  });

  test('normalizes a legacy resolved dispute to fixed', () async {
    stubGet({
      'id': 'dsp-1',
      'status': 'resolved',
      'resolution': 'refund',
      'note': 'approved by ops',
    });

    final d = await repo.fetchDispute('dsp-1');

    expect(d.state, DisputeState.fixed);
    expect(d.isResolved, isTrue);
    expect(d.note, 'approved by ops');
  });

  test('parses closed as a distinct admin-owned terminal state', () async {
    stubGet({'id': 'dsp-1', 'status': 'closed', 'note': 'review complete'});
    final d = await repo.fetchDispute('dsp-1');
    expect(d.state, DisputeState.closed);
    expect(d.note, 'review complete');
  });

  test('parses CaseDetailResponseV2 evidence and audit timeline', () async {
    stubGet({
      'id': 'dsp-1',
      'status': 'fixed',
      'version': 4,
      'photos': ['disputes/box.jpg'],
      'voiceUrl': 'disputes/note.m4a',
      'attachments': ['disputes/box.jpg', 'disputes/note.m4a'],
      'evidence': [
        {
          'source': 'chat_snapshot',
          'status': 'partial',
          'count': 8,
          'marker': 'truncated_max_messages',
          'payload': {'conversationId': 'conversation-1'},
        },
        {
          'source': 'delivery_history',
          'status': 'complete',
          'count': 2,
          'payload': {
            'statusHistory': [
              {'status': 'picked'},
              {'status': 'done'},
            ],
          },
        },
        {
          'source': 'gps_pings',
          'status': 'unavailable',
          'marker': 'route_unavailable',
          'count': 0,
        },
      ],
      'timeline': [
        {
          'eventId': 'event-1',
          'eventType': 'case.created',
          'createdAt': '2026-08-05T09:00:00Z',
          'data': <String, Object?>{},
        },
        {
          'eventId': 'event-2',
          'eventType': 'case.status_changed',
          'createdAt': '2026-08-05T10:00:00Z',
          'data': {'to': 'fixed', 'note': 'Issue corrected'},
        },
      ],
    });
    final d = await repo.fetchDispute('dsp-1');
    expect(d.state, DisputeState.fixed);
    expect(d.version, 4);
    expect(d.conversationRef, 'conversation-1');
    expect(d.evidence.isPartial, isTrue);
    expect(d.evidence.missingSources, ['chat_snapshot', 'gps_pings']);
    expect(d.evidence.chatMessageCount, 8);
    expect(d.evidence.timelineCount, 2);
    expect(d.evidence.photoCount, 1);
    expect(d.evidence.hasVoice, isTrue);
    expect(d.evidence.attachments, hasLength(2));
    expect(d.evidence.attachments.first.objectRef, 'disputes/box.jpg');
    expect(d.statusHistory, hasLength(2));
    expect(d.statusHistory.last.status, DisputeState.fixed);
    expect(d.statusHistory.last.note, 'Issue corrected');
  });

  test('falls back to the path id when the body omits id', () async {
    stubGet({'status': 'open'});
    final d = await repo.fetchDispute('dsp-path');
    expect(d.id, 'dsp-path');
    expect(d.evidence.hasAny, isFalse);
  });

  test('404 → notFound failure', () async {
    stubThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      () => repo.fetchDispute('missing'),
      throwsA(
        isA<DisputeStatusRepositoryException>().having(
          (e) => e.failure,
          'failure',
          DisputeStatusFailure.notFound,
        ),
      ),
    );
  });

  test('connection timeout → network failure', () async {
    stubThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    expect(
      () => repo.fetchDispute('dsp-1'),
      throwsA(
        isA<DisputeStatusRepositoryException>().having(
          (e) => e.failure,
          'failure',
          DisputeStatusFailure.network,
        ),
      ),
    );
  });

  test('401 → unauthorized failure', () async {
    stubThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      () => repo.fetchDispute('dsp-1'),
      throwsA(
        isA<DisputeStatusRepositoryException>().having(
          (e) => e.failure,
          'failure',
          DisputeStatusFailure.unauthorized,
        ),
      ),
    );
  });
}
