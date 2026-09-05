// F4 (notifications/07-tap-offeraccepted-7d.png): the jeeber header greeted
// "Welcome back" over a '?' disc while GET /users/me was still in flight.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_home_greeting.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// A `getMe` that never lands — the window the device caught. A Completer, not
/// a delayed Future: a pending timer would fail the widget tester on teardown.
class _PendingRepository implements CustomerProfileRepository {
  final Completer<CustomerProfileViewData> _never =
      Completer<CustomerProfileViewData>();

  @override
  Future<CustomerProfileViewData> fetchProfile() => _never.future;
}

/// The F2 outage path: `GET /users/me` ends, with nothing to show for it.
class _FailingRepository implements CustomerProfileRepository {
  @override
  Future<CustomerProfileViewData> fetchProfile() async =>
      throw const CustomerProfileRepositoryException(
        CustomerProfileFailure.network,
      );
}

/// A real account whose profile lands with no name and no avatar.
class _NamelessRepository implements CustomerProfileRepository {
  @override
  Future<CustomerProfileViewData> fetchProfile() async =>
      const CustomerProfileViewData(email: 'x@jeeb.app');
}

void main() {
  Widget harness({
    GreetingProfileState? profile,
    CustomerProfileRepository? repository,
    String? name,
    Locale locale = const Locale('en'),
  }) {
    final Widget greeting = JeeberHomeGreeting(name: name);
    return wrapForTest(
      Scaffold(
        body: (profile == null && repository == null)
            ? greeting
            : BlocProvider<GreetingProfileCubit>(
                create: (_) => GreetingProfileCubit(
                  repository: repository,
                  seed: profile ?? const GreetingProfileState(),
                )..load(),
                child: greeting,
              ),
      ),
      locale: locale,
    );
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(JeeberHomeGreeting)));

  Finder loadingId() =>
      find.bySemanticsIdentifier(JeeberHomeGreeting.loadingIdentifier);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a profile read in flight greets nobody, never the '
        'fallback', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        harness(repository: _PendingRepository(), locale: locale),
      );
      await tester.pump();

      final l10n = l10nOf(tester);
      expect(loadingId(), findsOneWidget);
      expect(find.text(l10n.homeGreetingFallback), findsNothing);
      // The '?' disc is a claim about a person nobody has read yet.
      expect(find.text('?'), findsNothing);
      // The band itself stays: the eyebrow is not profile data.
      expect(find.text(l10n.jeeberDashboardEyebrow), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('jeeber_home_avatar'),
        findsOneWidget,
      );
    });

    testWidgets('[$tag] a landed profile with no name keeps the fallback', (
      tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        harness(
          profile: const GreetingProfileState(avatarUrl: 'https://cdn/a.png'),
          locale: locale,
        ),
      );
      await tester.pump();

      expect(find.text(l10nOf(tester).homeGreetingFallback), findsOneWidget);
      expect(loadingId(), findsNothing);
    });

    testWidgets('[$tag] a profile that LANDS nameless and avatarless falls '
        'back, it does not hang on the pending band', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        harness(repository: _NamelessRepository(), locale: locale),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10nOf(tester).homeGreetingFallback), findsOneWidget);
      expect(loadingId(), findsNothing);
    });

    testWidgets('[$tag] a FAILED getMe falls back, it does not leave a '
        'permanent loading band', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        harness(repository: _FailingRepository(), locale: locale),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10nOf(tester).homeGreetingFallback), findsOneWidget);
      expect(loadingId(), findsNothing);
    });

    testWidgets('[$tag] no ambient cubit keeps the fallback', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(harness(locale: locale));
      await tester.pump();

      expect(find.text(l10nOf(tester).homeGreetingFallback), findsOneWidget);
      expect(loadingId(), findsNothing);
    });
  }

  testWidgets('an ambient cubit with no repository keeps the fallback', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(harness(profile: const GreetingProfileState()));
    await tester.pump();

    expect(find.text(l10nOf(tester).homeGreetingFallback), findsOneWidget);
    expect(loadingId(), findsNothing);
  });

  testWidgets('a resolved name greets that person', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(profile: const GreetingProfileState(name: 'Karim TestJeeber')),
    );
    await tester.pump();

    expect(
      find.text(l10nOf(tester).jeeberGreetingAhlan('Karim')),
      findsOneWidget,
    );
    expect(loadingId(), findsNothing);
  });

  testWidgets('a threaded name is not a pending read', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(repository: _PendingRepository(), name: 'Kamal'),
    );
    await tester.pump();

    expect(
      find.text(l10nOf(tester).jeeberGreetingAhlan('Kamal')),
      findsOneWidget,
    );
    expect(loadingId(), findsNothing);
  });
}
