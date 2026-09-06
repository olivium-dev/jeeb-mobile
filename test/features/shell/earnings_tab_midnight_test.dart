// MIDNIGHT M4 instruments for the Earnings tab's two gate arms (#12, #13).
// Read off the built widget: goldens tolerate 5% and would not see this.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/shell/tabs/earnings_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// The tab body as the shell mounts it: a Scaffold slot, no field of its own.
Widget _harness(Widget tab, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(backgroundColor: Colors.transparent, body: tab),
  );
}

JeebEmptyState _block(WidgetTester tester) =>
    tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));

/// The session read, held open forever.
Widget _loadingTab() => EarningsTab(sessionUserId: Completer<String?>().future);

/// The S0-OAD-03 fail-closed arm: the read completed with no session id.
Widget _unavailableTab() => EarningsTab(sessionUserId: Future<String?>.value(null));

void main() {
  group('EarningsTab · session-resolving arm (M4 #12)', () {
    testWidgets('is the radar skeleton, not a spinner', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(_loadingTab()));
      await tester.pumpAndSettle();

      final JeebEmptyState block = _block(tester);
      expect(block.variant, JeebEmptyStateVariant.radar);
      expect(block.status, JeebEmptyStateStatus.loading);
      expect(block.compact, isFalse);
    });

    // The defect itself: every ProgressIndicator in this tree was inked
    // `colorScheme.primary`, and under Midnight that token IS orange.
    testWidgets('draws no ProgressIndicator at all', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(_loadingTab()));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((Widget w) => w is ProgressIndicator),
        findsNothing,
        reason: 'an untinted OmdsLoadingState rings colorScheme.primary '
            '(#D73B00) — orange spent on a keychain read',
      );
    });

    testWidgets('names no second party on the ring', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(_loadingTab()));
      await tester.pumpAndSettle();

      expect(
        _block(tester).medallions,
        isEmpty,
        reason: 'the radar default seats three jeeber initials; a session read '
            'has nobody to name',
      );
    });

    testWidgets('carries the loading identifier and the earnings headline', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(_loadingTab()));
      await tester.pumpAndSettle();

      expect(_block(tester).identifier, EarningsTab.loadingIdentifier);
      expect(
        find.bySemanticsIdentifier(EarningsTab.loadingIdentifier),
        findsOneWidget,
      );
      expect(find.text('Loading your earnings'), findsOneWidget);

      handle.dispose();
    });

    // Reduce motion is what makes the state capturable at all: the old Material
    // spinner never settles, so `pumpAndSettle` on this tree used to time out.
    testWidgets('settles under reduce motion', (WidgetTester tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(_loadingTab()));

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders RTL under ar', (WidgetTester tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _harness(_loadingTab(), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(JeebEmptyState))),
        TextDirection.rtl,
      );
      expect(find.text('Loading your earnings'), findsNothing);
    });
  });

  group('EarningsTab · fail-closed arm (M4 #13)', () {
    testWidgets('is the danger-tinted radar, not a bare Text', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(_unavailableTab()));
      await tester.pumpAndSettle();

      final JeebEmptyState block = _block(tester);
      expect(block.variant, JeebEmptyStateVariant.radar);
      expect(block.effectiveStatus, JeebEmptyStateStatus.error);
      expect(block.reason, JeebEmptyStateReason.failed);
      expect(block.identifier, EarningsTab.unavailableIdentifier);
    });

    // The catalog state "Unavailable — no active session" captures this copy;
    // it must survive the restyle verbatim.
    testWidgets('keeps the frozen ARB copy as the headline', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(_unavailableTab()));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load earnings account.'), findsOneWidget);
      expect(_block(tester).headline, 'Unable to load earnings account.');
    });

    // ES-11/EP-18 reversal: a headline alone stranded the Jeeber on a dead
    // screen, so both acts are mounted — and neither is an inert Retry-only.
    testWidgets('offers a way out AND a way to re-check', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(_unavailableTab()));
      await tester.pumpAndSettle();

      expect(_block(tester).action, isNotNull);
      expect(
        find.bySemanticsIdentifier('earnings_tab_signout_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('earnings_tab_retry_cta'),
        findsOneWidget,
      );
      expect(_block(tester).body, isNotNull);
    });
  });

  group('EarningsTab · the gate frame', () {
    testWidgets('both arms paint the same still content field', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() arm in <Widget Function()>[
        _loadingTab,
        _unavailableTab,
      ]) {
        useReduceMotion(tester);
        await tester.pumpWidget(_harness(arm()));
        await tester.pumpAndSettle();

        final JeebMidnightField field =
            tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));
        expect(field.variant, JeebFieldVariant.content);
        expect(
          field.animateDecor,
          isFalse,
          reason: 'the earnings surface behind the gate does not move either',
        );
      }
    });

    // Drop the `Center` and the field shrink-wraps a short state, leaving the
    // rest of the tab painted by whatever is behind it.
    testWidgets('the field fills the whole tab', (WidgetTester tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(_loadingTab()));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(JeebMidnightField)).height,
        tester.getSize(find.byType(Scaffold)).height,
      );
    });

    testWidgets('production EarningsTab needs no seam to fail closed', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(const EarningsTab()));
      await tester.pumpAndSettle();

      expect(_block(tester).identifier, EarningsTab.unavailableIdentifier);
      expect(tester.takeException(), isNull);
    });
  });
}
