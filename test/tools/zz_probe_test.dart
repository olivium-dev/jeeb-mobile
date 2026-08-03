@Tags(<String>['capture'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_test_fonts.dart';

const Map<String, String> _candidates = <String, String>{
  'EngineNoto': 'test/support/fonts/NotoColorEmoji.ttf',
  'LayoutlibNoto':
      '/Users/oudaykhaled/.gradle/caches/9.4.1/transforms/'
          '88d3072557ef340052b85eca710b7cb8/transformed/'
          'layoutlib-runtime-15.2.3-mac-arm/data/fonts/NotoColorEmoji.ttf',
  'AppleEmoji': '/System/Library/Fonts/Apple Color Emoji.ttc',
  'AppleSymbols': '/System/Library/Fonts/Apple Symbols.ttf',
  'ArialUnicode': '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
};

double _w(String text, String family, {List<String>? fb}) {
  final TextPainter p = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: family, fontFamilyFallback: fb, fontSize: 24),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final double w = p.width;
  p.dispose();
  return w;
}

Future<bool> _load(String family, String path) async {
  final File f = File(path);
  if (!f.existsSync()) {
    // ignore: avoid_print
    print('$family MISSING $path');
    return false;
  }
  try {
    final Uint8List raw = f.readAsBytesSync();
    await (FontLoader(family)
          ..addFont(Future<ByteData>.value(ByteData.sublistView(raw))))
        .load();
    return true;
  } on Object catch (e) {
    // ignore: avoid_print
    print('$family load FAILED: $e');
    return false;
  }
}

void main() {
  final List<String> loaded = <String>[];
  setUpAll(() async {
    await loadInterTestFont();
    for (final MapEntry<String, String> e in _candidates.entries) {
      if (await _load(e.key, e.value)) loaded.add(e.key);
    }
    // ignore: avoid_print
    print('loaded: $loaded');
  });

  testWidgets('metrics', (WidgetTester tester) async {
    for (final String fam in loaded) {
      // ignore: avoid_print
      print('$fam: bolt=${_w('⚡', fam)} rocket=${_w('\u{1F680}', fam)} '
          'herb=${_w('\u{1F33F}', fam)} nonchar=${_w('\u{10FFFF}', fam)} '
          'A=${_w('A', fam)}');
      // ignore: avoid_print
      print('  as-fallback-of-Inter: bolt=${_w('⚡', 'Inter', fb: <String>[fam])} '
          'rocket=${_w('\u{1F680}', 'Inter', fb: <String>[fam])} '
          'nonchar=${_w('\u{10FFFF}', 'Inter', fb: <String>[fam])}');
    }
  });

  testWidgets('render', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (final String fam in loaded)
                  Text(
                    '$fam ⚡\u{1F680}\u{1F33F}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontFamilyFallback: <String>[fam],
                      fontSize: 26,
                      color: Colors.black,
                    ),
                  ),
                for (final String fam in loaded)
                  Text(
                    'direct ⚡\u{1F680}\u{1F33F}',
                    style: TextStyle(
                      fontFamily: fam,
                      fontSize: 26,
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final RenderRepaintBoundary b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image img = await b.toImage();
      final ByteData? bytes =
          await img.toByteData(format: ui.ImageByteFormat.png);
      File(
        '/private/tmp/claude-501/-Users-oudaykhaled-Desktop-olivium-jeeb/'
        '54d8f9c3-940c-4808-878f-fe3f841a5ef3/scratchpad/emoji_probe.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('wrote emoji_probe.png');
  });
}
