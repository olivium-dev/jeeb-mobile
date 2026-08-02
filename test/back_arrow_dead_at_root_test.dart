// JEBV4-13 P1-6: the AppBar back-ARROW (the OMDSAppBar leading IconButton) was
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _wrapRouter(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

String _locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Finder _appBarBackButton() => find.widgetWithIcon(IconButton, Icons.arrow_back);

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets(
      'offer-kyc-gate: AppBar back arrow at stack root lands on "/", not a '
      'no-op', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('HOME'))),
        ),
        GoRoute(
          path: '/jeeber/offer-gate',
          name: 'offer-kyc-gate',
          builder: (context, state) =>
              OfferKycGateScreen(gateway: FakeKycGateway()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_wrapRouter(router));
    await tester.pumpAndSettle();

    // Stack-REPLACING entry (mirrors jeeber_feed_tab_view's
    router.goNamed('offer-kyc-gate');
    await tester.pumpAndSettle();
    expect(_locationOf(router), '/jeeber/offer-gate');

    await tester.tap(_appBarBackButton());
    await tester.pumpAndSettle();

    expect(_locationOf(router), '/');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets(
      'delivery-register-prompt: AppBar back arrow at stack root lands on '
      '"/", not a no-op', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('HOME'))),
        ),
        GoRoute(
          path: '/jeeber/register-prompt',
          name: 'delivery-register-prompt',
          builder: (context, state) => const DeliveryRegisterPromptScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_wrapRouter(router));
    await tester.pumpAndSettle();

    router.goNamed('delivery-register-prompt');
    await tester.pumpAndSettle();
    expect(_locationOf(router), '/jeeber/register-prompt');

    await tester.tap(_appBarBackButton());
    await tester.pumpAndSettle();

    expect(_locationOf(router), '/');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets(
      'kyc-rejected: AppBar back arrow at stack root lands on '
      'customer-profile, not a no-op', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('HOME'))),
        ),
        GoRoute(
          path: '/customer-profile',
          name: 'customer-profile',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('CUSTOMER_PROFILE'))),
        ),
        GoRoute(
          path: '/kyc/rejected',
          name: 'kyc-rejected',
          builder: (context, state) =>
              KycRejectedScreen(gateway: FakeKycGateway()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_wrapRouter(router));
    await tester.pumpAndSettle();

    // dashboard_tab.dart / notifications_list_screen.dart both reach this via
    router.goNamed('kyc-rejected');
    await tester.pumpAndSettle();
    expect(_locationOf(router), '/kyc/rejected');

    await tester.tap(_appBarBackButton());
    await tester.pumpAndSettle();

    expect(_locationOf(router), '/customer-profile');
    expect(find.text('CUSTOMER_PROFILE'), findsOneWidget);
  });
}
