import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Auto-discovered by `flutter test` and applied to every test in this
/// directory. We disable google_fonts' runtime fetching so test widgets
/// don't attempt outbound HTTP calls (which the test binding blocks with
/// status 400 anyway) — without this, screens that rebuild while a font
/// is mid-load can drop their entire subtree and break interaction tests.
///
/// We also stub the `flutter_secure_storage` platform channel so any screen
/// that reads the session (e.g. the saved-locations picker resolving the
/// authenticated user id via [AuthTokenStore], iter6 DEFECT-A) gets a clean
/// `null` instead of a `MissingPluginException` in widget tests that don't
/// inject/mock the store explicitly. Reads return null; writes/deletes no-op.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async {
    switch (call.method) {
      case 'read':
        return null;
      case 'readAll':
        return <String, String>{};
      case 'containsKey':
        return false;
      default:
        // write / delete / deleteAll / etc. — no-op in tests.
        return null;
    }
  });

  await testMain();
}
