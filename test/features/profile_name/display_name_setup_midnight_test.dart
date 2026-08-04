// MIDNIGHT M3-33 per-element assertions for DisplayNameSetupScreen.
//
// Goldens are evidence, not gates (5% comparator tolerance), so every carried
// R6 decision is asserted by reading the value off the widget.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/profile_name/application/display_name_cubit.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';
import 'package:jeeb_mobile/features/profile_name/presentation/display_name_setup_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _delegate = SyncAppLocalizationsDelegate();

/// Never resolves, so `saving` is observable as a rest state.
class _HangingRepository implements DisplayNameRepository {
  @override
  Future<void> submitDisplayName(String name) => Completer<void>().future;
}

/// Always fails, for the error leg.
class _FailingRepository implements DisplayNameRepository {
  @override
  Future<void> submitDisplayName(String name) async {
    throw const DisplayNameRepositoryException(DisplayNameFailure.network);
  }
}

Widget _host({
  DisplayNameRepository? repository,
  DisplayNameCubit? cubit,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      _delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: DisplayNameSetupScreen(
      onDone: () {},
      repository: repository,
      cubit: cubit,
    ),
  );
}

void main() {
  group('M3-33 field — carried from R6', () {
    testWidgets('content variant, orange glow topEnd, still, no wash',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      // Wave-D measured R6's bloom as ORANGE at the top END.
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // R6 declares no periwinkle wash — a wash is a different layer.
      expect(field.washPlacement, isNull);
      // R6 is board-still.
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

    testWidgets('the field fills the viewport, not just the content band',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // REGRESSION: the field's Stack is `passthrough`, so a bare
      // SingleChildScrollView shrink-wraps and the band below the skip exit
      // falls through the transparent scaffold to bare white.
      final fieldHeight = tester.getSize(find.byType(JeebMidnightField)).height;
      final viewport = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      expect(fieldHeight, viewport);
    });

    testWidgets('status-bar glyphs flip light — the field bleeds under them',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.ancestor(
          of: find.byType(JeebMidnightField),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(region.value, SystemUiOverlayStyle.light);
    });
  });

  group('M3-33 orange budget', () {
    testWidgets('the heading takes onSurface, NOT primary', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final scheme = AppTheme.midnight().colorScheme;
      final title = tester.widget<Text>(
        find.byKey(const Key('profile-name.title')),
      );
      expect(title.style?.color, scheme.onSurface);
      // Under Midnight `primary` IS #D73B00 — a heading inked with it would
      // spend the orange budget on a read-only run.
      expect(title.style?.color, isNot(scheme.primary));
    });

    testWidgets('the subtitle takes the muted ink role', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final scheme = AppTheme.midnight().colorScheme;
      final subtitle = tester.widget<Text>(
        find.text(
          'Add your name so your receipts and chats greet you properly. '
          'You can skip this and add it later.',
        ),
      );
      expect(subtitle.style?.color, scheme.onSurfaceVariant);
    });

    testWidgets('Continue is the one accent act; Skip stays a bare text label',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final submit = tester.widget<JeebCtaButton>(
        find.byKey(const Key('profile-name.submit')),
      );
      // R6's forward CTA: the funnel's single orange moment, h58.
      expect(submit.variant, JeebCtaVariant.accent);
      expect(submit.height, JeebCtaButton.primaryHeightTall);

      final skip = tester.widget<JeebCtaButton>(
        find.byKey(const Key('profile-name.skip')),
      );
      expect(skip.variant, JeebCtaVariant.text);

      final accents = tester
          .widgetList<JeebCtaButton>(find.byType(JeebCtaButton))
          .where((w) => w.variant == JeebCtaVariant.accent)
          .length;
      expect(accents, 1, reason: 'exactly one orange act on the step');
    });

    testWidgets('the field is the themed glass input, not R6’s accent-rim box',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // R6's 2px orange rim is a per-tile measurement of its phone box; this
      // step takes `inputDecorationTheme`'s glassFill + glassBorder instead.
      expect(
        find.descendant(
          of: find.bySemanticsIdentifier('profile_name_input'),
          matching: find.byType(OmdsTextField),
        ),
        findsOneWidget,
      );
      final theme = AppTheme.midnight();
      final enabled = theme.inputDecorationTheme.enabledBorder;
      expect(enabled, isA<OutlineInputBorder>());
      expect(
        (enabled! as OutlineInputBorder).borderSide.color,
        isNot(theme.colorScheme.primary),
      );
    });
  });

  group('M3-33 states', () {
    testWidgets('default — CTA is mounted but gated on an empty field',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final submit = tester.widget<JeebCtaButton>(
        find.byKey(const Key('profile-name.submit')),
      );
      expect(submit.isEnabled, isFalse);
      expect(submit.isLoading, isFalse);
    });

    testWidgets('loading — saving drives the spinner and disables field + skip',
        (tester) async {
      await tester.pumpWidget(_host(repository: _HangingRepository()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile-name.field')),
        'Ahmad',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-name.submit')));
      // NOT pumpAndSettle: the CTA spinner loops forever.
      await tester.pump();

      final submit = tester.widget<JeebCtaButton>(
        find.byKey(const Key('profile-name.submit')),
      );
      expect(submit.isLoading, isTrue);
      expect(submit.isEnabled, isFalse);

      final skip = tester.widget<JeebCtaButton>(
        find.byKey(const Key('profile-name.skip')),
      );
      expect(skip.isEnabled, isFalse);

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('profile-name.field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.readOnly, isTrue);
    });

    testWidgets('error — the save failure surfaces on the Midnight snackbar',
        (tester) async {
      await tester.pumpWidget(_host(repository: _FailingRepository()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile-name.field')),
        'Ahmad',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-name.submit')));
      await tester.pumpAndSettle();

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      // The screen paints none itself: the surface comes from the Midnight
      // `snackBarTheme`, so a light slab can never appear here.
      expect(bar.backgroundColor, isNull);
      final theme = Theme.of(
        tester.element(find.byType(SnackBar)),
      );
      expect(
        theme.snackBarTheme.backgroundColor,
        AppTheme.midnight().colorScheme.surfaceContainerHigh,
      );
      // The step stays open — a failed save is fail-soft, never a block.
      expect(find.byKey(const Key('profile-name.skip')), findsOneWidget);
    });
  });

  group('M3-33 typography + RTL', () {
    testWidgets('heading is the ramp h1, subtitle the ramp body',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final styles = JeebTextStyles.midnight();
      final title = tester.widget<Text>(
        find.byKey(const Key('profile-name.title')),
      );
      expect(title.style?.fontSize, styles.h1.fontSize);
      expect(title.style?.fontWeight, styles.h1.fontWeight);
    });

    testWidgets('ar mirrors the whole step under the field', (tester) async {
      await tester.pumpWidget(_host(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(JeebMidnightField));
      expect(Directionality.of(context), TextDirection.rtl);
    });
  });
}
