import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/capture/obs_interaction_observer.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/secret_redactor.dart';

/// Requires `flutter test --dart-define=JEEB_DEVTOOL_ENABLED=true …` to
/// exercise the `skip:`-guarded groups below — [kObsCompiledIn] is a hard
String get _needsDevtoolDefine =>
    'requires --dart-define=JEEB_DEVTOOL_ENABLED=true';

class _FakeSink implements ObservabilitySink {
  final List<ObsEvent> events = <ObsEvent>[];

  @override
  void add(ObsEvent event, {bool flushNow = false}) => events.add(event);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  String? get sessionFilePath => null;
}

/// Routes a synthetic tap-family (down→up) gesture straight through the
/// REAL global pointer router — the exact path [ObsInteractionObserver]
void _sendTap(
  Offset position, {
  int pointer = 1,
  Duration downAt = Duration.zero,
  Duration? upAt,
  Offset? upPosition,
}) {
  final router = GestureBinding.instance.pointerRouter;
  router.route(
    PointerDownEvent(pointer: pointer, position: position, timeStamp: downAt),
  );
  router.route(PointerUpEvent(
    pointer: pointer,
    position: upPosition ?? position,
    timeStamp: upAt ?? downAt,
  ));
}

List<ObsInteractionEvent> _interactions(_FakeSink sink) =>
    sink.events.cast<ObsInteractionEvent>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSink sink;
  final observer = ObsInteractionObserver.instance;

  setUp(() {
    sink = _FakeSink();
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
    Observability.instance.sink = sink;
    observer.resetForTest();
  });

  tearDown(() {
    observer.uninstall();
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  test('install()/uninstall() are idempotent and safe even pre-install', () {
    observer.uninstall(); // never installed — must not throw
    expect(observer.isInstalled, isFalse);

    observer.install();
    final installedOnce = observer.isInstalled;
    observer.install(); // second call must not throw (no double-add assert)
    expect(observer.isInstalled, installedOnce);

    observer.uninstall();
    expect(observer.isInstalled, isFalse);
    observer.uninstall(); // second call must not throw
  });

  test('install()/uninstall() add and remove exactly one global pointer '
      'route, regardless of kObsCompiledIn', () {
    final router = GestureBinding.instance.pointerRouter;
    final baseline = router.debugGlobalRouteCount;

    observer.install();
    expect(
      router.debugGlobalRouteCount,
      kObsCompiledIn ? baseline + 1 : baseline,
    );

    observer.uninstall();
    expect(router.debugGlobalRouteCount, baseline);
  });

  test('emits nothing when not recording, even while installed '
      '(zero-cost no-op)', () {
    observer.install();
    ObservabilityConfig.instance.enabled = false;
    _sendTap(const Offset(10, 10));
    expect(sink.events, isEmpty);
  });

  group('pointer classification (compiled-in)', () {
    setUp(() {
      ObservabilityConfig.instance.enabled = true;
      observer.install();
    });

    test(
      'a quick, still tap emits gesture=tap at the down position',
      () {
        _sendTap(const Offset(100, 200));

        expect(sink.events, hasLength(1));
        final event = _interactions(sink).single;
        expect(event.gesture, 'tap');
        expect(event.dx, 100);
        expect(event.dy, 200);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'a pointer held past the long-press threshold emits long_press',
      () {
        _sendTap(const Offset(10, 10), upAt: kLongPressTimeout);
        expect(_interactions(sink).single.gesture, 'long_press');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'travel beyond touch slop emits drag, not tap',
      () {
        final router = GestureBinding.instance.pointerRouter;
        const start = Offset.zero;
        const dragged = Offset(kTouchSlop * 2, 0);
        router.route(const PointerDownEvent(pointer: 1, position: start));
        router.route(const PointerMoveEvent(pointer: 1, position: dragged));
        router.route(const PointerUpEvent(pointer: 1, position: dragged));

        expect(_interactions(sink).single.gesture, 'drag');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'two quick, close taps classify as tap then double_tap',
      () {
        _sendTap(const Offset(50, 50));
        _sendTap(
          const Offset(52, 52),
          downAt: const Duration(milliseconds: 100),
          upAt: const Duration(milliseconds: 100),
        );

        final events = _interactions(sink);
        expect(events, hasLength(2));
        expect(events[0].gesture, 'tap');
        expect(events[1].gesture, 'double_tap');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'a tap after the double-tap window stays a plain tap',
      () {
        _sendTap(const Offset(50, 50));
        final justAfter = kDoubleTapTimeout + const Duration(milliseconds: 1);
        _sendTap(const Offset(52, 52), downAt: justAfter, upAt: justAfter);

        final events = _interactions(sink);
        expect(events, hasLength(2));
        expect(events[1].gesture, 'tap');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'a tap far away shortly after another stays a plain tap '
      '(double-tap distance slop)',
      () {
        _sendTap(const Offset(50, 50));
        _sendTap(
          const Offset(50 + kDoubleTapSlop * 2, 50),
          downAt: const Duration(milliseconds: 50),
          upAt: const Duration(milliseconds: 50),
        );

        final events = _interactions(sink);
        expect(events, hasLength(2));
        expect(events[1].gesture, 'tap');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'pointer cancel drops pending state without emitting',
      () {
        final router = GestureBinding.instance.pointerRouter;
        router.route(
          const PointerDownEvent(pointer: 1, position: Offset(1, 1)),
        );
        router.route(const PointerCancelEvent(pointer: 1));

        expect(sink.events, isEmpty);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'concurrent pointers classify independently',
      () {
        final router = GestureBinding.instance.pointerRouter;
        const p2Start = Offset(500, 500);
        const p2Dragged = Offset(500 + kTouchSlop * 3, 500);
        router.route(const PointerDownEvent(pointer: 1, position: Offset.zero));
        router.route(const PointerDownEvent(pointer: 2, position: p2Start));
        router.route(const PointerMoveEvent(pointer: 2, position: p2Dragged));
        router.route(const PointerUpEvent(pointer: 1, position: Offset.zero));
        router.route(const PointerUpEvent(pointer: 2, position: p2Dragged));

        final events = _interactions(sink);
        expect(events, hasLength(2));
        expect(events[0].gesture, 'tap');
        expect(events[1].gesture, 'drag');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'captureInteractions=false suppresses emission (per-signal toggle)',
      () {
        ObservabilityConfig.instance.captureInteractions = false;
        _sendTap(const Offset(1, 1));
        expect(sink.events, isEmpty);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'screen reflects Observability.currentScreen at emit time',
      () {
        Observability.instance.currentScreen = '/checkout';
        _sendTap(const Offset(1, 1));
        expect(_interactions(sink).single.screen, '/checkout');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'with no semantics tree present, target resolution degrades to null '
      'without throwing',
      () {
        _sendTap(const Offset(1, 1));
        final event = _interactions(sink).single;
        expect(event.targetId, isNull);
        expect(event.targetLabel, isNull);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );
  });

  group('semantics-tree target resolution (compiled-in, widget-backed)', () {
    setUp(() {
      ObservabilityConfig.instance.enabled = true;
      observer.install();
    });

    testWidgets(
      'tapping a labeled/identified semantics target resolves both, '
      'redacting a secret-shaped label',
      (tester) async {
        // Disposed synchronously at the end of THIS test body (not via
        final handle = tester.ensureSemantics();
        const secretLabel = 'Submit Bearer abc123def456ghi789jkl012';

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'submit-button',
                label: secretLabel,
                container: true,
                child: const SizedBox(
                  key: Key('target'),
                  width: 48,
                  height: 48,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ));

        await tester.tap(find.byKey(const Key('target')));
        await tester.pump();

        final event = _interactions(sink).single;
        expect(event.gesture, 'tap');
        expect(event.targetId, 'submit-button');
        expect(event.targetLabel, isNotNull);
        expect(event.targetLabel, isNot(contains('abc123def456ghi789jkl012')));

        handle.dispose();
      },
      skip: !kObsCompiledIn,
    );
  });

  group('focus-based text_focus / text_submit (compiled-in, widget-backed)', () {
    setUp(() {
      ObservabilityConfig.instance.enabled = true;
      observer.install();
    });

    testWidgets(
      'focusing a text field emits text_focus with its redacted label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final fields = await _LoginForm.pump(tester);

        fields.email.requestFocus();
        await tester.pump();

        final event = _interactions(sink).single;
        expect(event.gesture, 'text_focus');
        expect(event.targetLabel, contains('Email'));
        expect(event.valuePreview, isNull);

        await fields.disposeCleanly(tester);
        handle.dispose();
      },
      skip: !kObsCompiledIn,
    );

    testWidgets(
      'moving focus away emits text_submit for the field just left',
      (tester) async {
        final handle = tester.ensureSemantics();
        final fields = await _LoginForm.pump(tester);

        fields.email.requestFocus();
        await tester.pump();
        fields.password.requestFocus();
        await tester.pump();

        final events = _interactions(sink);
        final submit = events.firstWhere((e) => e.gesture == 'text_submit');
        expect(submit.targetLabel, contains('Email'));
        final focusEvents = events.where((e) => e.gesture == 'text_focus');
        expect(focusEvents, hasLength(2));

        await fields.disposeCleanly(tester);
        handle.dispose();
      },
      skip: !kObsCompiledIn,
    );

    testWidgets(
      'an obscured field always previews as <redacted>, never a length or '
      'raw characters',
      (tester) async {
        final handle = tester.ensureSemantics();
        final fields = await _LoginForm.pump(tester);

        fields.password.requestFocus();
        await tester.pump();
        await tester.enterText(find.byType(TextField).last, 'hunter2');
        // A settle frame so the semantics tree reflects the new text BEFORE
        await tester.pump();
        fields.email.requestFocus();
        await tester.pump();

        final submit = _interactions(sink)
            .firstWhere((e) => e.gesture == 'text_submit');
        expect(submit.valuePreview, SecretRedactor.redacted);

        await fields.disposeCleanly(tester);
        handle.dispose();
      },
      skip: !kObsCompiledIn,
    );

    testWidgets(
      'a non-obscured field previews only a length — never the entered '
      'characters',
      (tester) async {
        final handle = tester.ensureSemantics();
        final fields = await _LoginForm.pump(tester);

        fields.email.requestFocus();
        await tester.pump();
        await tester.enterText(find.byType(TextField).first, 'hello');
        // A settle frame so the semantics tree reflects the new text BEFORE
        await tester.pump();
        fields.password.requestFocus();
        await tester.pump();

        final submit = _interactions(sink)
            .firstWhere((e) => e.gesture == 'text_submit');
        expect(submit.valuePreview, isNotNull);
        expect(submit.valuePreview, isNot(contains('hello')));
        expect(submit.valuePreview, '5 chars');

        await fields.disposeCleanly(tester);
        handle.dispose();
      },
      skip: !kObsCompiledIn,
    );
  });
}

/// A tiny email/password form used only by the focus-based tests. Bundles
/// its externally-owned [FocusNode]s so each test can request focus
/// directly (bypassing pointer taps, which would ALSO emit a confounding
class _LoginForm {
  const _LoginForm(this.email, this.password);

  final FocusNode email;
  final FocusNode password;

  static Future<_LoginForm> pump(WidgetTester tester) async {
    final form = _LoginForm(
      FocusNode(debugLabel: 'email'),
      FocusNode(debugLabel: 'password'),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          TextField(
            focusNode: form.email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            focusNode: form.password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        ]),
      ),
    ));
    return form;
  }

  /// Unfocuses both nodes and pumps BEFORE disposing, so `dispose()`'s
  /// internal `unfocus()` cascade has nothing pending to notify — disposing
  Future<void> disposeCleanly(WidgetTester tester) async {
    email.unfocus();
    password.unfocus();
    await tester.pump();
    email.dispose();
    password.dispose();
  }
}
