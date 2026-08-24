import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  group('store entrypoint auth surface', () {
    test('the product entrypoint has no Dev Tool dependency graph', () {
      final productMain = _source('lib/main.dart');

      expect(productMain, isNot(contains('devtool/')));
      expect(productMain, isNot(contains('core/dev_flags.dart')));
      expect(productMain, isNot(contains('DevToolApp')));
    });

    test('shared product DI has no Super Login registration', () {
      final productDependencies = _source(
        'lib/core/di/injection_container.dart',
      );

      expect(productDependencies, isNot(contains('super_login')));
      expect(productDependencies, isNot(contains('SuperLoginService')));
      expect(productDependencies, isNot(contains('SuperLoginDemoUserService')));
    });

    test('the native product activity accepts no Super Login seam extras', () {
      final activity = _source(
        'android/app/src/main/kotlin/app/jeeb/mobile/MainActivity.kt',
      );

      expect(activity, isNot(contains('jeeb.seam.super_login_')));
    });

    test('developer auth stays behind its separate guarded entrypoint', () {
      final devMain = _source('lib/main_devtool.dart');
      final devShell = _source('lib/devtool/devtool_shell.dart');

      expect(devMain, contains("import 'core/dev_flags.dart';"));
      expect(devMain, contains('if (!kDevToolEnabled)'));
      expect(devMain, contains("import 'devtool/devtool_shell.dart';"));
      expect(devShell, contains('super_login_service.dart'));
      expect(devShell, contains('super_login_demo_user.dart'));
    });
  });
}
