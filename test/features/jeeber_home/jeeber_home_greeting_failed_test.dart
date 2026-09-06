import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_home_greeting.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _Repository implements CustomerProfileRepository {
  _Repository({this.failure = const NetworkFailure(offline: true)});
  final AppFailure failure;
  final next = Completer<CustomerProfileViewData>();
  int reads = 0;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    if (++reads == 1) {
      throw CustomerProfileRepositoryException.classified(
        CustomerProfileFailure.network,
        appFailure: failure,
      );
    }
    return next.future;
  }
}

class _NamelessThenThrows implements CustomerProfileRepository {
  int reads = 0;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    if (++reads == 1) return const CustomerProfileViewData();
    throw const CustomerProfileRepositoryException.classified(
      CustomerProfileFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }
}

Widget _host(GreetingProfileCubit cubit, Locale locale, {String? name}) =>
    wrapForTest(
      BlocProvider<GreetingProfileCubit>.value(
        value: cubit,
        child: Scaffold(body: JeeberHomeGreeting(name: name)),
      ),
      locale: locale,
    );

AppLocalizations _copy(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(JeeberHomeGreeting)));

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;
    testWidgets('$tag: failed cold profile is honest and announces its body', (
      tester,
    ) async {
      useReduceMotion(tester);
      final semantics = tester.ensureSemantics();
      final cubit = GreetingProfileCubit(repository: _Repository());
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale));
      await cubit.load();
      await tester.pumpAndSettle();
      final copy = _copy(tester);
      final error = find.bySemanticsIdentifier('jeeber_home_greeting_error');
      expect(error, findsOneWidget);
      expect(
        find.bySemanticsIdentifier('jeeber_home_greeting_retry_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_home_greeting_loading'),
        findsNothing,
      );
      expect(find.bySemanticsIdentifier('jeeber_home_avatar'), findsOneWidget);
      expect(find.text(copy.homeGreetingFallback), findsNothing);
      expect(find.text('?'), findsNothing);
      expect(find.text(copy.customerProfileLoadErrorTitle), findsOneWidget);
      expect(find.text(copy.errorNetworkBody), findsOneWidget);
      expect(find.text(copy.jeeberDashboardEyebrow), findsOneWidget);
      final node = tester.getSemantics(error);
      expect(node.label, copy.errorNetworkBody);
      expect(node.flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    });

    for (final trigger in ['tap', 'reconnect', 'resume']) {
      testWidgets('$tag: $trigger recovers a failed read to the real person', (
        tester,
      ) async {
        useReduceMotion(tester);
        final semantics = tester.ensureSemantics();
        final reconnect = StreamController<void>.broadcast(sync: true);
        final resume = StreamController<void>.broadcast(sync: true);
        addTearDown(reconnect.close);
        addTearDown(resume.close);
        final repo = _Repository();
        final cubit = GreetingProfileCubit(
          repository: repo,
          reconnectSignals: reconnect.stream,
          resumeSignals: resume.stream,
        );
        addTearDown(cubit.close);
        await tester.pumpWidget(_host(cubit, locale));
        await cubit.load();
        await tester.pumpAndSettle();
        if (trigger == 'tap') {
          await tester.tap(
            find.bySemanticsIdentifier('jeeber_home_greeting_retry_cta'),
          );
        } else if (trigger == 'reconnect') {
          reconnect.add(null);
        } else {
          resume.add(null);
        }
        await tester.pump();
        await tester.pump();
        expect(repo.reads, 2);
        expect(
          find.bySemanticsIdentifier('jeeber_home_greeting_loading'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('jeeber_home_greeting_error'),
          findsNothing,
        );
        repo.next.complete(
          const CustomerProfileViewData(name: 'Karim TestJeeber'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(_copy(tester).jeeberGreetingAhlan('Karim')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('jeeber_home_greeting_error'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('jeeber_home_greeting_loading'),
          findsNothing,
        );
        expect(find.text('K'), findsOneWidget);
        semantics.dispose();
      });
    }

    testWidgets('$tag: session expired is informational without retry', (
      tester,
    ) async {
      useReduceMotion(tester);
      final cubit = GreetingProfileCubit(
        repository: _Repository(failure: const UnauthorizedFailure()),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale));
      await cubit.load();
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('jeeber_home_greeting_error'),
        findsOneWidget,
      );
      expect(find.text(_copy(tester).errorSessionExpiredBody), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('jeeber_home_greeting_retry_cta'),
        findsNothing,
      );
    });

    testWidgets('$tag: a thrown refresh over a nameless read shows the failed '
        'band, not the fallback', (tester) async {
      useReduceMotion(tester);
      final repo = _NamelessThenThrows();
      final cubit = GreetingProfileCubit(repository: repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale));
      await cubit.load();
      await tester.pumpAndSettle();
      expect(find.text(_copy(tester).homeGreetingFallback), findsOneWidget);
      await cubit.load();
      await tester.pumpAndSettle();
      expect(repo.reads, 2);
      expect(
        find.bySemanticsIdentifier('jeeber_home_greeting_error'),
        findsOneWidget,
      );
      expect(find.text(_copy(tester).homeGreetingFallback), findsNothing);
      expect(find.text('?'), findsNothing);
      expect(
        find.text(_copy(tester).customerProfileLoadErrorTitle),
        findsOneWidget,
      );
      expect(find.text(_copy(tester).errorNetworkBody), findsOneWidget);
    });

    testWidgets('$tag: threaded identity wins over the failed band', (
      tester,
    ) async {
      useReduceMotion(tester);
      final cubit = GreetingProfileCubit(repository: _Repository());
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale, name: 'Kamal'));
      await cubit.load();
      await tester.pumpAndSettle();
      expect(
        find.text(_copy(tester).jeeberGreetingAhlan('Kamal')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_home_greeting_error'),
        findsNothing,
      );
    });
  }
}
