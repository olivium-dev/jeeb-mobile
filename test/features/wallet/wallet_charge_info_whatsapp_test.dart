// F2 — WhatsApp support CTA on the wallet top-up screen. Extends the
// existing wallet_charge_info_midnight_test.dart harness pattern.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/support/domain/support_contact.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_charge_info_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _forbiddenIds = <String>[
  'charge_info_card_input',
  'charge_info_amount_field',
  'charge_info_store_directory',
];

Widget _harness(WalletChargeInfoScreen screen) {
  final GoRouter router = GoRouter(
    initialLocation: '/wallet/charge-info',
    routes: <RouteBase>[
      GoRoute(
        path: '/wallet/charge-info',
        name: 'wallet-charge-info',
        builder: (_, _) => screen,
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

void main() {
  Future<void> pump(WidgetTester tester, WalletChargeInfoScreen screen) async {
    await tester.pumpWidget(_harness(screen));
    await tester.pumpAndSettle();
  }

  testWidgets('empty number: the whole block is hidden', (tester) async {
    // The shipped default became a live number in 5374575f, so the hidden
    // branch has to be requested explicitly rather than inherited.
    await pump(
      tester,
      const WalletChargeInfoScreen(supportWhatsAppNumberE164: ''),
    );

    expect(
      find.bySemanticsIdentifier('charge_info_whatsapp_note'),
      findsNothing,
    );
    expect(
      find.bySemanticsIdentifier('charge_info_whatsapp_cta'),
      findsNothing,
    );
    // Regression: the store-flow content is unaffected either way.
    expect(
      find.bySemanticsIdentifier('charge_info_store_step'),
      findsOneWidget,
    );
    for (final id in _forbiddenIds) {
      expect(find.bySemanticsIdentifier(id), findsNothing, reason: id);
    }
  });

  testWidgets('shipped default is live, so the block renders out of the box', (
    tester,
  ) async {
    expect(kSupportWhatsAppNumberE164, isNotEmpty);
    await pump(tester, const WalletChargeInfoScreen());

    expect(
      find.bySemanticsIdentifier('charge_info_whatsapp_note'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('charge_info_whatsapp_cta'),
      findsOneWidget,
    );
  });

  testWidgets('populated number: note+CTA render and existing ids survive', (
    tester,
  ) async {
    await pump(
      tester,
      const WalletChargeInfoScreen(supportWhatsAppNumberE164: '+9613000099'),
    );

    expect(
      find.bySemanticsIdentifier('charge_info_whatsapp_note'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('charge_info_whatsapp_cta'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('charge_info_store_step'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('charge_info_identity_step'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('charge_info_pay_cash_step'),
      findsOneWidget,
    );
    for (final id in _forbiddenIds) {
      expect(find.bySemanticsIdentifier(id), findsNothing, reason: id);
    }
  });

  testWidgets(
    'tapping the CTA invokes the injected launcher with the expected wa.me '
    'Uri (no account phone resolved)',
    (tester) async {
      Uri? launchedUri;
      await pump(
        tester,
        WalletChargeInfoScreen(
          supportWhatsAppNumberE164: '+9613000099',
          whatsAppLauncher: (uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      );

      await tester.tap(find.bySemanticsIdentifier('charge_info_whatsapp_cta'));
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri!.scheme, 'https');
      expect(launchedUri!.host, 'wa.me');
      expect(launchedUri!.path, '/9613000099');
      expect(
        launchedUri!.queryParameters['text'],
        'Hi, I would like to add cash-funded Jeeb fee balance.',
      );
    },
  );

  testWidgets(
    'tapping the CTA appends the account-phone sentence when the local '
    'profile resolves one',
    (tester) async {
      Uri? launchedUri;
      await pump(
        tester,
        WalletChargeInfoScreen(
          supportWhatsAppNumberE164: '+9613000099',
          whatsAppLauncher: (uri) async {
            launchedUri = uri;
            return true;
          },
          accountPhoneProvider: () async => '+96170123456',
        ),
      );

      await tester.tap(find.bySemanticsIdentifier('charge_info_whatsapp_cta'));
      await tester.pumpAndSettle();

      expect(
        launchedUri!.queryParameters['text'],
        'Hi, I would like to add cash-funded Jeeb fee balance. '
        'My account phone number is +96170123456.',
      );
    },
  );

  testWidgets(
    'launcher returning false surfaces the fallback, and its Copy action '
    'writes the number to the clipboard',
    (tester) async {
      final List<MethodCall> clipboardCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(
        tester,
        WalletChargeInfoScreen(
          supportWhatsAppNumberE164: '+9613000099',
          whatsAppLauncher: (_) async => false,
        ),
      );

      await tester.tap(find.bySemanticsIdentifier('charge_info_whatsapp_cta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);

      // Let the SnackBar entrance animation finish so the action is hittable.
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(clipboardCalls, hasLength(1));
      expect(
        (clipboardCalls.single.arguments as Map<Object?, Object?>)['text'],
        '+9613000099',
      );
      expect(find.text('Number copied'), findsOneWidget);
    },
  );

  testWidgets(
    'a null launcher (unwired seam) also surfaces the fallback, never a '
    'dead tap',
    (tester) async {
      await pump(
        tester,
        const WalletChargeInfoScreen(supportWhatsAppNumberE164: '+9613000099'),
      );

      await tester.tap(find.bySemanticsIdentifier('charge_info_whatsapp_cta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
    },
  );
}
