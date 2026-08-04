// MIDNIGHT M4 — inventory rows #21 and #22: the two hand-built jeeber-home
// blocks that were Midnight-TOKENED but not part of the §2.7 pattern family.
//
// Both drew their headline in `colorScheme.primary`, which IS #D73B00 under
// Midnight — an orange h1 on a screen whose orange budget is the CTA. Both
// facts are read off the widget, because the goldens tolerate 5%.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_empty_view.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_unregistered_view.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.midnight(),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  // The illustrations loop ∞ (02-STUDY-NOTES M0-4).
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(body: child),
);

JeebEmptyState _block(WidgetTester tester) =>
    tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(JeebEmptyState)));

void main() {
  final ColorScheme scheme = AppTheme.midnight().colorScheme;

  group('#21 · JeeberFeedEmptyView', () {
    testWidgets('the empty feed is E3 street, lit, with both lines', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const JeeberFeedEmptyView(profileName: 'Kamal')),
      );
      await tester.pumpAndSettle();

      final JeebEmptyState block = _block(tester);
      final AppLocalizations l10n = _l10n(tester);
      expect(block.status, JeebEmptyStateStatus.empty);
      // A jeeber-side quiet state — the same variant every other no-requests
      // surface on this screen already draws.
      expect(block.variant, JeebEmptyStateVariant.street);
      expect(block.identifier, 'jeeber_feed_empty_view_empty_state');
      expect(block.headline, l10n.jeeberFeedEmptyTitle);
      expect(block.body, l10n.jeeberFeedEmptySubtitle);
    });

    testWidgets('its headline is onSurface, never the accent', (tester) async {
      await tester.pumpWidget(
        _host(const JeeberFeedEmptyView(profileName: 'Kamal')),
      );
      await tester.pumpAndSettle();

      final Text headline = tester.widget<Text>(
        find.text(_l10n(tester).jeeberFeedEmptyTitle),
      );
      expect(headline.style?.color, scheme.onSurface);
      expect(headline.style?.color, isNot(scheme.primary));
    });

    testWidgets('the availability switch above it still works', (tester) async {
      bool? toggled;
      await tester.pumpWidget(
        _host(
          JeeberFeedEmptyView(
            profileName: 'Kamal',
            acceptOrders: true,
            onAcceptOrdersChanged: (v) => toggled = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('jeeber-home-accept-orders-switch')),
      );
      await tester.pump();
      expect(toggled, isFalse);
    });
  });

  group('#22 · JeeberUnregisteredView', () {
    testWidgets('the upsell hero is E3 street, lit, with the upsell copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(JeeberUnregisteredView(onRegister: () {}, profileName: 'Kamal')),
      );
      await tester.pumpAndSettle();

      final JeebEmptyState block = _block(tester);
      final AppLocalizations l10n = _l10n(tester);
      expect(block.status, JeebEmptyStateStatus.empty);
      expect(block.variant, JeebEmptyStateVariant.street);
      expect(block.identifier, 'jeeber_unregistered_empty_state');
      expect(block.headline, l10n.jeeberRegisterTitle);
      expect(block.body, l10n.jeeberRegisterSubtitle);
      // The CTA stays in the DOCKED footer (both frozen ids live there), so
      // the block itself must not grow one.
      expect(block.action, isNull);
    });

    testWidgets('its h1 is onSurface, never the accent', (tester) async {
      await tester.pumpWidget(
        _host(JeeberUnregisteredView(onRegister: () {}, profileName: 'Kamal')),
      );
      await tester.pumpAndSettle();

      final Text headline = tester.widget<Text>(
        find.text(_l10n(tester).jeeberRegisterTitle),
      );
      expect(headline.style?.color, scheme.onSurface);
      expect(headline.style?.color, isNot(scheme.primary));
    });

    testWidgets('the docked register CTA and BOTH frozen ids survive', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(
          JeeberUnregisteredView(
            onRegister: () => tapped = true,
            profileName: 'Kamal',
            ctaIdentifier: 'delivery_register_now_cta',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_unregistered_register_button'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('delivery_register_now_cta'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(JeeberUnregisteredView.registerButtonKey));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('the hero survives a short viewport without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(JeeberUnregisteredView(onRegister: () {}, profileName: 'Kamal')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(JeebEmptyState), findsOneWidget);
    });
  });

  testWidgets('neither view leaves an OMDS state widget behind', (
    tester,
  ) async {
    for (final Widget view in <Widget>[
      const JeeberFeedEmptyView(profileName: 'Kamal'),
      JeeberUnregisteredView(onRegister: () {}, profileName: 'Kamal'),
    ]) {
      await tester.pumpWidget(_host(view));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w.runtimeType.toString().startsWith('Omds') &&
              w.runtimeType.toString().contains('State'),
        ),
        findsNothing,
      );
    }
  });
}
