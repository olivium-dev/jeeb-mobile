// MIDNIGHT M3-26 per-element assertions for PasswordSecurityScreen.
//
// Goldens are evidence, not gates (5% comparator tolerance), so every carried
// R22 decision is asserted by reading the value off the widget.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_section_label.dart';
import 'package:jeeb_mobile/features/password_security/application/password_security_cubit.dart';
import 'package:jeeb_mobile/features/password_security/application/password_security_state.dart';
import 'package:jeeb_mobile/features/password_security/presentation/password_security_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _delegate = SyncAppLocalizationsDelegate();

/// Seeds a state the public cubit API cannot reach (submitting).
class _SeededCubit extends PasswordSecurityCubit {
  _SeededCubit(PasswordSecurityState seed) {
    emit(seed);
  }
}

Widget _host({
  bool hasPassword = true,
  PasswordSecurityCubit Function()? cubitFactory,
}) {
  final router = GoRouter(
    initialLocation: '/settings/password',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings/password',
        name: 'password-security',
        builder: (_, _) => PasswordSecurityScreen(
          hasPassword: hasPassword,
          cubitFactory: cubitFactory,
        ),
      ),
      GoRoute(
        path: '/set-password',
        name: 'set-password',
        builder: (_, _) => const Scaffold(body: Text('setpw')),
      ),
      GoRoute(
        path: '/profile/customer',
        name: 'customer-profile',
        builder: (_, _) => const Scaffold(body: Text('profile')),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.midnight(),
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      _delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  group('M3-26 field — carried from R22', () {
    testWidgets('content variant, orange glow topEnd, still, no wash',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // R22 declares no periwinkle wash — a wash here would paint a layer the
      // nearest tile does not have.
      expect(field.washPlacement, isNull);
      // R22 is board-still.
      expect(field.animateDecor, isFalse);
    });

    testWidgets('scaffold is transparent so the field is what renders',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(
        find.ancestor(
          of: find.byType(JeebMidnightField),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, Colors.transparent);
    });
  });

  group('M3-26 bands — R22 section-label rhythm', () {
    testWidgets('password account bands SECURITY and ACCOUNT', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<JeebSectionLabel>(find.byType(JeebSectionLabel))
          .map((w) => w.label)
          .toList();
      expect(labels, <String>['Security', 'Account']);
    });

    testWidgets('social-only account keeps ACCOUNT and drops SECURITY',
        (tester) async {
      await tester.pumpWidget(_host(hasPassword: false));
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<JeebSectionLabel>(find.byType(JeebSectionLabel))
          .map((w) => w.label)
          .toList();
      expect(labels, <String>['Account']);
    });
  });

  group('M3-26 orange budget', () {
    testWidgets('neither CTA is accent — R22 spends orange on one lit frame',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final variants = tester
          .widgetList<JeebCtaButton>(find.byType(JeebCtaButton))
          .map((w) => w.variant)
          .toList();
      expect(variants, isNot(contains(JeebCtaVariant.accent)));
      // Submit is the periwinkle act; the set-password entry is the glass one.
      expect(variants, <JeebCtaVariant>[
        JeebCtaVariant.primary,
        JeebCtaVariant.outline,
      ]);
    });

    testWidgets('social-only promotes the entry to periwinkle, not orange',
        (tester) async {
      await tester.pumpWidget(_host(hasPassword: false));
      await tester.pumpAndSettle();

      final cta = tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));
      expect(cta.variant, JeebCtaVariant.primary);
    });

    testWidgets('reveal eye takes the muted ink role, not heading ink',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final muted = AppTheme.midnight().colorScheme.onSurfaceVariant;
      final eyes = tester.widgetList<IconButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('password_new_visibility_toggle'),
          matching: find.byType(IconButton),
        ),
      );
      expect(eyes, isNotEmpty);
      for (final eye in eyes) {
        expect(eye.color, muted);
      }
    });
  });

  group('M3-26 loading state', () {
    testWidgets('submitting drives the CTA spinner and disables the fields',
        (tester) async {
      await tester.pumpWidget(
        _host(
          cubitFactory: () => _SeededCubit(
            const PasswordSecurityState(
              status: PasswordSecurityStatus.submitting,
            ),
          ),
        ),
      );
      // NOT pumpAndSettle: the CTA spinner loops forever, so it never settles.
      await tester.pump();

      final submit = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('password_submit_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(submit.isLoading, isTrue);
      expect(submit.isEnabled, isFalse);

      final currentField = tester.widget<EditableText>(
        find.descendant(
          of: find.bySemanticsIdentifier('password_current_field'),
          matching: find.byType(EditableText),
        ),
      );
      expect(currentField.readOnly, isTrue);
    });
  });
}
