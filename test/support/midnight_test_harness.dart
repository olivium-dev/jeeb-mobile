// The three frictions every Midnight-surface test rediscovers: motion that
// never settles, frameless fixture latency, and network images that touch IO.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Midnight motion primitives loop forever (02-STUDY-NOTES M0-4), so
/// `pumpAndSettle` terminates — and a capture is deterministic — only under
/// reduce motion. Call inside the `testWidgets` body, before `pumpWidget`.
void useReduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Reduce motion settles the tree on the first frame, so a fixture that lands
/// behind a latency (`InMemoryClientHomeRepository.latency`, and every Home
/// tree built on it) needs the clock advanced by hand first: that timer is
/// frameless, and `pumpAndSettle` never advances to it.
///
/// The fallback loop covers trees that still hold a live animation after
/// [latency] — `pumpAndSettle` throws there, and pumping fixed frames does not.
Future<void> pumpPastFakeLatency(
  WidgetTester tester, {
  Duration latency = const Duration(milliseconds: 400),
  Duration frame = const Duration(milliseconds: 120),
  int frames = 4,
}) async {
  await tester.pump(latency);
  try {
    await tester.pumpAndSettle(frame);
  } on Object {
    for (int f = 0; f < frames; f++) {
      await tester.pump(frame);
    }
  }
}

/// Any tree seeding a network image reaches `flutter_cache_manager`, which asks
/// `path_provider` for a cache dir and then — on macOS/iOS/Android hosts, per
/// its own `Config._createRepo` — sqflite for a database factory.
///
/// The path_provider half is a plain channel mock. The sqflite half is NOT:
/// `sqflite_common` checks `databaseFactory` before any channel call, so no
/// MethodChannel mock can satisfy it and only a real factory will do. The ffi
/// factory is dev-only and opens libsqlite3 lazily, so hosts that never reach
/// sqflite (Linux CI takes the `JsonCacheInfoRepository` branch) never load it.
///
/// Call from `setUpAll`.
void stubNetworkImageCacheIo() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final Directory dir = Directory.systemTemp.createTempSync('jeeb_image_cache');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => dir.path,
      );
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
