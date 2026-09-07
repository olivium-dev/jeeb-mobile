// DEVICE JUDGE F1 (P06 client pending point): a failed or in-flight
// `GET /v1/users/me` must not fabricate an identity on the client home.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_greeting.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThrowsThenPends implements CustomerProfileRepository {
  _ThrowsThenPends({this.failure = const NetworkFailure(offline: true)});

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

class _NamedThenThrows implements CustomerProfileRepository {
  int reads = 0;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    if (++reads == 1) return const CustomerProfileViewData(name: 'Sami Fawaz');
    throw const CustomerProfileRepositoryException.classified(
      CustomerProfileFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }
}

class _Pending implements CustomerProfileRepository {
  final next = Completer<CustomerProfileViewData>();

  @override
  Future<CustomerProfileViewData> fetchProfile() => next.future;
}

Widget _host(
  GreetingProfileCubit cubit,
  Locale locale, {
  String? name,
  double textScale = 1,
}) => wrapForTest(
  BlocProvider<GreetingProfileCubit>.value(
    value: cubit,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        // Production's loading, failed and ready layouts all scroll it.
        child: Scaffold(
          body: ListView(children: [ClientHomeGreeting(name: name)]),
        ),
      ),
    ),
  ),
  locale: locale,
);

AppLocalizations _copy(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ClientHomeGreeting)));

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    for (final scale in [1.0, 1.1, 2.0]) {
      testWidgets('$tag: full profile failure title at text $scale', (
        tester,
      ) async {
        useReduceMotion(tester);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        final cubit = GreetingProfileCubit(repository: _ThrowsThenPends());
        addTearDown(cubit.close);
        await tester.pumpWidget(_host(cubit, locale, textScale: scale));
        await cubit.load();
        await tester.pumpAndSettle();
        final title = find.text(_copy(tester).customerProfileLoadErrorTitle);
        expect(title, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(title);
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'The failure title must be fully visible, not only semantic',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    for (final failure in const <AppFailure>[
      ConflictFailure(),
      ValidationFailure(),
    ]) {
      testWidgets(
        '$tag: ${failure.kind.name} offers a working profile read retry',
        (tester) async {
          useReduceMotion(tester);
          final repo = _ThrowsThenPends(failure: failure);
          final cubit = GreetingProfileCubit(repository: repo);
          addTearDown(cubit.close);
          await tester.pumpWidget(_host(cubit, locale));
          await cubit.load();
          await tester.pumpAndSettle();
          await tester.tap(
            find.bySemanticsIdentifier('client_home_greeting_retry_cta'),
          );
          await tester.pump();
          expect(repo.reads, 2);
          repo.next.complete(const CustomerProfileViewData(name: 'Sami Fawaz'));
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsIdentifier('client_home_greeting_error'),
            findsNothing,
          );
        },
      );
    }

    testWidgets('$tag: a cold read in flight greets nobody', (tester) async {
      useReduceMotion(tester);
      final semantics = tester.ensureSemantics();
      final repo = _Pending();
      final cubit = GreetingProfileCubit(repository: repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale));
      unawaited(cubit.load());
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('client_home_greeting_loading'),
        findsOneWidget,
      );
      expect(find.text(_copy(tester).homeGreetingFallback), findsNothing);
      expect(find.text('?'), findsNothing);

      repo.next.complete(const CustomerProfileViewData(name: 'Sami Fawaz'));
      await tester.pumpAndSettle();
      expect(
        find.text(_copy(tester).homeGreetingNamed('Sami')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('$tag: a failed cold read shows the typed failure rung', (
      tester,
    ) async {
      useReduceMotion(tester);
      final semantics = tester.ensureSemantics();
      final cubit = GreetingProfileCubit(repository: _ThrowsThenPends());
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale));
      await cubit.load();
      await tester.pumpAndSettle();

      final copy = _copy(tester);
      final error = find.bySemanticsIdentifier('client_home_greeting_error');
      expect(error, findsOneWidget);
      expect(
        find.bySemanticsIdentifier('client_home_greeting_retry_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('client_home_greeting_loading'),
        findsNothing,
      );
      expect(find.text(copy.homeGreetingFallback), findsNothing);
      expect(find.text('?'), findsNothing);
      expect(find.text(copy.customerProfileLoadErrorTitle), findsOneWidget);
      expect(find.text(copy.errorNetworkBody), findsOneWidget);
      final node = tester.getSemantics(error);
      expect(
        node.label,
        '${copy.customerProfileLoadErrorTitle}. ${copy.errorNetworkBody}',
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    });

    testWidgets('$tag: the band retry recovers the person in place', (
      tester,
    ) async {
      useReduceMotion(tester);
      final semantics = tester.ensureSemantics();
      final repo = _ThrowsThenPends();
      final cubit = GreetingProfileCubit(repository: repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale));
      await cubit.load();
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('client_home_greeting_retry_cta'),
      );
      await tester.pump();
      await tester.pump();
      expect(repo.reads, 2);
      expect(
        find.bySemanticsIdentifier('client_home_greeting_loading'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('client_home_greeting_error'),
        findsNothing,
      );

      repo.next.complete(const CustomerProfileViewData(name: 'Sami Fawaz'));
      await tester.pumpAndSettle();
      expect(
        find.text(_copy(tester).homeGreetingNamed('Sami')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('client_home_greeting_error'),
        findsNothing,
      );
      expect(find.text('S'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('$tag: session expired is informational without retry', (
      tester,
    ) async {
      useReduceMotion(tester);
      final cubit = GreetingProfileCubit(
        repository: _ThrowsThenPends(failure: const UnauthorizedFailure()),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('client_home_greeting_error'),
        findsOneWidget,
      );
      expect(find.text(_copy(tester).errorSessionExpiredBody), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('client_home_greeting_retry_cta'),
        findsNothing,
      );
    });

    testWidgets('$tag: a warm identity survives a later failed read', (
      tester,
    ) async {
      useReduceMotion(tester);
      final repo = _NamedThenThrows();
      final cubit = GreetingProfileCubit(repository: repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale));
      await cubit.load();
      await tester.pumpAndSettle();
      await cubit.load();
      await tester.pumpAndSettle();

      expect(repo.reads, 2);
      expect(
        find.text(_copy(tester).homeGreetingNamed('Sami')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('client_home_greeting_error'),
        findsNothing,
      );
    });

    testWidgets('$tag: a threaded name keeps the band identified', (
      tester,
    ) async {
      useReduceMotion(tester);
      final cubit = GreetingProfileCubit(repository: _ThrowsThenPends());
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, locale, name: 'Layla'));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(
        find.text(_copy(tester).homeGreetingNamed('Layla')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('client_home_greeting_error'),
        findsNothing,
      );
    });
  }
}
