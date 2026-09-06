// MIDNIGHT M3-13 adoption instruments (wallet-charge-info).
//
// Derived from R4 (04-r4-wallet), the hub whose `+ Top up` CTA is the only way
// here. Read back off the BUILT widget: the golden comparator tolerates 5%
// pixel diff, and the leak this row fixes — three solid `colorScheme.primary`
// discs, i.e. #D73B00 under Midnight — is well inside that tolerance.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_charge_info_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _harness() {
  final GoRouter router = GoRouter(
    initialLocation: '/wallet/charge-info',
    routes: <RouteBase>[
      GoRoute(
        path: '/wallet/charge-info',
        name: 'wallet-charge-info',
        builder: (_, _) => const WalletChargeInfoScreen(),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (_, _) => const Scaffold(),
      ),
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

/// The decorated box the numbered badge paints — found by its digit.
BoxDecoration _badgeDecoration(WidgetTester tester, String digit) {
  final Finder box = find.ancestor(
    of: find.text(digit),
    matching: find.byType(Container),
  );
  return tester.widget<Container>(box.first).decoration! as BoxDecoration;
}

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
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

  testWidgets('the three step badges are the glass disc rung, NOT solid '
      'accent — R4 rations orange to the one money act', (tester) async {
    await pump(tester);

    final ThemeData theme = Theme.of(tester.element(find.text('1')));
    final JeebSemanticColors glass = theme.extension<JeebSemanticColors>()!;

    for (final String digit in <String>['1', '2', '3']) {
      final BoxDecoration d = _badgeDecoration(tester, digit);
      expect(d.color, glass.glassFillEmphasis, reason: 'badge $digit fill');
      expect(d.color, isNot(theme.colorScheme.primary));
      expect(d.border, Border.all(color: glass.glassBorder));
      expect(d.shape, BoxShape.circle);
      // The digit knocks out in the heading ink, not in on-accent white.
      expect(
        tester.widget<Text>(find.text(digit)).style!.color,
        theme.colorScheme.onSurface,
      );
    }
  });

  testWidgets('the single exit is the periwinkle CTA, never the accent', (
    tester,
  ) async {
    await pump(tester);

    final JeebCtaButton cta = tester.widget<JeebCtaButton>(
      find.byType(JeebCtaButton),
    );
    expect(cta.variant, JeebCtaVariant.primary);
    expect(cta.variant, isNot(JeebCtaVariant.accent));
    expect(find.bySemanticsIdentifier('charge_info_back_cta'), findsOneWidget);
  });

  testWidgets('every frozen identifier survives the re-skin', (tester) async {
    await pump(tester);

    for (final String id in <String>[
      'charge_info_root',
      'charge_info_back',
      'charge_info_store_step',
      'charge_info_identity_step',
      'charge_info_pay_cash_step',
      'charge_info_auto_update_note',
      'charge_info_fee_note',
      'charge_info_back_cta',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    }
    // JM-054: the three forbidden payment affordances stay absent.
    for (final String id in <String>[
      'charge_info_card_input',
      'charge_info_amount_field',
      'charge_info_store_directory',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsNothing, reason: id);
    }
  });
}
