import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/chat/data/dio_accepted_conversations_repository.dart';
import 'package:jeeb_mobile/features/chat/domain/accepted_conversation.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _resp(Object? data) => Response<dynamic>(
      data: data,
      requestOptions: RequestOptions(path: '/requests'),
    );

void main() {
  late _MockDio dio;
  late DioAcceptedConversationsRepository repository;

  setUp(() {
    dio = _MockDio();
    repository = DioAcceptedConversationsRepository(dio);
  });

  void stub(Object? data) {
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => _resp(data));
  }

  group('isAcceptedStatus', () {
    test('matches accepted + in-progress synonyms only', () {
      expect(DioAcceptedConversationsRepository.isAcceptedStatus('accepted'), isTrue);
      expect(DioAcceptedConversationsRepository.isAcceptedStatus('ACCEPTED'), isTrue);
      expect(DioAcceptedConversationsRepository.isAcceptedStatus('in_progress'), isTrue);
      expect(DioAcceptedConversationsRepository.isAcceptedStatus('searching'), isFalse);
      expect(DioAcceptedConversationsRepository.isAcceptedStatus('pending'), isFalse);
      expect(DioAcceptedConversationsRepository.isAcceptedStatus(null), isFalse);
    });
  });

  group('fetchAccepted', () {
    test('keeps only accepted rows from the requests envelope', () async {
      stub({
        'items': [
          {'id': 'r1', 'status': 'accepted', 'conversationId': 'c1', 'title': 'Pharmacy run'},
          {'id': 'r2', 'status': 'searching', 'offersCount': 0},
          {'id': 'r3', 'status': 'offers-received', 'offersCount': 2},
        ],
      });

      final result = await repository.fetchAccepted();

      expect(result, hasLength(1));
      expect(result.single.requestId, 'r1');
      expect(result.single.conversationId, 'c1');
      expect(result.single.title, 'Pharmacy run');
      // routeId prefers the request id (== correlationKey).
      expect(result.single.routeId, 'r1');
    });

    test('sends the configured role to the gateway', () async {
      stub({'items': <dynamic>[]});
      final jeeberRepo = DioAcceptedConversationsRepository(dio, role: 'jeeber');

      await jeeberRepo.fetchAccepted();

      final captured = verify(() => dio.get<dynamic>(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .captured
          .last as Map<String, dynamic>;
      expect(captured['role'], 'jeeber');
    });

    test('dedupes rows that share a request id', () async {
      stub({
        'items': [
          {'id': 'r1', 'status': 'accepted', 'conversationId': 'c1'},
          {'id': 'r1', 'status': 'accepted', 'conversationId': 'c1b'},
        ],
      });

      expect(await repository.fetchAccepted(), hasLength(1));
    });

    // F12 — an empty list used to mean BOTH "no accepted orders" and "the
    // gateway is down", so a total outage rendered as an empty banner.
    test('THROWS a classified failure on a transport error', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/requests'),
        type: DioExceptionType.connectionError,
      ));

      await expectLater(
        repository.fetchAccepted(),
        throwsA(isA<AcceptedConversationsException>()
            .having((e) => e.failure, 'failure', isA<NetworkFailure>())),
      );
    });

    test('THROWS on a 503 rather than answering "no accepted orders"',
        () async {
      final options = RequestOptions(path: '/requests');
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(requestOptions: options, statusCode: 503),
      ));

      await expectLater(
        repository.fetchAccepted(),
        throwsA(isA<AcceptedConversationsException>()
            .having((e) => e.failure, 'failure', isA<ServerFailure>())),
      );
    });

    // An unexpected SHAPE is not a failure: the gateway answered, and the
    // envelope simply held no rows.
    test('returns empty on an unexpected payload shape', () async {
      stub('not-a-list-or-map');
      expect(await repository.fetchAccepted(), isEmpty);
    });
  });
}
