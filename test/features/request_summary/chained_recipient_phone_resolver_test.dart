import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/request_summary/data/chained_recipient_phone_resolver.dart';
import 'package:jeeb_mobile/features/request_summary/domain/recipient_phone_resolver.dart';

class _StubResolver implements RecipientPhoneResolver {
  _StubResolver(this._value, {this.throws = false});
  final String? _value;
  final bool throws;
  int calls = 0;

  @override
  Future<String?> resolve() async {
    calls++;
    if (throws) throw Exception('boom');
    return _value;
  }
}

void main() {
  group('ChainedRecipientPhoneResolver', () {
    test('returns the first non-null phone and short-circuits', () async {
      final first = _StubResolver('+9613000001');
      final second = _StubResolver('+9619999999');
      final chain = ChainedRecipientPhoneResolver([first, second]);

      expect(await chain.resolve(), '+9613000001');
      expect(first.calls, 1);
      expect(second.calls, 0, reason: 'short-circuits on first hit');
    });

    test('falls through nulls/empties to the next source', () async {
      final chain = ChainedRecipientPhoneResolver([
        _StubResolver(null),
        _StubResolver('   '),
        _StubResolver('+9613000002'),
      ]);
      expect(await chain.resolve(), '+9613000002');
    });

    test('a throwing delegate is skipped, not fatal', () async {
      final chain = ChainedRecipientPhoneResolver([
        _StubResolver(null, throws: true),
        _StubResolver('+9613000003'),
      ]);
      expect(await chain.resolve(), '+9613000003');
    });

    test('returns null when every source misses', () async {
      final chain = ChainedRecipientPhoneResolver([
        _StubResolver(null),
        _StubResolver(''),
      ]);
      expect(await chain.resolve(), isNull);
    });

    test('trims a hit before returning it', () async {
      final chain = ChainedRecipientPhoneResolver([
        _StubResolver('  +9613000004  '),
      ]);
      expect(await chain.resolve(), '+9613000004');
    });
  });
}
