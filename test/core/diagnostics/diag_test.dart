import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';

/// Decodes a `[jeeb-diag] {json}` line back into a map.
Map<String, dynamic> decodeLine(String line) {
  expect(line, startsWith('${Diag.prefix} '));
  final jsonPart = line.substring(Diag.prefix.length + 1);
  return jsonDecode(jsonPart) as Map<String, dynamic>;
}

void main() {
  late List<String> lines;

  setUp(() {
    lines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = lines.add;
    Diag.clock = () => DateTime.utc(2026, 7, 2, 10, 30, 15);
  });

  tearDown(Diag.resetForTest);

  group('Diag.event JSON shape', () {
    test('emits a single well-formed line with t=evt, name, data, ts', () {
      Diag.event('offer_submitted', {'requestId': 'r-1', 'priceUsd': 12.5});

      expect(lines, hasLength(1));
      final record = decodeLine(lines.single);
      expect(record['t'], 'evt');
      expect(record['name'], 'offer_submitted');
      expect(record['data'], {'requestId': 'r-1', 'priceUsd': 12.5});
      expect(record['ts'], '2026-07-02T10:30:15.000Z');
    });

    test('every line carries the stable [jeeb-diag] grep prefix', () {
      Diag.event('session_auth', {'status': 'authenticated'});
      expect(lines.single, startsWith('[jeeb-diag] {'));
    });

    test('defensively scrubs a token a caller mistakenly passes', () {
      Diag.event('session_auth', {
        'status': 'authenticated',
        'accessToken': 'header.payload.signature-XYZ9',
      });

      final data = decodeLine(lines.single)['data'] as Map<String, dynamic>;
      expect(data['status'], 'authenticated');
      expect(data['accessToken'], isNot(contains('signature')));
      expect(data['accessToken'], startsWith('tok:'));
      // last-4 correlation handle is kept, the secret body is not.
      expect(data['accessToken'], endsWith('XYZ9'));
    });
  });

  group('Diag.nav shape', () {
    test('emits t=nav with evt/route/name/params/ts', () {
      Diag.nav(
        evt: 'push',
        route: '/orders/:id',
        name: 'delivery-detail',
        params: {'id': 'd-42'},
      );

      final record = decodeLine(lines.single);
      expect(record['t'], 'nav');
      expect(record['evt'], 'push');
      expect(record['route'], '/orders/:id');
      expect(record['name'], 'delivery-detail');
      expect(record['params'], {'id': 'd-42'});
      expect(record['ts'], isNotNull);
    });
  });

  group('Diag.api shape', () {
    test('emits t=api with m/path/status/ms/reqId, path query-stripped', () {
      Diag.api(
        method: 'get',
        path: '/v1/requests?token=abc',
        status: 201,
        ms: 123,
        reqId: 'corr-1',
      );

      final record = decodeLine(lines.single);
      expect(record['t'], 'api');
      expect(record['m'], 'GET');
      expect(record['path'], '/v1/requests');
      expect(record['status'], 201);
      expect(record['ms'], 123);
      expect(record['reqId'], 'corr-1');
    });
  });

  group('build gate', () {
    test('no line is emitted when disabled', () {
      Diag.enabledOverride = false;
      Diag.event('offer_submitted', {'requestId': 'r-1'});
      Diag.nav(evt: 'push', route: '/x', name: 'x');
      Diag.api(method: 'GET', path: '/y', status: 200, ms: 1);
      expect(lines, isEmpty);
    });
  });
}
