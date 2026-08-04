// MIDNIGHT M3-34 per-element assertions for SetPasswordScreen.
//
// Goldens are evidence, not gates (5% comparator tolerance), so every carried
// R22 decision is asserted by reading the value off the widget.
//
// The screen is LIVE, not an orphan: Profile tab → customer-profile →
// password-security → `pushNamed('set-password')`. The JEBV4-199 removal took
// the `recovery` mode, not this authenticated add-a-password surface.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_section_label.dart';
import 'package:jeeb_mobile/features/auth/application/set_password_cubit.dart';
import 'package:jeeb_mobile/features/auth/application/set_password_state.dart';
import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/presentation/set_password_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _delegate = SyncAppLocalizationsDelegate();

/// Never touched: no test here drives a *valid* submit.
class _InertAuthRepository implements AuthRepository {
  const _InertAuthRepository();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used');
}

/// Seeds a state the public cubit API cannot reach (submitting).
class _SeededCubit extends SetPasswordCubit {
  _SeededCubit(SetPasswordState seed)
      : super(repository: const _InertAuthRepository(), email: '') {
    emit(seed);
  }
}

Widget _host({SetPasswordCubit Function()? cubitFactory}) => MaterialApp(
      theme: AppTheme.midnight(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SetPasswordScreen(cubitFactory: cubitFactory),
    );

void main() {
  group('M3-34 field — carried from R22', () {
    testWidgets('content variant, orange glow topEnd, still, no wash',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // R22 declares no periwinkle wash — a wash is a different layer.
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

    testWidgets('the field wraps the whole screen, header included',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // A field mounted *under* the top bar would leave the header on the flat
      // scaffold navy, which is exactly the pre-M3-34 defect.
      expect(
        find.descendant(
          of: find.byType(JeebMidnightField),
          matching: find.bySemanticsIdentifier('setpw_back'),
        ),
        findsOneWidget,
      );
    });
  });

  group('M3-34 bands — R22 section-label rhythm', () {
    testWidgets('the field pair sits under one SECURITY band', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<JeebSectionLabel>(find.byType(JeebSectionLabel))
          .map((w) => w.label)
          .toList();
      expect(labels, <String>['Security']);
    });
  });

  group('M3-34 orange budget', () {
    testWidgets('the submit CTA is periwinkle, never accent', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final variants = tester
          .widgetList<JeebCtaButton>(find.byType(JeebCtaButton))
          .map((w) => w.variant)
          .toList();
      expect(variants, <JeebCtaVariant>[JeebCtaVariant.primary]);
      expect(variants, isNot(contains(JeebCtaVariant.accent)));
    });

    testWidgets('the reveal eyes take the muted ink role, not primary',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final scheme = AppTheme.midnight().colorScheme;
      final icons = tester.widgetList<Icon>(
        find.descendant(
          of: find.bySemanticsIdentifier('setpw_new_visibility_toggle'),
          matching: find.byType(Icon),
        ),
      );
      expect(icons, isNotEmpty);
      for (final icon in icons) {
        final element = tester.element(find.byWidget(icon));
        final resolved = icon.color ?? IconTheme.of(element).color;
        expect(resolved, isNot(scheme.primary));
        expect(resolved, scheme.onSurfaceVariant);
      }
    });
  });

  group('M3-34 states', () {
    testWidgets('default — the CTA is live and no error note is mounted',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final submit = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('setpw_submit_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(submit.isEnabled, isTrue);
      expect(submit.isLoading, isFalse);
      expect(find.byType(JeebInfoNote), findsNothing);
    });

    testWidgets('loading — submitting drives the spinner and locks the fields',
        (tester) async {
      await tester.pumpWidget(
        _host(
          cubitFactory: () => _SeededCubit(
            const SetPasswordState(status: SetPasswordStatus.submitting),
          ),
        ),
      );
      // NOT pumpAndSettle: the CTA spinner loops forever.
      await tester.pump();

      final submit = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('setpw_submit_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(submit.isLoading, isTrue);
      expect(submit.isEnabled, isFalse);

      final newField = tester.widget<EditableText>(
        find.descendant(
          of: find.bySemanticsIdentifier('setpw_new_field'),
          matching: find.byType(EditableText),
        ),
      );
      expect(newField.readOnly, isTrue);
    });

    testWidgets('error — the validation note is the family error_outline glyph',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('setpw_submit_cta'));
      await tester.pumpAndSettle();

      final note = tester.widget<JeebInfoNote>(
        find.descendant(
          of: find.bySemanticsIdentifier('setpw_validation_error'),
          matching: find.byType(JeebInfoNote),
        ),
      );
      expect(note.icon, Icons.error_outline);
    });
  });
}
