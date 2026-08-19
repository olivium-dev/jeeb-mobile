import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dev Tool uses an independently launchable activity and task', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/app/jeeb/mobile/MainActivity.kt',
    ).readAsStringSync();
    final devToolActivity = File(
      'android/app/src/main/kotlin/app/jeeb/mobile/DevToolActivity.kt',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".DevToolActivity"'));
    expect(
      manifest,
      contains('android:taskAffinity="\${applicationId}.devtool"'),
    );
    expect(manifest, contains('android:launchMode="singleTask"'));
    expect(manifest, isNot(contains('<activity-alias')));
    expect(mainActivity, contains('open class MainActivity'));
    expect(devToolActivity, contains('class DevToolActivity : MainActivity()'));
    expect(
      devToolActivity,
      contains('override fun getInitialRoute(): String = "/devtool"'),
    );
  });
}
