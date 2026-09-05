// JEBV4-13: the OfflineBanner's DISMISS action was `onTap: () {}` — a dead
// CTA. TEST-11: it was then asserted by `find.text('Dismiss')`, which is blind
// to Arabic and to a copy change, so the banner is now asserted by identifier
// in both locales.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/offline_mode/application/offline_cubit.dart';
import 'package:jeeb_mobile/features/offline_mode/presentation/offline_banner.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// The banner's dismiss target, by id rather than by its visible label.
const String _kDismissId = 'offline_banner_dismiss_cta';

Widget _host(OfflineCubit cubit, {Locale locale = const Locale('en')}) {
  return BlocProvider<OfflineCubit>.value(
    value: cubit,
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: Column(children: <Widget>[OfflineBanner()])),
    ),
  );
}

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets(
      'DISMISS hides the banner and a NEW offline episode re-arms it · '
      '${locale.languageCode}',
      (WidgetTester tester) async {
        final OfflineCubit cubit = OfflineCubit();
        addTearDown(cubit.close);

        await tester.pumpWidget(_host(cubit, locale: locale));
        await tester.pumpAndSettle();
        expect(find.byType(MaterialBanner), findsNothing);

        cubit.setOffline();
        await tester.pumpAndSettle();
        expect(find.byType(MaterialBanner), findsOneWidget);
        expect(find.bySemanticsIdentifier(_kDismissId), findsOneWidget);

        // Previously a no-op: tapping DISMISS left the banner up forever.
        await tester.tap(find.bySemanticsIdentifier(_kDismissId));
        await tester.pump();
        expect(find.byType(MaterialBanner), findsNothing);
        expect(cubit.state.bannerDismissed, isTrue);

        // Back online, then a NEW outage → the banner must return.
        cubit.setOnline();
        await tester.pump();
        cubit.setOffline();
        await tester.pump();
        expect(find.byType(MaterialBanner), findsOneWidget);
      },
    );
  }

  testWidgets('the banner copy promises nothing the app cannot deliver', (
    WidgetTester tester,
  ) async {
    final OfflineCubit cubit = OfflineCubit()..setOffline();
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(MaterialBanner)),
    );
    expect(find.text(l10n.offlineBannerMessage), findsOneWidget);
    expect(
      l10n.offlineBannerMessage.toLowerCase(),
      isNot(contains('sync')),
      reason: 'COPY-11: there is no outbox, so the banner must not promise '
          'that changes will sync when the connection returns',
    );
  });
}
