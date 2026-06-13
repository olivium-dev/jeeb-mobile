import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/data/prohibited_acknowledgment_repository_impl.dart';

String? _capturedPath;
String? _capturedMethod;

Dio _capturingDio(Object? responseBody) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        _capturedPath = options.path;
        _capturedMethod = options.method;
        handler.resolve(
          Response(
            data: responseBody,
            statusCode: 200,
            requestOptions: options,
          ),
        );
      },
    ),
  );
  return dio;
}

DioProhibitedAcknowledgmentRepository _repo(
  Dio dio,
  SharedPreferences prefs,
) => DioProhibitedAcknowledgmentRepository(dio: dio, prefs: prefs);

void main() {
  group(
      'DioProhibitedAcknowledgmentRepository — T-MOB-021 endpoint contract',
      () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('fetchItems uses GET /prohibited-items (mock :3055 verified)',
        () async {
      _capturedPath = null;
      final repo = _repo(
        _capturingDio({
          'items': <dynamic>[],
          'version': '2026-06-05T12:00:00.0000000Z',
        }),
        prefs,
      );

      await repo.fetchItems();

      expect(_capturedPath, '/prohibited-items');
      expect(_capturedMethod, 'GET');
    });

    test('acknowledge uses POST /prohibited-items/acknowledge', () async {
      _capturedPath = null;
      final repo = _repo(
        _capturingDio(<String, dynamic>{
          'userId': 'u-1',
          'version': 'v1',
          'acknowledgedAt': '2026-06-13T00:00:00Z',
        }),
        prefs,
      );

      await repo.acknowledge();

      expect(_capturedPath, '/prohibited-items/acknowledge');
      expect(_capturedMethod, 'POST');
    });

    test('hasAcknowledged returns false before local save', () async {
      final repo = _repo(_capturingDio(null), prefs);

      expect(await repo.hasAcknowledged(), isFalse);
    });

    test('saveLocalAcknowledgment persists flag in SharedPreferences',
        () async {
      final repo = _repo(_capturingDio(null), prefs);

      await repo.saveLocalAcknowledgment();

      expect(await repo.hasAcknowledged(), isTrue);
    });

    test('parses items array from response correctly', () async {
      final repo = _repo(
        _capturingDio({
          'items': [
            {'id': 'arak', 'name': 'Arak', 'category': 'alcohol'},
            {
              'id': 'knife',
              'name': 'Kitchen Knife',
              'category': 'weapons',
              'severity': 'warn',
            },
          ],
          'version': '2026-06-05T12:00:00.0000000Z',
        }),
        prefs,
      );

      final items = await repo.fetchItems();

      expect(items.length, 2);
      expect(items[0].id, 'arak');
      expect(items[0].name, 'Arak');
      expect(items[1].id, 'knife');
    });
  });
}
