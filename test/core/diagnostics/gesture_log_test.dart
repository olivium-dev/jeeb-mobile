import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/gesture_log.dart';

/// Wraps [child] in the root gesture listener with a fixed devicePixelRatio so
/// device-pixel coordinate emission is deterministic under test.
Widget _harness(Widget child) => GestureLogListener(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: Center(child: child),
        ),
      ),
    );

/// A Semantics-identified, tappable box (mimics a real button's identity).
Widget _tappable({required String id, required String text}) => Semantics(
      identifier: id,
      label: text,
      child: GestureDetector(
        onTap: () {},
        child: SizedBox(width: 120, height: 48, child: Text(text)),
      ),
    );

void main() {
  late List<String> lines;

  setUp(() {
    lines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = lines.add;
    GestureLog.instance.enabled = true;
  });

  tearDown(() {
    Diag.resetForTest();
    GestureLog.instance.enabled = false;
  });

  String gestureLine() =>
      lines.firstWhere((l) => l.contains('"t":"gesture"'), orElse: () => '');

  group('Diag.gesture wire shape', () {
    test('emits a flat [jeeb-diag] gesture record with stable keys', () {
      Diag.gesture(
        type: 'tap',
        x: 540,
        y: 1188,
        screen: '/orders/:id',
        id: 'accept_offer',
        text: 'Accept',
        target: 'ElevatedButton',
        key: 'acceptBtn',
      );
      expect(lines, hasLength(1));
      expect(
        lines.single,
        startsWith(
          '[jeeb-diag] {"t":"gesture","type":"tap","x":540,"y":1188,'
          '"screen":"/orders/:id","id":"accept_offer","text":"Accept",'
          '"target":"ElevatedButton","key":"acceptBtn"',
        ),
      );
    });

    test('is a no-op when the diag stream is disabled', () {
      Diag.enabledOverride = false;
      Diag.gesture(type: 'tap', x: 1, y: 1);
      expect(lines, isEmpty);
    });
  });

  group('GestureLogListener', () {
    testWidgets('a tap emits one record with semantics id + visible text',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(_tappable(id: 'submit_btn', text: 'Submit')),
      );
      await tester.tap(find.text('Submit'));
      await tester.pump();

      final line = gestureLine();
      expect(line, contains('"type":"tap"'));
      expect(line, contains('"id":"submit_btn"'));
      expect(line, contains('"text":"Submit"'));
      handle.dispose();
    });

    testWidgets('a drag beyond the move threshold classifies as swipe',
        (tester) async {
      await tester.pumpWidget(
        _harness(_tappable(id: 'row', text: 'Row')),
      );
      await tester.drag(find.text('Row'), const Offset(80, 0));
      await tester.pump();
      expect(gestureLine(), contains('"type":"swipe"'));
    });

    testWidgets('a secret-length caption word is redacted, not logged verbatim',
        (tester) async {
      const secret = 'eyJhbGciOiJIUzI1NiJ9leak';
      await tester.pumpWidget(
        _harness(_tappable(id: 'copy', text: secret)),
      );
      await tester.tap(find.text(secret));
      await tester.pump();

      final line = gestureLine();
      expect(line, isNot(contains(secret)));
      expect(line, contains('"text":"tok:'));
    });

    testWidgets('emits nothing while the toggle is OFF', (tester) async {
      GestureLog.instance.enabled = false;
      await tester.pumpWidget(
        _harness(_tappable(id: 'submit_btn', text: 'Submit')),
      );
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(gestureLine(), isEmpty);
    });
  });
}
