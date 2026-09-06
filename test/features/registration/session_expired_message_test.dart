// NET-18: a session killed mid-flight dropped the user on the login route with
// no explanation at all.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/session/auth_loss_signals.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _MockOtpService extends Mock implements OtpService {}

void main() {
  late _MockOtpService otp;
  late StreamController<DateTime> ticker;

  setUp(() {
    otp = _MockOtpService();
    ticker = StreamController<DateTime>.broadcast();
    AuthLossSignals.instance.clearReason();
  });

  tearDown(() async {
    await ticker.close();
    AuthLossSignals.instance.clearReason();
  });

  RegistrationCubit makeCubit() =>
      RegistrationCubit(otpService: otp, tickerFactory: () => ticker.stream);

  Widget host(RegistrationCubit cubit, {Locale locale = const Locale('en')}) =>
      wrapForTest(RegistrationScreen(cubit: cubit), locale: locale);

  testWidgets('nothing renders when the session was not lost', (tester) async {
    final RegistrationCubit cubit = makeCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(host(cubit));
    await tester.pump();

    expect(
      find.bySemanticsIdentifier('registration_session_expired_note'),
      findsNothing,
    );
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets(
        'a lost session explains itself once (${locale.languageCode})',
        (tester) async {
      AuthLossSignals.instance.signal(reason: AuthLossReason.sessionExpired);
      final RegistrationCubit cubit = makeCubit();
      addTearDown(cubit.close);

      await tester.pumpWidget(host(cubit, locale: locale));
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('registration_session_expired_note'),
        findsOneWidget,
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(RegistrationScreen)),
      );
      expect(find.text(l10n.errorSessionExpiredBody), findsOneWidget);

      // The reason is consumed at mount, so a later surface cannot repeat it.
      expect(AuthLossSignals.instance.lastReason, isNull);

      // A rebuild keeps exactly one note — never a second.
      cubit.phoneChanged('711');
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('registration_session_expired_note'),
        findsOneWidget,
      );
    });
  }

  testWidgets('a store-unavailable loss explains itself too', (tester) async {
    AuthLossSignals.instance.signal(reason: AuthLossReason.storeUnavailable);
    final RegistrationCubit cubit = makeCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(host(cubit));
    await tester.pump();

    expect(
      find.bySemanticsIdentifier('registration_session_expired_note'),
      findsOneWidget,
    );
  });

  testWidgets('a fresh mount after the reason was consumed shows nothing',
      (tester) async {
    AuthLossSignals.instance.signal();
    final RegistrationCubit first = makeCubit();
    addTearDown(first.close);
    await tester.pumpWidget(host(first));
    await tester.pump();
    expect(
      find.bySemanticsIdentifier('registration_session_expired_note'),
      findsOneWidget,
    );

    final RegistrationCubit second = makeCubit();
    addTearDown(second.close);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host(second));
    await tester.pump();
    expect(
      find.bySemanticsIdentifier('registration_session_expired_note'),
      findsNothing,
    );
  });
}
