import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_footer.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/client_unreachable/presentation/client_unreachable_screen.dart';

/// The screen reads its copy from the feature-local `ClientUnreachableL10n`
/// (no ARB keys exist for it yet — see
/// `docs/redesign-2026-08/wiring/w4-client-unreachable.md`), so the host needs
/// only the framework delegates.
Widget _host(Locale locale) => MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      home: const ClientUnreachableScreen(deliveryId: 'delivery-1'),
    );

void main() {
  group('ClientUnreachableScreen (redesign-2026-08 re-skin)', () {
    testWidgets('keeps every frozen semantics identifier', (tester) async {
      await tester.pumpWidget(_host(const Locale('en')));
      await tester.pumpAndSettle();

      for (final id in const <String>[
        'client_unreachable_root',
        'client_unreachable_call_again_cta',
        'client_unreachable_chat_cta',
        'client_unreachable_flag_cta',
        // New, per the kit's `<screen>_back` contract.
        'client_unreachable_back',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
    });

    testWidgets('renders the kit surfaces, not the OMDS app bar', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(JeebTopBar), findsOneWidget);
      expect(find.byType(JeebInfoNote), findsOneWidget);
      expect(find.byType(JeebCtaFooter), findsOneWidget);
      // Two outline recovery actions + the docked primary edge.
      expect(find.byType(JeebCtaButton), findsNWidgets(3));
    });

    testWidgets('the flag CTA still pops true', (tester) async {
      Object? popped;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<Object?>(
                      MaterialPageRoute<Object?>(
                        builder: (_) => const ClientUnreachableScreen(
                          deliveryId: 'delivery-1',
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('client_unreachable_flag_cta'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets('lays out in Arabic and at 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const Locale('ar')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _host(const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
