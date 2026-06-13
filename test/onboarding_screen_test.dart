import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';

import 'support/sync_app_localizations.dart';

/// Wraps [OnboardingScreen] with the [OnboardingCubit] and a minimal
/// [MaterialApp] so widget tests don't need a full router in scope.
Widget _harness({required OnboardingCubit cubit, VoidCallback? onComplete}) {
  return wrapForTest(
    BlocProvider<OnboardingCubit>.value(
      value: cubit,
      child: OnboardingScreen(onComplete: onComplete),
    ),
  );
}

void main() {
  late SharedPreferences prefs;
  late OnboardingCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cubit = OnboardingCubit(prefs: prefs);
  });

  tearDown(() => cubit.close());

  testWidgets('renders all 3 onboarding slides and the Skip CTA',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit));
    await tester.pump();

    expect(find.byKey(const Key('onboarding.skip')), findsOneWidget);
    expect(find.byKey(const Key('onboarding.next')), findsOneWidget);
    expect(find.byKey(const Key('onboarding.dots')), findsOneWidget);
  });

  testWidgets(
      'Next CTA advances to the last slide and becomes Get Started',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit));
    await tester.pump();

    // Advance to slide 2
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    // Advance to slide 3 (last)
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding.getStarted')), findsOneWidget);
  });

  testWidgets(
      'tapping Skip marks onboarding as complete in SharedPreferences',
      (tester) async {
    expect(cubit.state, isFalse);
    var navigated = false;

    await tester.pumpWidget(
      _harness(cubit: cubit, onComplete: () => navigated = true),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('onboarding.skip')));
    await tester.pump(); // allow async complete() to run

    expect(cubit.state, isTrue);
    expect(navigated, isTrue);
  });
}
