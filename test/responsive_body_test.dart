import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/layout/responsive_scaffold.dart';

void main() {
  group('ResponsiveBody', () {
    testWidgets('fills edge-to-edge on compact (phone) width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveBody(
              child: SizedBox(key: Key('probe'), width: double.infinity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final probeBox = tester.getRect(find.byKey(const Key('probe')));
      expect(probeBox.left, 0.0);
    });

    testWidgets('adds horizontal padding on medium width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveBody(child: SizedBox(key: Key('probe'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final probeBox = tester.getRect(find.byKey(const Key('probe')));
      expect(probeBox.left, greaterThan(0));
    });

    testWidgets('constrains max width on expanded (tablet) width',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveBody(
              child: SizedBox(key: Key('probe'), width: double.infinity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final probeBox = tester.getRect(find.byKey(const Key('probe')));
      expect(probeBox.width, lessThanOrEqualTo(ResponsiveBody.maxContentWidth));
    });
  });

  group('deviceFormFactor', () {
    testWidgets('returns compact for narrow viewport', (tester) async {
      late DeviceFormFactor result;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(375, 812)),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                result = deviceFormFactor(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(result, DeviceFormFactor.compact);
    });

    testWidgets('returns medium for mid-range viewport', (tester) async {
      late DeviceFormFactor result;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(700, 1024)),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                result = deviceFormFactor(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(result, DeviceFormFactor.medium);
    });

    testWidgets('returns expanded for wide viewport', (tester) async {
      late DeviceFormFactor result;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1200, 900)),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                result = deviceFormFactor(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(result, DeviceFormFactor.expanded);
    });
  });
}
