import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/data/prohibited_acknowledgment_repository_impl.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/cubit/prohibited_acknowledgment_cubit.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/cubit/prohibited_acknowledgment_state.dart';

class _Wire {
  _Wire(this.body) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final failure = options.method == 'GET' ? getFailure : postFailure;
          if (failure != null) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                error: failure,
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: options.method == 'GET'
                  ? body
                  : postBody ??
                        <String, Object?>{
                          'userId': 'user-1',
                          'version':
                              (options.data as Map<String, Object?>)['version'],
                          'acknowledgedAt': '2026-09-06T12:00:00Z',
                        },
            ),
          );
        },
      ),
    );
  }

  final Dio dio = Dio(BaseOptions(baseUrl: 'https://unit-test.invalid'));
  final List<RequestOptions> requests = [];
  Object? body;
  Object? postBody;
  AppFailure? getFailure;
  AppFailure? postFailure;
}

Map<String, Object?> _catalog(Object? version) => {
  'version': version,
  'acknowledged': false,
  'items': [
    {'id': 'policy-item', 'name': 'Policy item', 'severity': 'warn'},
  ],
};

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  DioProhibitedAcknowledgmentRepository repository(_Wire wire) {
    addTearDown(() => wire.dio.close(force: true));
    return DioProhibitedAcknowledgmentRepository(dio: wire.dio, prefs: prefs);
  }

  for (final items in <List<Object?>>[
    [
      {'id': 'broken'},
      'junk',
    ],
    [
      {'id': 'valid', 'name': 'Valid'},
      {'id': 'broken'},
    ],
    [42],
    [
      {'id': ' ', 'name': 'Name'},
    ],
    [
      {'id': 'id', 'name': 42},
    ],
    [
      {'id': 'id', 'name': 'Name', 'severity': 'unexpected'},
    ],
  ]) {
    test(
      'unreadable policy rows fail the dialog state and cannot POST: $items',
      () async {
        await prefs.setBool('app.acknowledged_prohibited', true);
        final wire = _Wire({
          ..._catalog('v1'),
          'items': items,
          'acknowledged': true,
        });
        final cubit = ProhibitedAcknowledgmentCubit(
          repository: repository(wire),
        );
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.status, ProhibitedAckStatus.error);
        expect(
          cubit.state.failure,
          isA<UnknownFailure>().having((f) => f.parse, 'parse', true),
        );
        await cubit.acknowledge();
        expect(wire.requests.map((r) => r.method), ['GET']);
      },
    );
  }

  test(
    'server policy and account state supersede the old global preference',
    () async {
      await prefs.setBool('app.acknowledged_prohibited', true);
      final wire = _Wire({..._catalog('v1'), 'acknowledged': true});
      final repo = repository(wire);
      final cubit = ProhibitedAcknowledgmentCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.status, ProhibitedAckStatus.acknowledged);
      // Same user, updated server policy must be displayed again.
      wire.body = _catalog('v2');
      await cubit.load();
      expect(cubit.state.status, ProhibitedAckStatus.loaded);
      await cubit.acknowledge();
      expect(wire.requests.last.data, {'version': 'v2'});
      expect(cubit.state.status, ProhibitedAckStatus.acknowledged);
      expect(prefs.containsKey('app.acknowledged_prohibited'), isFalse);
      // A different authenticated session returns its own unacknowledged v2.
      wire.body = _catalog('v2');
      final nextSession = ProhibitedAcknowledgmentCubit(repository: repo);
      addTearDown(nextSession.close);
      await nextSession.load();
      expect(nextSession.state.status, ProhibitedAckStatus.loaded);
      expect(wire.requests.where((r) => r.method == 'GET'), hasLength(3));
    },
  );

  test(
    'failed refresh invalidates previous policy acknowledgment and version',
    () async {
      final wire = _Wire({..._catalog('v1'), 'acknowledged': true});
      final repo = repository(wire);
      await repo.fetchItems();
      expect(await repo.hasAcknowledged(), isTrue);
      wire.body = {
        'version': 'v2',
        'acknowledged': true,
        'items': ['bad'],
      };
      await expectLater(repo.fetchItems(), throwsA(isA<UnknownFailure>()));
      expect(await repo.hasAcknowledged(), isFalse);
      await expectLater(repo.acknowledge(), throwsA(isA<UnknownFailure>()));
      expect(wire.requests.any((r) => r.method == 'POST'), isFalse);
    },
  );

  for (final postBody in <Object>[
    {},
    {
      'userId': 'user-1',
      'version': 'wrong',
      'acknowledgedAt': '2026-09-06T12:00:00Z',
    },
    {'userId': 'user-1', 'version': 'v1', 'acknowledgedAt': 'invalid'},
  ]) {
    test(
      'malformed acknowledgment response cannot dismiss the dialog: $postBody',
      () async {
        final wire = _Wire(_catalog('v1'))..postBody = postBody;
        final cubit = ProhibitedAcknowledgmentCubit(
          repository: repository(wire),
        );
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.acknowledge();
        expect(cubit.state.status, ProhibitedAckStatus.acknowledgeFailed);
        expect(cubit.state.failure, isA<UnknownFailure>());
      },
    );
  }

  test(
    'acknowledges the successfully displayed version without another GET',
    () async {
      final wire = _Wire(_catalog('version-1'));
      final repo = repository(wire);
      expect((await repo.fetchItems()).single.id, 'policy-item');
      wire.body = _catalog('version-2');

      await repo.acknowledge();

      expect(wire.requests.map((request) => request.method), ['GET', 'POST']);
      expect(wire.requests.last.path, '/prohibited-items/acknowledge');
      expect(wire.requests.last.data, {'version': 'version-1'});
      expect(await repo.hasAcknowledged(), isFalse);
    },
  );

  test(
    'latest successful catalogue fetch replaces the cached version',
    () async {
      final wire = _Wire(_catalog('version-1'));
      final repo = repository(wire);
      await repo.fetchItems();
      wire.body = _catalog('version-2');
      await repo.fetchItems();
      await repo.acknowledge();
      expect(wire.requests.last.data, {'version': 'version-2'});
    },
  );

  test(
    'fetchless acknowledgment GETs a version before POST and caches it',
    () async {
      final wire = _Wire(_catalog('version-1'));
      final repo = repository(wire);
      await repo.acknowledge();
      await repo.acknowledge();
      expect(wire.requests.map((request) => request.method), [
        'GET',
        'POST',
        'POST',
      ]);
      expect(wire.requests.first.path, '/prohibited-items');
      expect(wire.requests.skip(1).map((request) => request.data), [
        {'version': 'version-1'},
        {'version': 'version-1'},
      ]);
    },
  );

  for (final entry in <String, Object?>{
    'missing': {'items': []},
    'null': _catalog(null),
    'empty': _catalog(''),
    'blank': _catalog(' \n\t '),
    'numeric': _catalog(7),
    'object': _catalog({'value': 'version-1'}),
    'malformed body': 'not a catalogue',
    'legacy list without version': [],
    'missing acknowledgment state': {'version': 'v1', 'items': []},
    'nonboolean acknowledgment state': {
      ..._catalog('v1'),
      'acknowledged': 'true',
    },
  }.entries) {
    test(
      '${entry.key} version prevents a fetchless acknowledgment POST',
      () async {
        final wire = _Wire(entry.value);
        final repo = repository(wire);
        await expectLater(
          repo.acknowledge(),
          throwsA(
            isA<UnknownFailure>().having(
              (failure) => failure.parse,
              'parse',
              isTrue,
            ),
          ),
        );
        expect(wire.requests.map((request) => request.method), ['GET']);
        expect(await repo.hasAcknowledged(), isFalse);
      },
    );
    test(
      '${entry.key} version cannot be a successful catalogue fetch',
      () async {
        final wire = _Wire(entry.value);
        final repo = repository(wire);
        await expectLater(
          repo.fetchItems(),
          throwsA(
            isA<UnknownFailure>().having(
              (failure) => failure.parse,
              'parse',
              isTrue,
            ),
          ),
        );
        wire.body = _catalog('recovered-version');
        await repo.acknowledge();
        expect(wire.requests.map((request) => request.method), [
          'GET',
          'GET',
          'POST',
        ]);
        expect(wire.requests.last.data, {'version': 'recovered-version'});
      },
    );
  }

  test('a failed GET preserves classification and never sends POST', () async {
    const failure = ServerFailure(status: 503);
    final wire = _Wire(_catalog('version-1'))..getFailure = failure;
    final repo = repository(wire);
    await expectLater(repo.acknowledge(), throwsA(same(failure)));
    expect(wire.requests.map((request) => request.method), ['GET']);
  });

  test(
    'an unreadable catalogue cannot cache an otherwise valid version',
    () async {
      final wire = _Wire({'version': 'not-displayed', 'items': 'malformed'});
      final repo = repository(wire);
      await expectLater(repo.fetchItems(), throwsA(isA<UnknownFailure>()));
      wire.body = _catalog('recovered-version');
      await repo.acknowledge();
      expect(wire.requests.map((request) => request.method), [
        'GET',
        'GET',
        'POST',
      ]);
      expect(wire.requests.last.data, {'version': 'recovered-version'});
    },
  );

  test(
    'a failed POST preserves classification and does not save locally',
    () async {
      const failure = ForbiddenFailure();
      final wire = _Wire(_catalog('version-1'))..postFailure = failure;
      final repo = repository(wire);
      await repo.fetchItems();
      await expectLater(repo.acknowledge(), throwsA(same(failure)));
      expect(wire.requests.map((request) => request.method), ['GET', 'POST']);
      expect(wire.requests.last.data, {'version': 'version-1'});
      expect(await repo.hasAcknowledged(), isFalse);
    },
  );
}
