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

/// REAL-bug topology (proven by a Maestro hierarchy dump): a legacy OUTER
/// `Semantics(container: true, identifier: [outer])` — a button-style merge
Widget _buttonMergedIdentity({
  required String outer,
  required String inner,
  required String text,
}) =>
    Semantics(
      container: true,
      identifier: outer,
      child: Semantics(
        identifier: inner,
        child: GestureDetector(
          onTap: () {},
          child: SizedBox(width: 120, height: 48, child: Text(text)),
        ),
      ),
    );

/// Explicit-merge variant: a [MergeSemantics] boundary collapses the group into
/// one node whose `mergeAllDescendantsIntoThisNode` is TRUE. The OUTER id still
Widget _mergeSemanticsIdentity({
  required String outer,
  required String inner,
  required String text,
}) =>
    MergeSemantics(
      child: Semantics(
        identifier: outer,
        child: Semantics(
          identifier: inner,
          child: GestureDetector(
            onTap: () {},
            child: SizedBox(width: 120, height: 48, child: Text(text)),
          ),
        ),
      ),
    );

/// Both-exposed topology: two `container: true` boundaries keep the OUTER and
/// INNER identifiers as SEPARATE non-merged nodes — both visible to the a11y
Widget _bothExposedIdentity({
  required String outer,
  required String inner,
  required String text,
}) =>
    Semantics(
      container: true,
      identifier: outer,
      child: Semantics(
        container: true,
        identifier: inner,
        child: GestureDetector(
          onTap: () {},
          child: SizedBox(width: 120, height: 48, child: Text(text)),
        ),
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
    testWidgets(
        'holds a semantics handle only while logging is enabled',
        (tester) async {
      // Device-critical: an adb-injected tap has no accessibility service
      final binding = tester.binding;
      GestureLog.instance.enabled = false;
      await tester.pumpWidget(
        _harness(_tappable(id: 'submit_btn', text: 'Submit')),
      );
      final baseline = binding.debugOutstandingSemanticsHandles;

      GestureLog.instance.enabled = true;
      await tester.pump();
      expect(binding.debugOutstandingSemanticsHandles, baseline + 1,
          reason: 'hook must acquire one SemanticsHandle when logging turns on');

      GestureLog.instance.enabled = false;
      await tester.pump();
      expect(binding.debugOutstandingSemanticsHandles, baseline,
          reason: 'hook must release its SemanticsHandle when logging turns off');
    });

    testWidgets('a tap emits one record with semantics id + visible text',
        (tester) async {
      // No tester.ensureSemantics(): the hook forces the semantics tree itself.
      await tester.pumpWidget(
        _harness(_tappable(id: 'submit_btn', text: 'Submit')),
      );
      await tester.tap(find.text('Submit'));
      await tester.pump();

      final line = gestureLine();
      expect(line, contains('"type":"tap"'));
      expect(line, contains('"id":"submit_btn"'));
      expect(line, contains('"text":"Submit"'));
    });

    testWidgets(
        'a container boundary around a bare Semantics no longer folds it away, '
        'so the deepest exposed id wins', (tester) async {
      // Flutter <=3.38 absorbed the inner annotation into the outer container
      // node; since 3.40 an `identifier` always forces its own node.
      await tester.pumpWidget(
        _harness(_buttonMergedIdentity(
          outer: 'onboarding_next_button',
          inner: 'walkthrough_next_cta',
          text: 'Next',
        )),
      );
      await tester.tap(find.text('Next'));
      await tester.pump();

      final line = gestureLine();
      expect(line, contains('"id":"walkthrough_next_cta"'));
      expect(line, isNot(contains('"id":"onboarding_next_button"')));
      // id already IS the innermost annotation, so the breadcrumb is dropped.
      expect(line, isNot(contains('"idInner"')));
    });

    testWidgets(
        'MergeSemantics-merged nested Semantics also records the OUTER id',
        (tester) async {
      await tester.pumpWidget(
        _harness(_mergeSemanticsIdentity(
          outer: 'onboarding_next_button',
          inner: 'walkthrough_next_cta',
          text: 'Next',
        )),
      );
      await tester.tap(find.text('Next'));
      await tester.pump();

      final line = gestureLine();
      expect(line, contains('"id":"onboarding_next_button"'));
      expect(line, isNot(contains('"id":"walkthrough_next_cta"')));
    });

    testWidgets(
        'when BOTH ids stay exposed, records the nearest (deepest) exposed id',
        (tester) async {
      // Two non-merged boundaries ⇒ both ids are in the exposed tree; the hook
      await tester.pumpWidget(
        _harness(_bothExposedIdentity(
          outer: 'onboarding_next_button',
          inner: 'walkthrough_next_cta',
          text: 'Next',
        )),
      );
      await tester.tap(find.text('Next'));
      await tester.pump();

      final line = gestureLine();
      expect(line, contains('"id":"walkthrough_next_cta"'));
      expect(line, isNot(contains('"id":"onboarding_next_button"')));
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
