import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/request_summary/data/dio_request_submission_service.dart';
import 'package:jeeb_mobile/features/request_summary/domain/recipient_phone_resolver.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';

/// Stub [RecipientPhoneResolver] returning a fixed default phone (or null). Lets
/// the wire-body tests exercise the BUG-7 fallback (signed-in client's own
/// profile phone) without SharedPreferences / a live gateway.
class _FakeRecipientPhoneResolver implements RecipientPhoneResolver {
  const _FakeRecipientPhoneResolver([this._phone]);

  final String? _phone;

  @override
  Future<String?> resolve() async => _phone;
}

/// Builds the service under test. [defaultPhone] is what the injected resolver
/// yields when the draft carries no recipient phone (null = resolver miss).
DioRequestSubmissionService _service(Dio dio, {String? defaultPhone}) =>
    DioRequestSubmissionService(dio, _FakeRecipientPhoneResolver(defaultPhone));

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

/// Rejects every request with [type] (and optional [status]/[body]).
Dio _dioError(DioExceptionType type, {int? status, Object? body}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(
          requestOptions: options,
          type: type,
          response: status != null
              ? Response(
                  data: body,
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
      final service = _service(
        _dioRespond({'id': 'req-7c636340', 'status': 'pending'}),
      );

      final id = await service.submit(_draft);

      expect(id, 'req-7c636340');
    });

    test('POSTs to /v1/requests with the assembled gateway body shape',
        () async {
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

      await _service(dio).submit(_draft);

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

    // BUG-6 create-payload contract: the POST /v1/requests body MUST carry the
    test('serializes the tier UUID (never the slug) + real non-zero pickup',
        () async {
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-uuid'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      const uuidDraft = RequestDraft(
        description: 'Parcel to Hamra',
        // The wire-side tier id ComposeRequestController resolves from
        tierId: '2bd0d5df-db76-5d14-9e4d-741d60b2fa12',
        tierName: 'express',
        pickupLat: 33.8886,
        pickupLng: 35.4955,
        pickupAddress: 'Current location (33.8886, 35.4955)',
        dropoffLat: 33.8886,
        dropoffLng: 35.4955,
        dropoffAddress: 'Current location (33.8886, 35.4955)',
      );

      await _service(dio).submit(uuidDraft);

      // tier: a UUID, never a slug.
      expect(capturedBody?['tierId'], '2bd0d5df-db76-5d14-9e4d-741d60b2fa12');
      expect(capturedBody?['tierId'], isNot('express'));
      // pickup: real, non-zero {lat,lng} + a non-empty address.
      final pickup = capturedBody?['pickupLocation'] as Map<String, dynamic>?;
      expect(pickup, isNotNull);
      expect(pickup?['lat'], isNot(0));
      expect(pickup?['lng'], isNot(0));
      expect(pickup?['lat'], 33.8886);
      expect(pickup?['lng'], 35.4955);
      expect(capturedBody?['pickupAddress'], isNotEmpty);
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

      await _service(dio)
          .submit(const RequestDraft(description: 'minimal'));

      expect(capturedBody?.containsKey('pickupLocation'), isFalse);
      expect(capturedBody?.containsKey('dropoffLocation'), isFalse);
      expect(capturedBody?.containsKey('transcription'), isFalse);
      expect(capturedBody?['photos'], <String>[]);
    });

    // BUG-7 handover-OTP fix: the POST /v1/requests body MUST carry a non-empty
    test('emits the compose-form recipientPhone (E.164) when the draft has one',
        () async {
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-phone'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      const phoneDraft = RequestDraft(
        description: 'Parcel to Verdun',
        recipientPhone: '+96170123456',
      );

      // Resolver default differs, to prove the explicit draft phone WINS.
      await _service(dio, defaultPhone: '+96171999999').submit(phoneDraft);

      final phone = capturedBody?['recipientPhone'] as String?;
      expect(phone, '+96170123456');
      expect(phone, isNotNull);
      expect(phone, isNotEmpty);
      expect(phone, startsWith('+'));
    });

    test(
        'falls back to the resolver default (E.164) when the draft omits a phone',
        () async {
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-default-phone'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      // _draft carries no recipientPhone → the injected resolver (signed-in
      await _service(dio, defaultPhone: '+96171999999').submit(_draft);

      final phone = capturedBody?['recipientPhone'] as String?;
      expect(phone, '+96171999999');
      expect(phone, isNotNull);
      expect(phone, isNotEmpty);
      expect(phone, startsWith('+'));
    });

    test('omits recipientPhone when neither draft nor resolver supplies one',
        () async {
      Map<String, dynamic>? capturedBody;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data as Map<String, dynamic>?;
            handler.resolve(
              Response(
                data: {'id': 'req-no-phone'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      // No draft phone AND resolver miss (defaultPhone null) → field omitted,
      await _service(dio).submit(_draft);

      expect(capturedBody?.containsKey('recipientPhone'), isFalse);
    });

    // EP-23: the enum stays, the PROSE goes — the classified parse failure
    // rides on appFailure instead of 'missing id in 201 response'.
    test('throws server failure with a parse AppFailure when 201 has no id',
        () async {
      final service = _service(
        _dioRespond({'status': 'pending'}),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestSubmissionException>(
            (e) =>
                e.failure == RequestSubmissionFailure.server &&
                e.appFailure is UnknownFailure &&
                (e.appFailure! as UnknownFailure).parse &&
                e.message == null,
          ),
        ),
      );
    });

    test('maps connection error to network failure', () async {
      final service = _service(
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
      final service = _service(
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

    test('JEBV4-108: maps 401 to the typed unauthorized failure (session), '
        'never invalidInput', () async {
      final service = _service(
        _dioError(DioExceptionType.badResponse, status: 401),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestSubmissionException>(
            (e) => e.failure == RequestSubmissionFailure.unauthorized,
          ),
        ),
      );
    });

    test('maps 422 to invalidInput failure', () async {
      final service = _service(
        _dioError(DioExceptionType.badResponse, status: 422),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestSubmissionException>(
            (e) =>
                e.failure == RequestSubmissionFailure.invalidInput &&
                e.appFailure is ValidationFailure,
          ),
        ),
      );
    });

    // AE-01/NET-15: every non-401 4xx used to bucket into `invalidInput` with
    // a stringified 'HTTP <status>' the UI could never render honestly.
    for (final int status in <int>[403, 404, 410, 429]) {
      test('maps $status to SERVER, not invalidInput, carrying its kind',
          () async {
        final service = _service(
          _dioError(DioExceptionType.badResponse, status: status),
        );

        await expectLater(
          service.submit(_draft),
          throwsA(
            predicate<RequestSubmissionException>(
              (e) =>
                  e.failure == RequestSubmissionFailure.server &&
                  e.appFailure != null &&
                  e.appFailure is! ValidationFailure,
            ),
          ),
        );
      });
    }

    test('a 409 that is NOT a moderation suffix stays a server failure',
        () async {
      final service = _service(
        _dioError(
          DioExceptionType.badResponse,
          status: 409,
          body: <String, dynamic>{'type': 'https://jeeb/errors/duplicate'},
        ),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestSubmissionException>(
            (e) =>
                e is! RequestModerationRequired &&
                e.failure == RequestSubmissionFailure.server,
          ),
        ),
      );
    });

    // AE-01: the two moderation suffixes are their OWN exception.
    test('a 409 prohibited-item-requires-ack becomes RequestModerationRequired '
        'carrying the flagged keywords', () async {
      final service = _service(
        _dioError(
          DioExceptionType.badResponse,
          status: 409,
          body: <String, dynamic>{
            'type': 'https://jeeb/errors/prohibited-item-requires-ack',
            'matches': <dynamic>[
              <String, dynamic>{'keyword': 'knife'},
            ],
          },
        ),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestModerationRequired>(
            (e) => !e.blocked && e.matches.contains('knife'),
          ),
        ),
      );
    });

    test('a 409 prohibited-item-blocked is TERMINAL', () async {
      final service = _service(
        _dioError(
          DioExceptionType.badResponse,
          status: 409,
          body: <String, dynamic>{
            'type': 'https://jeeb/errors/prohibited-item-blocked',
            'matches': <dynamic>['firearm'],
          },
        ),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(
          predicate<RequestModerationRequired>(
            (e) => e.blocked && e.matches.contains('firearm'),
          ),
        ),
      );
    });

    // A RequestModerationRequired is still a RequestSubmissionException, so
    // every existing `on RequestSubmissionException catch` keeps working.
    test('RequestModerationRequired is caught by the legacy catch', () async {
      final service = _service(
        _dioError(
          DioExceptionType.badResponse,
          status: 409,
          body: <String, dynamic>{
            'type': 'https://jeeb/errors/prohibited-item-requires-ack',
          },
        ),
      );

      await expectLater(
        service.submit(_draft),
        throwsA(isA<RequestSubmissionException>()),
      );
    });

    // NET-12: without the header a retried create can mint a second request.
    test('sends the draft operationId as the Idempotency-Key', () async {
      Map<String, dynamic>? headers;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            headers = options.headers;
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{'id': 'req-1'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      await _service(dio).submit(
        const RequestDraft(description: 'x', operationId: 'op-abc'),
      );

      expect(headers?['Idempotency-Key'], 'op-abc');
    });

    test('sends NO Idempotency-Key when the draft carries no operationId',
        () async {
      Map<String, dynamic>? headers;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            headers = options.headers;
            handler.resolve(
              Response<Map<String, dynamic>>(
                data: <String, dynamic>{'id': 'req-1'},
                statusCode: 201,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      await _service(dio).submit(const RequestDraft(description: 'x'));

      expect(headers?.containsKey('Idempotency-Key'), isFalse);
    });

    test('maps 5xx to server failure', () async {
      final service = _service(
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
