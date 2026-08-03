// Widget tests for SetPasswordScreen (JM-022 / JM-061, in-app-social).
//
// Added with the redesign-2026-08 re-skin: the screen had no widget coverage,
// so the Semantics(identifier:) contract Maestro keys on (CTO brief §6.6) was
// unprotected while its layout moved onto the Jeeb kit. These assert on
// `find.bySemanticsIdentifier`, plus the two structural facts the re-skin
// introduced (in-body top bar, docked CTA footer).
//
// No repository is injected: `_resolveAuthRepository()` falls back to a
// Dio-backed impl that is never touched unless a *valid* submit fires, the
// same construction path `w0_routes_resolve_test.dart` exercises.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_footer.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/auth/presentation/set_password_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _delegate = SyncAppLocalizationsDelegate();

Widget _host() => const MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SetPasswordScreen(),
    );

void main() {
  testWidgets('exposes the full JM-022 id contract', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('setpw_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('setpw_new_field'), findsOneWidget);
    expect(find.bySemanticsIdentifier('setpw_confirm_field'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('setpw_new_visibility_toggle'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('setpw_confirm_visibility_toggle'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('setpw_submit_cta'), findsOneWidget);
    // Added by the re-skin (`<screen>_<element>`): the old OMDSAppBar back
    // button carried no identifier.
    expect(find.bySemanticsIdentifier('setpw_back'), findsOneWidget);
  });

  testWidgets('renders the kit structure: in-body top bar + docked CTA footer',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byType(JeebTopBar), findsOneWidget);
    expect(find.byType(JeebCtaFooter), findsOneWidget);
    // The Material app bar is gone — the header is a body row now.
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('empty submit surfaces setpw_validation_error as an info note',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('setpw_validation_error'), findsNothing);

    // Empty fields fail the policy client-side — no network call is made.
    await tester.tap(find.bySemanticsIdentifier('setpw_submit_cta'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('setpw_validation_error'), findsOneWidget);
    expect(
      find.descendant(
        of: find.bySemanticsIdentifier('setpw_validation_error'),
        matching: find.byType(JeebInfoNote),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the eye toggle reveals the new-password field', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    EditableText editable() => tester.widget<EditableText>(
          find.descendant(
            of: find.bySemanticsIdentifier('setpw_new_field'),
            matching: find.byType(EditableText),
          ),
        );

    expect(editable().obscureText, isTrue);
    await tester.tap(find.bySemanticsIdentifier('setpw_new_visibility_toggle'));
    await tester.pumpAndSettle();
    expect(editable().obscureText, isFalse);
  });
}
