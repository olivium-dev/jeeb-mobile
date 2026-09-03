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
          'These call sites pin the implicit default database, so a backend '
          'move to a named database is silently invisible to them. Use '
          'JeebFirestore.instance():\n${offenders.join('\n')}',
    );
  });
}
