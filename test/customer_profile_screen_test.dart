import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/features/rate_app/domain/app_review_launcher.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Recording [AppReviewLauncher] double — JM-064 test seam. Counts how many
/// times the Rate-app row asked the OS for a store-review sheet, without
/// touching any platform plugin.
class _RecordingAppReviewLauncher implements AppReviewLauncher {
  int requestCount = 0;

  @override
  Future<void> requestReview() async {
    requestCount++;
  }
}

/// Synchronous ARB-backed localizations delegate so widget tests render the
/// real strings without hitting the asset bundle.
class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) =>
      _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

// A rated, verified, not-yet-Jeeber customer.
const _ratedCustomer = CustomerProfileViewData(
  name: 'Sami Fawaz',
  email: 'kamalhaaj@gmail.com',
  isVerified: true,
  rating: 4.8,
  ratingCount: 42,
);

// An unrated customer (the seeded `user-client-001` carries no rating) — the
const _unratedCustomer = CustomerProfileViewData(
  name: 'Nadia Client',
  isVerified: true,
);

const _jeeberCustomer = CustomerProfileViewData(
  name: 'Kamal Hajj',
  isJeeber: true,
  rating: 4.9,
  ratingCount: 312,
);

/// No GoRouter is provided: the screen runs in fixture-only mode (GetIt is not
/// configured under test, so no live `getMe` fires), and the tests assert on
Widget _harness({
  CustomerProfileViewData data = _ratedCustomer,
  Locale locale = const Locale('en'),
  AppReviewLauncher? reviewLauncher,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: CustomerProfileScreen(data: data, reviewLauncher: reviewLauncher),
  );
}

/// Router-backed harness for the row-navigation assertions. The profile rows
/// (password / language / contact / addresses) now `goNamed`/`pushNamed` REAL
Widget _stubRoot(String id) => Semantics(
      identifier: id,
      container: true,
      child: const Scaffold(body: SizedBox.expand()),
    );

Widget _routerHarness({
  CustomerProfileViewData data = _ratedCustomer,
  Locale locale = const Locale('en'),
}) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => CustomerProfileScreen(data: data),
      ),
      GoRoute(
        path: '/password-security',
        name: 'password-security',
        builder: (context, state) => _stubRoot('password_security_root'),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: router,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(440 * 3, 1400 * 3);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('CustomerProfileScreen (JM-035)', () {
    testWidgets('renders identity (name) for a customer', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(find.text('Sami Fawaz'), findsOneWidget);
      expect(find.text('kamalhaaj@gmail.com'), findsOneWidget);
    });

    testWidgets('shows the Register pill for a non-Jeeber customer',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('hides the Register row once the customer is a Jeeber',
        (tester) async {
      await tester.pumpWidget(_harness(data: _jeeberCustomer));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('customer_profile_register_delivery_row'),
        findsNothing,
      );
      expect(find.text('Register'), findsNothing);
    });

    testWidgets(
        'exposes the EXACT JM-035 Semantics identifiers on header + every row',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // §2.15 contract — header (wallet chip + bell are shell-owned, NOT here).
      for (final id in const [
        'customer_profile_avatar',
        'customer_profile_name',
        'customer_profile_rating',
        'customer_profile_register_delivery_row',
        'customer_profile_password_row',
        'customer_profile_notifications_row',
        'customer_profile_language_row',
        'customer_profile_contact_row',
        'customer_profile_rate_app_row',
        'customer_profile_logout_row',
        'customer_profile_addresses_row',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      handle.dispose();
    });

    testWidgets(
        'rating chip renders (with its id) for an unrated customer too',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(data: _unratedCustomer));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('customer_profile_rating'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('does NOT render the shell-owned wallet chip / bell ids',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      // These are painted by ShellHeaderActions (the shell), never by the
      expect(
        find.bySemanticsIdentifier('customer_profile_wallet_chip'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('customer_profile_bell'),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets(
        'password row navigates to the registered password-security route',
        (tester) async {
      // W3/W4 cross-wave: password-security now EXISTS and is registered, so the
      await tester.pumpWidget(_routerHarness());
      await tester.pumpAndSettle();

      // The tab root hosts the row before the tap.
      expect(find.byKey(CustomerProfileScreen.rootKey), findsOneWidget);

      await tester.tap(
        find.bySemanticsIdentifier('customer_profile_password_row'),
      );
      await tester.pumpAndSettle();

      // Navigated honestly to the registered password-security screen — never an
      expect(
        find.bySemanticsIdentifier('password_security_root'),
        findsOneWidget,
      );
    });

    testWidgets(
        'rate-app row invokes the native review launcher + keeps the tab root '
        'alive (JM-064)', (tester) async {
      final launcher = _RecordingAppReviewLauncher();
      await tester.pumpWidget(_harness(reviewLauncher: launcher));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('customer_profile_rate_app_row'),
      );
      await tester.pump(); // let the fire-and-forget request resolve

      // The OS store-review sheet was requested exactly once (JM-064 AC).
      expect(launcher.requestCount, 1);
      // Returns to Profile — the tab root survives (no route, no crash; AP-9).
      expect(find.byKey(CustomerProfileScreen.rootKey), findsOneWidget);
    });

    testWidgets('renders mirrored Arabic strings under ar locale',
        (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('الحساب'), findsOneWidget); // Account section header
      expect(find.text('الدعم'), findsOneWidget); // Support section header
      expect(
        Directionality.of(
          tester.element(find.byKey(CustomerProfileScreen.rootKey)),
        ),
        TextDirection.rtl,
      );
    });
  });
}
