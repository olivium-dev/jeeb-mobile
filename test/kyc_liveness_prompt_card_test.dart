import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_liveness_prompt_card.dart';
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
    home: const Scaffold(body: SafeArea(child: _CardHarness())),
  );
}

class _CardHarness extends StatelessWidget {
  const _CardHarness();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KycLivenessPromptCard(
      title: l10n.kycSelfieLivenessPrompt,
      prompts: [
        KycLivenessPrompt(
          icon: Icons.remove_red_eye_outlined,
          text: l10n.kycSelfieLivenessBlink,
        ),
        KycLivenessPrompt(
          icon: Icons.sentiment_satisfied_alt_rounded,
          text: l10n.kycSelfieLivenessSmile,
        ),
      ],
    );
  }
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets(
    'renders the title and both blink + smile prompts (English)',
    (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('Quick liveness check'), findsOneWidget);
      expect(
        find.text('Blink twice while looking at the camera'),
        findsOneWidget,
      );
      expect(
        find.text('Smile gently right after the blink'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.remove_red_eye_outlined), findsOneWidget);
      expect(
        find.byIcon(Icons.sentiment_satisfied_alt_rounded),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders Arabic copy when locale is ar',
    (tester) async {
      await tester.pumpWidget(_host(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('فحص سريع للنشاط'), findsOneWidget);
      expect(
        find.text('أغمض عينيك مرتين أثناء النظر إلى الكاميرا'),
        findsOneWidget,
      );
      expect(
        find.text('ابتسم بلطف بعد الإغماض مباشرة'),
        findsOneWidget,
      );
    },
  );
}
