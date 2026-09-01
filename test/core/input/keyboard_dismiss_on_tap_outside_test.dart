import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/input/keyboard_dismiss_on_tap_outside.dart';

const _firstFieldKey = Key('first-field');
const _secondFieldKey = Key('second-field');
const _backgroundKey = Key('background');

void _ignorePointer(PointerDownEvent event) {}

class _HitTestBackground extends StatelessWidget {
  const _HitTestBackground({super.key});

  @override
  Widget build(BuildContext context) => const Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _ignorePointer,
    child: SizedBox.expand(),
  );
}

Widget _formHarness({
  required FocusNode firstFocus,
  required FocusNode secondFocus,
  required TextEditingController firstController,
  VoidCallback? onPressed,
}) {
  return MaterialApp(
    home: keyboardDismissOnTapOutside(
      child: Scaffold(
        body: Column(
          children: [
            TextField(
              key: _firstFieldKey,
              focusNode: firstFocus,
              controller: firstController,
            ),
            TextField(key: _secondFieldKey, focusNode: secondFocus),
            ElevatedButton(
              key: const Key('child-button'),
              onPressed: onPressed,
              child: const Text('Continue'),
            ),
            const Expanded(child: _HitTestBackground(key: _backgroundKey)),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a touch on blank background dismisses focus and keeps text', (
    tester,
  ) async {
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    final firstController = TextEditingController();
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);
    addTearDown(firstController.dispose);

    await tester.pumpWidget(
      _formHarness(
        firstFocus: firstFocus,
        secondFocus: secondFocus,
        firstController: firstController,
      ),
    );

    await tester.tap(find.byKey(_firstFieldKey));
    await tester.pump();
    await tester.enterText(find.byKey(_firstFieldKey), 'kept value');

    expect(firstFocus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byKey(_backgroundKey));
    await tester.pump();

    expect(firstFocus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(firstController.text, 'kept value');
  });

  testWidgets('field switching and child controls keep their normal behavior', (
    tester,
  ) async {
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    final firstController = TextEditingController();
    var presses = 0;
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);
    addTearDown(firstController.dispose);

    await tester.pumpWidget(
      _formHarness(
        firstFocus: firstFocus,
        secondFocus: secondFocus,
        firstController: firstController,
        onPressed: () => presses++,
      ),
    );

    await tester.tap(find.byKey(_firstFieldKey));
    await tester.pump();
    await tester.tap(find.byKey(_secondFieldKey));
    await tester.pump();

    expect(firstFocus.hasFocus, isFalse);
    expect(secondFocus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byKey(const Key('child-button')));
    await tester.pump();

    expect(presses, 1);
    expect(secondFocus.hasFocus, isFalse);
  });

  testWidgets('the action does not consume a scroll gesture', (tester) async {
    final focusNode = FocusNode();
    final scrollController = ScrollController();
    addTearDown(focusNode.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: keyboardDismissOnTapOutside(
          child: Scaffold(
            body: ListView(
              key: const Key('scroll-view'),
              controller: scrollController,
              children: [
                TextField(key: _firstFieldKey, focusNode: focusNode),
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(_firstFieldKey));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('scroll-view'))),
    );
    await gesture.moveBy(const Offset(0, -300));
    await gesture.up();
    await tester.pump();

    expect(scrollController.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('routes and modal overlays inherit the global action', (
    tester,
  ) async {
    final routeFocus = FocusNode();
    final modalFocus = FocusNode();
    addTearDown(routeFocus.dispose);
    addTearDown(modalFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => keyboardDismissOnTapOutside(child: child!),
        routes: {
          '/': (context) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  key: const Key('open-route'),
                  onPressed: () => Navigator.of(context).pushNamed('/second'),
                  child: const Text('Open route'),
                ),
                ElevatedButton(
                  key: const Key('open-modal'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => Dialog(
                      child: SizedBox(
                        height: 300,
                        child: Column(
                          children: [
                            TextField(
                              key: const Key('modal-field'),
                              focusNode: modalFocus,
                            ),
                            const Expanded(
                              child: _HitTestBackground(
                                key: Key('modal-background'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open modal'),
                ),
              ],
            ),
          ),
          '/second': (context) => Scaffold(
            body: Column(
              children: [
                TextField(key: const Key('route-field'), focusNode: routeFocus),
                const Expanded(
                  child: _HitTestBackground(key: Key('route-background')),
                ),
              ],
            ),
          ),
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('route-field')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('route-background')));
    await tester.pump();
    expect(routeFocus.hasFocus, isFalse);

    Navigator.of(
      tester.element(find.byKey(const Key('route-background'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-modal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('modal-field')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('modal-background')));
    await tester.pump();

    expect(modalFocus.hasFocus, isFalse);
  });
}
