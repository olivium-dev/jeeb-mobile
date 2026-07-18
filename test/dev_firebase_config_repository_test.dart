import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const injectedConfig = 'android/app/src/dev/google-services.json';
  const safeTemplate = 'android/app/src/dev/google-services.json.template';

  test(
    'dev Firebase config is injected and only its safe template is retained',
    () async {
      final trackedFiles = await Process.run('git', const <String>[
        'ls-files',
        '--',
        injectedConfig,
      ]);
      final realPathIsRetained =
          (trackedFiles.stdout as String).trim().isNotEmpty &&
          File(injectedConfig).existsSync();
      expect(
        realPathIsRetained,
        isFalse,
        reason:
            'The real-path dev Firebase config must not be retained in VCS.',
      );
      expect(
        File(safeTemplate).existsSync(),
        isTrue,
        reason: 'Fresh clones need a committed safe template.',
      );

      final ignoreCheck = await Process.run('git', const <String>[
        'check-ignore',
        '--no-index',
        '--quiet',
        injectedConfig,
      ]);
      expect(
        ignoreCheck.exitCode,
        0,
        reason: 'The injected config path must be covered by .gitignore.',
      );

      final template = File(safeTemplate).readAsStringSync();
      expect(template, contains('app.jeeb.mobile.dev'));
      expect(template, contains('TODO_'));
      expect(template, isNot(contains('private_key')));
    },
  );
}
