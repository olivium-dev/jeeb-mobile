// ES-02 / OFF-01 / NET-09: the feed repository must never turn an outage into
// "quiet street — you're online".

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  int getStatus = 200;
  int postStatus = 204;
  DioExceptionType? transportError;
  Object body = const <String, Object?>{'items': <Object?>[], 'totalCount': 0};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final type = transportError;
    if (type != null) {
      throw DioException(requestOptions: options, type: type);
    }
    if (options.method == 'POST') {
      return ResponseBody.fromString('', postStatus);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      getStatus,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, Object?> _row(String id, {Object? dropoff}) => <String, Object?>{
      'requestId': id,
      'status': 'pending',
      'description': 'Delivery $id',
      'pickup': <String, Object?>{
        'address': 'Hamra',
        'location': <String, Object?>{'lat': 33.89, 'lng': 35.48},
      },
      'dropoff': ?dropoff,
      'potentialEarnings': 12.5,
      'currency': 'USD',
    };

void main() {
  late _ScriptedAdapter adapter;
  late Dio dio;
  late DioRequestFeedRepository repo;

  setUp(() {
    adapter = _ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = adapter;
    repo = DioRequestFeedRepository(dio: dio);
  });

  tearDown(() => repo.dispose());

  group('refresh() throws a CLASSIFIED failure, never an empty list', () {
    test('a connection error is a NetworkFailure', () async {
      adapter.transportError = DioExceptionType.connectionError;
      await expectLater(repo.refresh(), throwsA(isA<NetworkFailure>()));
    });

    test('a 503 is a ServerFailure carrying the status', () async {
      adapter.getStatus = 503;
      await expectLater(
        repo.refresh(),
        throwsA(isA<ServerFailure>().having((f) => f.status, 'status', 503)),
      );
    });

    test('a 401 is an UnauthorizedFailure', () async {
      adapter.getStatus = 401;
      await expectLater(repo.refresh(), throwsA(isA<UnauthorizedFailure>()));
    });

    test('a receive timeout is a TimeoutFailure', () async {
      adapter.transportError = DioExceptionType.receiveTimeout;
      await expectLater(repo.refresh(), throwsA(isA<TimeoutFailure>()));
    });

    test('a 200 with zero items is still an EMPTY list, not a failure',
        () async {
      final rows = await repo.refresh();
      expect(rows, isEmpty);
    });
  });

  group('accept()/decline() keep their business outcomes, throw the rest', () {
    test('409 → alreadyTaken', () async {
      adapter.postStatus = 409;
      expect(await repo.accept('r1'), RequestActionOutcome.alreadyTaken);
    });

    test('410 → expired', () async {
      adapter.postStatus = 410;
      expect(await repo.accept('r1'), RequestActionOutcome.expired);
    });

    test('500 THROWS instead of collapsing to networkError', () async {
      adapter.postStatus = 500;
      await expectLater(repo.accept('r1'), throwsA(isA<ServerFailure>()));
    });

    test('403 THROWS a ForbiddenFailure — it never blames the connection',
        () async {
      adapter.postStatus = 403;
      await expectLater(repo.accept('r1'), throwsA(isA<ForbiddenFailure>()));
    });

    test('decline() throws the classified failure', () async {
      adapter.postStatus = 500;
      await expectLater(repo.decline('r1'), throwsA(isA<ServerFailure>()));
    });
  });

  group('degrade-don\'t-drop on a missing location (UX-21 as measured)', () {
    test('a row with no dropoff still reaches the jeeber, label-only',
        () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[
          _row('with-dropoff', dropoff: <String, Object?>{
            'address': 'Achrafieh',
            'location': <String, Object?>{'lat': 33.88, 'lng': 35.52},
          }),
          _row('no-dropoff'),
        ],
        'totalCount': 2,
      };

      final rows = await repo.refresh();

      expect(rows.map((r) => r.id), ['with-dropoff', 'no-dropoff']);
      // Nothing on this surface reads the coordinates; the LABEL is the
      // contract, and a missing one degrades to empty rather than a fake pin.
      expect(rows.last.dropoff.label, isEmpty);
    });
  });

  group('a missing price is never rendered as a real 0.00 (R6-13a)', () {
    test('earningsKnown is false when the envelope carried no price',
        () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'requestId': 'priceless', 'status': 'pending'},
        ],
        'totalCount': 1,
      };

      final rows = await repo.refresh();

      expect(rows.single.earningsKnown, isFalse);
      expect(rows.single.potentialEarnings, 0.0);
    });

    test('earningsKnown is true when a price parsed', () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[_row('priced')],
        'totalCount': 1,
      };

      final rows = await repo.refresh();

      expect(rows.single.earningsKnown, isTrue);
      expect(rows.single.potentialEarnings, 12.5);
    });
  });
}
