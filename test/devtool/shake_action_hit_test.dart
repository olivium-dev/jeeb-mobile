import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/app/app_restarter.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/shake/devtool_shake.dart';

const _pageActionKey = ValueKey('page-action');
const _pageListKey = ValueKey('page-list');

void main() {
  for (final banner in [false, true]) {
    for (final textScale in [1.0, 2.0]) {
      for (final label in ['Retry', 'Server URL']) {
        testWidgets(
          '$label is not intercepted; banner=$banner text=$textScale',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(320, 568);
            tester.view.padding = const FakeViewPadding(bottom: 24);
            tester.view.viewPadding = const FakeViewPadding(bottom: 24);
            addTearDown(tester.view.reset);
            var pageActions = 0;
            await tester.pumpWidget(
              AppRestarter(
                child: MaterialApp(
                  theme: AppTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: DevToolShakeHost(
                      initiallyOpen: true,
                      layerBuilder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Dev Tool')),
                        body: Column(
                          children: [
                            if (banner)
                              const SizedBox(
                                height: 48,
                                child: Text('Server URL override is active'),
                              ),
                            Expanded(
                              child: ListView(
                                key: _pageListKey,
                                padding: const EdgeInsets.only(bottom: 104),
                                children: [
                                  const SizedBox(height: 900),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: SizedBox(
                                      width: 220,
                                      child: ElevatedButton(
                                        key: _pageActionKey,
                                        onPressed: () => pageActions += 1,
                                        child: Text(label),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: child!,
                    ),
                  ),
                  home: const Scaffold(body: Text('Product')),
                ),
              ),
            );
            final hostState = tester.state(find.byType(DevToolShakeHost));
            await tester.drag(find.byKey(_pageListKey), const Offset(0, -1600));
            await tester.pumpAndSettle();
            final actionRect = tester.getRect(find.byKey(_pageActionKey));
            final applyRect = tester.getRect(find.byKey(kDevToolShakeApplyKey));
            final closeRect = tester.getRect(find.byKey(kDevToolShakeCloseKey));
            final listRect = tester.getRect(find.byKey(_pageListKey));
            await tester.tapAt(actionRect.center);
            await tester.pumpAndSettle();
            expect(
              pageActions,
              1,
              reason: 'The page action must receive the tap',
            );
            expect(find.byKey(kDevToolShakeLayerKey), findsOneWidget);
            expect(
              tester.state(find.byType(DevToolShakeHost)),
              same(hostState),
            );
            expect(actionRect.overlaps(applyRect), isFalse);
            expect(actionRect.overlaps(closeRect), isFalse);
            expect(listRect.bottom, lessThanOrEqualTo(applyRect.top));
            expect(closeRect.bottom, lessThanOrEqualTo(568 - 24));
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
