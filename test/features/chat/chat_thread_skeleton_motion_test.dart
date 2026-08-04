// M5 audit A3 — the chat loading placeholder pulses on the KIT primitive.
//
// R20 draws no loading state at all, so the frame borrows the one governed
// breathe rather than a hand-rolled `AnimationController`: same .45→1 curve as
// before, but now on `JMotionLoop`'s reduce-motion and stagger contracts.
//
// Both mounts are this one widget — `ChatScreen` (history read) and
// `chat_detail_screen`'s `/chat/:id` resolver — so these assertions cover both.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/motion/jeeb_motion_loop.dart';
import 'package:jeeb_mobile/core/motion/jeeb_motion_primitives.dart';
import 'package:jeeb_mobile/core/motion/jeeb_motion_tokens.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_chat_bubble.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';

Widget _host({bool disableAnimations = false}) => MaterialApp(
  theme: AppTheme.midnight(),
  home: Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: const Scaffold(body: ChatThreadSkeleton()),
    ),
  ),
);

FadeTransition _fade(WidgetTester tester) => tester.widget<FadeTransition>(
  find
      .descendant(
        of: find.byType(JBreathe),
        matching: find.byType(FadeTransition),
      )
      .first,
);

void main() {
  testWidgets('the pulse is ONE jBreathe on the container, at 1.6s / no delay',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host());

    expect(find.byType(JBreathe), findsOneWidget);
    final JBreathe breathe = tester.widget<JBreathe>(find.byType(JBreathe));
    expect(breathe.duration, JeebMotion.breatheDurationMin);
    expect(breathe.duration, const Duration(milliseconds: 1600));
    expect(breathe.delay, Duration.zero);
    // On the harness, not a feature-owned controller.
    expect(find.byType(JMotionLoop), findsOneWidget);
  });

  testWidgets('it wraps the WHOLE column — never one breathe per bubble',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host());

    // Three shells under ONE breathe: they share a phase. A per-bubble wrap
    // would give 3 breathes and a stagger the board never draws.
    expect(find.byType(JeebChatBubble), findsNWidgets(3));
    expect(find.byType(JBreathe), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(JBreathe),
        matching: find.byType(JeebChatBubble),
      ),
      findsNWidgets(3),
    );
    expect(
      find.descendant(
        of: find.byType(JeebChatBubble),
        matching: find.byType(JBreathe),
      ),
      findsNothing,
    );
  });

  testWidgets('the curve runs .45 → 1 and keeps a frame scheduled',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host());

    expect(_fade(tester).opacity.value, closeTo(0.45, 0.001));
    // Half a cycle is the peak; a quarter is strictly between the two.
    await tester.pump(const Duration(milliseconds: 400));
    final double quarter = _fade(tester).opacity.value;
    expect(quarter, greaterThan(0.45));
    expect(quarter, lessThan(1.0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_fade(tester).opacity.value, closeTo(1.0, 0.001));
    // The scheduled frame is what lets a `pumpAndSettle` host advance its
    // async lookup (chat_detail_active_thread_test).
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('reduce motion pins .45 and stops the ticker',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));

    expect(_fade(tester).opacity.value, closeTo(0.45, 0.001));
    await tester.pump(const Duration(milliseconds: 800));
    expect(_fade(tester).opacity.value, closeTo(0.45, 0.001));
    expect(tester.binding.transientCallbackCount, 0);
    // The placeholders stay legible — a still skeleton is not an invisible one.
    expect(find.byType(JeebChatBubble), findsNWidgets(3));
  });
}
