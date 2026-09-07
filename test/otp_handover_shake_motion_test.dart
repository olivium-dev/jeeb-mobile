// M5/B10 — the jeeber's wrong-code shake is KEPT: it is one-shot, off-tile
// error feedback the board's frozen export could never have depicted. What it
// may not do is run when the user has asked the system for no motion.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';

import 'support/sync_app_localizations.dart';

class _MockRepo extends Mock implements OtpHandoverRepository {}

Widget _jeeberScreen(
  OtpHandoverCubit cubit, {
  required bool disableAnimations,
}) {
  return wrapForTest(
    BlocProvider<OtpHandoverCubit>.value(
      value: cubit,
      child: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: const OtpHandoverScreen(
            deliveryId: 'DLV-770001',
            isClient: false,
          ),
        ),
      ),
    ),
  );
}

/// The live horizontal offset the shake is applying to the code entry.
double _entryOffset(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.bySemanticsIdentifier('otp_handover_input'),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getTranslation()
    .x;

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.submitOtp(
        deliveryId: any(named: 'deliveryId'),
        otp: any(named: 'otp'),
      ),
    ).thenThrow(const OtpHandoverException(OtpHandoverErrorKind.invalidOtp));
  });

  /// The largest displacement the entry reaches over the shake's 400ms.
  Future<double> peakOffset(
    WidgetTester tester, {
    required bool disableAnimations,
  }) async {
    final cubit = OtpHandoverCubit(
      repository: repo,
      deliveryId: 'DLV-770001',
      isClient: false,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _jeeberScreen(cubit, disableAnimations: disableAnimations),
    );
    await tester.pump();

    await cubit.submitOtp('0000');
    await tester.pump();

    double peak = 0;
    for (int frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
      peak = peak > _entryOffset(tester).abs()
          ? peak
          : _entryOffset(tester).abs();
    }
    return peak;
  }

  testWidgets('a wrong code shakes the entry', (tester) async {
    expect(
      await peakOffset(tester, disableAnimations: false),
      greaterThan(1),
      reason: 'the tween peaks at 8dp; anything above noise proves it ran',
    );
  });

  testWidgets('reduce motion suppresses the shake entirely', (tester) async {
    expect(await peakOffset(tester, disableAnimations: true), 0);
  });

  testWidgets('reduce motion still delivers the error in words', (
    tester,
  ) async {
    final cubit = OtpHandoverCubit(
      repository: repo,
      deliveryId: 'DLV-770001',
      isClient: false,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_jeeberScreen(cubit, disableAnimations: true));
    await tester.pump();
    await cubit.submitOtp('0000');
    await tester.pump();

    // The whole message survives the missing motion: headline, live counter.
    expect(
      find.text("That code isn't right. Check it and try again."),
      findsOneWidget,
    );
    expect(find.textContaining('2 attempt'), findsOneWidget);
    expect(_entryOffset(tester), 0);
  });
}
