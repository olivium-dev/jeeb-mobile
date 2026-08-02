// sprint-009 offer-lifecycle: the pending-offers list now surfaces EVERY offer

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/offer_lifecycle_signals.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_submitted_offers_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offer.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offers_repository.dart';

void main() {
  group('OfferStatus.fromWire', () {
    test('maps the customer decisions', () {
      expect(OfferStatus.fromWire('accepted'), OfferStatus.accepted);
      expect(OfferStatus.fromWire('accept'), OfferStatus.accepted);
      expect(OfferStatus.fromWire('lost'), OfferStatus.lost);
      expect(OfferStatus.fromWire('rejected'), OfferStatus.lost);
      expect(OfferStatus.fromWire('not_selected'), OfferStatus.lost);
    });

    test('open/absent/unknown fall back to submitted (never vanish)', () {
      expect(OfferStatus.fromWire('submitted'), OfferStatus.submitted);
      expect(OfferStatus.fromWire('pending'), OfferStatus.submitted);
      expect(OfferStatus.fromWire(null), OfferStatus.submitted);
      expect(OfferStatus.fromWire('wat'), OfferStatus.submitted);
    });

    test('isTerminal is true only for a decided offer', () {
      expect(OfferStatus.submitted.isTerminal, isFalse);
      expect(OfferStatus.accepted.isTerminal, isTrue);
      expect(OfferStatus.lost.isTerminal, isTrue);
    });
  });

  group('DioSubmittedOffersRepository parse (sprint-009)', () {
    late _RecordingAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = _RecordingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
        ..httpClientAdapter = adapter;
    });

    test('surfaces EVERY offer with its status — accepted + lost are no longer '
        'filtered out', () async {
      adapter.body = {
        'items': [
          {'id': 'o1', 'requestId': 'r1', 'fee': 12.5, 'status': 'submitted'},
          {'id': 'o2', 'requestId': 'r2', 'fee': 9, 'status': 'accepted'},
          {'id': 'o3', 'requestId': 'r3', 'fee': 7, 'status': 'lost'},
        ],
      };
      final offers = await DioSubmittedOffersRepository(
        dio: dio,
        jeeberId: 'me',
      ).listSubmitted();

      expect(offers.map((o) => o.id), ['o1', 'o2', 'o3']);
      expect(offers[0].status, OfferStatus.submitted);
      expect(offers[1].status, OfferStatus.accepted);
      expect(offers[2].status, OfferStatus.lost);
      // fee (dollars) is parsed as the price.
      expect(offers[0].price, 12.5);
    });

    test('withdraw treats 404 as an idempotent success (row clears), 409 as a '
        'failure (row stays)', () async {
      adapter.deleteStatus = 404;
      expect(
        await DioSubmittedOffersRepository(dio: dio).withdraw('gone'),
        isTrue,
      );
      adapter.deleteStatus = 409;
      expect(
        await DioSubmittedOffersRepository(dio: dio).withdraw('locked'),
        isFalse,
      );
    });
  });

  group('SubmittedOffersCubit lifecycle', () {
    test('applyOfferLifecycle flips the matching row then re-pulls', () async {
      final repo = _ScriptedRepo([
        const SubmittedOffer(id: 'o1', requestId: 'r1', price: 5, currency: 'USD'),
      ]);
      final cubit = SubmittedOffersCubit(repository: repo);
      await cubit.load();
      expect(cubit.state.offers.single.status, OfferStatus.submitted);

      // Server now reports it accepted; the flip is optimistic, the re-pull is
      repo.next = [
        const SubmittedOffer(
          id: 'o1',
          requestId: 'r1',
          price: 5,
          currency: 'USD',
          status: OfferStatus.accepted,
        ),
      ];
      await cubit.applyOfferLifecycle('o1', OfferStatus.accepted);
      expect(cubit.state.offers.single.status, OfferStatus.accepted);
      expect(repo.listCalls, 2); // initial load + lifecycle re-pull
      await cubit.close();
    });

    test('a lifecycle signal on the bus triggers a re-pull', () async {
      final repo = _ScriptedRepo([
        const SubmittedOffer(id: 'o1', requestId: 'r1', price: 5, currency: 'USD'),
      ]);
      final bus = OfferLifecycleSignals();
      addTearDown(bus.dispose);
      final cubit = SubmittedOffersCubit(
        repository: repo,
        lifecycleSignals: bus.stream,
      );
      await cubit.load();
      final before = repo.listCalls;

      bus.signal(const OfferLifecycleEvent(offerId: 'o1', accepted: false));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(repo.listCalls, greaterThan(before));
      await cubit.close();
    });
  });
}

class _ScriptedRepo implements SubmittedOffersRepository {
  _ScriptedRepo(this._initial);

  final List<SubmittedOffer> _initial;
  List<SubmittedOffer>? next;
  int listCalls = 0;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    listCalls += 1;
    return next ?? _initial;
  }

  @override
  Future<bool> withdraw(String offerId) async => true;
}

class _RecordingAdapter implements HttpClientAdapter {
  Map<String, Object?> body = const {'items': <dynamic>[]};
  int deleteStatus = 204;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'DELETE') {
      // Return the raw status; Dio's validateStatus turns a 4xx into a
      return ResponseBody.fromString('', deleteStatus);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
