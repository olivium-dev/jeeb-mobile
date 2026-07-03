import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/formatting/friendly_reference.dart';

void main() {
  group('friendlyReference', () {
    test('shortens a canonical UUID to the last 6 chars, uppercased', () {
      expect(
        friendlyReference('9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6'),
        '#CC42E6',
      );
    });

    test('strips separators before taking the tail', () {
      // Last 6 alphanumerics of "...-77aa10cc42e6" are "cc42e6".
      expect(friendlyReference('ORDER_00-77aa10-cc42e6'), '#CC42E6');
    });

    test('null and blank fall back to the placeholder', () {
      expect(friendlyReference(null), '#—');
      expect(friendlyReference('   '), '#—');
    });

    test('an id with no alphanumerics falls back', () {
      expect(friendlyReference('---'), '#—');
    });

    test('passes through an already-human ORD- reference verbatim', () {
      expect(friendlyReference('ORD-23470'), 'ORD-23470');
    });

    test('passes through a JB- reference and a #-reference verbatim', () {
      expect(friendlyReference('JB-1042'), 'JB-1042');
      expect(friendlyReference('#A1B2C3'), '#A1B2C3');
    });

    test('passes through a REQ- reference verbatim', () {
      expect(friendlyReference('REQ-001'), 'REQ-001');
    });

    test('trims surrounding whitespace', () {
      expect(friendlyReference('  ORD-23470  '), 'ORD-23470');
    });

    test('short ids shorter than 6 chars are used whole, uppercased', () {
      expect(friendlyReference('ab12'), '#AB12');
    });

    test('respects a custom prefix', () {
      expect(
        friendlyReference(
          '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
          prefix: 'Ref ',
        ),
        'Ref CC42E6',
      );
    });

    test('is deterministic for the same id', () {
      const id = 'delivery-3f9c2b7a-11aa-4bb2-9cd3-556677889900';
      expect(friendlyReference(id), friendlyReference(id));
    });
  });

  group('looksLikeInternalIdentifier', () {
    test('flags a synthetic jeeb account handle', () {
      expect(looksLikeInternalIdentifier('jeeb-e1a35ea8a520'), isTrue);
      expect(looksLikeInternalIdentifier('JEEB-89A486F968ED'), isTrue);
    });

    test('flags an @jeeb.internal email', () {
      expect(
        looksLikeInternalIdentifier(
          'phone-only+cb39e21caa8241f587043ffb1e3086d3@jeeb.internal',
        ),
        isTrue,
      );
    });

    test('flags a bare UUID', () {
      expect(
        looksLikeInternalIdentifier('9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6'),
        isTrue,
      );
    });

    test('flags blank/null as unusable', () {
      expect(looksLikeInternalIdentifier(null), isTrue);
      expect(looksLikeInternalIdentifier('  '), isTrue);
    });

    test('accepts a real human name', () {
      expect(looksLikeInternalIdentifier('Sami Fawaz'), isFalse);
      expect(looksLikeInternalIdentifier('Kamal'), isFalse);
    });

    test('does not flag a name that merely contains the word jeeb', () {
      expect(looksLikeInternalIdentifier('Jeeb Rider'), isFalse);
    });
  });

  group('displayNameOrNull', () {
    test('returns null for an internal handle so callers show a generic', () {
      expect(displayNameOrNull('jeeb-e1a35ea8a520'), isNull);
    });

    test('returns null for blank input', () {
      expect(displayNameOrNull(''), isNull);
      expect(displayNameOrNull(null), isNull);
    });

    test('returns the trimmed real name', () {
      expect(displayNameOrNull('  Sami Fawaz '), 'Sami Fawaz');
    });
  });
}
