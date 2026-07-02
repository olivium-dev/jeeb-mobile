import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_nav_observer.dart';

Map<String, dynamic> decodeLine(String line) =>
    jsonDecode(line.substring(Diag.prefix.length + 1)) as Map<String, dynamic>;

Route<void> route(String name, {Object? arguments}) => MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
      settings: RouteSettings(name: name, arguments: arguments),
    );

void main() {
  late List<String> lines;
  late DiagNavObserver observer;

  setUp(() {
    lines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = lines.add;
    observer = DiagNavObserver();
  });

  tearDown(Diag.resetForTest);

  test('didPush emits t=nav evt=push with route/name and path params', () {
    observer.didPush(
      route('/orders/:id', arguments: <String, Object?>{'id': 'd-42'}),
      null,
    );

    final record = decodeLine(lines.single);
    expect(record['t'], 'nav');
    expect(record['evt'], 'push');
    expect(record['route'], '/orders/:id');
    expect(record['name'], '/orders/:id');
    expect(record['params'], {'id': 'd-42'});
    expect(record['ts'], isNotNull);
  });

  test('didReplace emits evt=replace for the new route', () {
    observer.didReplace(newRoute: route('/wallet'), oldRoute: route('/'));
    final record = decodeLine(lines.single);
    expect(record['evt'], 'replace');
    expect(record['route'], '/wallet');
  });

  test('didPop reports the destination route (previousRoute)', () {
    observer.didPop(route('/orders/:id/otp'), route('/orders/:id'));
    final record = decodeLine(lines.single);
    expect(record['evt'], 'pop');
    expect(record['route'], '/orders/:id');
  });

  test('query tokens on a raw-location route name are stripped', () {
    observer.didPush(route('/set-password?resetToken=SECRET123'), null);
    final line = lines.single;
    expect(line, isNot(contains('SECRET123')));
    final record = decodeLine(line);
    expect(record['route'], '/set-password');
    expect(record['name'], '/set-password');
  });

  test('a sensitive key in route arguments is redacted, not logged raw', () {
    observer.didPush(
      route('/x', arguments: <String, Object?>{'token': 'raw-token-9999'}),
      null,
    );
    final line = lines.single;
    expect(line, isNot(contains('raw-token-9999')));
    final params = decodeLine(line)['params'] as Map<String, dynamic>;
    expect(params['token'], startsWith('tok:'));
    expect(params['token'], endsWith('9999'));
  });

  test('emits nothing when the stream is disabled', () {
    Diag.enabledOverride = false;
    observer.didPush(route('/orders/:id'), null);
    expect(lines, isEmpty);
  });
}
