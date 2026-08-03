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

  final materialIcons = _flutterMaterialIconsFont();
  final materialIconBytes = await materialIcons.readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(materialIconBytes)))).load();

  final encoded = File(
    'test/support/fonts/noto_sans_arabic_golden.b64',
  ).readAsStringSync().trim();
  final arabicBytes = base64Decode(encoded);
  await (FontLoader(
    _arabicGoldenFontFamily,
  )..addFont(Future.value(ByteData.sublistView(arabicBytes)))).load();
}

/// Adds the deterministic Arabic family to every Material text
ThemeData withGoldenTestFonts(ThemeData theme) {
  const fallback = <String>[_arabicGoldenFontFamily];
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamilyFallback: fallback,
    ),
  );
}

/// The Arabic brand face, loaded from `test/support/fonts/` because the ramp's
/// own fallback list names it and Inter carries no Arabic.
const String captureArabicFallbackFamily = 'Noto Naskh Arabic';

/// `jeebFontFamilyFallback` plus the Arabic test face.
const List<String> captureFontFamilyFallback = <String>[
  'Baloo Bhaijaan 2',
  captureArabicFallbackFamily,
  'Apple Color Emoji',
  'Noto Color Emoji',
];

/// The ONLY emoji face that paints under `flutter test`: the committed
/// `NotoColorEmoji.ttf` is CBDT/CBLC and a COLRv1 build inks nothing.
const String _macEmojiFont = '/System/Library/Fonts/Apple Color Emoji.ttc';

/// Everything [loadInterTestFont] loads, plus the faces a screen-catalog
/// capture needs to be honest: Inter w800, the Arabic brand face, and emoji.
Future<void> loadCatalogCaptureFonts() async {
  await loadInterTestFont();

  await _loadAsset('Inter', 'assets/fonts/Inter-ExtraBold.ttf');
  for (final asset in <String>[
    'assets/fonts/BalooBhaijaan2-Medium.ttf',
    'assets/fonts/BalooBhaijaan2-SemiBold.ttf',
    'assets/fonts/BalooBhaijaan2-Bold.ttf',
  ]) {
    await _loadAsset('Baloo Bhaijaan 2', asset);
  }

  await _loadFile(
    captureArabicFallbackFamily,
    'test/support/fonts/NotoNaskhArabic-Regular.ttf',
  );
  if (File(_macEmojiFont).existsSync()) {
    await _loadFile('Apple Color Emoji', _macEmojiFont);
  }
}

/// Puts [captureFontFamilyFallback] behind every Material text style. The Jeeb
/// ramp carries its own fallback list; this covers what omds/Material draw.
ThemeData withCaptureTestFonts(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(
    fontFamilyFallback: captureFontFamilyFallback,
  ),
  primaryTextTheme: theme.primaryTextTheme.apply(
    fontFamilyFallback: captureFontFamilyFallback,
  ),
);

Future<void> _loadAsset(String family, String asset) async {
  final bytes = await rootBundle.load(asset);
  await (FontLoader(family)..addFont(Future.value(bytes))).load();
}

Future<void> _loadFile(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('capture harness font missing: $path');
  }
  final bytes = ByteData.sublistView(file.readAsBytesSync());
  await (FontLoader(family)..addFont(Future.value(bytes))).load();
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
