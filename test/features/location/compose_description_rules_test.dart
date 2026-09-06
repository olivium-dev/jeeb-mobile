import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/location/domain/compose_description_rules.dart';

void main() {
  test('description contract mirrors the approved five-character minimum', () {
    expect(kComposeDescriptionMinLength, 5);
    expect(kComposeDescriptionMaxLength, 280);
    for (final text in <String>['', ' ', 'a', 'ab  c', '    abcd ']) {
      expect(isDescriptionLongEnough(text), isFalse, reason: text);
    }
    for (final text in <String>['abcde', ' ab   cd ', 'حليب 2', 'a' * 281]) {
      expect(isDescriptionLongEnough(text), isTrue, reason: text);
    }
    expect(collapseDescription('  milk\t\n  2L  '), 'milk 2L');
  });
}
