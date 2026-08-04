// M5 audit B9 — R3 animates nothing (03-MOTION-NOTES §R3), and the at-door card
// carried an `AnimatedSlide(offset: Offset.zero)`: a compile-time-constant
// offset that could never move anything. Dead cruft on a zero-motion tile.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/otp_at_door_card.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _host({String? code}) => MaterialApp(
  theme: AppTheme.midnight(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 390,
        child: OtpAtDoorCard(deliveryId: 'DLV-770001', handoverCode: code),
      ),
    ),
  ),
);

void main() {
  testWidgets('the at-door card enters on a hard cut — no AnimatedSlide',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(code: '1234'));

    expect(find.byType(AnimatedSlide), findsNothing);
    expect(
      find.descendant(
        of: find.byType(OtpAtDoorCard),
        matching: find.byType(ImplicitlyAnimatedWidget),
      ),
      findsNothing,
    );
  });

  testWidgets('R3 is STATIC — no ticker at mount or a second later',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(code: '1234'));

    expect(tester.binding.transientCallbackCount, 0);
    final Offset before = tester.getTopLeft(find.byType(OtpAtDoorCard));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.getTopLeft(find.byType(OtpAtDoorCard)), before);
  });

  testWidgets('the card still draws its code and CTA',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(code: '1234'));

    expect(find.byKey(const Key('tracking.atDoorCode')), findsOneWidget);
    expect(find.byType(JeebCtaButton), findsOneWidget);
  });
}
