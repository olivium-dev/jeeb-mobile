// MIDNIGHT M3-14 adoption instruments (customer-wallet stub).
//
// Derived from R4 (04-r4-wallet) — this is the surface the wallet chip reaches
// instead of R4's hub. Read back off the BUILT widget: the two leaks this row
// fixes (an `h1` headline and a Ø56 glyph, both `colorScheme.primary`, i.e.
// #D73B00 under Midnight) are well inside the golden comparator's 5% tolerance.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/wallet/presentation/customer_wallet_stub_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _harness() {
  final GoRouter router = GoRouter(
    initialLocation: '/customer-wallet',
    routes: <RouteBase>[
      GoRoute(
        path: '/customer-wallet',
        name: 'customer-wallet',
        builder: (_, _) => const CustomerWalletStubScreen(),
      ),
      GoRoute(path: '/', name: 'shell', builder: (_, _) => const Scaffold()),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.midnight(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child ?? const SizedBox.shrink(),
    ),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  late AppLocalizations l10n;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    l10n = AppLocalizations.of(
      tester.element(find.byType(CustomerWalletStubScreen)),
    );
  }

  testWidgets('field — content variant, ORANGE glow top-start, PERIWINKLE wash '
      'end-mid, still', (tester) async {
    await pump(tester);

    final JeebMidnightField field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.glowPlacement, JeebFieldGlowPlacement.topStart);
    expect(field.washPlacement, JeebFieldWashPlacement.endMid);
    expect(field.animateDecor, isFalse);
    expect(field.glowPlacement!.fx, closeTo(0.12, 0.001));
    expect(field.glowPlacement!.fy, closeTo(-0.08, 0.001));
    expect(field.washPlacement!.fx, closeTo(1.17, 0.001));
    expect(field.washPlacement!.fy, closeTo(0.65, 0.001));
  });

  testWidgets('the headline is the heading ink, NOT the accent — a screen with '
      'no money act spends no orange', (tester) async {
    await pump(tester);

    final Element el = tester.element(
      find.text(l10n.customerWalletStubHeadline),
    );
    final ColorScheme scheme = Theme.of(el).colorScheme;
    final TextStyle style = tester
        .widget<Text>(find.text(l10n.customerWalletStubHeadline))
        .style!;
    expect(style.color, scheme.onSurface);
    expect(style.color, isNot(scheme.primary));
    // §6 h1 — 26/w700/-0.6.
    expect(style.fontSize, 26);
  });

  testWidgets('the body takes inkSoft, the brighter muted rung (§3)', (
    tester,
  ) async {
    await pump(tester);

    final JeebSemanticColors semantic = Theme.of(
      tester.element(find.text(l10n.customerWalletStubBody)),
    ).extension<JeebSemanticColors>()!;
    expect(
      tester.widget<Text>(find.text(l10n.customerWalletStubBody)).style!.color,
      semantic.inkSoft,
    );
  });

  testWidgets('the cash mark is the glass disc rung, not a solid accent glyph',
      (tester) async {
    await pump(tester);

    final ThemeData theme = Theme.of(
      tester.element(find.byIcon(Icons.payments)),
    );
    final JeebSemanticColors glass = theme.extension<JeebSemanticColors>()!;

    final BoxDecoration d = tester
            .widget<Container>(
              find
                  .ancestor(
                    of: find.byIcon(Icons.payments),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;
    expect(d.color, glass.glassFillEmphasis);
    expect(d.color, isNot(theme.colorScheme.surfaceContainerHigh));
    expect(d.border, Border.all(color: glass.glassBorder));

    final Icon glyph = tester.widget<Icon>(find.byIcon(Icons.payments));
    expect(glyph.color, theme.colorScheme.onSurface);
    expect(glyph.color, isNot(theme.colorScheme.primary));
  });

  testWidgets('the single exit is the periwinkle CTA and keeps its frozen id', (
    tester,
  ) async {
    await pump(tester);

    final JeebCtaButton cta = tester.widget<JeebCtaButton>(
      find.byType(JeebCtaButton),
    );
    expect(cta.variant, JeebCtaVariant.primary);
    expect(cta.variant, isNot(JeebCtaVariant.accent));
    expect(
      find.bySemanticsIdentifier('customer_wallet_stub_done'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('customer_wallet_stub'), findsOneWidget);
  });

  testWidgets('still a STUB: no balance, no top-up, no payment affordance', (
    tester,
  ) async {
    await pump(tester);

    for (final String id in <String>[
      'wallet_available_balance',
      'wallet_topup_cta',
      'wallet_gift_badge',
      'wallet_earnings_row',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsNothing, reason: id);
    }
  });
}
