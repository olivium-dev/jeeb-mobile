// The create capsule's rotating typed hint.
//
// The capsule is a PINNED layer inside the shell's IndexedStack, so the two
// things pinned here are the reduce-motion still (no ticker at all, which is
// also what lets every existing `pumpAndSettle` harness terminate) and the fact
// that the run advances on its own clock without ever growing past one line.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_typed_hint.dart';

const List<String> _en = <String>['Alpha', 'Beta'];
const List<String> _ar = <String>['كيلوين بندورة', 'شاحن تلفون'];
const Color _accent = Color(0xFFFF6A2B);
const TextStyle _style = TextStyle(fontSize: 18);

/// One full round of 'Alpha' (5 chars): 350 type + 1800 hold + 200 delete +
/// 350 gap.
const Duration _alphaCycle = Duration(milliseconds: 2700);

Widget _host({
  List<String> examples = _en,
  bool reduceMotion = false,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  double width = 240,
}) {
  return MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: Directionality(
      textDirection: direction,
      child: Center(
        child: SizedBox(
          width: width,
          child: ClientHomeTypedHint(
            examples: examples,
            restLabel: 'Type it',
            style: _style,
            caretColor: _accent,
          ),
        ),
      ),
    ),
  );
}

/// The run as a reader sees it, caret included.
String _visible(WidgetTester tester) {
  final Text text = tester.widget<Text>(find.byType(Text));
  return text.data ?? text.textSpan!.toPlainText();
}

String _run(WidgetTester tester) =>
    _visible(tester).replaceAll(ClientHomeTypedHint.caretGlyph, '');

bool _hasCaret(WidgetTester tester) =>
    _visible(tester).contains(ClientHomeTypedHint.caretGlyph);

void main() {
  testWidgets('reduce motion shows the stable label and settles', (
    tester,
  ) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    // The pin: a perpetual ticker here would hang every existing client-home
    // harness, all of which settle.
    await tester.pumpAndSettle();

    expect(find.text('Type it'), findsOneWidget);
    expect(_hasCaret(tester), isFalse);
  });

  testWidgets('the first example types itself out one character at a time', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(_run(tester), 'A');

    await tester.pump(ClientHomeTypedHint.typeStep * 2);
    expect(_run(tester), 'Alp');

    await tester.pump(ClientHomeTypedHint.typeStep * 2);
    expect(_run(tester), 'Alpha');
  });

  testWidgets('the caret rides the typing and the deleting, not the hold', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(_hasCaret(tester), isTrue, reason: 'typing');

    // 350ms types 'Alpha' out; the 1800ms hold starts there.
    await tester.pump(const Duration(milliseconds: 700));
    expect(_run(tester), 'Alpha');
    expect(_hasCaret(tester), isFalse, reason: 'holding');

    // 2150ms in, the deletion is running.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_run(tester).length, lessThan(5));
    expect(_hasCaret(tester), isTrue, reason: 'deleting');
  });

  testWidgets('the run rotates to the next example and wraps', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(_run(tester), 'A');

    await tester.pump(_alphaCycle);
    await tester.pump(const Duration(milliseconds: 30));
    expect(_run(tester), 'B', reason: 'the cycle must advance the example');

    await tester.pump(ClientHomeTypedHint.typeStep * 3);
    expect(_run(tester), 'Beta');

    // 'Beta' is 4 chars: 280 + 1800 + 160 + 350.
    await tester.pump(const Duration(milliseconds: 2590));
    await tester.pump(const Duration(milliseconds: 30));
    expect(_run(tester), 'A', reason: 'the list must wrap, not run out');
  });

  testWidgets('ar: the run shapes character by character under RTL', (
    tester,
  ) async {
    await tester.pumpWidget(_host(examples: _ar, direction: TextDirection.rtl));
    await tester.pump();
    expect(_run(tester), 'ك');

    await tester.pump(ClientHomeTypedHint.typeStep * 3);
    expect(_run(tester), 'كيلو');
    expect(tester.takeException(), isNull);
  });

  testWidgets('one line, ellipsized, at textScale 2.0 in a narrow slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(examples: <String>['Medicine from the pharmacy'], textScale: 2),
    );
    await tester.pump(const Duration(milliseconds: 1500));

    final Text text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    // An overflow is a test failure on its own; arriving here is the pin.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the animating run is its own repaint boundary', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(ClientHomeTypedHint),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });
}
