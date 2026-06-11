import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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

const _verifiedCustomer = CustomerProfileViewData(
  name: 'Sami Fawaz',
  email: 'kamalhaaj@gmail.com',
  isVerified: true,
);

const _jeeberCustomer = CustomerProfileViewData(
  name: 'Sami Fawaz',
  email: 'kamalhaaj@gmail.com',
  isJeeber: true,
);

Widget _harness({
  CustomerProfileViewData data = _verifiedCustomer,
  Locale locale = const Locale('en'),
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
    home: CustomerProfileScreen(data: data),
  );
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(440 * 3, 962 * 3);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('CustomerProfileScreen', () {
    testWidgets('renders header identity + section headers + rows (EN)',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Sami Fawaz'), findsOneWidget);
      expect(find.text('kamalhaaj@gmail.com'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Register as a delivery'), findsOneWidget);
      expect(find.text('Password and security'), findsOneWidget);
      expect(find.text('Notification'), findsOneWidget);
      expect(find.text('Reset my location'), findsOneWidget);
      expect(find.text('Contact us'), findsOneWidget);
      expect(find.text('Rate the app'), findsOneWidget);
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
      expect(find.text('Register as a delivery'), findsNothing);
      expect(find.text('Register'), findsNothing);
    });

    testWidgets('exposes Semantics identifiers on interactive rows',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      for (final id in const [
        'customer_profile_register_delivery_row',
        'customer_profile_register_button',
        'customer_profile_password_security_row',
        'customer_profile_notification_row',
        'customer_profile_reset_location_row',
        'customer_profile_contact_us_row',
        'customer_profile_rate_app_row',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      handle.dispose();
    });

    testWidgets('renders mirrored Arabic strings under ar locale',
        (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('الملف الشخصي'), findsOneWidget);
      expect(find.text('الحساب'), findsOneWidget);
      expect(find.text('الدعم'), findsOneWidget);
      expect(find.text('تسجيل'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(CustomerProfileScreen.rootKey)),
        ),
        TextDirection.rtl,
      );
    });
  });
}
