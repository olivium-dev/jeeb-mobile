import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/accessibility/accessibility.dart';

void main() {
  testWidgets(
    'a nested 1.0 max text-scale clamp remains valid under the app clamp',
    (tester) async {
      final frameworkClamped =
          const MediaQueryData(textScaler: TextScaler.linear(3)).copyWith(
            textScaler: const TextScaler.linear(3).clamp(maxScaleFactor: 1),
          );

      expect(() => A11y.clampTextScaler(frameworkClamped), returnsNormally);

      await tester.pumpWidget(
        MediaQuery(
          data: frameworkClamped,
          child: Builder(
            builder: (context) => jeebA11yBuilder(
              context,
              const SizedBox(key: Key('nested-clamp-child')),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final childContext = tester.element(
        find.byKey(const Key('nested-clamp-child')),
      );
      expect(MediaQuery.textScalerOf(childContext).scale(16), 16);
    },
  );
}
