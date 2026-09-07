// WP7-N4: with no SupportRepository registered, a release build must NOT
// confirm a fabricated ticket.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/support/application/support_cubit.dart';
import 'package:jeeb_mobile/features/support/data/stub_support_repository.dart';
import 'package:jeeb_mobile/features/support/data/unavailable_support_repository.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

void main() {
  Widget harness(SupportCubit cubit, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        theme: AppTheme.midnight(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: SupportTicketScreen(cubit: cubit),
      );

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  SupportCubit seeded(SupportRepository repo) => SupportCubit(repo)
    ..setCategory(SupportCategory.delivery)
    ..setBody('My delivery never arrived.');

  test(
    'the unavailable repository throws rather than fabricating a ticket',
    () {
      expect(
        () => const UnavailableSupportRepository().submitTicket(
          const SupportTicketDraft(
            category: SupportCategory.other,
            body: 'help',
            operationId: 'op-1',
          ),
        ),
        throwsA(isA<SupportRepositoryException>()),
      );
    },
  );

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets(
      '[${locale.languageCode}] the release fallback ends in support_error, '
      'not a confirmation',
      (tester) async {
        useReduceMotion(tester);
        final cubit = seeded(const UnavailableSupportRepository());
        await cubit.submit();
        await tester.pumpWidget(harness(cubit, locale: locale));
        await tester.pumpAndSettle();

        expect(byId('support_error'), findsOneWidget);
        expect(byId('support_confirmation'), findsNothing);
        expect(byId('support_view_thread_cta'), findsNothing);
      },
    );
  }

  testWidgets('the debug stub still confirms, for the catalog', (tester) async {
    useReduceMotion(tester);
    final cubit = seeded(const StubSupportRepository());
    await cubit.submit();
    await tester.pumpWidget(harness(cubit));
    await tester.pumpAndSettle();

    expect(byId('support_confirmation'), findsOneWidget);
    expect(byId('support_error'), findsNothing);
  });
}
