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

  test('parses an open dispute + its auto-attached evidence (D53)', () async {
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
    expect(d.state, DisputeState.open);
    expect(d.outcome, DisputeOutcome.none);
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

  test('derives a refund outcome from the resolution string (D2)', () async {
    stubGet({
      'id': 'dsp-1',
      'status': 'resolved',
      'resolution': 'refund',
      'refundAmount': 12.5,
      'currency': 'USD',
      'note': 'approved by ops',
    });

    final d = await repo.fetchDispute('dsp-1');

    expect(d.state, DisputeState.resolved);
    expect(d.isResolved, isTrue);
    expect(d.outcome, DisputeOutcome.refund);
    expect(d.refundAmount, 12.5);
    expect(d.currency, 'USD');
    expect(d.note, 'approved by ops');
  });

  test('derives a penalty outcome (D2)', () async {
    stubGet({'id': 'dsp-1', 'status': 'closed', 'resolution': 'penalty'});
    final d = await repo.fetchDispute('dsp-1');
    expect(d.state, DisputeState.resolved);
    expect(d.outcome, DisputeOutcome.penalty);
  });

  test('resolved with no resolution string → other outcome', () async {
    stubGet({'id': 'dsp-1', 'status': 'resolved'});
    final d = await repo.fetchDispute('dsp-1');
    expect(d.outcome, DisputeOutcome.other);
  });

  test('falls back to the path id when the body omits id', () async {
    stubGet({'status': 'open'});
    final d = await repo.fetchDispute('dsp-path');
    expect(d.id, 'dsp-path');
    expect(d.evidence.hasAny, isFalse);
  });

  test('404 → notFound failure', () async {
    stubThrow(DioException(
      requestOptions: RequestOptions(path: ''),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 404,
      ),
      type: DioExceptionType.badResponse,
    ));

    expect(
      () => repo.fetchDispute('missing'),
      throwsA(isA<DisputeStatusRepositoryException>().having(
        (e) => e.failure,
        'failure',
        DisputeStatusFailure.notFound,
      )),
    );
  });

  test('connection timeout → network failure', () async {
    stubThrow(DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.connectionTimeout,
    ));

    expect(
      () => repo.fetchDispute('dsp-1'),
      throwsA(isA<DisputeStatusRepositoryException>().having(
        (e) => e.failure,
        'failure',
        DisputeStatusFailure.network,
      )),
    );
  });

  test('401 → unauthorized failure', () async {
    stubThrow(DioException(
      requestOptions: RequestOptions(path: ''),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    ));

    expect(
      () => repo.fetchDispute('dsp-1'),
      throwsA(isA<DisputeStatusRepositoryException>().having(
        (e) => e.failure,
        'failure',
        DisputeStatusFailure.unauthorized,
      )),
    );
  });
}
