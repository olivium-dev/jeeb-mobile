import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _arabicGoldenFontFamily = 'NotoSansArabicGolden';

Future<void> loadInterTestFont() async {
  for (final asset in <String>[
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]) {
    final bytes = await rootBundle.load(asset);
    await (FontLoader('Inter')..addFont(Future.value(bytes))).load();
  }

  // Flutter's golden test binding does not register Material Icons. Load the
  // font from the active SDK cache, matching Flutter's own icon golden tests,
  // so icon glyphs render deterministically rather than as tofu squares.
  final materialIcons = _flutterMaterialIconsFont();
  final materialIconBytes = await materialIcons.readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(materialIconBytes)))).load();

  // Deterministic SIL-OFL Noto Sans Arabic subset containing only glyphs used
  // by these goldens. It is a distinct fallback family because Inter's regular
  // face wins weight matching before glyph fallback within the same family.
  final encoded = File(
    'test/support/fonts/noto_sans_arabic_golden.b64',
  ).readAsStringSync().trim();
  final arabicBytes = base64Decode(encoded);
  await (FontLoader(
    _arabicGoldenFontFamily,
  )..addFont(Future.value(ByteData.sublistView(arabicBytes)))).load();
}

/// Adds the deterministic Arabic family to every Material text role used by
/// the golden harness while preserving the production Inter primary family.
ThemeData withGoldenTestFonts(ThemeData theme) {
  const fallback = <String>[_arabicGoldenFontFamily];
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamilyFallback: fallback,
    ),
  );
}

File _flutterMaterialIconsFont() {
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  if (configuredRoot != null) {
    final configured = File(
      '$configuredRoot/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    );
    if (configured.existsSync()) return configured;
  }

  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final candidate = File(
      '${directory.path}/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    );
    if (candidate.existsSync()) return candidate;
    directory = directory.parent;
  }
  throw StateError(
    'MaterialIcons-Regular.otf was not found in the Flutter SDK',
  );
}
