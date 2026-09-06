import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_cubit.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_state.dart';
import 'package:jeeb_mobile/features/notifications/data/dio_notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';

/// These gateway-projection wires are explicitly constructed literal fixtures:
/// FM-1 cannot deploy its gateway branch to capture that boundary. The source
String _fixture(String name) =>
    File('test/features/notifications/fixtures/fm1/$name').readAsStringSync();

Dio _dioRespondingWithWire(String wire, {String Function()? readWire}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            data: jsonDecode(readWire?.call() ?? wire),
            statusCode: 200,
            requestOptions: options,
          ),
        );
      },
    ),
  );
  return dio;
}

Future<NotificationItem> _parseSingle(String wire) async {
  final repository = DioNotificationsRepository(
    dio: _dioRespondingWithWire(wire),
  );
  final items = await repository.fetchNotifications();
  expect(items, hasLength(1));
  return items.single;
}

void main() {
  test(
    'malformed notification read fails, retries, and retains warm rows',
    () async {
      var wire = '{"items":{}}';
      final dio = _dioRespondingWithWire(wire, readWire: () => wire);
      addTearDown(() => dio.close(force: true));
      final cubit = NotificationsListCubit(
        repository: DioNotificationsRepository(dio: dio),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.status, NotificationsListStatus.failed);
      expect(cubit.state.appFailure, isA<UnknownFailure>());
      wire = '{"items":[{"id":"valid","title":"Actual notification"}]}';
      await cubit.retry();
      expect(cubit.state.status, NotificationsListStatus.loaded);
      expect(cubit.state.items.single.id, 'valid');
      wire = '{"items":[{"id":"valid"},42]}';
      await cubit.refresh();
      expect(cubit.state.status, NotificationsListStatus.loaded);
      expect(cubit.state.items.single.title, 'Actual notification');
      expect(cubit.state.refreshError, isA<UnknownFailure>());
    },
  );

  for (final wire in <String>[
    'null',
    '{}',
    '{"items":null}',
    '{"items":{}}',
    '{"items":null,"notifications":[]}',
    '{"items":["junk"]}',
    '{"items":[{"id":""}]}',
    '{"items":[{"id":"valid"},42]}',
  ]) {
    test('malformed notification success is rejected: $wire', () async {
      final dio = _dioRespondingWithWire(wire);
      addTearDown(() => dio.close(force: true));
      final repo = DioNotificationsRepository(dio: dio);
      await expectLater(
        repo.fetchNotifications(),
        throwsA(isA<UnknownFailure>().having((e) => e.parse, 'parse', isTrue)),
      );
    });
  }
  test('an explicit empty notification list remains successful', () async {
    final dio = _dioRespondingWithWire('{"items":[]}');
    addTearDown(() => dio.close(force: true));
    expect(
      await DioNotificationsRepository(dio: dio).fetchNotifications(),
      isEmpty,
    );
  });
  test(
    'P02 constructed target contract preserves ref and resolves supported wire kinds',
    () async {
      final repository = DioNotificationsRepository(
        dio: _dioRespondingWithWire(
          _fixture('constructed-p02-target-contract.json'),
        ),
      );
      final items = await repository.fetchNotifications();
      expect(items, hasLength(9));
      const expected = <String, NotificationKind>{
        'p02-new': NotificationKind.newRequest,
        'p02-chat': NotificationKind.chat,
        'p02-offer': NotificationKind.offer,
        'p02-accepted': NotificationKind.offerAccepted,
        'p02-delivery': NotificationKind.status,
        'p02-cancel': NotificationKind.status,
        'p02-expand': NotificationKind.requestExpired,
        'p02-expired': NotificationKind.requestExpired,
        'p02-availability': NotificationKind.availability,
      };
      for (final item in items) {
        expect(item.kind, expected[item.id]);
        expect(DateTime.tryParse(item.timestamp), isNotNull);
        if (item.kind == NotificationKind.availability) {
          expect(item.ref, isNull);
        } else {
          expect(item.ref, 'request-${item.id.substring(4)}');
        }
      }
    },
  );
  test(
    'FM1 R19 constructed gateway wire rejects degenerate ref and type shapes',
    () async {
      final missingRef = await _parseSingle(
        _fixture('constructed-projected-offer-no-ref.json'),
      );
      expect(missingRef.ref, isNull);
      expect(missingRef.kind, NotificationKind.offer);

      final emptyRef = await _parseSingle(
        _fixture('constructed-projected-offer-empty-ref.json'),
      );
      expect(emptyRef.ref, isNull);

      final huskedRef = await _parseSingle(
        _fixture('constructed-projected-offer-husk-ref.json'),
      );
      expect(huskedRef.ref, isNull);

      final unknownType = await _parseSingle(
        _fixture('constructed-projected-unknown-type.json'),
      );
      expect(unknownType.kind, NotificationKind.unknown);

      final absentType = await _parseSingle(
        _fixture('constructed-projected-absent-type.json'),
      );
      expect(absentType.kind, NotificationKind.unknown);
    },
  );

  test(
    'FM1 constructed gateway wire accepts offer and order ref aliases',
    () async {
      const aliases = <String, String>{
        'constructed-projected-offer-id-camel.json': 'offer-camel',
        'constructed-projected-offer-id-snake.json': 'offer-snake',
        'constructed-projected-order-id-camel.json': 'order-camel',
      };

      for (final entry in aliases.entries) {
        final item = await _parseSingle(_fixture(entry.key));
        expect(item.ref, entry.value);
      }
    },
  );

  test(
    'projects dispute and support ids from nested notification data',
    () async {
      final dispute = await _parseSingle('''
      {"items":[{"id":"n1","type":"jeeb.dispute.updated","data":{"caseId":"dsp-1"}}]}
    ''');
      expect(dispute.kind, NotificationKind.dispute);
      expect(dispute.ref, 'dsp-1');

      final support = await _parseSingle('''
      {"items":[{"id":"n2","type":"jeeb.support.replied","data":{"caseId":"ticket-1"}}]}
    ''');
      expect(support.kind, NotificationKind.support);
      expect(support.ref, 'ticket-1');
    },
  );
}
