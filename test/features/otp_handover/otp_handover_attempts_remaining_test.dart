// AE-11 / COPY-14 — the SERVER's `attemptsRemaining` wins, and the plural set
// resolves in both locales.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_state.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _RejectingRepository implements OtpHandoverRepository {
  const _RejectingRepository({this.attemptsRemaining});

  final int? attemptsRemaining;

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async =>
      const OtpFetchResult(smsTriggered: true);

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async => throw OtpHandoverException(
        OtpHandoverErrorKind.invalidOtp,
        null,
        attemptsRemaining,
      );
}

Widget _host(OtpHandoverCubit cubit, Locale locale) => wrapForTest(
      BlocProvider<OtpHandoverCubit>.value(
        value: cubit,
        child: const OtpHandoverScreen(
          deliveryId: 'DLV-770001',
          isClient: false,
        ),
      ),
      locale: locale,
    );

void main() {
  testWidgets('the server count beats the local subtraction, EN and AR',
      (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      final cubit = OtpHandoverCubit(
        repository: const _RejectingRepository(attemptsRemaining: 2),
        deliveryId: 'DLV-770001',
        isClient: false,
      );
      await tester.pumpWidget(_host(cubit, locale));
      await tester.pumpAndSettle();

      await cubit.submitOtp('9999');
      await tester.pumpAndSettle();

      expect(cubit.state.attemptsRemaining, 2);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(OtpHandoverScreen)),
      );
      expect(find.text(l10n.otpHandoverAttemptsRemaining(2)), findsOneWidget);
      // The retired single-form key is gone from this surface.
      expect(find.text(l10n.otpAttemptsRemaining(2)), findsNothing);
      expect(
        find.bySemanticsIdentifier('otp_handover_input'),
        findsOneWidget,
      );
      await cubit.close();
    }
  });

  testWidgets('with no server count the local subtraction still renders',
      (tester) async {
    final cubit = OtpHandoverCubit(
      repository: const _RejectingRepository(),
      deliveryId: 'DLV-770001',
      isClient: false,
    );
    await tester.pumpWidget(_host(cubit, const Locale('en')));
    await tester.pumpAndSettle();

    await cubit.submitOtp('9999');
    await tester.pumpAndSettle();

    expect(
      cubit.state.attemptsRemaining,
      OtpHandoverState.maxAttempts - 1,
    );
    await cubit.close();
  });
}
