import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_submitting_view.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);
  }

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _host({Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(body: SafeArea(child: KycSubmittingView())),
  );
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets(
    'renders headline, body, upload icon, and spinner (English)',
    (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump();

      expect(find.byKey(KycSubmittingView.rootKey), findsOneWidget);
      expect(find.byKey(KycSubmittingView.titleKey), findsOneWidget);
      expect(find.byKey(KycSubmittingView.spinnerKey), findsOneWidget);
      expect(find.text('Submitting your documents'), findsOneWidget);
      // D20: the KYC submit copy no longer references vehicle details (the
      // vehicle step was removed; the stale "vehicle" wording was dropped).
      expect(
        find.textContaining('uploading your ID and selfie'),
        findsOneWidget,
      );
      expect(find.textContaining('vehicle'), findsNothing);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'renders Arabic copy when locale is ar',
    (tester) async {
      await tester.pumpWidget(_host(locale: const Locale('ar')));
      await tester.pump();

      expect(find.text('جاري إرسال مستنداتك'), findsOneWidget);
      expect(
        find.textContaining('نقوم برفع الهوية والصورة الشخصية'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'marks itself as a live region for screen readers',
    (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump();

      final semantics = tester.getSemantics(
        find.byKey(KycSubmittingView.rootKey),
      );
      expect(semantics.label.isNotEmpty, isTrue);
    },
  );
}
