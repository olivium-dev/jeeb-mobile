// AE-07 / AE-08: a 409 is disambiguated by the gateway's own RFC 7807 `type`
// suffix, never by lower-casing English prose out of the body.

import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/data/dio_offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/offers_failure_copy.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const String _base = 'https://example.invalid';

/// Answers the accept POST with a 409 carrying [type]; every GET succeeds.
class _ConflictAdapter implements HttpClientAdapter {
  _ConflictAdapter(this.type, {this.status = 409});

  final String? type;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode(<String, Object>{'items': <Object>[]}),
        200,
        headers: _json,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{
        'type': type,
        'title': 'Conflict',
        'detail': 'the request is no longer accepting offers',
        'status': status,
      }),
      status,
      headers: _json,
    );
  }

  @override
  void close({bool force = false}) {}
}

const Map<String, List<String>> _json = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

DioOffersRepository _repo(String? type, {int status = 409}) {
  final Dio dio = Dio(BaseOptions(baseUrl: _base));
  dio.httpClientAdapter = _ConflictAdapter(type, status: status);
  return DioOffersRepository(dio);
}

Future<OffersRepositoryException> _accept(String? type, {int status = 409}) async {
  try {
    await _repo(type, status: status)
        .acceptOffer(requestId: 'r1', offerId: 'o1');
  } on OffersRepositoryException catch (e) {
    return e;
  }
  fail('expected an OffersRepositoryException');
}

String _suffix(String name) => 'https://jeeb.example/errors/$name';

void main() {
  test('request-expired is its OWN failure, not offerNotPending', () async {
    final OffersRepositoryException e = await _accept(_suffix('request-expired'));
    expect(e.failure, OffersFailure.requestExpired);
  });

  test('offer-jeeber-insufficient-balance → jeeberWalletShort', () async {
    final OffersRepositoryException e =
        await _accept(_suffix('offer-jeeber-insufficient-balance'));
    expect(e.failure, OffersFailure.jeeberWalletShort);
  });

  test('too-many-active-deliveries → jeeberAtCapacity', () async {
    final OffersRepositoryException e =
        await _accept(_suffix('too-many-active-deliveries'));
    expect(e.failure, OffersFailure.jeeberAtCapacity);
  });

  test('request-not-open / already-accepted → requestNotOpen', () async {
    for (final String name in const <String>[
      'request-not-open',
      'request-not-acceptable',
      'already-accepted',
    ]) {
      expect(
        (await _accept(_suffix(name))).failure,
        OffersFailure.requestNotOpen,
        reason: name,
      );
    }
  });

  test('an unknown suffix falls back with upstreamCode recorded', () async {
    final OffersRepositoryException e =
        await _accept(_suffix('some-new-thing'));
    expect(e.failure, OffersFailure.offerNotPending);
    expect(e.upstreamCode, 'some-new-thing');
  });

  test('English prose alone no longer decides the bucket', () async {
    // The body's detail says "no longer accepting offers", which the old
    // substring haystack read as requestNotOpen.
    final OffersRepositoryException e = await _accept(null);
    expect(e.failure, OffersFailure.offerNotPending);
    expect(e.upstreamCode, isNull);
  });

  test('410 and 404 stay requestNotOpen', () async {
    expect(
      (await _accept(null, status: 410)).failure,
      OffersFailure.requestNotOpen,
    );
    expect(
      (await _accept(null, status: 404)).failure,
      OffersFailure.requestNotOpen,
    );
  });

  group('each new value renders its own ARB line', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      test(locale.languageCode, () async {
        final AppLocalizations l10n =
            await const SyncAppLocalizationsDelegate().load(locale);
        expect(
          offersFailureCopy(
            l10n,
            OffersFailure.requestExpired,
            phase: OffersErrorPhase.accept,
          ),
          l10n.offersErrorRequestExpired,
        );
        expect(
          offersFailureCopy(
            l10n,
            OffersFailure.jeeberWalletShort,
            phase: OffersErrorPhase.accept,
          ),
          l10n.offersErrorJeeberWalletShort,
        );
      });
    }
  });
}
