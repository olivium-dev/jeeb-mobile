import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_id_alignment_guide.dart';
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
    home: const Scaffold(
      body: SizedBox(
        width: 360,
        child: _AlignmentGuideHarness(),
      ),
    ),
  );
}

class _AlignmentGuideHarness extends StatelessWidget {
  const _AlignmentGuideHarness();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KycIdAlignmentGuide(
      title: l10n.kycIdAlignmentGuideTitle,
      caption: l10n.kycIdAlignmentGuideCaption,
    );
  }
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets(
    'renders frame with localized caption and ID-1 aspect ratio',
    (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.byKey(KycIdAlignmentGuide.rootKey), findsOneWidget);
      expect(find.byKey(KycIdAlignmentGuide.frameKey), findsOneWidget);
      expect(
        find.text('Place the card flat, fill the frame, and avoid glare.'),
        findsOneWidget,
      );

      final aspect = tester.widget<AspectRatio>(
        find.ancestor(
          of: find.byKey(KycIdAlignmentGuide.frameKey),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(
        aspect.aspectRatio,
        closeTo(KycIdAlignmentGuide.idCardAspectRatio, 1e-9),
      );
    },
  );

  testWidgets(
    'renders Arabic caption when locale is ar',
    (tester) async {
      await tester.pumpWidget(_host(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(
        find.text('ضع البطاقة مسطحة، واملأ الإطار، وتجنّب الانعكاسات.'),
        findsOneWidget,
      );
    },
  );
}
