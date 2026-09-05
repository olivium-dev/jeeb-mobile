// MIXD-01 — a whitespace-only string survived the `isEmpty` guard and threw a
// RangeError out of `.trim().codeUnits.first`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/mixed_direction/presentation/mixed_direction_text.dart';

void main() {
  test('whitespace-only input returns ltr and does not throw', () {
    for (final input in const <String>['   ', '\t', '\n', '   ']) {
      expect(
        () => MixedDirectionText.detectDirection(input),
        returnsNormally,
        reason: 'input: ${input.codeUnits}',
      );
      expect(MixedDirectionText.detectDirection(input), TextDirection.ltr);
    }
  });

  test('the empty string and real content still resolve as before', () {
    expect(MixedDirectionText.detectDirection(''), TextDirection.ltr);
    expect(MixedDirectionText.detectDirection('hello'), TextDirection.ltr);
    expect(MixedDirectionText.detectDirection('  مرحبا'), TextDirection.rtl);
  });

  testWidgets('a whitespace-only label renders without faulting',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MixedDirectionText('   '))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
