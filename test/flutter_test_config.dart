import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Auto-discovered by `flutter test` and applied to every test in this
/// directory. We disable google_fonts' runtime fetching so test widgets
/// don't attempt outbound HTTP calls (which the test binding blocks with
/// status 400 anyway) — without this, screens that rebuild while a font
/// is mid-load can drop their entire subtree and break interaction tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
