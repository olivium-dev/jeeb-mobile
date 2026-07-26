import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';

void main() {
  tearDown(AppLifecycleGate.debugReset);

  test('always-foreground gate is inert and fails open', () {
    const gate = AlwaysForegroundAppLifecycleGate();
    final notifications = <bool>[];

    gate.addForegroundListener(notifications.add);
    gate.removeForegroundListener(notifications.add);

    expect(gate.isForeground, isTrue);
    expect(notifications, isEmpty);
  });

  test('manual gate notifies synchronously only for real transitions', () {
    final gate = ManualAppLifecycleGate();
    final notifications = <bool>[];
    gate.addForegroundListener(notifications.add);

    gate
      ..setForeground(true)
      ..setForeground(false)
      ..setForeground(false)
      ..setForeground(true);

    expect(notifications, <bool>[false, true]);
    gate.removeForegroundListener(notifications.add);
  });

  test('manual gate tolerates listener removal during notification', () {
    final gate = ManualAppLifecycleGate();
    final notifications = <String>[];

    void first(bool value) {
      notifications.add('first:$value');
      gate.removeForegroundListener(first);
    }

    void second(bool value) {
      notifications.add('second:$value');
    }

    gate
      ..addForegroundListener(first)
      ..addForegroundListener(second)
      ..setForeground(false)
      ..setForeground(true);

    expect(notifications, <String>[
      'first:false',
      'second:false',
      'second:true',
    ]);
  });

  test('ambient identity and listener survive a late install', () {
    final beforeInstall = AppLifecycleGate.instance;
    final notifications = <bool>[];
    beforeInstall.addForegroundListener(notifications.add);
    final source = ManualAppLifecycleGate(isForeground: false);

    AppLifecycleGate.install(source);

    expect(AppLifecycleGate.instance, same(beforeInstall));
    expect(beforeInstall.isForeground, isFalse);
    expect(notifications, <bool>[false]);

    source.setForeground(true);
    expect(notifications, <bool>[false, true]);

    beforeInstall.removeForegroundListener(notifications.add);
    expect(AppLifecycleGate.debugListenerCount, isZero);
  });

  test('install is idempotent and debugReset returns to fail-open', () {
    final source = ManualAppLifecycleGate(isForeground: false);
    final notifications = <bool>[];
    AppLifecycleGate.instance.addForegroundListener(notifications.add);

    AppLifecycleGate.install(source);
    AppLifecycleGate.install(source);
    source.setForeground(true);
    source.setForeground(false);
    AppLifecycleGate.debugReset();

    expect(notifications, <bool>[false, true, false, true]);
    expect(AppLifecycleGate.instance.isForeground, isTrue);

    AppLifecycleGate.instance.removeForegroundListener(notifications.add);
  });

  testWidgets('binding gate maps only resumed to foreground', (tester) async {
    final gate = WidgetsBindingAppLifecycleGate();
    final notifications = <bool>[];
    gate.addForegroundListener(notifications.add);

    for (final state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      gate.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(gate.isForeground, isTrue);

      gate.didChangeAppLifecycleState(state);
      expect(gate.isForeground, isFalse, reason: '$state is background');

      gate.didChangeAppLifecycleState(state);
    }

    expect(notifications, <bool>[false, true, false, true, false, true, false]);

    gate.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('binding gate forwards through the ambient gate', (tester) async {
    final source = WidgetsBindingAppLifecycleGate();
    final ambient = AppLifecycleGate.instance;
    final notifications = <bool>[];
    ambient.addForegroundListener(notifications.add);
    AppLifecycleGate.install(source);

    source.didChangeAppLifecycleState(AppLifecycleState.inactive);
    source.didChangeAppLifecycleState(AppLifecycleState.inactive);
    source.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(notifications, <bool>[false, true]);
    expect(ambient.isForeground, isTrue);

    ambient.removeForegroundListener(notifications.add);
    AppLifecycleGate.debugReset();
    source.dispose();
    expect(AppLifecycleGate.debugListenerCount, isZero);
    expect(tester.takeException(), isNull);
  });
}
