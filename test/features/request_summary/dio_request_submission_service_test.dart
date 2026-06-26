import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/request_summary/data/dio_request_submission_service.dart';
import 'package:jeeb_mobile/features/request_summary/domain/recipient_phone_resolver.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';

/// Fake [RecipientPhoneResolver] returning a fixed phone (or null) for the
/// default-recipient-phone tests.
class _FakeResolver implements RecipientPhoneResolver {
  _FakeResolver(this._phone);
  final String? _phone;
  @override
  Future<String?> resolve() async => _phone;
}

/// A resolver that throws — proves a resolver fault never fails the create.
class _ThrowingResolver implements RecipientPhoneResolver {
  @override
  Future<String?> resolve() async => throw Exception('boom');
}

/// Resolves every request to [body]/[status] without hitting the network.
Dio _dioRespond(Object? body, {int status = 201}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(data: body, statusCode: status, requestOptions: options),
      ),
    ),
  );
  return dio;
}

/// Rejects every request with [type] (and optional [status]).
Dio _dioError(DioExceptionType type, {int? status}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(
          requestOptions: options,
          type: type,
          response: status != null
              ? Response(
                  data: null,
                  statusCode: status,
                  requestOptions: options,
                )
              : null,
        ),
      ),
    ),
  );
  return dio;
}

const _draft = RequestDraft(
  description: 'Need a package delivered to Verdun',
  transcription: 'voice text',
  audioUrl: 'https://cdn/audio.m4a',
  photoUrls: ['https://cdn/p1.jpg'],
  tierId: 'flash',
  tierName: 'Flash',
  pickupLat: 33.8938,
  pickupLng: 35.5018,
  pickupAddress: 'Downtown Bakery, Hamra St',
  dropoffLat: 33.88,
  dropoffLng: 35.51,
  dropoffAddress: 'Verdun Residence, Block C',
);

void main() {
  group('DioRequestSubmissionService — T-MOB-REQSUBMIT POST /v1/requests', () {
    test('parses id from 201 response body', () async {
      final service = DioRequestSubmissionService(
        _dioRespond({'id': 'req-7c636340', 'status': 'pending'}),
      );

      final id = await service.submit(_draft);

      expect(id, 'req-7c636340');
    });

    test('POSTs to /v1/requests with the assembled gateway body shape', () async {
      String? capturedPath;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedPath = options.path;
            capturedMethod = options.method;
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-1'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      await DioRequestSubmissionService(dio).submit(_draft);

      expect(capturedPath, '/v1/requests');
      expect(capturedMethod, 'POST');
      expect(capturedBody?['description'], _draft.description);
      expect(capturedBody?['transcription'], 'voice text');
      expect(capturedBody?['tierId'], 'flash');
      expect(capturedBody?['photos'], _draft.photoUrls);
      expect(
        capturedBody?['pickupLocation'],
        {'lat': 33.8938, 'lng': 35.5018},
      );
      expect(
        capturedBody?['dropoffLocation'],
        {'lat': 33.88, 'lng': 35.51},
      );
      expect(capturedBody?['pickupAddress'], 'Downtown Bakery, Hamra St');
    });

    test('omits optional location keys when coordinates are absent', () async {
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-2'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      await DioRequestSubmissionService(dio)
          .submit(const RequestDraft(description: 'minimal'));

      expect(capturedBody?.containsKey('pickupLocation'), isFalse);
      expect(capturedBody?.containsKey('dropoffLocation'), isFalse);
      expect(capturedBody?.containsKey('transcription'), isFalse);
      expect(capturedBody?['photos'], <String>[]);
    });

    // ---- T-BE-019 / JEB-55: recipientPhone plumbing ----

    test('includes recipientPhone from the draft (draft phone wins)', () async {
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-rp'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      await DioRequestSubmissionService(
        dio,
        // Resolver returns a DIFFERENT phone — the explicit draft phone must win.
        phoneResolver: _FakeResolver('+962700000000'),
      ).submit(
        const RequestDraft(description: 'gift', recipientPhone: '+96170123456'),
      );

      expect(capturedBody?['recipientPhone'], '+96170123456');
    });

    test('defaults recipientPhone to the resolved client phone when the draft '
        'has none', () async {
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-default'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      await DioRequestSubmissionService(
        dio,
        phoneResolver: _FakeResolver('+96170123456'),
      ).submit(const RequestDraft(description: 'no phone in draft'));

      expect(capturedBody?['recipientPhone'], '+96170123456');
    });

    test('omits recipientPhone when neither draft nor resolver yields one',
        () async {
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-none'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      // No resolver supplied (and the draft carries no phone).
      await DioRequestSubmissionService(dio)
          .submit(const RequestDraft(description: 'no phone anywhere'));

      expect(capturedBody?.containsKey('recipientPhone'), isFalse);
    });

    test('a resolver fault degrades to omitting recipientPhone (create still '
        'succeeds)', () async {
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-fault'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final id = await DioRequestSubmissionService(
        dio,
        phoneResolver: _ThrowingResolver(),
      ).submit(const RequestDraft(description: 'resolver throws'));

      expect(id, 'req-fault');
      expect(capturedBody?.containsKey('recipientPhone'), isFalse);
    });

    test('throws server failure when 201 body has no id', () async {
      final service = DioRequestSubmissionService(
        _dioRespond({'status': 'pending'}),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestSubmissionException>(
            (e) => e.failure == RequestSubmissionFailure.server,
          ),
        ),
      );
    });

    test('maps connection error to network failure', () async {
      final service = DioRequestSubmissionService(
        _dioError(DioExceptionType.connectionError),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestSubmissionException>(
            (e) => e.failure == RequestSubmissionFailure.network,
          ),
        ),
      );
    });

    test('maps receive timeout to network failure', () async {
      final service = DioRequestSubmissionService(
        _dioError(DioExceptionType.receiveTimeout),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestSubmissionException>(
            (e) => e.failure == RequestSubmissionFailure.network,
          ),
        ),
      );
    });

    test('maps 4xx to invalidInput failure', () async {
      final service = DioRequestSubmissionService(
        _dioError(DioExceptionType.badResponse, status: 422),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestSubmissionException>(
            (e) => e.failure == RequestSubmissionFailure.invalidInput,
          ),
        ),
      );
    });

    test('maps 5xx to server failure', () async {
      final service = DioRequestSubmissionService(
        _dioError(DioExceptionType.badResponse, status: 503),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestSubmissionException>(
            (e) => e.failure == RequestSubmissionFailure.server,
          ),
        ),
      );
    });
  });
}
