// F4 (outage-jeeber/23-profile-retry-t2.xml): the retry window drew
// `customer_profile_loading` WITH a '?' avatar. A blank load draws the rung alone.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_status_block.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// A `getMe` the test lands or fails by hand, so the in-flight window is a
/// frame the test can inspect.
class _GatedRepository implements CustomerProfileRepository {
  final List<Completer<CustomerProfileViewData>> reads =
      <Completer<CustomerProfileViewData>>[];

  @override
  Future<CustomerProfileViewData> fetchProfile() {
    final completer = Completer<CustomerProfileViewData>();
    reads.add(completer);
    return completer.future;
  }

  void failPendingRead() => reads.last.completeError(
    const CustomerProfileRepositoryException.classified(
      CustomerProfileFailure.network,
      appFailure: NetworkFailure(offline: true),
    ),
  );

  void landPendingRead(CustomerProfileViewData data) =>
      reads.last.complete(data);
}

void main() {
  Widget harness({
    required CustomerProfileRepository repository,
    CustomerProfileViewData data = const CustomerProfileViewData(),
    Locale locale = const Locale('en'),
  }) {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: <RouteBase>[
        GoRoute(
          path: '/profile',
          builder: (_, _) =>
              CustomerProfileScreen(data: data, repository: repository),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
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
    );
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  /// The three nodes the device XML caught riding the loading rung.
  const List<String> placeholderIds = <String>[
    'customer_profile_avatar',
    'customer_profile_name',
    'customer_profile_rating',
  ];

  void expectLoadingRungAlone(WidgetTester tester) {
    expect(byId(CustomerProfileStatusBlock.loadingIdentifier), findsOneWidget);
    expect(byId(CustomerProfileStatusBlock.errorIdentifier), findsNothing);
    for (final id in placeholderIds) {
      expect(byId(id), findsNothing, reason: id);
    }
    final l10n = AppLocalizations.of(
      tester.element(byId(CustomerProfileStatusBlock.loadingIdentifier)),
    );
    expect(find.text(l10n.profileNamePlaceholder), findsNothing);
    expect(find.text(l10n.deliveryManProfileEmptyReviewsTitle), findsNothing);
    // Signing out survives a read that has not landed.
    expect(byId('customer_profile_logout_row'), findsOneWidget);
  }

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] F4 · the FIRST load draws the loading rung alone', (
      tester,
    ) async {
      useReduceMotion(tester);
      final repository = _GatedRepository();
      await tester.pumpWidget(harness(repository: repository, locale: locale));
      await tester.pump();

      expectLoadingRungAlone(tester);
    });

    testWidgets('[$tag] F4 · the RETRY window draws the loading rung alone', (
      tester,
    ) async {
      useReduceMotion(tester);
      final repository = _GatedRepository();
      await tester.pumpWidget(harness(repository: repository, locale: locale));
      await tester.pump();

      repository.failPendingRead();
      await tester.pumpAndSettle();
      expect(byId(CustomerProfileStatusBlock.errorIdentifier), findsOneWidget);

      await tester.tap(byId(CustomerProfileStatusBlock.retryIdentifier));
      await tester.pump();

      expectLoadingRungAlone(tester);
      expect(repository.reads, hasLength(2));
    });

    testWidgets('[$tag] F4 · a landed profile with an unset name still shows '
        'its placeholder', (tester) async {
      useReduceMotion(tester);
      final repository = _GatedRepository();
      await tester.pumpWidget(harness(repository: repository, locale: locale));
      await tester.pump();

      repository.landPendingRead(
        const CustomerProfileViewData(email: 'karim@example.com'),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(byId('customer_profile_name')));
      expect(find.text(l10n.profileNamePlaceholder), findsOneWidget);
      for (final id in placeholderIds) {
        expect(byId(id), findsOneWidget, reason: id);
      }
      expect(byId(CustomerProfileStatusBlock.loadingIdentifier), findsNothing);
    });

    testWidgets('[$tag] F4 · a refresh over a real profile keeps the card', (
      tester,
    ) async {
      useReduceMotion(tester);
      final repository = _GatedRepository();
      await tester.pumpWidget(
        harness(
          repository: repository,
          data: const CustomerProfileViewData(name: 'Karim TestJeeber'),
          locale: locale,
        ),
      );
      await tester.pump();

      // The seeded profile is real data: the load in flight over it must NOT
      // blank the identity card.
      expect(byId('customer_profile_name'), findsOneWidget);
      expect(find.text('Karim TestJeeber'), findsOneWidget);
    });
  }

  testWidgets('the identity name is announced once, not twice', (tester) async {
    final handle = tester.ensureSemantics();
    useReduceMotion(tester);
    final repository = _GatedRepository();
    await tester.pumpWidget(
      harness(
        repository: repository,
        data: const CustomerProfileViewData(name: 'Karim TestJeeber'),
      ),
    );
    await tester.pump();

    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsIdentifier('customer_profile_name'),
    );
    expect(node.label, 'Karim TestJeeber');
    handle.dispose();
  });
}
