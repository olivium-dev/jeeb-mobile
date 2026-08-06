import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/idempotency/operation_id.dart';

void main() {
  test('newOperationId returns distinct RFC 4122 version 4 UUIDs', () {
    final first = newOperationId();
    final second = newOperationId();

    expect(isOperationId(first), isTrue);
    expect(isOperationId(second), isTrue);
    expect(first[14], '4');
    expect('89ab'.contains(first[19]), isTrue);
    expect(second, isNot(first));
  });

  test('isOperationId rejects delivery-derived and malformed keys', () {
    expect(isOperationId('delivery-123'), isFalse);
    expect(isOperationId('123e4567-e89b-12d3-a456-426614174000'), isFalse);
    expect(isOperationId(''), isFalse);
  });
}
