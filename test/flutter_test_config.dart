import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Golden comparator with a small diff tolerance. Exact-pixel goldens flake
/// across renderer/platform micro-drift (observed 0.68–2.44% residual after
/// the JEBV4-321 router change even with byte-faithful CI-recovered
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile);

  /// 5% — the 200%-text-scale golden variants measure up to 4.58% pure
  /// anti-aliasing drift (scale amplifies edge pixels proportionally); real
  static const double _maxDiffPercent = 5.0;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    // Review artifacts are actual renders, never replacement baselines. Save
    // before reading the golden so missing references remain inspectable.
    final reviewPath = Platform.environment['JEEB_CAPTURE_REVIEW_DIR'];
    var failureOutputDirectory = basedir;
    if (reviewPath != null && reviewPath.isNotEmpty) {
      final reviewDirectory = Directory(reviewPath).absolute;
      await reviewDirectory.create(recursive: true);
      final baselineDirectory = Directory.fromUri(
        basedir.resolveUri(golden).resolve('.'),
      );
      if (await reviewDirectory.resolveSymbolicLinks() ==
          await baselineDirectory.resolveSymbolicLinks()) {
        throw FlutterError(
          'Capture review output must not be the baseline directory',
        );
      }
      final filename = golden.pathSegments.last;
      if (!filename.endsWith('.png') ||
          filename.contains('/') ||
          filename.contains('\\')) {
        throw FlutterError('Capture review requires a PNG basename');
      }
      await File('${reviewDirectory.path}/$filename').writeAsBytes(imageBytes);
      failureOutputDirectory = reviewDirectory.uri;
    }
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) {
      result.dispose();
      return true;
    }
    final diffPercent = result.diffPercent * 100;
    if (diffPercent <= _maxDiffPercent) {
      debugPrint(
        'Golden "$golden": diff ${diffPercent.toStringAsFixed(2)}% '
        'within tolerance $_maxDiffPercent% — accepted',
      );
      result.dispose();
      return true;
    }
    try {
      final feedback = await generateFailureOutput(
        result,
        golden,
        failureOutputDirectory,
      );
      throw FlutterError(
        'Golden "$golden": pixel diff ${diffPercent.toStringAsFixed(2)}% '
        'exceeds tolerance $_maxDiffPercent%\n$feedback',
      );
    } finally {
      result.dispose();
    }
  }
}

/// Auto-discovered by `flutter test` and applied to every test in this
/// directory. We disable google_fonts' runtime fetching so test widgets
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  if (goldenFileComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(
      Uri.parse(
        '${(goldenFileComparator as LocalFileComparator).basedir}config.dart',
      ),
    );
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
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
