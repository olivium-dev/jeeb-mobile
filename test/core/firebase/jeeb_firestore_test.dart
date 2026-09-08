// The seam that decides which Firestore database chat reads from must agree
// with the contract every backend repo pins.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/firebase/jeeb_firestore.dart';

Map<String, dynamic> _contract() =>
    jsonDecode(File('contracts/jeeb-firebase-v1.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('contracts/jeeb-firebase-v1.json declares the Firebase identity', () {
    final contract = _contract();
    expect(contract['projectId'], 'jeeb-5a293');
    expect(contract['projectNumber'], '1051234312170');
    expect(contract['firestoreDatabaseId'], isA<String>());
  });

  test('the Firestore database id defaults to the contracted database', () {
    expect(JeebFirestore.databaseId, _contract()['firestoreDatabaseId']);
  });

  test('the default database id is Firestore\'s unnamed database', () {
    expect(JeebFirestore.defaultDatabaseId, '(default)');
    expect(JeebFirestore.usesDefaultDatabase, isTrue);
    expect(JeebFirestore.effectiveDatabaseId, JeebFirestore.defaultDatabaseId);
  });

  test('only the exact canonical database is accepted without substitution', () {
    expect(JeebFirestore.resolveDatabaseId('(default)'), '(default)');
    for (final value in ['', '  ', 'chat-staging', ' (default)', '(default) ']) {
      expect(() => JeebFirestore.resolveDatabaseId(value), throwsStateError);
    }
  });

  test('no source file in lib/ resolves Firestore outside the seam', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path == 'lib/core/firebase/jeeb_firestore.dart') continue;
      for (final line in entity.readAsLinesSync()) {
        final code = line.trimLeft();
        if (code.startsWith('//') || code.startsWith('*')) continue;
        if (code.contains('FirebaseFirestore.instance')) {
          offenders.add('${entity.path}: $code');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These call sites bypass the canonical database validation. Use '
          'JeebFirestore.instance():\n${offenders.join('\n')}',
    );
  });
}
