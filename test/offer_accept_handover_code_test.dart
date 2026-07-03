// G4 (sprint-009 P0) — "the regular user is not receiving the OTP code".
//
// ROOT CAUSE #1 pinned here: the accept response carries `handoverCode` (mock
// `POST /v1/offers/:offerId/accept` → `{ offer, handoverCode, conversationId,
// conversationPhase }`) and the pre-fix `_parseAcceptResult` DISCARDED it —
// `OfferAcceptResult` had no field for it, so the one wire moment the customer
// was given their code threw it away. These tests prove BOTH accept paths
// (offer-review sheet → DioOffersRepository, chat Accept → DioChatGateway):
//   1. retain `handoverCode` on the returned OfferAcceptResult, and
//   2. persist it into the HandoverCodeStore keyed by deliveryId, and
//   3. never leak the raw code through the diag event stream.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/client_offers/data/dio_offers_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/handover_code_store.dart';

/// Minimal recording Dio: scripts the next POST body.
class _RecordingDio extends Fake implements Dio {
  final List<String> postPaths = [];
  Map<String, dynamic> nextPostData = const {};

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    postPaths.add(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: nextPostData as T,
    );
  }
}

class _MemoryStore implements HandoverCodeStore {
  final Map<String, String> rows = {};

  @override
  Future<void> save({required String deliveryId, required String code}) async {
    rows[deliveryId] = code;
  }

  @override
  Future<String?> read({required String deliveryId}) async => rows[deliveryId];

  @override
  Future<void> clear({required String deliveryId}) async {
    rows.remove(deliveryId);
  }
}

void main() {
  group('DioOffersRepository accept — handoverCode retention (G4)', () {
    test('parse retains handoverCode alongside deliveryId/conversationId',
        () async {
      final dio = _RecordingDio()
        ..nextPostData = {
          'offer': {'id': 'off-1', 'status': 'accepted'},
          'deliveryId': 'DLV-77',
          'conversationId': 'conv-1',
          'conversationPhase': 'accepted',
          'handoverCode': '1234',
        };
      final repo = DioOffersRepository(dio);

      final result =
          await repo.acceptOffer(requestId: 'req-1', offerId: 'off-1');

      expect(result.deliveryId, 'DLV-77');
      expect(result.conversationId, 'conv-1');
      expect(result.handoverCode, '1234',
          reason: 'the pre-fix parser DISCARDED handoverCode — the single '
              'wire moment the customer receives their door code');
    });

    test('snake_case handover_code is accepted too', () async {
      final dio = _RecordingDio()
        ..nextPostData = {
          'delivery_id': 'DLV-77',
          'handover_code': '4321',
        };
      final repo = DioOffersRepository(dio);

      final result =
          await repo.acceptOffer(requestId: 'req-1', offerId: 'off-1');

      expect(result.handoverCode, '4321');
    });

    test('missing/blank handoverCode maps to null (no crash, no store write)',
        () async {
      final store = _MemoryStore();
      final dio = _RecordingDio()
        ..nextPostData = {'deliveryId': 'DLV-77', 'handoverCode': '  '};
      final repo = DioOffersRepository(dio, handoverCodeStore: store);

      final result =
          await repo.acceptOffer(requestId: 'req-1', offerId: 'off-1');

      expect(result.handoverCode, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(store.rows, isEmpty);
    });

    test('accept persists the code into the HandoverCodeStore by deliveryId',
        () async {
      final store = _MemoryStore();
      final dio = _RecordingDio()
        ..nextPostData = {'deliveryId': 'DLV-77', 'handoverCode': '1234'};
      final repo = DioOffersRepository(dio, handoverCodeStore: store);

      await repo.acceptOffer(requestId: 'req-1', offerId: 'off-1');
      // The store write is fire-and-forget — flush the microtask queue.
      await Future<void>.delayed(Duration.zero);

      expect(store.rows['DLV-77'], '1234');
    });
  });

  group('DioChatGateway accept — handoverCode retention (G4)', () {
    test('chat accept retains + persists the handoverCode', () async {
      final store = _MemoryStore();
      final dio = _RecordingDio()
        ..nextPostData = {'deliveryId': 'DLV-88', 'handoverCode': '5678'};
      final gateway = DioChatGateway(
        dio: dio,
        currentUserId: 'user-1',
        handoverCodeStore: store,
      );

      final result = await gateway.acceptOffer('conv-1', 'off-9');
      await Future<void>.delayed(Duration.zero);

      expect(result.deliveryId, 'DLV-88');
      expect(result.handoverCode, '5678');
      expect(store.rows['DLV-88'], '5678');
      await gateway.dispose();
    });

    test('chat accept without a code stays null and writes nothing', () async {
      final store = _MemoryStore();
      final dio = _RecordingDio()..nextPostData = {'deliveryId': 'DLV-88'};
      final gateway = DioChatGateway(
        dio: dio,
        currentUserId: 'user-1',
        handoverCodeStore: store,
      );

      final result = await gateway.acceptOffer('conv-1', 'off-9');
      await Future<void>.delayed(Duration.zero);

      expect(result.handoverCode, isNull);
      expect(store.rows, isEmpty);
      await gateway.dispose();
    });
  });

  group('diag redaction — the code never reaches a diag line (G4)', () {
    tearDown(Diag.resetForTest);

    test('Diag.event with a handoverCode payload emits NO raw digits', () {
      final lines = <String>[];
      Diag.enabledOverride = true;
      Diag.sink = lines.add;
      Diag.clock = () => DateTime.utc(2026, 7, 3);

      Diag.event('offer_accept_result', <String, Object?>{
        'offerId': 'off-1',
        'deliveryId': 'DLV-77',
        'handoverCode': '1234',
        'nested': <String, Object?>{'handover_code': '5678'},
      });

      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line, contains('offer_accept_result'));
      expect(line, isNot(contains('1234')),
          reason: 'the handover code must NEVER appear in diag output');
      expect(line, isNot(contains('5678')));
      // Correlation survives: the key is present, masked.
      expect(line, contains('handoverCode'));
    });
  });
}
